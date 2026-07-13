## Runs when the developer clicks "Generate Scene" in the dock. 
# Writes a node tree into a .tscn file.
@tool
class_name UIGenerator
extends RefCounted

## Control scene templates preloaded once at class level.
## UIGenerator instantiates these (it never constructs control nodes by hand!)
const SLIDER_ROW_SCENE  := preload("res://addons/Configura/runtime/controls/slider_row.tscn")
const SWAP_GROUP_SCENE  := preload("res://addons/Configura/runtime/controls/swap_group.tscn")
const COLOR_ROW_SCENE   := preload("res://addons/Configura/runtime/controls/color_row.tscn")
const ANIM_ROW_SCENE  := preload("res://addons/Configura/runtime/controls/anim_row.tscn")


## Entry point. Called by SceneGenerator with:
## ui: 			the CreatorUI VBoxContainer node already added to the scene tree
## options:		the finalised Array[OptionDefinition] from CharacterConfig
## scene_root:	the CharacterCreator root node; every new node's .owner must be set to this
## theme:		grab the theme path from the config 
func build(
		ui: VBoxContainer,
		options: Array[OptionDefinition],
		scene_root: Node,
		theme: Theme,
		randomize_option: bool) -> void:
	
	ui.theme = theme
	
	_build_tabs(ui, options, scene_root)
	_build_footer(ui, scene_root,randomize_option)

## --- Tab structure --- 
func _build_tabs(
		ui: VBoxContainer,
		options: Array[OptionDefinition],
		scene_root: Node) -> void:
	
	var tabs := TabContainer.new()
	tabs.name                  = "Tabs"
	tabs.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("tab_separation", 10)
	ui.add_child(tabs)
	tabs.owner = scene_root

	## Group options by .group string
	## An empty group string falls back to "General".
	var group_order: Array[String] = []
	var grouped: Dictionary        = {}

	for opt in options:
		var g: String = opt.group if opt.group != "" else "General"
		if not grouped.has(g):
			group_order.append(g)
			grouped[g] = []
		grouped[g].append(opt)
	
	for group_name in group_order:
		print("Building tab for group ", group_name)
		_build_tab(tabs, group_name, grouped[group_name], scene_root)

