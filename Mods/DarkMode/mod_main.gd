extends Node

const Loader := preload("res://Mods/mod_loader.gd")
const VANILLA_UI_COLORS := {
	&"red": Color(0.9373, 0.2588, 0.4196, 1.0),
	&"blue": Color(0.1922, 0.7765, 0.9686, 1.0),
	&"yellow": Color(1.0, 0.8078, 0.0, 1.0),
	&"light_grey": Color(0.4824, 0.4824, 0.4824, 1.0),
	&"dark_grey":  Color(0.3529, 0.3529, 0.3882, 1.0),
	&"white": Color.WHITE
}
const PROPERTY_OVERRIDES: Dictionary[String, Dictionary] = {
	"Icon": {"self_modulate": Color.WHITE}, 
	"Logo": {"self_modulate": Color(0.73, 0.786, 0.965, 1.0)},
	"Prismagon": {"self_modulate": Color(0.492, 0.524, 0.647, 1.0)},
	"BG": {"self_modulate": Color(0.457, 0.489, 0.612, 1.0)},
	"Frame": {"self_modulate": Color(0.686, 0.711, 0.807, 1.0)},
	"Type0": {"self_modulate": Color(0.719, 0.716, 0.763, 1.0)},
	"Type1": {"self_modulate": Color(0.719, 0.716, 0.763, 1.0)},
	"CommonContainer/PercentLabel": {"font_color": Color.WHITE},
	"Shadow": {"self_modulate": Color(0.113, 0.126, 0.178, 1.0)},
	"RerollButton": {"self_modulate": Color(0.439, 0.392, 0.251, 1.0)},
	"BattleButton": {"self_modulate": Color(0.388, 0.561, 0.561, 1.0)},
	"ShopUI/CancelButton": {"self_modulate": Color(0.388, 0.561, 0.561, 1.0)},
	"CanvasLayer/ConfirmButton": {"self_modulate": Color(0.388, 0.561, 0.561, 1.0)},
	"CanvasLayer/HideEndscreenButton": {"self_modulate": Color(0.388, 0.561, 0.561, 1.0)},
	"ShopBackground": {"texture": "shop_bg.png"},
	"GodRays": {"visible": false},
	"GodRays2": {"visible": false},
	"MeadowMap": {"modulate": Color(0.361, 0.431, 0.812, 1.0)},
	"SnowField": {"modulate": Color(0.361, 0.431, 0.812, 1.0)},
	"CaveMap": {"modulate": Color(0.627, 0.714, 0.878, 1.0)},
}

var _started := false
var loader: Loader
var theme_map: Dictionary[StringName, Dictionary] = {}
var tex_colors := []

func mod_ready():
	if _started: return
	_started = true
	loader = get_node("/root/ModLoader")
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(node):
	_on_node_added(node)
	for child in node.get_children(): _scan(child)

func _on_node_added(node: Node):
	if node is Control:
		set_node_to_theme(node)
	override_node_properties(node)

func set_node_to_theme(node: Control):
	var theme = node.get(&"theme")
	if not theme:
		node.theme = Theme.new()
	else:
		node.theme = theme.duplicate()
	for type in node.theme.get_type_list():
		match type:
			&"Label", &"RichTextLabel":
				set_colors(node, type)
			&"Button":
				set_colors(node, type)
				modulate_stylebox(node, type)
			&"PanelContainer":
				modulate_stylebox(node, type)

func override_node_properties(node: Node):
	for end_of_path in PROPERTY_OVERRIDES:
		if str(node.get_path()).ends_with(end_of_path):
			for pn in PROPERTY_OVERRIDES[end_of_path]:
				var val = PROPERTY_OVERRIDES[end_of_path][pn]
				if pn == "font_color":
					node.add_theme_color_override(&"font_color", val)
				elif pn == "texture":
					var path := "%s/%s/%s" % [loader.get_mods_dir(), "DarkMode", val]
					var imgtex := ImageTexture.new()
					var img := Image.new()
					img.load(path)
					imgtex.set_image(img)
					node.set(pn, imgtex)
				elif end_of_path in ["MeadowMap", "SnowField", "CaveMap"]:
					if loader.get_config("dark_mode", "night_battles", true):
						node.set(pn, val)
				else:
					node.set(pn, val)

func set_colors(node: Control, type: StringName):
	for color in node.theme.get_color_list(type):
		if color.contains("shadow"):
			node.theme.set_color(color, type, Color("424242"))
		elif color.contains("outline"):
			pass
		else:
			node.theme.set_color(color, type, Color.WHITE)

func modulate_stylebox(node: Control, type: StringName):
	for style_name in node.theme.get_stylebox_list(type):
		var new_style: StyleBox
		if node.has_theme_stylebox_override(style_name):
			new_style = node.get_theme_stylebox(style_name, type).duplicate()
			node.remove_theme_stylebox_override(style_name)
			node.add_theme_stylebox_override(style_name, new_style)
		else:
			new_style = node.theme.get_stylebox(style_name, type).duplicate()
			node.theme.set_stylebox(style_name, type, new_style)
		if new_style is StyleBoxTexture:
			new_style.modulate_color = get_modulate_from_texture(new_style.texture)

func get_modulate_from_texture(texture: Texture2D) -> Color:
	var img: Image = texture.get_image()
	var size := Vector2(img.get_size())
	var tex_color: Color = img.get_pixel(int(size.x / 2.0), int(size.y / 2.0))
	if tex_color not in tex_colors:
		tex_colors.append(tex_color)
	if color_is_near_color(VANILLA_UI_COLORS[&"red"], tex_color) or color_is_near_color(VANILLA_UI_COLORS[&"blue"], tex_color):
		return Color(0.388, 0.561, 0.561, 1.0)
	elif color_is_near_color(VANILLA_UI_COLORS[&"yellow"], tex_color):
		return Color(0.439, 0.392, 0.251, 1.0)
	else:
		return Color(0.127, 0.154, 0.195, 1.0)

func color_is_near_color(color1: Color, color2: Color, x: float = 0.1) -> bool:
	var v1 := Vector3(color1.r, color1.g, color1.b)
	var v2 := Vector3(color2.r, color2.g, color2.b)
	return (v1 - v2).length() <= x
