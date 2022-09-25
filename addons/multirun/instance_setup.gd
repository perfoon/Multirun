extends Node


#-------------------------------------------------------------------------------
# A per-instance setup for multirun instances
# Transforms instance windows according to passed cmdline arguments
# And exposes an instance-specific 'user://' subfolder
# And can be used to manually write things like settings and save files
#-------------------------------------------------------------------------------


# When running multiple game instances you might want to have separate 'user://' folders for each
# So you can store settings and data unique to these instances
# When launched with an argument '--user_subfolder=path' 'path' will be appended to the current 'user://' dir
# Otherwise will refer to 'user://' dir
# Settings that are to be separate for each instance should use THIS path instead of 'user://'
var instance_user_dir: String = ''




func _ready():
	setup_instance(parse_cmdline_args())


# Parse cmdline arguments into a Dictionaey
# Stripping all special symbols
func parse_cmdline_args() -> Dictionary:
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			# Options without an argument might be present in the dictionary,
			# With the value set to an empty string.
			arguments[argument.lstrip("--")] = ""
	return arguments


# Set this instance up according to passed arguments
# Mostly related to window transform
func setup_instance(arguments: Dictionary):
	instance_user_dir = 'user://'
	var decorations_size = OS.get_real_window_size() - OS.window_size
	
	for arg_name in arguments:
		var arg_val = arguments[arg_name]
		match arg_name:
			
			'window_pos_x':
				OS.window_position = Vector2(int(arg_val), OS.window_position.y)
			
			'window_pos_y':
				OS.window_position = Vector2(OS.window_position.x, int(arg_val))
			
			'window_size_x':
				OS.window_size = Vector2(int(arg_val), OS.window_size.y)
			
			'window_size_y':
				OS.window_size = Vector2(OS.window_size.x, int(arg_val))
			
			'window_title':
				OS.set_window_title(arguments.window_title)
			
			'user_subfolder':
				instance_user_dir += arg_val
				instance_user_dir.replace('\\', '/')
				if !instance_user_dir.ends_with('/'):
					instance_user_dir += '/'
				Directory.new().make_dir_recursive(instance_user_dir)
	
	OS.window_size -= decorations_size


# Get full path to dir/file with the instance dir path
# If we were to replicate 'user://dir/file.cfg'
# We would pass just 'dir/file.cfg'
# And receive 'user://instance_user_dir/dir/file.cfg'
func get_user_path(relative_path: String) -> String:
	return instance_user_dir + relative_path