func _build_tab(
		tabs: TabContainer,
		group_name: String,
		options: Array,
		scene_root: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.name                   = group_name
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	scroll.owner = scene_root
	
	var margins := MarginContainer.new()
	margins.name = "margins"
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin_value = 10
	margins.add_theme_constant_override("margin_top", margin_value)
	margins.add_theme_constant_override("margin_left", margin_value)
	margins.add_theme_constant_override("margin_bottom", margin_value)
	margins.add_theme_constant_override("margin_right", margin_value)
	scroll.add_child(margins)
	margins.owner = scene_root
	
	var vbox := VBoxContainer.new()
	vbox.name                      = "OptionList"
	vbox.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	margins.add_child(vbox)
	vbox.owner = scene_root
	
	var anim_button_group := ButtonGroup.new()
	for opt in options:
		var control := _build_control(opt, scene_root, anim_button_group)
		if control == null:
			continue
		vbox.add_child(control)
		_set_owners(control, scene_root)
		
	if vbox.get_child_count() == 0:
		tabs.remove_child(scroll)
		scroll.free()

## Walks a subtree and sets .owner on every node.
func _set_owners(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	
	node.scene_file_path = ""

	for child in node.get_children():
		_set_owners(child, scene_root)

## --- Control builders (one per OptionDefinition subtype) --- 
## Builds the control for each OptionDefinition subtype
func _build_control(
		opt: OptionDefinition,
		scene_root: Node,
		anim_button_group: ButtonGroup = null) -> Control:
	if opt.get("include") != null and not opt.include:
		return null
	if opt is MeshSwapOption:
		return _build_swap_group(opt as MeshSwapOption, scene_root)
	if opt is BlendshapeOption:
		return _build_slider_row(opt as BlendshapeOption)
	if opt is ColorOption:
		return _build_color_row(opt as ColorOption)
	if opt is AnimationOption:
		return _build_anim_row(opt as AnimationOption, anim_button_group)
	if opt is DeformOption:
		return _build_deform_row(opt as DeformOption)
	if opt is TextureAtlasOption: 
		return _build_atlas_group(opt as TextureAtlasOption, scene_root)

	push_warning(
		"[UIGenerator] Unrecognised OptionDefinition subtype '%s' — skipped."
		% opt.get_class()
	)
	return null

## Builds a slider option for blendshape
func _build_slider_row(opt: BlendshapeOption) -> SliderRow:
	var row := SLIDER_ROW_SCENE.instantiate() as SliderRow
	row.name      = "SliderRow_" + opt.resource_name
	row.option_id = opt.resource_name

	row.find_child("OptionLabel", true, false).text = opt.display_name
	row.find_child("Slider", true, false).min_value = opt.min_value
	row.find_child("Slider", true, false).max_value = opt.max_value
	row.find_child("Slider", true, false).value     = opt.default_value
	row.find_child("Readout", true, false).text     = "%.2f" % opt.default_value

	return row

## Builds buttons for mesh swap options
func _build_swap_group(opt: MeshSwapOption, scene_root: Node) -> SwapGroup:
	print("\tBuilding swap group for ", opt.group)
	var group := SWAP_GROUP_SCENE.instantiate() as SwapGroup
	group.name      = "SwapGroup_" + opt.resource_name
	group.option_id = opt.resource_name

	group.find_child("OptionLabel", true, false).text = opt.display_name

	var container := group.find_child("ButtonContainer", true, false) as HFlowContainer

	for i in range(opt.choices.size()):
		var choice := opt.choices[i] as MeshSwapChoice
		var btn = null
		if choice.icon:
			btn = TextureButton.new()
			btn.texture_normal = choice.icon
		else:
			btn = Button.new()
			btn.text = choice.label
		btn.name = "Choice_%d" % i
		btn.toggle_mode = true
		btn.button_pressed = (i == opt.default_choice)
		container.add_child(btn)

	return group

## Builds a color option
func _build_color_row(opt: ColorOption) -> ColorRow:
	var row := COLOR_ROW_SCENE.instantiate() as ColorRow
	row.name      = "ColorRow_" + opt.resource_name
	row.option_id = opt.resource_name

	row.find_child("OptionLabel", true, false).text  = opt.display_name
	row.find_child("ColorPicker", true, false).color = opt.default_color

	return row

func _build_anim_row(opt: AnimationOption, button_group: ButtonGroup) -> AnimRow:
	var row := ANIM_ROW_SCENE.instantiate() as AnimRow
	row.name           = "AnimRow_" + opt.resource_name
	row.option_id      = opt.resource_name
	row.animation_name = opt.animation_name

	row.find_child("OptionLabel", true, false).text   = opt.display_name
	var btn := row.find_child("PreviewButton", true, false) as Button
	btn.text          = "Preview"
	btn.toggle_mode   = true
	btn.button_group  = button_group

	return row
	
func _build_deform_row(opt: DeformOption) -> SliderRow:
	var row := SLIDER_ROW_SCENE.instantiate() as SliderRow
	row.name = "DeformRow_" + opt.resource_name
	row.option_id = opt.resource_name
	
	row.find_child("OptionLabel", true, false).text = opt.display_name
	row.find_child("Slider", true, false).min_value = opt.get_min_value()
	row.find_child("Slider", true, false).max_value = opt.get_max_value()
	row.find_child("Slider", true, false).value     = opt.default_value
	row.find_child("Readout", true, false).text     = "%.2f" % opt.default_value

	## For bidirectional sliders, adds a center tick
	if opt.deform_type == DeformOption.DeformType.BIDIRECTIONAL:
		row.find_child("Slider", true, false).tick_count       = 3
		row.find_child("Slider", true, false).ticks_on_borders = false

	return row
	
## Builds buttons for texture atlas options
func _build_atlas_group(opt: TextureAtlasOption, scene_root: Node) -> Control:
	print("\tBuilding atlas group for ", opt.display_name)
	var group := SWAP_GROUP_SCENE.instantiate() as SwapGroup
	group.name      = "AtlasGroup_" + opt.resource_name
	group.option_id = opt.resource_name

	group.find_child("OptionLabel", true, false).text = opt.display_name

	var container := group.find_child("ButtonContainer", true, false) as HFlowContainer

	for i in range(opt.choice_labels.size()):
		var btn = null
		if i < opt.choice_icons.size() and opt.choice_icons[i]:
			btn = TextureButton.new()
			btn.texture_normal = opt.choice_icons[i]
		else:
			btn = Button.new()
			btn.text = opt.choice_labels[i]
		btn.name           = "Choice_%d" % i
		btn.toggle_mode    = true
		btn.button_pressed = (i == opt.default_choice)
		container.add_child(btn)

	return group

## --- Footer --- 
func _build_footer(ui: VBoxContainer, scene_root: Node,randomize_choice:bool) -> void:
	var footer := HBoxContainer.new()
	footer.name                    = "Footer"
	footer.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	footer.alignment               = BoxContainer.ALIGNMENT_END
	ui.add_child(footer)
	footer.owner = scene_root
	var choices: Array = []
	
	if(randomize_choice):
		choices =[["RandomizeButton", "Randomize"]]
	choices.append_array([["SaveButton",   "Save"],
						  ["LoadButton",   "Load"]])
	for spec in choices:
		var btn := Button.new()
		btn.name = spec[0]
		btn.text = spec[1]
		footer.add_child(btn)
		btn.owner = scene_root
