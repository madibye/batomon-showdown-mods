extends Node

const Loader := preload("res://Mods/mod_loader.gd")
const VANILLA_UI_COLORS: Dictionary[String, Color] = {
	"red": Color(0.9373, 0.2588, 0.4196, 1.0),
	"light_red": Color(1.0, 0.2902, 0.4196, 1.0),
	"red_2": Color(0.8549, 0.3098, 0.3765, 1.0),
	"dark_red": Color(0.867, 0.2, 0.349, 1.0),
	"blue": Color(0.082, 0.616, 0.847, 1.0),
	"dark_blue": Color(0.0, 0.5176, 0.7412, 1.0),
	"light_blue": Color(0.1922, 0.7765, 0.9686, 1.0),
	"yellow": Color(1.0, 0.8078, 0.0, 1.0),
	"yellow_2": Color(1.0, 0.7412, 0.0314, 1.0),
	"light_grey": Color(0.4824, 0.4824, 0.4824, 1.0),
	"grey": Color(0.4157, 0.4157, 0.4157, 1.0),
	"dark_grey":  Color(0.3529, 0.3529, 0.3882, 1.0),
	"almost_white": Color(0.9059, 0.9059, 0.9059, 1.0),
	"run_summary_blue": Color(0.161, 0.776, 0.741, 1.0),
	"white": Color.WHITE
}
const PROPERTY_OVERRIDES: Dictionary[String, Dictionary] = {
	"Icon": {"self_modulate": Color.WHITE}, 
	"Logo": {"self_modulate": Color(0.73, 0.786, 0.965, 1.0)},
	"TitleState/CanvasLayer/Prismagon": {"self_modulate": Color(0.492, 0.524, 0.647, 1.0)},
	"TitleState/CanvasLayer/BG": {"self_modulate": Color(0.457, 0.489, 0.612, 1.0)},
	"SlotContainer/Frame": {"self_modulate": Color(0.686, 0.711, 0.807, 1.0)},
	"Type0": {"self_modulate": Color(0.719, 0.716, 0.763, 1.0)},
	"Type1": {"self_modulate": Color(0.719, 0.716, 0.763, 1.0)},
	"CommonContainer/PercentLabel": {"font_color": Color.WHITE},
	"QuitButton": {"self_modulate": Color.WHITE},
	"PauseButton": {"self_modulate": Color.WHITE},
	"FastForwardButton": {"self_modulate": Color.WHITE},
	"Shadow": {"self_modulate": Color(0.113, 0.126, 0.178, 1.0)},
	"ShopBackground": {"texture": "shop_bg.png"},
	"GodRays": {"visible": false},
	"GodRays2": {"visible": false},
	"MeadowMap": {"modulate": Color(0.361, 0.431, 0.812, 1.0)},
	"SnowField": {"modulate": Color(0.361, 0.431, 0.812, 1.0)},
	"CaveMap": {"modulate": Color(0.627, 0.714, 0.878, 1.0)},
}

var _started := false
var loader: Loader
var already_darkened_resources := []

var time_in_set_node_to_theme := 0
var time_in_override_node_properties := 0

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
	if node is TextureButton and node.get(&"texture_normal"):
		node.self_modulate = get_modulate_from_texture(node.texture_normal)
	if not node.theme:
		return
	for type in node.theme.get_type_list():
		match type:
			&"Label", &"RichTextLabel":
				set_colors(node, type)
			&"Button":
				set_colors(node, type)
				modulate_stylebox(node, type)
			&"PanelContainer":
				modulate_stylebox(node, type)
	already_darkened_resources.append(node.theme)

func override_node_properties(node: Node):
	var path := str(node.get_path())
	var key_idx := PROPERTY_OVERRIDES.keys().find_custom(func(k): return path.ends_with(k))
	if key_idx == -1: 
		return
	var key: String = PROPERTY_OVERRIDES.keys()[key_idx]
	var val_dict := PROPERTY_OVERRIDES[key]
	for pn in val_dict:
		var val = val_dict[pn]
		if pn == "font_color":
			node.add_theme_color_override(&"font_color", val)
		elif pn == "texture":
			var tex_path := "%s/%s/%s" % [loader.get_mods_dir(), "DarkMode", val]
			var imgtex := ImageTexture.new()
			var img := Image.new()
			img.load(tex_path)
			imgtex.set_image(img)
			node.set(pn, imgtex)
		elif key in ["MeadowMap", "SnowField", "CaveMap"]:
			if loader.get_config("dark_mode", "night_battles", true):
				node.set(pn, val)
		else:
			node.set(pn, val)
	return

func set_colors(node: Control, type: StringName):
	if node.theme in already_darkened_resources:
		return
	for color in node.theme.get_color_list(type):
		if color.contains("shadow"):
			node.theme.set_color(color, type, Color("424242"))
		elif color.contains("outline"):
			pass
		else:
			node.theme.set_color(color, type, Color.WHITE)

func modulate_stylebox(node: Control, type: StringName):
	for style_name in node.theme.get_stylebox_list(type):
		var new_style: StyleBox = node.get_theme_stylebox(style_name, type)
		if new_style is StyleBoxTexture:
			new_style.modulate_color = get_modulate_from_texture(new_style.texture)
			already_darkened_resources.append(new_style)

func get_modulate_from_texture(texture: Texture2D) -> Color:
	var img: Image = texture.get_image()
	var size := Vector2(img.get_size())
	var tex_color: Color = img.get_pixel(int(size.x / 2.0), int(size.y / 2.0))
	if colors_check(["red", "light_red", "red_2", "dark_red", "blue", "light_blue", "dark_blue", "run_summary_blue"], tex_color):
		return Color(0.388, 0.561, 0.561, 1.0)
	elif colors_check(["yellow", "yellow_2"], tex_color):
		return Color(0.439, 0.392, 0.251, 1.0)
	elif colors_check(["light_grey", "grey", "dark_grey", "almost_white", "white"], tex_color):
		return Color(0.127, 0.154, 0.195, 1.0)
	else:
		return Color.WHITE

var tcs := []

func colors_check(colors: Array[String], comparison_color: Color, x: float = 0.1) -> bool:
	var results: Array[bool] = []
	var tcs_results := []
	for color: Color in VANILLA_UI_COLORS.values():
		tcs_results.append(color_is_near_color(color, comparison_color, x))
	for color: Color in tcs:
		tcs_results.append(color_is_near_color(color, comparison_color, x))
	if not tcs_results.any(func(a): return a):
		tcs.append(comparison_color)
		print(tcs)
	for color_name in colors:
		results.append(color_is_near_color(VANILLA_UI_COLORS[color_name], comparison_color, x))
	return results.any(func(a): return a)
	
func color_is_near_color(color1: Color, color2: Color, x: float = 0.1) -> bool:
	var v1 := Vector3(color1.r, color1.g, color1.b)
	var v2 := Vector3(color2.r, color2.g, color2.b)
	return absf((v1 - v2).length()) <= x
