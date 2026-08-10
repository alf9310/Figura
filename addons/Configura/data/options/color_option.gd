## Drives a color parameter on a material, producing a ColorPickerButton, 
## Handles both ShaderMaterial custom uniforms and StandardMaterial3D built-in properties.
@tool
class_name ColorOption
extends OptionDefinition

enum DisplayMode { 
	SWATCHES, 
	SWATCHES_AND_PICKER, 
	PICKER }

## NodePath to the MeshInstance3D whose material contains this parameter.
@export var mesh_paths: Array[NodePath] = []
## Surface index on the mesh to target. -1 means apply to all surfaces.
@export var surface_index: int = 0
## For ShaderMaterial: the uniform name as declared in the shader.
## For StandardMaterial3D: one of the recognised property names below.
@export var shader_param: String = ""
@export var default_color: Color = Color.WHITE
## If true, also update the material on any other MeshInstance3D nodes
## that share the same material resource (e.g. eyelashes sharing skin material).
@export var apply_to_shared_material: bool = false
## Tracks all the mesh groups this shape appears in, used by the editor dock only (not read at runtime).
@export var editor_groups: Array[String] = []
## Mode for how colors are displayed
@export var display_mode: DisplayMode = DisplayMode.PICKER
## Icon for how color swatches appear
@export var swatch_icon: Texture2D

func get_option_category() -> String:
	return "color"
	
func get_default_value() -> Color:
	return default_color

func get_random_value() -> Color:
	var h := randf()
	var s := randf_range(0.0, 0.7)
	var v := randf_range(0.4, 0.95)
	return Color.from_hsv(h, s, v)

func get_mesh_paths() -> Array[NodePath]:
	return mesh_paths

func get_surface_index() -> int:
	return surface_index

func apply_to_preview(manager: CreatorManager, value: Variant, should_camera_focus: bool = false, force_full_pass: bool = false) -> void:
	manager._apply_color(self, value as Color)

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	for path in mesh_paths:
		var mesh := character_root.get_node_or_null(path) as MeshInstance3D
		if mesh == null: 
			continue
		## Helper logic to apply to all surfaces if index is -1
		var start_idx = 0 if surface_index == -1 else surface_index
		var end_idx = mesh.get_surface_override_material_count() - 1 if surface_index == -1 else surface_index

		## Makes materials independent from the root scene
		for i in range(start_idx, end_idx + 1):
			var mat := mesh.get_active_material(i).duplicate()
			if mat is ShaderMaterial:
				mat.set_shader_parameter(shader_param, value as Color)
			elif mat is StandardMaterial3D and shader_param == "albedo_color":
				mat.albedo_color = value as Color
			mesh.set_surface_override_material(i,mat)
	
func get_editor_groups() -> Array[String]:
	if editor_groups.is_empty():
		return [group if not group.is_empty() else "General"]
	return editor_groups

func create_editor_rows(content_vbox, group_ui, group_name, group_has_atlas, active_ui_controls, group_scene, row_scene) -> GroupContainer:
	var row: OptionRow = row_scene.instantiate()
	row.set_meta("source_option", self)
	row.set_meta("category", group_name)
	content_vbox.add_child(row)
	row.setup(self)
	_build_color_editor_controls(row)
	active_ui_controls.append(row)
	return group_ui
	
func _build_color_editor_controls(row: OptionRow) -> void:
	var controls_box := HBoxContainer.new()
	controls_box.name = "ColorModeControls"

	var mode_button := OptionButton.new()
	mode_button.name = "DisplayModeOption"
	for mode_name in DisplayMode.keys():
		mode_button.add_item(mode_name.capitalize().replace("_", " "))
	mode_button.select(display_mode)
	controls_box.add_child(mode_button)

	var icon_picker := ResourcePicker.new()
	icon_picker.name        = "SwatchIconPicker"
	icon_picker.picker_type = "Texture2D"
	icon_picker.min_size    = Vector2(100, 28)
	icon_picker.visible     = display_mode != DisplayMode.PICKER
	controls_box.add_child(icon_picker)

	row.add_child(controls_box)

	icon_picker.picker.edited_resource = swatch_icon
	icon_picker.picker.resource_changed.connect(func(res: Resource):
		swatch_icon = res as Texture2D
	)

	mode_button.item_selected.connect(func(idx: int):
		display_mode = idx as DisplayMode
		icon_picker.visible = display_mode != DisplayMode.PICKER
	)

func _to_string() -> String:
	return "ColorOption(%s | %s surface:%d | param: %s | default: %s | shared: %s | mode: %s)" % [
		display_name, mesh_paths.size(), surface_index,
		shader_param, default_color.to_html(), apply_to_shared_material,
		DisplayMode.keys()[display_mode]
	]
