## Controls for color
class_name ColorRow
extends HBoxContainer

signal changed(option_id: String, value: Variant)

@export var option_id: String = ""
@onready var _label:  Label             = $OptionLabel
@onready var _picker: ColorPickerButton = $ColorPicker
var _applying := false

func _ready() -> void:
	_picker.color_changed.connect(_on_color_changed)

func _on_color_changed(color: Color) -> void:
	changed.emit(option_id, color)

func set_color_no_signal(color: Color) -> void:
	_applying = true
	_picker.color = color
	_applying = false
