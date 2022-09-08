tool
extends EditorPlugin


#-------------------------------------------------------------------------------
# Due to plugin's size, everything is handled here
# Besides per-instance setup
#-------------------------------------------------------------------------------


const PTH_NUMBER_OF_WINDOWS: String 			= 'multirun/settings/number_of_windows'
const PTH_DISTANCE_BETWEEN_WINDOWS: String 		= 'multirun/settings/distance_between_window'
const PTH_INDIVIDUAL_INSTANCE_ARGS: String 		= 'multirun/settings/individual_instance_args'
const PTH_ADD_INDIVIDUAL_INSTANCE_ARGS: String 	= 'multirun/settings/add_individual_instance_args'
const PTH_USER_DIR_SHORTCUT: String 			= 'multirun/shortcuts/user_dir'
const PTH_RUN_SHORTCUT: String 					= 'multirun/shortcuts/run'
const PTH_STOP_SHORTCUT: String 				= 'multirun/shortcuts/stop'


var icons: Dictionary = {}
var button_user_dir: ToolButton = null
var button_run: ToolButton = null
var button_stop: ToolButton = null

var instance_pids: Array = []
var are_instances_running: bool = false setget _set_are_instances_running
var refresh_timer: Timer = Timer.new()
var refresh_wait_time: float = 0.5




#-------------------------------------------------------------------------------
# Lifecycle
#-------------------------------------------------------------------------------


func _ready():
	add_autoload_singleton('MultirunInstanceSetup', 'res://addons/multirun/instance_setup.gd')
	_setup_refresh_timer()


func _enter_tree():
	_cache_icons()
	_add_settings()
	_add_buttons()
	ProjectSettings.connect('project_settings_changed', self, '_on_project_settings_changed')


func _exit_tree():
	_remove_buttons()
	kill_all_instances()
	ProjectSettings.disconnect('project_settings_changed', self, '_on_project_settings_changed')


# We want to update run button icon when no instances are running
# But doing so requires constant polling, so we due it at small intervals
func _setup_refresh_timer():
	refresh_timer.wait_time = refresh_wait_time
	refresh_timer.autostart = true
	refresh_timer.one_shot = false
	refresh_timer.connect('timeout', self, '_refresh_state')
	add_child(refresh_timer)


# Refresh our plugin state periodically
func _refresh_state(): 
	if !_is_any_instance_running() && are_instances_running:
		_stop_pressed()




#-------------------------------------------------------------------------------
# UI management
#-------------------------------------------------------------------------------


# Cache icons so we won't have to query for them again
func _cache_icons():
	var editor_node = get_tree().get_root().get_child(0)
	var gui_base = editor_node.get_gui_base()
	icons.load 			= gui_base.get_icon("Load", "EditorIcons")
	icons.transition 	= gui_base.get_icon("TransitionSync", "EditorIcons")
	icons.stop 			= gui_base.get_icon("Stop", "EditorIcons")
	icons.rotate_left	= gui_base.get_icon("RotateLeft", "EditorIcons")


func _add_buttons():
	button_user_dir = _add_toolbar_button(
		"_user_dir_pressed", icons.load, 
		ProjectSettings.get_setting(PTH_USER_DIR_SHORTCUT),
		'Open "user://" directory.')
	
	button_run = _add_toolbar_button(
		"_run_pressed", icons.transition, 
		ProjectSettings.get_setting(PTH_RUN_SHORTCUT),
		'Run multiple instances of the main scene.')
	
	button_stop = _add_toolbar_button(
		"_stop_pressed", icons.stop,
		ProjectSettings.get_setting(PTH_STOP_SHORTCUT),
		'Stop all running instances of the main scene.')


func _remove_buttons():
	if button_run:
		remove_control_from_container(CONTAINER_TOOLBAR, button_run)
		button_run.queue_free()
	if button_user_dir:
		remove_control_from_container(CONTAINER_TOOLBAR, button_user_dir)
		button_user_dir.queue_free()
	if button_stop:
		remove_control_from_container(CONTAINER_TOOLBAR, button_stop)
		button_stop.queue_free()


func _add_toolbar_button(method_name: String, icon, shortcut: Dictionary = {}, tooltip: String = '') -> ToolButton:
	var button = ToolButton.new();
	add_control_to_container(CONTAINER_TOOLBAR, button)
	
	button.icon = icon
	if shortcut:
		button.shortcut = _shortcut_from_dict(shortcut)
		button.shortcut_in_tooltip = true
	button.hint_tooltip = tooltip
	button.connect("pressed", self, method_name)
	
	return button


