extends SettingsMenu
## Extend the original menu, preserving native settings and navigation.
const Loader := preload("res://Mods/mod_loader.gd")

var mods_tab_button: Button
var mods_page: VBoxContainer
var mod_rows: VBoxContainer
var mod_picker
var mod_info: Label
var mod_error: Label
var mod_scroll: ScrollContainer
var available_mods: Array = []
var selected_mod = 0
var loader: Loader

func _ready() -> void:
	super._ready()
	loader = get_node("/root/ModLoader")
	available_mods = loader.get_mods()
	mods_tab_button = game_tab_button.duplicate(0)
	mods_tab_button.name = "ModsTabButton"
	mods_tab_button.text = "Mods"
	mods_tab_button.button_group = game_tab_button.button_group
	mods_tab_button.set_pressed_no_signal(false)
	var tabs = game_tab_button.get_parent()
	tabs.add_child(mods_tab_button)
	tabs.move_child(mods_tab_button, system_tab_button.get_index() + 1)
	mods_page = VBoxContainer.new()
	mods_page.custom_minimum_size.y = maxf(game_page.custom_minimum_size.y, system_page.custom_minimum_size.y)
	mods_page.name = "ModsPage"
	mods_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_page.get_parent().add_child(mods_page)
	game_page.get_parent().move_child(mods_page, system_page.get_index() + 1)
	mod_picker = _make_row(mods_page, "Mod")
	mod_picker.incremented.connect(_pick_mod.bind(1))
	mod_picker.decremented.connect(_pick_mod.bind(-1))
	mod_picker.activated.connect(_pick_mod.bind(1))
	mod_info = Label.new()
	mod_info.mouse_filter = Control.MOUSE_FILTER_PASS
	mod_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_info.theme = load("res://assets/ui/themes/text/description_text.tres")
	_set_tooltip_theme(mod_info)
	mods_page.add_child(mod_info)
	mod_scroll = ScrollContainer.new()
	mod_scroll.theme = load("res://assets/ui/themes/scroll_bar/scroll_bar.tres")
	mod_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mod_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mod_scroll.follow_focus = true
	mods_page.add_child(mod_scroll)
	mod_rows = VBoxContainer.new()
	mod_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_scroll.add_child(mod_rows)
	mod_error = Label.new()
	mod_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_error.add_theme_font_size_override("font_size", 10)
	mod_error.add_theme_color_override("font_color", Color("b82349"))
	mod_error.hide()
	mods_page.add_child(mod_error)
	mods_page.hide()
	_build_mod_rows()
	update_ui_text()

func _make_row(parent: Node, title: String):
	var row = load("res://game/ui/common/settings_entry.tscn").instantiate()
	parent.add_child(row)
	row.label.text = title
	row.set_active(true)
	return row

func update_ui_text():
	super.update_ui_text()
	if mods_tab_button == null: return
	var height = game_tab_button.custom_minimum_size.y
	for tab in [game_tab_button, system_tab_button, mods_tab_button]:
		tab.custom_minimum_size = Vector2(68, height)
	mods_tab_button.text = "Mods"
	for row in mod_rows.get_children():
		if row.has_method("refresh_input_layout"): row.refresh_input_layout()
	mod_picker.refresh_input_layout()
	mods_page.custom_minimum_size.y = maxf(game_page.custom_minimum_size.y, system_page.custom_minimum_size.y)
	mod_scroll.custom_minimum_size.y = 163.0 if SettingsManager.is_touch_mode() else 129.0

func _on_tab_pressed(button: BaseButton) -> void:
	_select_tab(button)

func _select_tab(button: BaseButton) -> void:
	if mods_page == null:
		super._select_tab(button)
		return
	game_tab_button.set_pressed_no_signal(button == game_tab_button)
	system_tab_button.set_pressed_no_signal(button == system_tab_button)
	mods_tab_button.set_pressed_no_signal(button == mods_tab_button)
	game_page.visible = button == game_tab_button
	system_page.visible = button == system_tab_button
	mods_page.visible = button == mods_tab_button
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused) and not focused.is_visible_in_tree():
		_focus_first_row()

func _cycle_tab() -> void:
	if mods_page == null:
		super._cycle_tab()
		return
	var target = system_tab_button if game_page.visible else mods_tab_button if system_page.visible else game_tab_button
	_select_tab(target)
	AudioManager.play(TAB_SFX)

