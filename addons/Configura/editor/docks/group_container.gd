## UI for dock containing options to include group, change group name, set group required, and set group default.
@tool
extends Control
class_name GroupContainer

@onready var _include_group		: CheckBox		= %IncludeGroup
@onready var _group_field		: LineEdit		= %GroupField
@onready var _required_row		: HBoxContainer = %RequiredRow
@onready var _required			: CheckBox		= %Required
@onready var _default_row		: HBoxContainer = %DefaultRow
@onready var _default_options	: OptionButton 	= %DefaultOptions
@onready var _option_row_container : VBoxContainer = %OptionRowContainer

var _owned_rows: Array[OptionRow] = []
var _source_option: OptionDefinition

var _curr_required: bool
var _curr_default: int

## Accepts MeshSwapOption or TextureAtlasOption.
## 'include' and 'required' are only defined on MeshSwapOption;
## atlas groups default to included=true, required=true (None is never offered).
func setup(opt: OptionDefinition) -> void:
	var has_choices : bool = (opt is MeshSwapOption and not opt.choices.is_empty()) or opt is TextureAtlasOption
	_required_row.visible = has_choices
	_default_row.visible  = has_choices
	_source_option        = opt
	_group_field.text     = opt.group

func register_rows(rows: Array[OptionRow]) -> void:
	_owned_rows = rows
	if not _required.button_pressed:
		_default_options.add_item("None")
	for row in rows:
		row._display_name_changed.connect(func(text: String):
			var offset := 0 if _required.button_pressed else 1
			_default_options.set_item_text(_owned_rows.find(row) + offset, text)
		)
	# Sync initial visibility with the checkbox state
	_set_rows_visible(_include_group.button_pressed) 

## Showing/hiding group's rows together
func _set_rows_visible(visible: bool) -> void:
	for row in _owned_rows:
		row.visible = visible
	_option_row_container.visible = visible
		
func add_option_rows(row: OptionRow) -> void:
	_option_row_container.add_child(row)

## Returns null when the group is unchecked.
## Returns MeshSwapOption or TextureAtlasOption depending on _source_option type.
func get_config_option() -> OptionDefinition:
	if not _include_group.button_pressed:
		return null
	if _source_option is TextureAtlasOption:
		return _get_atlas_option()
	return _get_swap_option()

## Iterates _owned_rows via get_choice() and injects a leading "None" entry when
## the group is not required.  Returns the assembled choices and resolved default index.
func _harvest_rows() -> Dictionary:
	var choices: Array[MeshSwapChoice] = []
	var dropdown_row_idx := _default_options.selected

	for row in _owned_rows:
		var choice := row.get_choice()
		if choice == null:
			continue
			
		var icon_container := row.get_node_or_null("%IconResourceContainer")
		if icon_container:
			var rp := icon_container as ResourcePicker
			if rp and rp.selected_resource:
				choice.icon = rp.selected_resource as Texture2D
		choices.append(choice)
		
	var default_idx := 0
	if not _required.button_pressed:
		var none_choice        := MeshSwapChoice.new()
		none_choice.label       = "None"
		none_choice.include     = true
		none_choice.mesh_path   = NodePath("")
		none_choice.file_path 	= ""
		choices.push_front(none_choice)

	return { "choices": choices, "default_choice": dropdown_row_idx }

func _get_swap_option() -> MeshSwapOption:
	var harvested      := _harvest_rows()
	var opt            := MeshSwapOption.new()
	opt.group           = _group_field.text
	opt.required        = _required.button_pressed
	opt.include         = true
	opt.choices.append_array(harvested["choices"])
	opt.default_choice  = harvested["default_choice"]
	return opt

func _get_atlas_option() -> TextureAtlasOption:
	var opt: TextureAtlasOption = _source_option.duplicate()
	opt.group          = _group_field.text
	opt.required       = _required.button_pressed
	opt.include        = true
	opt.choice_labels.clear()
	opt.choice_icons.clear()

	if not _required.button_pressed:
		opt.choice_labels.append("None")
		opt.choice_icons.append(null)

	for row in _owned_rows:
		opt.choice_labels.append(row._display_name.text)
		opt.choice_icons.append(null)
	opt.default_choice = _default_options.selected
	return opt

## Reenables required/default controls when "include" checkbox toggled
func _on_include_group_toggled(toggled_on: bool) -> void:
	_set_rows_visible(toggled_on) 
	_required.disabled = not toggled_on
	_required.button_pressed = _curr_required if toggled_on else false
	_default_options.disabled = not toggled_on
	_default_options.selected = _curr_default if toggled_on else 0
	
## Tracks chosen default index
func _on_default_options_item_selected(index: int) -> void:
	_curr_default = index
	
## Add "None" option when required is toggled
func _on_required_toggled(toggled_on: bool) -> void:
	_required.button_pressed = toggled_on
	if not _required.disabled:
		_curr_required = toggled_on
	var current_items: Array[String] = []
	for i in _default_options.item_count:
		var label := _default_options.get_item_text(i)
		if label != "None":
			current_items.append(label)
	_default_options.clear()
	if not toggled_on:
		_default_options.add_item("None")
	for label in current_items:
		_default_options.add_item(label)
	var offset := 0 if toggled_on else 1
	_default_options.selected = _curr_default + offset
	
func add_default_option(label: String) -> void:
	_default_options.add_item(label)
	
## Returns excluded copy of source option so SceneGenerator still bakes group's hidden state
func get_excluded_option() -> OptionDefinition:
	if _include_group.button_pressed or _source_option == null:
		return null
	var opt = _source_option.duplicate()
	opt.default_choice = -1
	opt.include = false
	return opt
	
# saving and loading of group containers
func get_group_state() -> Dictionary:
	var state := {
		"group_field": _group_field.text,
		"include_group": _include_group.button_pressed,
		"required": _required.button_pressed,
		"default_selected": _default_options.selected,
		"rows": [],
	}
	for row in _owned_rows:
		state["rows"].append(row.get_row_state())
	return state

func apply_group_state(state: Dictionary) -> void:
	_curr_required = state.get("required", _curr_required)
	_curr_default  = state.get("default_selected", _curr_default)

	if state.has("group_field"):
		_group_field.text = state["group_field"]
	if state.has("include_group"):
		_include_group.button_pressed = state["include_group"]
		_on_include_group_toggled(state["include_group"])
	if state.has("rows"):
		var rows: Array = state["rows"]
		for i in min(rows.size(), _owned_rows.size()):
			_owned_rows[i].apply_row_state(rows[i])
	if state.has("default_selected") and _default_options.item_count > 0:
		var idx: int = state["default_selected"]
		_default_options.selected = clampi(idx, 0, _default_options.item_count - 1)
