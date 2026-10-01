extends Node
## Adds the downloaded leaderboard without replacing the game's title state.
var _started = false
var _panel_script: Script

func mod_ready():
	if _started: return
	_started = true
	_panel_script = load(get_script().resource_path.get_base_dir().path_join("leaderboard_panel.gd"))
	if _panel_script == null: return
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(node):
	_on_node_added(node)
	for child in node.get_children(): _scan(child)

func _on_node_added(node):
	var script = node.get_script()
	if script != null and script.resource_path.get_file().get_basename() == "mod_title_state":
		_attach.call_deferred(weakref(node))

func _attach(reference):
	var title = reference.get_ref()
	if title == null or not title.is_inside_tree() or title.is_queued_for_deletion(): return
	var canvas = title.get_node_or_null("CanvasLayer")
	var menu = title.get_node_or_null("CanvasLayer/TitleMenu")
	if canvas == null or menu == null or canvas.has_node("SideloadLeaderboard"): return
	var settings = menu.find_child("SettingsButton", true, false)
	if settings == null: settings = menu.find_child("QuitButton", true, false)
	if settings == null: return
	var panel = _panel_script.new()
	panel.name = "SideloadLeaderboard"
	canvas.add_child(panel)
	var button = load("res://game/ui/common/menu_button.tscn").instantiate()
	button.name = "SideloadLeaderboardButton"
	button.text = "Leaderboard"
	settings.get_parent().add_child(button)
	settings.get_parent().move_child(button, settings.get_index())
	button.pressed.connect(func():
		if settings.disabled: return
		menu.hide()
		panel.show_leaderboard()
	)
	panel.close_requested.connect(func():
		menu.show()
		button.grab_focus()
	)
	print("[LeaderboardMod] Added Leaderboard to title menu.")
