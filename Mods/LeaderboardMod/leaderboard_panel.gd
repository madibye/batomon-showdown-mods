extends PanelContainer
signal close_requested
const COLUMNS = [["rank", "Rank", 30], ["display_name", "Player", 0], ["games_played", "Games Played", 70], ["winrate", "Win Rate", 58], ["ranked_mmr", "Rating", 58]]
var provider_override: Node
var _request_id = 0
var _fetch_pending = false
var _entries: Array = []
var _sort_key = "rank"
var _ascending = true
var _headers = {}
var _current_user_id = ""
var _summary = {}
var _rank_icon: TextureRect
var list_container: VBoxContainer
var scroll_container: ScrollContainer
var local_note: Label
var close_button: Button

func _label(value, font_size = 12, align = HORIZONTAL_ALIGNMENT_LEFT):
	var label = Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _box(color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _banner(text_value, color):
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(color))
	var label = _label(text_value, 13, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color("52525a"))
	panel.add_child(label)
	return panel

func _stat(parent, key, caption):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var value = _label("—", 15, HORIZONTAL_ALIGNMENT_CENTER)
	_summary[key] = value
	column.add_child(value)
	column.add_child(_label(caption, 10, HORIZONTAL_ALIGNMENT_CENTER))

func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = load("res://assets/ui/themes/inner_section_container.tres").duplicate()
	theme.merge_with(load("res://assets/ui/themes/text/description_text.tres"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	margin.add_child(layout)
	var title_row = HBoxContainer.new()
	layout.add_child(title_row)
	var banner = _title_banner()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(banner)
	close_button = load("res://game/ui/common/menu_button.tscn").instantiate()
	close_button.text = ""
	close_button.icon = load("res://assets/ui/textures/common/x_icon.png")
	close_button.custom_minimum_size = Vector2(22, 22)
	close_button.add_theme_font_size_override("font_size", 9)
	close_button.tooltip_text = "Close leaderboard"
	close_button.pressed.connect(_on_done)
	title_row.add_child(close_button)
	var summary_frame = PanelContainer.new()
	var frame_style = _box(Color.WHITE)
	summary_frame.add_theme_stylebox_override("panel", frame_style)
	layout.add_child(summary_frame)
	var summary_layout = VBoxContainer.new()
	summary_layout.add_theme_constant_override("separation", 2)
	summary_frame.add_child(summary_layout)
	var identity = HBoxContainer.new()
	summary_layout.add_child(identity)
	_stat(identity, "position", "Position")
	_rank_icon = TextureRect.new()
	_rank_icon.custom_minimum_size = Vector2(24, 24)
	_rank_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity.add_child(_rank_icon)
	var player = VBoxContainer.new()
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player.size_flags_stretch_ratio = 4
	identity.add_child(player)
	_summary["name"] = _label("Player", 15)
	_summary["name"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary["tier"] = _label("", 10)
	player.add_child(_summary["name"])
	player.add_child(_summary["tier"])
	_stat(identity, "rating", "Rating")
	var stats = HBoxContainer.new()
	summary_layout.add_child(stats)
	_stat(stats, "wins", "Championships")
	_stat(stats, "games", "Games Played")
	_stat(stats, "winrate", "Win Rate")
	var rankings = PanelContainer.new()
	rankings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(rankings)
	var table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	rankings.add_child(table)
	table.add_child(_banner("MASTER TIER RANKINGS", Color("ff4672")))
	# Reserve the same scrollbar width in the fixed header and scrolling rows.
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var contents = VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(contents)
	var header_frame = PanelContainer.new()
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_right", int(scroll_container.get_v_scroll_bar().get_combined_minimum_size().x))
	table.add_child(header_margin)
	header_margin.add_child(header_frame)
	table.add_child(scroll_container)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header_frame.add_child(header)
	for column in COLUMNS:
		var button = Button.new()
		button.add_theme_font_override("font", theme.get_font("font", "Label"))
		button.add_theme_font_size_override("font_size", 11)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("52525a"))
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, _box(Color("fff0f4") if state != "normal" else Color.WHITE))
		button.clip_text = true
		_cell_width(button, column)
		button.tooltip_text = "Sort by " + column[1] + "; click again to reverse"
		button.pressed.connect(_sort_by.bind(column[0]))
		_headers[column[0]] = button
		header.add_child(button)
	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 3)
	contents.add_child(list_container)
	local_note = _label("", 10, HORIZONTAL_ALIGNMENT_CENTER)
	local_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(local_note)
	local_note.hide()
	_update_headers()
	_update_position()
	get_window().size_changed.connect(_update_position)
	# Container sorting can briefly expand the panel while many rows are added.
	# Reapply the viewport bounds after its minimum sizes have settled.
	minimum_size_changed.connect(_update_position.call_deferred)
	resized.connect(_update_position.call_deferred)

func _cell_width(control, column):
	control.custom_minimum_size.x = column[2]
	if column[0] == "display_name": control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _update_position():
	var viewport_size = get_viewport_rect().size
	custom_minimum_size = Vector2(min(viewport_size.x * 0.85, 640.0), 0)
	size = Vector2(custom_minimum_size.x, min(viewport_size.y * 0.88, 700.0))
	position = (viewport_size - size) / 2

