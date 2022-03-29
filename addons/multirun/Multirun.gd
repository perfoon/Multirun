tool
extends EditorPlugin

# Mac: If your Godot app isn't in this folder path, it will need to be updated for multirun to work
const godot_editor_file_path_mac = "/Applications/Godot.app/Contents/MacOS/Godot"

var panel1
var panel2
var pids = []

func _enter_tree():
	var editor_node = get_tree().get_root().get_child(0)
	var gui_base = editor_node.get_gui_base()
	var icon_transition = gui_base.get_icon("TransitionSync", "EditorIcons") #ToolConnect
	var icon_transition_auto = gui_base.get_icon("TransitionSyncAuto", "EditorIcons")
	var icon_load = gui_base.get_icon("Load", "EditorIcons")
	
	panel2 = _add_toolbar_button("_loaddir_pressed", icon_load, icon_load)
	panel1 = _add_toolbar_button("_multirun_pressed", icon_transition, icon_transition_auto)
	
	_add_setting("debug/multirun/number_of_windows", TYPE_INT, 2)
	_add_setting("debug/multirun/window_distance", TYPE_INT, 1270)
	_add_setting("debug/multirun/add_custom_args", TYPE_BOOL, true)
	_add_setting("debug/multirun/first_window_args", TYPE_STRING, "listen")
	_add_setting("debug/multirun/other_window_args", TYPE_STRING, "join")

func _multirun_pressed():
	var window_count : int = ProjectSettings.get_setting("debug/multirun/number_of_windows")
	var window_dist : int = ProjectSettings.get_setting("debug/multirun/window_distance")
	var add_custom_args : bool = ProjectSettings.get_setting("debug/multirun/add_custom_args")
	var first_args : String = ProjectSettings.get_setting("debug/multirun/first_window_args")
	var other_args : String = ProjectSettings.get_setting("debug/multirun/other_window_args")
	var commands = ["--position", "50,10"]
	if first_args && add_custom_args:
		for arg in first_args.split(" "):
			commands.push_front(arg)

	var main_run_args = ProjectSettings.get_setting("editor/main_run_args")
	if main_run_args != first_args:
		ProjectSettings.set_setting("editor/main_run_args", first_args)
	var interface = get_editor_interface()
	interface.play_main_scene()
	if main_run_args != first_args:
		ProjectSettings.set_setting("editor/main_run_args", main_run_args)

	kill_pids()
	for i in range(window_count-1):
		commands = ["--position", str(50 + (i+1) * window_dist) + ",10"]
		if other_args && add_custom_args:
			for arg in other_args.split(" "):
				commands.push_front(arg)
		# If mac, then need different path
		if OS.get_name() == "OSX":
			# For some reason, executing multiple shell commands on one OS.execute wouldn't work correctly
			# but it works when just executing one command per OS.execute, so 2 are needed here
			OS.execute('cd', [ProjectSettings.globalize_path("res://")], true)
			pids.append(OS.execute(godot_editor_file_path_mac, commands, false))
		else:
			pids.append(OS.execute(OS.get_executable_path(), commands, false))	

func _loaddir_pressed():
	OS.shell_open(OS.get_user_data_dir())

func _exit_tree():
	_remove_panels()
	kill_pids()
	
func kill_pids():
	for pid in pids:
		OS.kill(pid)
	pids = []

func _remove_panels():
	if panel1:
		remove_control_from_container(CONTAINER_TOOLBAR, panel1)
		panel1.free()
	if panel2:
		remove_control_from_container(CONTAINER_TOOLBAR, panel2)
		panel2.free()

func _unhandled_input(event):	
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_F4:
			_multirun_pressed()

func _add_toolbar_button(action:String, icon_normal, icon_pressed):
	var panel = PanelContainer.new()
	var b = TextureButton.new();
	b.texture_normal = icon_normal
	b.texture_pressed = icon_pressed
	b.connect("pressed", self, action)
	panel.add_child(b)
	add_control_to_container(CONTAINER_TOOLBAR, panel)
	return panel
	
func _add_setting(name:String, type, value):
	if ProjectSettings.has_setting(name):
		return
	ProjectSettings.set(name, value)
	var property_info = {
		"name": name,
		"type": type
	}
	ProjectSettings.add_property_info(property_info)
