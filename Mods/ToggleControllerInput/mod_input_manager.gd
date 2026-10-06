extends InputManager

const Loader := preload("res://Mods/mod_loader.gd")

var loader: Loader

func _init():
	loader = get_node("/root/ModLoader")
	loader.config_changed.connect(_config_changed)
	
func _config_changed():
	_set_using_controller(_using_controller, _using_gamepad)

func _set_using_controller(on: bool, gamepad: bool) -> void:
	var controller_input_setting: bool = loader.get_config("toggle_controller_input", "controller_input", true)
	if not controller_input_setting:
		_using_controller = false
		_using_gamepad = false
		_apply_mouse_mode()
		changed.emit(false)
		return
	super(on, gamepad)
