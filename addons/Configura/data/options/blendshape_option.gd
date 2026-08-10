## Drives a single blendshape weight via an HSlider. Maps to Blender shape keys.
@tool
class_name BlendshapeOption
extends OptionDefinition

## Array of NodePaths to the MeshInstance3D nodes that share this blendshape.
@export var mesh_paths: Array[NodePath] = []

## Tracks all the mesh groups this shape appears in, used by the editor dock only (not read at runtime).
@export var editor_groups: Array[String] = []

## The exact string returned by get_blend_shape_name() for this shape.
@export var blend_shape_name: String

@export_range(0.0, 1.0, 0.01) var default_value: float = 0.0
@export_range(0.0, 1.0, 0.01) var min_value: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_value: float = 1.0

func get_option_category() -> String:
	return "blendshape"

func get_default_value() -> float:
	return default_value

func get_random_value() -> float:
	return randf_range(min_value, max_value)

func get_mesh_paths() -> Array[NodePath]:
	return mesh_paths

func apply_to_preview(manager: CreatorManager, value: Variant, should_camera_focus: bool = false, force_full_pass: bool = false) -> void:
	manager._apply_blendshape(self, value as float)

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	for mesh in skeleton.get_children():
		var current = mesh as MeshInstance3D
		if current == null: 
			continue
		var idx := current.find_blend_shape_by_name(blend_shape_name)
		if idx != -1:
			current.set_blend_shape_value(idx, value as float)

func get_editor_groups() -> Array[String]:
	if editor_groups.is_empty():
		return [group if not group.is_empty() else "General"]
	return editor_groups
	
func create_editor_rows(content_vbox, group_ui, group_name, group_has_atlas, active_ui_controls, group_scene, row_scene) -> GroupContainer:
	var container : GroupContainer = group_ui
	if container == null:
		container = group_scene.instantiate()
		content_vbox.add_child(container)
		container.setup(self)
		active_ui_controls.append(container)
	var row: OptionRow = row_scene.instantiate()
	row.set_meta("source_option", self)
	row.set_meta("category", group_name)
	container.add_option_rows(row)
	row.setup(self)
	active_ui_controls.append(row)
	return container

func _to_string() -> String:
	return "BlendshapeOption(%s | %s::%s | default: %.2f [%.2f–%.2f])" % [
		display_name, mesh_paths.size(), blend_shape_name,
		default_value, min_value, max_value
	]
