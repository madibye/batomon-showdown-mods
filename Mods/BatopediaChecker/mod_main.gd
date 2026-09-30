extends Node
## Read-only Batopedia marks on live cards. No game resources are replaced.

const OVERLAY_NAME = "BatopediaCheckerIcons"
const CARD_SCRIPTS = {
	"monster_slot_ui": "team",
	"shop_slot_ui": "shop",
	"description_box": "description",
}
const ICON_PATHS = [
	"res://assets/ui/textures/dex/trophy_icon.png",
	"res://assets/ui/textures/dex/medal_icon.png",
	"res://assets/ui/textures/dex/rainbow_star_icon.png",
]
var _started = false
var _textures = []
var _visibility = {"description": true, "team": true, "shop": true}

func _config_changed(mod_id, _key, _value):
	if mod_id != "batopedia_checker": return
	var loader = get_node_or_null("/root/ModLoader")
	for kind in _visibility:
		var key = "show_tooltip" if kind == "description" else "show_" + kind
		_visibility[kind] = loader.get_config("batopedia_checker", key, true)

func mod_ready():
	if _started: return
	_started = true
	var loader = get_node_or_null("/root/ModLoader")
	if loader != null and loader.has_method("get_config"):
		_config_changed("batopedia_checker", "", null)
		loader.config_changed.connect(_config_changed)
	for path in ICON_PATHS:
		var texture = load(path)
		if not texture is Texture2D:
			push_error("[BatopediaChecker] Missing Batopedia icon: " + path)
			return
		_textures.append(texture)
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)
	print("[BatopediaChecker] Enabled: team, bench, shop and inspection cards.")

func _scan(node):
	_on_node_added(node)
	for child in node.get_children():
		_scan(child)

func _on_node_added(node):
	if not node is Control: return
	var script = node.get_script()
	if script == null: return
	var key = script.resource_path.get_file().get_basename()
	if CARD_SCRIPTS.has(key):
		_attach.call_deferred(weakref(node), CARD_SCRIPTS[key])

func _attach(reference, kind):
	var card = reference.get_ref()
	if card == null or not card.is_inside_tree() or card.is_queued_for_deletion(): return
	if card.has_node(OVERLAY_NAME): return
	var overlay = CompletionIcons.new()
	overlay.name = OVERLAY_NAME
	overlay.kind = kind
	overlay.textures = _textures
	overlay.settings = _visibility
	card.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

class CompletionIcons extends Control:
	const MARKS = ["won", "lv3", "shiny"]
	const ICON_SIZE = 11.0
	var kind = ""
	var textures = []
	var settings = {}
	var mask = 0
	var icon_size = ICON_SIZE
	var origin = Vector2.ZERO
	var _species_id = ""
	var _base_id = ""

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Draw above the card's art without adding a minimum size to its container.
		z_index = 2
		process_mode = Node.PROCESS_MODE_ALWAYS
		_refresh()

	func _process(_delta):
		if is_visible_in_tree(): _refresh()

	func _species():
		var card = get_parent()
		var content = null
		match kind:
			"team":
				if card.is_locked: return null
				content = card.current_monster
			"shop": content = card.current_content
			"description":
				# Preserve the game's hidden/unknown-monster presentation.
				if card.name_label.text == "???": return null
				content = card._current_data
		if content is MonsterInstance or content is BattleUnit:
			return content.data
		return null

	func _refresh():
		if not settings.get(kind, true):
			if mask != 0:
				mask = 0
				queue_redraw()
			return
		var next_mask = 0
		var species = _species()
		var manager = get_node_or_null("/root/UserManager")
		if species != null and manager != null and manager.data != null:
			if _species_id != species.id:
				_species_id = species.id
				_base_id = GameDatabase.get_base_species_id(_species_id)
			var achievements = manager.data.dex_achievements.get(_base_id, {})
			for i in range(3):
				if achievements.get(MARKS[i], false): next_mask |= 1 << i
		var count = 0
		for i in range(3):
			if next_mask & (1 << i): count += 1
		var next_size = ICON_SIZE
		var next_origin = Vector2(1, -1)
		var card = get_parent()
		if kind == "team":
			next_origin = Vector2(card.size.x - count * next_size - 2, 0)
		elif kind == "shop":
			# Level labels occupy the left edge; the shiny label is on the right.
			if card.level_2_indicator.visible or card.level_3_indicator.visible:
				next_origin.y = 10
		elif kind == "description" and count > 0:
			var left = card.name_label.position.x + card.name_label.size.x + 3
			var right = card.rarity_label.position.x - 3
			var available = maxf(0, right - left)
			next_size = minf(ICON_SIZE, floorf(available / count))
			if next_size < 6:
				next_mask = 0
			else:
				next_origin = card.get_node("HeaderContainer").position + Vector2(floorf((left + right - count * next_size) / 2), 2)
		# PanelContainer may inset this overlay; positions above are card-local.
		next_origin -= position
		if mask != next_mask or origin != next_origin or icon_size != next_size:
			mask = next_mask
			origin = next_origin
			icon_size = next_size
			queue_redraw()

	func _draw():
		var index = 0
		for i in range(3):
			if mask & (1 << i):
				draw_texture_rect(textures[i], Rect2(origin + Vector2(index * icon_size, 0), Vector2.ONE * icon_size), false)
				index += 1
