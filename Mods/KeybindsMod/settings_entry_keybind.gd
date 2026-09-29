extends PanelContainer

@onready var label: Label = %Label
@onready var button: BaseButton = %Button

signal listening_started(kbid: StringName)
signal listening_ended(kbid: StringName)

var keybind_id: StringName:
	set(x):
		if not is_node_ready():
			await ready
		keybind_id = x
		_update_button_text()
var keybind_name: String:
	set(x):
		if not is_node_ready():
			await ready
		keybind_name = x
		label.text = keybind_name
		_update_button_text()
var listening := false:
	set(x):
		if not is_node_ready():
			await ready
		listening = x
		button.button_pressed = not x
		_update_button_text()

func _ready():
	button.pressed.connect(_button_pressed)
	listening = false
	
func _button_pressed():
	listening = true
	listening_started.emit(keybind_id)
	
func listening_cancelled():
	if not listening:
		return
	listening = false
	listening_ended.emit(keybind_id)
	
func _update_button_text():
	if listening:
		button.text = "Listening for Input..."
		return
	var events = InputMap.action_get_events(keybind_id)
	if len(events) > 0:
		var event = events[0]
		button.text = event.as_text()
	else:
		button.text = "(unset)"
	
func _input(event):
	if listening and (event is InputEventKey or (event is InputEventMouseButton and event.mouse_button != MOUSE_BUTTON_LEFT)) and event.pressed:
		InputMap.action_erase_events(keybind_id)
		InputMap.action_add_event(keybind_id, event)
		listening = false
		listening_ended.emit(keybind_id)
		get_viewport().set_input_as_handled()