func _update_run_button_icon():
	if are_instances_running:
		button_run.icon = icons.rotate_left
	else:
		button_run.icon = icons.transition




#-------------------------------------------------------------------------------
# UI events/signals
#-------------------------------------------------------------------------------


func _user_dir_pressed():
	open_user_data_dir()


func _run_pressed():
	run_all_instances()


func _stop_pressed():
	kill_all_instances()




#-------------------------------------------------------------------------------
# Project settings management
#-------------------------------------------------------------------------------


func _add_settings():
	_add_setting(PTH_NUMBER_OF_WINDOWS, TYPE_INT, 4)
	_add_setting(PTH_DISTANCE_BETWEEN_WINDOWS, TYPE_INT, 0)
	# This is a trick to simplify adding new instance args
	# Same as we would use in Inspector properties to trigger some kind of change|
	# Basically acts as a button
	_add_setting(PTH_ADD_INDIVIDUAL_INSTANCE_ARGS, TYPE_BOOL, false)
	# A Dictionary of 
	#	{ 'window_idx': args:String }
	# A key of '-1' would mean arguments applied to ALL windows
	# Except those with an individual override in the same dictionary
	# NOTE: Overrides do not combine arguments, they replaces the whole argument string
	_add_setting(PTH_INDIVIDUAL_INSTANCE_ARGS, TYPE_DICTIONARY, {})
	
	var user_dir_shortcut := mk_dummy_shortcut_dict()
	user_dir_shortcut.scancode = KEY_F9
	user_dir_shortcut.control = true
	_add_setting(PTH_USER_DIR_SHORTCUT, TYPE_DICTIONARY, user_dir_shortcut)
	
	var run_shortcut := mk_dummy_shortcut_dict()
	run_shortcut.scancode = KEY_F5
	run_shortcut.control = true
	_add_setting(PTH_RUN_SHORTCUT, TYPE_DICTIONARY, run_shortcut)
	
	var stop_shortcut := mk_dummy_shortcut_dict()
	stop_shortcut.scancode = KEY_F8
	stop_shortcut.control = true
	_add_setting(PTH_STOP_SHORTCUT, TYPE_DICTIONARY, stop_shortcut)


# To ease adding new instance args, we query ProjectSettings for changes
# Add create a placeholder for each individual_instance_args entry
func _on_project_settings_changed():
	var individual_instance_args: Dictionary 	= ProjectSettings.get_setting(PTH_INDIVIDUAL_INSTANCE_ARGS)
	var add_individual_instance_args: bool 		= ProjectSettings.get_setting(PTH_ADD_INDIVIDUAL_INSTANCE_ARGS)
	
	if add_individual_instance_args:
		ProjectSettings.call_deferred('set_setting', PTH_ADD_INDIVIDUAL_INSTANCE_ARGS, false)
		
		var window_idx = -1
		if individual_instance_args.size() > 0:
			window_idx = individual_instance_args.keys()[individual_instance_args.size() - 1] + 1
		individual_instance_args[window_idx] = ''
	
	for window_idx in individual_instance_args:
		if !(individual_instance_args[window_idx] is String):
			individual_instance_args[window_idx] = ''
	
	ProjectSettings.set_setting(PTH_INDIVIDUAL_INSTANCE_ARGS, individual_instance_args)


# Shorthand for adding a setting
func _add_setting(name:String, type, value):
	if ProjectSettings.has_setting(name):
		return
	ProjectSettings.set(name, value)
	var property_info = {
		"name": name,
		"type": type
	}
	ProjectSettings.add_property_info(property_info)




#-------------------------------------------------------------------------------
# Instance management
#-------------------------------------------------------------------------------


