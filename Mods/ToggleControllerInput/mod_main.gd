extends Node

const Loader := preload("res://Mods/mod_loader.gd")
const ShopInputHandler := preload("res://game/shop/shop_input_handler.gd")
const EndlessEnablePrompt := preload("res://game/ui/common/endless_enable_prompt.gd")
const DexUI := preload("res://game/ui/dex/dex_ui.gd")
const InputStopper := preload("res://Mods/ToggleControllerInput/input_stopper.gd")

var _started := false
var loader: Loader

var stopped_input_classes: Array[Script] = [
	BattleView, ShopInputHandler, ShopUI, TitleState, EventState, TrinketSelectState, TrainerSelectState, RunSummaryState, 
	BoxRevealPopup, SeasonRecapPopup, SettingsMenu, BlockingPopup, MasterLeaderboardUI, PaintedSpeciesPopup, HamburgerMenu, 
	LanguagePickerPopup, MonsterInspectPopup, MatchHistoryUI, CollectionUI, PatchNotesUI, TeamOverlay, EndlessEnablePrompt,
	TrainerChoicePopup, DexFilterPopup, TrinketSelectUI, DexUI
]

func mod_ready():
	if _started: return
	_started = true
	loader = get_node("/root/ModLoader")
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)
	loader.config_changed.connect(_on_config_changed)

func _scan(node):
	_on_node_added(node)
	for child in node.get_children(): _scan(child)
	
func _on_config_changed(mod_id, key, value):
	if mod_id == "toggle_controller_input" and key == "controller_input" and value == false:
		InputManager._set_using_controller(false, false)

func _on_node_added(node: Node):
	for cls in stopped_input_classes:
		if node.get_script() == cls:
			var input_stopper := InputStopper.new()
			input_stopper.loader = loader
			node.add_child(input_stopper)
			
		
