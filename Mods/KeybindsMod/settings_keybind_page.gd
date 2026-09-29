extends VBoxContainer

const KEYBIND_ACTIONS = {
	&"reroll_shop": "Reroll Shop",
	&"request_battle": "Enter Battle",
	&"show_trinkets": "Toggle Trinket UI",
	&"show_dex": "Toggle Batopedia",
	&"show_settings": "Toggle Settings"
}
const KEYBINDS_CONF_PATH = "res://Mods/KeybindsMod/keybinds.json"
const KeybindEntry = preload("res://Mods/KeybindsMod/settings_entry_keybind.tscn")
const SettingsEntryKeybind = preload("res://Mods/KeybindsMod/settings_entry_keybind.gd")

var entries: Array[SettingsEntryKeybind]

func _ready():
	for action in KEYBIND_ACTIONS:
		var entry: SettingsEntryKeybind = KeybindEntry.instantiate()
		%VBoxContainer.add_child(entry)
		entry.keybind_id = action
		entry.keybind_name = KEYBIND_ACTIONS[action]
		entry.listening_started.connect(_listening_started)
		entry.listening_ended.connect(_listening_ended)

func _listening_started(kbid: StringName):
	for entry in entries:
		if entry.keybind_id != kbid:
			entry.listening_cancelled()
	
func _listening_ended(kbid: StringName):
	var rfile = FileAccess.open(KEYBINDS_CONF_PATH, FileAccess.READ)
	var parsed_str = JSON.parse_string(rfile.get_as_text())
	rfile.close()
	var keybind_conf: Dictionary = {} if (not parsed_str is Dictionary) else parsed_str
	var events = InputMap.action_get_events(kbid)
	if len(events) > 0:
		var event = events[0]
		if event is InputEventMouseButton:
			keybind_conf[kbid] = "m" + str(event.button_index)
		elif event is InputEventKey:
			keybind_conf[kbid] = "k" + str(event.keycode)

	var wfile = FileAccess.open(KEYBINDS_CONF_PATH, FileAccess.WRITE)
	if wfile:
		var json_string = JSON.stringify(keybind_conf, "\t")
		wfile.store_string(json_string)
		print("Local Provider: Keybinds saved to ", KEYBINDS_CONF_PATH)
	else:
		printerr("Local Provider Error: Could not write keybind config file.")