func run_all_instances():
	kill_all_instances()
	
	var window_count: int 						= ProjectSettings.get_setting(PTH_NUMBER_OF_WINDOWS)
	# Later on we will mix in distance between adjacent windows
	# I don't know why someone might need it, but here it is
	var window_dist: int 						= ProjectSettings.get_setting(PTH_DISTANCE_BETWEEN_WINDOWS)
	var individual_instance_args: Dictionary 	= ProjectSettings.get_setting(PTH_INDIVIDUAL_INSTANCE_ARGS)
	var main_run_args: Array		 			= PoolStringArray(ProjectSettings.get_setting("editor/main_run_args").split(' '))
	
	# We make some assumptions on how windows are laid out
	# But this guess is fairly good for up to 12 instances
	# More than 8 seems excess anyways
	var screen_size := get_available_screen_size()
	var columns := int(ceil(window_count / 3.0))
	var rows := int(ceil(float(window_count) / columns))
	screen_size -= Vector2(window_dist * (columns - 1), window_dist * (rows - 1))
	
	for i in range(0, window_count):
		var size := screen_size / Vector2(columns, rows)
		var pos := Vector2()
		pos.x = (i % columns) * (screen_size.x / columns) + (i % columns) * window_dist
		pos.y = (i / columns) * (screen_size.y / rows) + (i / columns) * window_dist
		
		var instance_args := [
			'--window_pos_x=%d' % [int(pos.x)],
			'--window_pos_y=%d' % [int(pos.y)],
			'--window_size_x=%d' % [int(size.x)],
			'--window_size_y=%d' % [int(size.y)],
			'--window_title="Instance %d"' % [i] if i != 0 else '--window_title="Instance %d Main"' % [i],
			'--user_subfolder="multirun_inst_%d"' % [i]
		]
		
		# We assume the main scene and our additional instances have an equal status (i.e. "A game being launched")
		# Thus all arguments passed to the main scene on regular 'Run' (from ProjectSettings)
		# Should be passed to our instances as well
		instance_args.append_array(main_run_args)
		
		# Append per-instance arguments if present
		if individual_instance_args.has(i):
			instance_args.append_array(individual_instance_args[i].split(' '))
		# Append defualt arguments for all instances if present
		elif individual_instance_args.has(-1):
			instance_args.append_array(individual_instance_args[-1].split(' '))
		
		# If running first instance, run it through intended/native means
		if i == 0:
			run_main_instance(instance_args, main_run_args)
		# If not, run executable with arguments
		else:
			instance_pids.append(OS.execute(OS.get_executable_path(), instance_args, false, [], false, true))
	
	_set_are_instances_running(true)


# We want to feed our arguments to the main scene as well
# But to preserve the project setting, we need to set it to previous value
# After we're done
func run_main_instance(instance_args: Array, main_run_args: Array):
	var interface = get_editor_interface()
	ProjectSettings.set_setting("editor/main_run_args", PoolStringArray(instance_args).join(' '))
	interface.play_main_scene()
	ProjectSettings.set_setting("editor/main_run_args",  PoolStringArray(main_run_args).join(' '))


func kill_all_instances():
	_kill_main_instance()
	
	for pid in instance_pids:
		OS.kill(pid)
	instance_pids = []
	
	_set_are_instances_running(false)


func _kill_main_instance():
	var interface = get_editor_interface()
	interface.stop_playing_scene()


func _set_are_instances_running(val):
	are_instances_running = val
	_update_run_button_icon()


func _is_any_instance_running():
	for pid in instance_pids:
		if OS.is_process_running(pid):
			return true
	
	var interface := get_editor_interface()
	if interface.is_playing_scene():
		return true
	
	return false




#-------------------------------------------------------------------------------
# Misc
#-------------------------------------------------------------------------------


# Opening a user dir can be relevant if we need to test settings/save files
# Being written for each instance ran
func open_user_data_dir():
	OS.shell_open(OS.get_user_data_dir())


# Get the screen size that is left after excluding screen-occupying elements
# Like Windows taskbar
func get_available_screen_size() -> Vector2:
	var prev_maximized = OS.window_maximized
	OS.window_maximized = true
	var screen_size = OS.get_real_window_size()
	OS.window_maximized = prev_maximized
	return screen_size



func _shortcut_from_dict(dict: Dictionary) -> ShortCut:
	var shortcut = ShortCut.new()
	shortcut.shortcut = InputEventKey.new()
	shortcut.shortcut.scancode 	= dict.scancode
	shortcut.shortcut.alt 		= dict.alt
	shortcut.shortcut.shift 	= dict.shift
	shortcut.shortcut.meta 		= dict.meta
	shortcut.shortcut.command 	= dict.command
	shortcut.shortcut.control 	= dict.control
	return shortcut


func mk_dummy_shortcut_dict() -> Dictionary:
	return {
		'scancode': -1,
		'alt': 		false,
		'shift': 	false,
		'control': 	false,
		'meta': 	false,
		'command': 	false,
	}