func _show_user_stats():
	for key in _summary: _summary[key].text = "—"
	var user = UserManager.data
	_rank_icon.texture = null
	if user == null:
		_summary["name"].text = "No player data"
		return
	_summary["name"].text = user.display_name if user.display_name != "" else "Player"
	_summary["tier"].text = user.rank_tier.capitalize() + (" %d" % user.rank_sub if user.rank_tier != "master" else "")
	_summary["rating"].text = str(user.ranked_mmr)
	_summary["wins"].text = str(user.runs_won)
	_summary["games"].text = str(user.games_played)
	_summary["winrate"].text = "%.1f%%" % (100.0 * user.runs_won / user.games_played) if user.games_played > 0 else "—"
	var icon_path = "res://assets/ui/textures/ranked/%s_icon.png" % user.rank_tier
	if ResourceLoader.exists(icon_path): _rank_icon.texture = load(icon_path)

func show_leaderboard():
	if visible: return
	_request_id += 1
	_entries.clear()
	_render_rows()
	_show_user_stats()
	_update_position()
	show()
	close_button.grab_focus()
	local_note.text = "Loading rankings..."
	local_note.show()
	_current_user_id = ""
	var auth = get_node_or_null("/root/AuthManager")
	if auth != null and auth.has_method("get_user_id"): _current_user_id = str(auth.get_user_id())
	_fetch_pending = true
	_start_fetch()

func _start_fetch():
	var provider = provider_override if provider_override != null else RunManager.data_provider
	var request_id = _request_id
	if provider == null or not provider.has_method("get_master_leaderboard"):
		_finish_fetch([], request_id)
		return
	get_tree().create_timer(10.0).timeout.connect(_on_fetch_timeout.bind(request_id))
	var rows = await provider.get_master_leaderboard(200)
	_finish_fetch(rows, request_id)

func _finish_fetch(rows: Array, request_id: int):
	if not _fetch_pending or request_id != _request_id: return
	_fetch_pending = false
	_on_fetch_done(rows)

func _on_fetch_timeout(request_id: int):
	_finish_fetch([], request_id)

func _on_fetch_done(rows: Array):
	_entries.clear()
	for i in range(rows.size()):
		if not rows[i] is Dictionary: continue
		var row = rows[i].duplicate()
		row["rank"] = int(row.get("rank", i + 1))
		row["display_name"] = str(row.get("display_name", "")).strip_edges()
		if row["display_name"] == "": row["display_name"] = "Unnamed player"
		row["winrate"] = null
		if row.get("games_played") != null and row.get("runs_won") != null and float(row["games_played"]) > 0:
			row["winrate"] = 100.0 * float(row["runs_won"]) / float(row["games_played"])
		_entries.append(row)
		if _current_user_id != "" and str(row.get("user_id", "")) == _current_user_id:
			_summary["position"].text = str(row["rank"])
	local_note.text = "No rankings available. Check your connection and try again."
	local_note.visible = _entries.is_empty()
	_render_rows()

func _sort_by(key):
	if key == _sort_key: _ascending = not _ascending
	else:
		_sort_key = key
		_ascending = true
	_update_headers()
	_render_rows()
	scroll_container.scroll_vertical = 0

func _update_headers():
	for column in COLUMNS:
		_headers[column[0]].text = column[1] + ((" ↑" if _ascending else " ↓") if _sort_key == column[0] else "")

func _less(a, b):
	var av = a.get(_sort_key)
	var bv = b.get(_sort_key)
	# Unknown statistics remain last in either direction.
	if av == null or bv == null:
		if av == null and bv == null: return a["rank"] < b["rank"]
		return bv == null
	if _sort_key == "display_name":
		av = str(av).to_lower()
		bv = str(bv).to_lower()
	else:
		av = float(av)
		bv = float(bv)
	if av == bv: return a["rank"] < b["rank"]
	return av < bv if _ascending else av > bv

func _render_rows():
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()
	_entries.sort_custom(_less)
	for entry in _entries:
		var panel = PanelContainer.new()
		panel.custom_minimum_size.y = 27
		list_container.add_child(panel)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		panel.add_child(row)
		var is_me = _current_user_id != "" and str(entry.get("user_id", "")) == _current_user_id
		for column in COLUMNS:
			var value = entry.get(column[0])
			var display = str(value) if value != null else "—"
			if column[0] == "winrate" and value != null: display = "%.1f%%" % value
			if column[0] == "display_name" and is_me: display += " (You)"
			var label = _label(display, 13, HORIZONTAL_ALIGNMENT_LEFT if column[0] == "display_name" else HORIZONTAL_ALIGNMENT_CENTER)
			_cell_width(label, column)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = display
			if column[0] == "rank" and entry["rank"] <= 3:
				label.add_theme_color_override("font_color", [Color("a47e13"), Color("777782"), Color("916238")][maxi(0, entry["rank"] - 1)])
			if is_me: label.add_theme_color_override("font_color", Color("b62250"))
			row.add_child(label)

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_done()

func _on_done():
	if not visible: return
	_fetch_pending = false
	_request_id += 1
	hide()
	close_requested.emit()

func _title_banner():
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("ffbf00")))
	var center = CenterContainer.new()
	panel.add_child(center)
	var row = HBoxContainer.new()
	center.add_child(row)
	var icon = TextureRect.new()
	icon.texture = load("res://assets/ui/textures/dex/trophy_icon.png")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label = _label("LEADERBOARD", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color("52525a"))
	row.add_child(label)
	return panel
