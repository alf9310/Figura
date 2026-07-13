## CreatorUI is the generated control tree the player actually interacts with. 
## Receive OptionDefinition resources, produce controls, emit signals when controls change.
## The mapping between a control's value and a mesh operation lives entirely in CreatorManager. 

## Could be replaced with custom UI as long as signals emitted: 
## option_changed(option_id, value), save_pressed, load_pressed, randomize_pressed
@tool
class_name CreatorUI
extends VBoxContainer

## Emitted whenever any control value changes.
## option_id matches OptionDefinition.resource_name.
## value is float, int, Color, or String depending on the control type.
signal option_changed(option_id: String, value: Variant)
signal save_pressed()
signal load_pressed()
signal randomize_pressed()

## Flat map of option_id -> Control node, used to sync controls without re-emitting signals.
var _control_map: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	# Walk the tree once to index the controls and connect their signals.
	_bind_controls(self)
	_bind_footer_buttons()

## Recursively searches the tree for custom Option control nodes
func _bind_controls(node: Node) -> void:
	if node is SwapGroup or node is SliderRow or node is ColorRow or node is AnimRow:
		var opt_id: String = node.option_id
		_control_map[opt_id] = node
		
		node.changed.connect(func(id: String, val: Variant) -> void: 
			option_changed.emit(id, val)
		)
		
	for child in node.get_children():
		_bind_controls(child)

## Finds the standard footer buttons and wires them up
func _bind_footer_buttons() -> void:
	var randomize_btn := find_child("RandomizeButton", true, false) as Button
	if randomize_btn:
		randomize_btn.pressed.connect(func() -> void: randomize_pressed.emit())

	var save_btn := find_child("SaveButton", true, false) as Button
	if save_btn:
		save_btn.pressed.connect(func() -> void: save_pressed.emit())
		
	var load_btn := find_child("LoadButton", true, false) as Button
	if load_btn:
		load_btn.pressed.connect(func() -> void: load_pressed.emit())

func hide_randomize_button() -> void:
	var btn := find_child("RandomizeButton", true, false) as Button
	if btn:
		btn.visible = false

## Syncing controls to a loaded state.
## Uses the UIGenerator's custom row APIs to mutate values without triggering signals.
func apply_state(state: CharacterState) -> void:
	for option_id in state.values:
		var control = _control_map.get(option_id)
		if control == null:
			continue
		var value: Variant = state.values[option_id]
		if control is SwapGroup:
			control.set_choice_no_signal(value as int)
		if control is SliderRow:
			control.set_value_no_signal(value as float)
		if control is ColorRow:
			control.set_color_no_signal(value as Color)
		if control is AnimRow:
			control.set_pressed_no_signal(value == control.animation_name)
