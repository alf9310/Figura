## Control for a slider
@tool
class_name SliderRow
extends HBoxContainer

signal changed(option_id: String, value: Variant)

@export var option_id: String = ""
@onready var _label:   Label   = $OptionLabel
@onready var _slider:  HSlider = $Slider
@onready var _readout: Label   = $Readout

func _ready() -> void:
	_slider.value_changed.connect(_on_value_changed)

func _on_value_changed(v: float) -> void:
	_readout.text = "%.2f" % v
	changed.emit(option_id, v)

func set_value_no_signal(v: float) -> void:
	_slider.set_value_no_signal(v)
	_readout.text = "%.2f" % v
