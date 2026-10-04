extends TitleState

@onready var title_menu_vbox_container: = $CanvasLayer / TitleMenu / MarginContainer / VBoxContainer
var anim_key_values = {}
var times_run := 0

var title_menu_scale := Vector2.ONE:
	set(x):
		title_menu_scale = x
		if not is_node_ready():
			await ready
		for anim_name in title_menu_anim_player.get_animation_list():
			var anim: Animation = title_menu_anim_player.get_animation(anim_name)
			for key in anim.track_get_key_count(0):
				anim.track_set_key_value(0, key, anim_key_values.get(anim_name, {}).get(key, Vector2.ONE) * title_menu_scale)
		if title_menu.visible:
			title_menu.scale = title_menu_scale

func _ready():
	super()
	for anim_name in title_menu_anim_player.get_animation_list():
		var anim: Animation = title_menu_anim_player.get_animation(anim_name)
		anim_key_values[anim_name] = {}
		for key in anim.track_get_key_count(0):
			anim_key_values[anim_name][key] = anim.track_get_key_value(0, key)
		
func _recenter_title_menu_pivot():
	super()
	var visible_children := len(title_menu_vbox_container.get_children().filter(func(c): return c.visible))
	if visible_children > 5:
		title_menu_scale = Vector2.ONE * (5.0 / float(visible_children))

func _exit_tree():
	for anim_name in title_menu_anim_player.get_animation_list():
		var anim: Animation = title_menu_anim_player.get_animation(anim_name)
		for key in anim.track_get_key_count(0):
			anim.track_set_key_value(0, key, anim_key_values.get(anim_name, {}).get(key, Vector2.ONE))
