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
	_bind_swatches()

func _on_color_changed(color: Color) -> void:
	if _applying:
		return
	changed.emit(option_id, color)

func set_color_no_signal(color: Color) -> void:
	_applying = true
	_picker.color = color
	_applying = false
	
func select_swatch(color: Color) -> void:
	_picker.color = color
	_on_color_changed(color)

func _bind_swatches() -> void:
	var swatch_container := get_node_or_null("SwatchContainer")
	if swatch_container == null:
		return
	for btn in swatch_container.get_children():
		if btn.has_meta("swatch_color"):
			var color: Color = btn.get_meta("swatch_color")
			btn.pressed.connect(select_swatch.bind(color))
