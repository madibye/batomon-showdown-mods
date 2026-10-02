extends Node
## Loads archives and loose entry scripts from each Mods/<mod_name>/ folder.
## Root-level archives remain supported for older installations.
## Packs load alphabetically; loose scripts take precedence over packed entries.

const VERSION = "1.2.1"
const LOG_PREFIX := "[ModLoader] "
const LOG_FILE_NAME := "mod_loader.log"

var _loaded_packs: Array[String] = []
var _loose_mods: Dictionary = {}
var _mod_nodes: Dictionary = {}
var _mod_entry_paths: Dictionary = {}
var _mods_dir := ""
signal config_changed(mod_id: String, key: String, value: Variant)
var _registry: Dictionary = {}
var _dependency_errors: Array[String] = []
var _configs := ConfigFile.new()
var _settings_script: Script
var _title_script: Script
const CONFIG_PATH = "user://mod_settings.cfg"


# Mount packs before the main scene loads so resource replacements take effect.
func _init() -> void:
	_mods_dir = OS.get_executable_path().get_base_dir().path_join("Mods")
	if not DirAccess.dir_exists_absolute(_mods_dir):
		_mods_dir = "res://Mods"
	if not DirAccess.dir_exists_absolute(_mods_dir):
		return
	_reset_logs_in(_mods_dir)
	_log("Session started " + Time.get_datetime_string_from_system())
	var config_error = _configs.load(CONFIG_PATH)
	if config_error != OK and config_error != ERR_FILE_NOT_FOUND:
		_log("Could not read mod settings: " + error_string(config_error))
	_load_packs_in(_mods_dir)
	var dirs := Array(DirAccess.get_directories_at(_mods_dir))
	dirs.sort()
	for dir_name: String in dirs:
		var mod_dir := _mods_dir.path_join(dir_name)
		_load_packs_in(mod_dir)
		var entry_path := mod_dir.path_join("mod_main.gd")
		if FileAccess.file_exists(entry_path):
			_loose_mods[dir_name] = entry_path
			if not _loaded_packs.has(dir_name):
				_loaded_packs.append(dir_name)
			_log("Found loose mod " + dir_name)
	for pack_name in _loaded_packs:
		_register_mod(pack_name)
	_check_dependencies()
	if not _dependency_errors.is_empty():
		for message in _dependency_errors:
			_log(message)
		return
	for pack_name in _loaded_packs:
		_prepare_mod_entry(pack_name)


