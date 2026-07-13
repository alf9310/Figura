## Creates resource picker for character creator dock
@tool
extends Container
class_name ResourcePicker

@export var picker_type: String = ""
@export var min_size: Vector2
var picker: EditorResourcePicker = EditorResourcePicker.new()
var selected_resource: Resource

func _ready():
	picker.name = "ResourcePicker"
	if picker_type:
		picker.base_type = picker_type
	picker.clip_contents = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if min_size > Vector2.ZERO:
		picker.custom_minimum_size = min_size
	picker.resource_changed.connect(func(res): selected_resource = res)
	add_child(picker)
	