func _active_nav_rows() -> Array[Control]:
	if mods_page == null or not mods_page.visible: return super._active_nav_rows()
	var rows: Array[Control] = [mod_picker]
	for row in mod_rows.get_children():
		if row is VBoxContainer:
			rows.append(row.get_child(1))
		else:
			rows.append(row)
	rows.append(done_button if done_button.visible else close_tab_button)
	return rows

func _pick_mod(direction: int):
	if available_mods.is_empty(): return
	selected_mod = posmod(selected_mod + direction, available_mods.size())
	_build_mod_rows()

func _build_mod_rows():
	for row in mod_rows.get_children():
		mod_rows.remove_child(row)
		row.queue_free()
	mod_error.text = ""
	mod_error.visible = false
	mod_scroll.scroll_vertical = 0
	if available_mods.is_empty():
		mod_picker.update("None")
		mod_picker.set_active(false)
		mod_info.text = "No installed mods have configurable settings."
		return
	var info = available_mods[selected_mod]
	mod_picker.set_active(true)
	mod_picker.update(info.name)
	mod_info.text = "%s | v%s%s" % [info.name, info.version, (" | " + info.author) if not info.author.is_empty() else ""]
	for setting in info.settings:
		if setting.type == "string":
			var box = VBoxContainer.new()
			mod_rows.add_child(box)
			var label = Label.new()
			label.text = setting.get("label", setting.key)
			box.add_child(label)
			var edit = LineEdit.new()
			edit.text = loader.get_config(info.id, setting.key)
			box.add_child(edit)
			edit.text_submitted.connect(func(value): _save_value(info.id, setting.key, value))
			edit.focus_exited.connect(func(): _save_value(info.id, setting.key, edit.text))
		else:
			var row = _make_row(mod_rows, setting.get("label", setting.key))
			row.tooltip_text = setting.get("description", "")
			_refresh_value(row, info.id, setting)
			row.incremented.connect(_change_value.bind(row, info.id, setting, 1))
			row.decremented.connect(_change_value.bind(row, info.id, setting, -1))
			row.activated.connect(_change_value.bind(row, info.id, setting, 1))
	var custom_settings_menu_entries = loader.call_mod_method(info.folder, &"make_custom_settings_menu_entries")
	if custom_settings_menu_entries is Array:
		for entry in custom_settings_menu_entries:
			if not entry is Control:
				continue
			mod_rows.add_child(entry)
	print(mod_rows.get_children())
	if len(mod_rows.get_children()) == 0:
		var description_label := Label.new()
		description_label.theme = load("res://assets/ui/themes/text/description_text.tres")
		description_label.text = info.description
		mod_rows.add_child(description_label)
		mod_info.tooltip_text = ""
	else:
		mod_info.tooltip_text = info.description


func _save_value(id: String, key: String, value: Variant):
	var error = loader.set_config(id, key, value)
	mod_error.text = "" if error == OK else "Could not save: " + error_string(error)
	mod_error.visible = error != OK

func _refresh_value(row, id, setting):
	var value = loader.get_config(id, setting.key)
	row.update(("On" if value else "Off") if setting.type == "bool" else str(value))

func _change_value(row, id, setting, direction):
	var value = loader.get_config(id, setting.key)
	match setting.type:
		"bool": value = not value
		"enum": value = setting.options[posmod(setting.options.find(value) + direction, setting.options.size())]
		"int", "float":
			value = clampf(value + direction * setting.get("step", 1), setting.get("min", 0), setting.get("max", 100))
			if setting.type == "int": value = int(value)
	_save_value(id, setting.key, value)
	_refresh_value(row, id, setting)

func _set_tooltip_theme(object: Control):
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = load("res://assets/ui/textures/trainer_description/trainer_description_box_bg.png")
	stylebox.texture_margin_bottom = 5
	stylebox.texture_margin_top = 5
	stylebox.texture_margin_left = 5
	stylebox.texture_margin_right = 5
	object.theme.set_stylebox(&"panel", &"TooltipPanel", stylebox)
	object.theme.set_color(&"font_color", &"TooltipLabel", Color("52525a"))
	object.theme.set_color(&"font_outline_color", &"TooltipLabel", Color("000000"))
	object.theme.set_color(&"font_shadow_color", &"TooltipLabel", Color("ffffff"))
	object.theme.set_font(&"font", &"TooltipLabel", load("res://assets/ui/fonts/Guilty Treasure.otf"))
