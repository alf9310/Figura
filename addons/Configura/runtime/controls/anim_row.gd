## Control for animations
class_name AnimRow
extends HBoxContainer

signal changed(option_id: String, value: Variant)

@export var option_id:      String = ""
@export var animation_name: String = ""
@onready var _label:  Label  = $OptionLabel
@onready var _button: Button = $PreviewButton

func _ready() -> void:
	_button.pressed.connect(_on_pressed)

func _on_pressed() -> void:
	changed.emit(option_id, animation_name)

func set_pressed_no_signal(active: bool) -> void:
	_button.set_pressed_no_signal(active)
