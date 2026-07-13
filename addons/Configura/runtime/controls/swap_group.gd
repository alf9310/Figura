## Scene contains fixed header and empty container for UIGenerator to populate
class_name SwapGroup
extends VBoxContainer

signal changed(option_id: String, value: Variant)

@export var option_id: String = ""
@onready var _container: HFlowContainer = $ButtonContainer
var _btn_group := ButtonGroup.new()
var btn

## Buttons are added by [UIGenerator] before _ready() runs, this connects their signals.
func _ready() -> void:
	for i in range(_container.get_child_count()):
		var child = _container.get_child(i)
		if child is Button or child is TextureButton:
			btn = child
		if btn == null:
			continue
		btn.button_group = _btn_group
		btn.toggled.connect(_on_button_toggled.bind(i))

func _on_button_toggled(active: bool, idx: int) -> void:
	if active:
		print("Swap ", idx, " of group ", option_id, " selected")
		changed.emit(option_id, idx)

func set_choice_no_signal(idx: int) -> void:
	for i in range(_container.get_child_count()):
		var btn := _container.get_child(i) as Button
		if btn:
			btn.set_pressed_no_signal(i == idx)
