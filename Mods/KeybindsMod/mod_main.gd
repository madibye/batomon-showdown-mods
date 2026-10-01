extends Node

const OVERLAY_NAME = "KeybindsMod"
const KEYBINDS_CONF_PATH = "res://Mods/KeybindsMod/keybinds.json"
const SettingsEntryKeybind := preload("res://Mods/KeybindsMod/settings_entry_keybind.gd")
const KEYBIND_LISTENER_SCRIPTS = [
	"shop_ui",
	"trainer_select_state",
	"team_overlay",
]
const OTHER_SCRIPTS = [
	"settings_menu"
]
const KEYBIND_ACTIONS_DEFAULTS = {
	&"request_battle": "k4194309",
	&"reroll_shop": "k82",
	&"show_dex": "k68",
	&"show_settings": "k70",
	&"show_trinkets": "k84"
}
const KEYBIND_ACTIONS_NAMES = {
	&"request_battle": "Start Battle",
	&"reroll_shop": "Reroll Shop",
	&"show_dex": "Toggle Batopedia",
	&"show_settings": "Toggle Settings",
	&"show_trinkets": "Toggle Trinkets UI"
}

var _started = false
var nodes: Dictionary[String, WeakRef] = {}
var _using_controller: bool:
	get: return InputManager.is_using_controller()
var loader: Node

func mod_ready():
	if _started: return
	_started = true
	loader = get_node("/root/ModLoader")
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)
	var rfile = FileAccess.open(KEYBINDS_CONF_PATH, FileAccess.READ)
	var parsed_str
	if rfile:
		parsed_str = JSON.parse_string(rfile.get_as_text())
		rfile.close()
	var keybind_conf: Dictionary = {} if (not parsed_str is Dictionary) else parsed_str
	for keybind in KEYBIND_ACTIONS_DEFAULTS:
		var stored_keybind: String = keybind_conf.get(keybind, KEYBIND_ACTIONS_DEFAULTS[keybind])
		InputMap.add_action(keybind)
		var event: InputEvent
		if stored_keybind.begins_with("k"):
			event = InputEventKey.new()
			event.keycode = int(stored_keybind.substr(1))
		elif stored_keybind.begins_with("m"):
			event = InputEventMouseButton.new()
			event.button_index = int(stored_keybind.substr(1))
		else:
			continue
		InputMap.action_add_event(keybind, event)
	print("[KeybindsMod] Enabled")

func _scan(node):
	_on_node_added(node)
	for child in node.get_children():
		_scan(child)

func _on_node_added(node):
	var script = node.get_script()
	if script == null: return
	var key = script.resource_path.get_file().get_basename()
	if key in KEYBIND_LISTENER_SCRIPTS + OTHER_SCRIPTS:
		_attach.call_deferred(weakref(node), key)
		
func _attach(reference, script_name):
	nodes[script_name] = reference
	
func _input(event):
	if not _using_controller:
		for n in KEYBIND_LISTENER_SCRIPTS:
			var ref = nodes.get(n)
			if not ref:
				continue
			var node = ref.get_ref()
			if not node:
				continue
			if event.is_action_pressed(&"reroll_shop"):
				if n == "shop_ui":
					if not node.reroll_button.disabled:
						node._on_reroll_pressed()
			elif event.is_action_pressed(&"request_battle"):
				if n == "shop_ui":
					if not node.battle_button.disabled:
						node.battle_requested.emit()
			elif event.is_action_pressed(&"show_trinkets"):
				if n == "shop_ui" or n == "team_overlay":
					node.trinket_bag_ui.toggle()
			elif event.is_action_pressed(&"show_settings"):
				node._on_settings_button_pressed()
			elif event.is_action_pressed(&"show_dex"):
				node._on_dex_button_pressed()
			else:
				continue
			get_viewport().set_input_as_handled()

func make_custom_settings_menu_entries() -> Array[Control]:
	var entries := []
	for action in KEYBIND_ACTIONS_NAMES:
		var entry: SettingsEntryKeybind = load("res://Mods/KeybindsMod/settings_entry_keybind.tscn").instantiate()
		entries.append(entry)
		entry.keybind_id = action
		entry.keybind_name = KEYBIND_ACTIONS_NAMES.get(action, "")
	return entries
