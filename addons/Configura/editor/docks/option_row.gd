## Sets up an option
@tool
extends Control
class_name OptionRow

signal _display_name_changed(new_name: String)

## Inspector nodes (set in .tscn)
@onready var _include_option:	CheckBox	= %IncludeOption
@onready var _display_name:		LineEdit	= %DisplayName
@onready var _icon_container:	PanelContainer = %InputContainer
@onready var _icon_label:		Label 		= %IconLabel
@onready var _color_picker:		ColorPickerButton = %ColorPicker
@onready var _icon_resource_container: ResourcePicker = %IconResourceContainer

## Node path to this option's mesh
var _mesh_path: NodePath
## The path to load this option's mesh
var _file_path: String

func _ready() -> void:
	_icon_label.visible = false
	_icon_container.visible = false
	
func setup(option: OptionDefinition) -> void:
	_include_option.button_pressed = true
	_display_name.text = option.display_name 
	if option is ColorOption:
		_color_picker.visible = true
		_color_picker.color = option.default_color
		_color_picker.color_changed.connect(func(c: Color):
			(option as ColorOption).default_color = c
		)
	
## Used by GroupContainer for individual swap choices
func setup_choice(choice: MeshSwapChoice, group: String) -> void:
	_include_option.button_pressed	= choice.include
	_display_name.text				= choice.label
	_mesh_path						= choice.mesh_path
	_file_path						= choice.file_path
	_icon_container.visible = true
	_icon_label.visible = true
	_display_name.text_changed.connect(func(text: String): _display_name_changed.emit(text))

## Atlas variant of setup_choice: no mesh path needed, badge reads "texture".
func setup_atlas_choice(label: String, is_default: bool) -> void:
	_include_option.button_pressed = true
	_display_name.text             = label
	_icon_container.visible = true
	_icon_label.visible = true
	_display_name.text_changed.connect(func(text: String): _display_name_changed.emit(text))

func get_choice() -> MeshSwapChoice:
	if not _include_option.button_pressed:
		return null
	var choice            := MeshSwapChoice.new()
	choice.label           = _display_name.text
	choice.include         = true
	choice.mesh_path       = _mesh_path
	choice.file_path	   = _file_path
	return choice

## Saving and loading of row options
func get_row_state() -> Dictionary:
	var state := {
		"include": _include_option.button_pressed,
		"display_name": _display_name.text,
	}
	if _icon_container.visible:
		var rp := _icon_resource_container as ResourcePicker
		state["icon"] = rp.selected_resource as Texture2D
	if _color_picker.visible:
		state["color"] = _color_picker.color
		
	var mode_controls := get_node_or_null("ColorModeControls")
	if mode_controls:
		var mode_button := mode_controls.get_node_or_null("DisplayModeOption") as OptionButton
		var icon_picker := mode_controls.get_node_or_null("SwatchIconPicker") as ResourcePicker
		if mode_button:
			state["display_mode"] = mode_button.selected
		if icon_picker and icon_picker.selected_resource:
			state["swatch_icon"] = icon_picker.selected_resource
	return state

func apply_row_state(state: Dictionary) -> void:
	if state.has("include"):
		_include_option.button_pressed = state["include"]
	if state.has("display_name"):
		_display_name.text = state["display_name"]
		_display_name_changed.emit(state["display_name"])
	if state.has("color") and _color_picker.visible:
		_color_picker.color = state["color"]
	if state.has("icon") and _icon_container.visible:
		_icon_resource_container.picker.set_edited_resource(state["icon"])
	var mode_controls := get_node_or_null("ColorModeControls")
	if mode_controls:
		if state.has("display_mode"):
			var mode_button := mode_controls.get_node_or_null("DisplayModeOption") as OptionButton
			if mode_button:
				mode_button.selected = state["display_mode"]
				mode_button.item_selected.emit(state["display_mode"])
		if state.has("swatch_icon") and mode_controls.get_node_or_null("SwatchIconPicker"):
			var icon_picker := mode_controls.get_node_or_null("SwatchIconPicker") as ResourcePicker
			if icon_picker.picker:
				icon_picker.picker.edited_resource = state["swatch_icon"]
