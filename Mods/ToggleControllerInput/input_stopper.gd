extends Node

const Loader := preload("res://Mods/mod_loader.gd")

var loader: Loader

func _input(event):
	var controller_input_config: bool = loader.get_config("toggle_controller_input", "controller_input", true)
	if not controller_input_config and UiNav.is_controller_event(event):
		get_viewport().set_input_as_handled()
