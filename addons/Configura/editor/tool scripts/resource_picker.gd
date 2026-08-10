## Creates resource picker for character creator dock
@tool
extends Container
class_name ResourcePicker

@export var picker_type: String = ""
@export var min_size: Vector2
@export var show_edit_button: bool = false

var picker: EditorResourcePicker = EditorResourcePicker.new()
var selected_resource: Resource

func _ready():
	if not Engine.is_editor_hint():
		return
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
	if show_edit_button:
		var edit_btn := Button.new()
		edit_btn.text = "Edit"
		edit_btn.pressed.connect(func():
			if picker.edited_resource:
				EditorInterface.inspect_object(picker.edited_resource)
		)
		add_child(edit_btn)
