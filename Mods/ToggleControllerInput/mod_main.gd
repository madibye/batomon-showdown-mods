extends Node

const Loader := preload("res://Mods/mod_loader.gd")

var _started := false
var loader: Loader
var _input_manager_script: Script
var _mod_input_manager

func mod_ready():
	if _started: return
	_started = true
	loader = get_node("/root/ModLoader")
	_input_manager_script = load("res://Mods/ToggleControllerInput/mod_input_manager.gd")
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(node):
	_on_node_added(node)
	for child in node.get_children(): _scan(child)

func _on_node_added(node: Node):
	var script = node.get_script()
	# node_added runs before _ready, so inherited onready fields initialize normally.
	if _input_manager_script != null and script != null and script.resource_path.get_file().get_basename() == "input_manager":
		node.set_script(_input_manager_script)
		_mod_input_manager = node