## Clear only log files before any packs or mod entries can write this session.
func _reset_logs_in(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension().to_lower() != "log" or dir.is_link(file_name):
			continue
		var path := directory.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.close()
		else:
			push_warning(LOG_PREFIX + "Could not reset log " + path)
	for dir_name: String in dir.get_directories():
		if not dir.is_link(dir_name):
			_reset_logs_in(directory.path_join(dir_name))


func _load_packs_in(directory: String) -> void:
	var files := Array(DirAccess.get_files_at(directory))
	files.sort()
	for file_name: String in files:
		var ext := file_name.get_extension().to_lower()
		if ext != "pck" and ext != "zip":
			continue
		var pack_path := directory.path_join(file_name)
		if not ProjectSettings.load_resource_pack(pack_path, true):
			push_error(LOG_PREFIX + "Failed to load " + pack_path)
			_log("Failed to load " + pack_path)
			continue
		_log("Loaded " + pack_path)
		if not _loaded_packs.has(file_name.get_basename()):
			_loaded_packs.append(file_name.get_basename())


func _ready() -> void:
	if not _dependency_errors.is_empty():
		get_tree().paused = true
		_show_dependency_error.call_deferred()
		return
	_settings_script = load(_mods_dir.path_join("mod_settings_menu.gd"))
	_title_script = load(_mods_dir.path_join("mod_title_state.gd"))
	get_tree().node_added.connect(_on_node_added)
	for pack_name in _loaded_packs:
		_start_mod_entry(pack_name)


func _on_node_added(node: Node) -> void:
	var script = node.get_script()
	# node_added runs before _ready, so inherited onready fields initialize normally.
	if _settings_script != null and script != null and script.resource_path.get_file().get_basename() == "settings_menu":
		node.set_script(_settings_script)
	elif _title_script != null and script != null and script.resource_path.get_file().get_basename() == "title_state":
		node.set_script(_title_script)
	else:
		return
	place_exported_properties(node)
		
func place_exported_properties(node: Node):
	var vanilla_scene_state: SceneState = load(node.scene_file_path).get_state()
	for i in vanilla_scene_state.get_node_property_count(0):
		var n := vanilla_scene_state.get_node_property_name(0, i)
		var v = vanilla_scene_state.get_node_property_value(0, i)
		if node.get(n) == null:
			node.set(n, v)

func _register_mod(pack_name: String) -> void:
	var path = _mods_dir.path_join(pack_name).path_join("mod.json")
	if not FileAccess.file_exists(path):
		path = "res://mods/%s/mod.json" % pack_name
	var metadata = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			metadata = parsed
		else:
			_dependency_errors.append(pack_name + ": invalid mod.json; dependencies cannot be checked.")
	var id = str(metadata.get("id", pack_name))
	if id.is_empty() or _registry.has(id):
		_dependency_errors.append(pack_name + ": invalid or duplicate mod ID: " + id)
		id = pack_name
	while _registry.has(id):
		id += "_legacy"
	var schema = []
	var keys = {}
	var declared = metadata.get("settings", [])
	if declared is Array:
		for setting in declared:
			if not setting is Dictionary: continue
			var key = setting.get("key", "")
			if not key is String or key.is_empty() or keys.has(key): continue
			if not _valid_setting(setting, setting.get("default")): continue
			keys[key] = true
			schema.append(setting.duplicate(true))
	_registry[id] = {"id": id, "name": str(metadata.get("name", pack_name)),
		"version": str(metadata.get("version", "Unknown")), "author": str(metadata.get("author", "")),
		"description": str(metadata.get("description", "")), "folder": pack_name, "settings": schema,
		"dependencies": metadata.get("dependencies", [])}


func _valid_setting(setting: Dictionary, value: Variant) -> bool:
	match setting.get("type", ""):
		"bool": return value is bool
		"enum": return setting.get("options") is Array and not setting.options.is_empty() and setting.options.has(value)
		"int", "float":
			if not (value is int or value is float): return false
			if not is_finite(float(value)): return false
			var low = setting.get("min", 0)
			var high = setting.get("max", 100)
			var step = setting.get("step", 1)
			if not (low is float or low is int) or not (high is float or high is int) or not (step is float or step is int): return false
			if not is_finite(float(low)) or not is_finite(float(high)) or not is_finite(float(step)): return false
			if step <= 0 or low > high or value < low or value > high: return false
			return setting.type != "int" or (float(value) == floorf(float(value)) and float(step) == floorf(float(step)))
		"string": return value is String
	return false


func get_mods(configurable_only: bool = false) -> Array:
	var result = []
	for info in _registry.values():
		if not configurable_only or not info.settings.is_empty():
			result.append(info.duplicate(true))
	return result

func get_mods_dir() -> String:
	return _mods_dir

func get_config(mod_id: String, key: String, fallback: Variant = null) -> Variant:
	for setting in _registry.get(mod_id, {}).get("settings", []):
		if setting.key == key:
			var value = _configs.get_value(mod_id, key, setting.default)
			return value if _valid_setting(setting, value) else setting.default
	return fallback


func set_config(mod_id: String, key: String, value: Variant) -> Error:
	for setting in _registry.get(mod_id, {}).get("settings", []):
		if setting.key != key: continue
		if not _valid_setting(setting, value): return ERR_INVALID_PARAMETER
		var previous = get_config(mod_id, key)
		_configs.set_value(mod_id, key, value)
		var error = _configs.save(CONFIG_PATH)
		if error != OK:
			_configs.set_value(mod_id, key, previous)
			_log("Could not save mod settings: " + error_string(error))
			return error
		config_changed.emit(mod_id, key, value)
		return OK
	return ERR_DOES_NOT_EXIST


func _prepare_mod_entry(pack_name: String) -> void:
	var entry_path := "res://mods/%s/mod_main.gd" % pack_name
	var load_path := entry_path
	if _loose_mods.has(pack_name):
		load_path = _loose_mods[pack_name]
	elif not ResourceLoader.exists(entry_path):
		return
	var script: Script = load(load_path)
	if script == null:
		push_error(LOG_PREFIX + "Could not load " + load_path)
		_log("Could not load " + load_path)
		return
	var node: Node = script.new()
	if node == null:
		push_error(LOG_PREFIX + "Could not instantiate " + load_path)
		_log("Could not instantiate " + load_path)
		return
	node.name = pack_name.validate_node_name()
	_mod_nodes[pack_name] = node
	_mod_entry_paths[pack_name] = load_path
	call_mod_method(pack_name, &"mod_init")
	_log("Prepared " + load_path)
	
func get_mod_node(pack_name: String) -> Node:
	return _mod_nodes.get(pack_name)
	
func call_mod_method(pack_name: String, method: StringName) -> Variant:
	var mod_node = get_mod_node(pack_name)
	if mod_node and mod_node.has_method(method):
		return mod_node.call(method)
	return null

func _start_mod_entry(pack_name: String) -> void:
	if not _mod_nodes.has(pack_name):
		return
	var node: Node = _mod_nodes[pack_name]
	var load_path: String = _mod_entry_paths.get(pack_name, pack_name)
	add_child(node)
	call_mod_method(pack_name, &"mod_ready")
	call_mod_method(pack_name, &"mod_bootstrap")
	_log("Started " + load_path)


func _log(message: String) -> void:
	printerr(LOG_PREFIX, message)
	var log_path := _mods_dir.path_join(LOG_FILE_NAME)
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(LOG_PREFIX + message)


# All manifests are registered first, independent of folder order.
func _check_dependencies() -> void:
	for info in _registry.values():
		var dependencies = info.dependencies
		var _owner = "%s (%s)" % [info.name, info.id]
		if not dependencies is Array:
			_dependency_errors.append(_owner + ": dependencies must be an array of mod IDs.")
			continue
		var seen = {}
		for dependency in dependencies:
			if not dependency is String or dependency.strip_edges().is_empty():
				_dependency_errors.append(_owner + ": each dependency must be a non-empty mod ID string.")
				continue
			if seen.has(dependency): continue
			seen[dependency] = true
			if not _registry.has(dependency):
				_dependency_errors.append(_owner + " requires missing mod: " + dependency)


func _show_dependency_error() -> void:
	# Keep the error screen interactive while game processing and input are paused.
	var layer = CanvasLayer.new()
	layer.name = "DependencyError"
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var background = ColorRect.new()
	background.color = Color("20202b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	background.add_child(margin)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title = Label.new()
	title.text = "Mod dependencies missing or invalid"
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var help = Label.new()
	help.text = "Install the required mods or remove the affected mods, then restart the game."
	help.add_theme_font_size_override("font_size", 12)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var details = Label.new()
	details.name = "Details"
	details.text = "\n\n".join(_dependency_errors)
	details.add_theme_font_size_override("font_size", 12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	var exit_button = Button.new()
	exit_button.name = "Exit"
	exit_button.text = "Exit"
	exit_button.custom_minimum_size.y = 30
	exit_button.add_theme_font_size_override("font_size", 16)
	exit_button.pressed.connect(func(): get_tree().quit())
	content.add_child(exit_button)
	exit_button.grab_focus()
