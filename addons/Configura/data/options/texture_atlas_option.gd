## Drives texture atlas selection with buttons. Used by offsetting UV coordinates on target material.
@tool
class_name TextureAtlasOption
extends OptionDefinition

## Array of NodePaths to the MeshInstance3D nodes that this option controls.
@export var mesh_paths: Array[NodePath] = []
## Surface index on the mesh to target.
@export var surface_index: int = 0
## Number of options in a horizontal row
@export var columns: int = 4
## Number of rows for options
@export var rows: int = 1
## The labels for each UI button (e.g. ["Almond", "Round", "Cat", "Droopy"])
## The size of this array determines how many buttons are generated.
@export var choice_labels: Array[String] = []
## If true, at least one option must be selected
@export var required: bool = true
## The default texture atlas
@export var default_choice: int = 0
## If true, modifying this material alters all meshes sharing it.
@export var apply_to_shared_material: bool = true
## Icons shown on each choice button, displayed in the generated scene.
@export var choice_icons: Array[Texture2D] = []
## Tracks all the mesh groups this option appears in, not read at runtime.
@export var editor_groups: Array[String] = []
## For ShaderMaterial: the uniform name for UV offset (usually vec2 or vec3).
## For StandardMaterial3D: leave blank, uses uv1_offset automatically.
@export var shader_param: String = ""

func get_option_category() -> String:
	return "atlas"

func get_default_value() -> Variant:
	return default_choice

func get_random_value() -> int:
	return randi() % choice_labels.size()

func get_mesh_paths() -> Array[NodePath]:
	return mesh_paths

func get_surface_index() -> int:
	return surface_index

func apply_to_preview(manager: CreatorManager, value: Variant, force_full_pass: bool = false) -> void:
	manager._apply_texture_atlas(self, value as int)

func get_editor_groups() -> Array[String]:
	if editor_groups.is_empty():
		return [group if not group.is_empty() else "General"]
	return editor_groups

func create_editor_rows(content_vbox, group_ui, group_name, group_has_atlas, active_ui_controls, group_scene, row_scene) -> GroupContainer:
	var container : GroupContainer = group_scene.instantiate()
	content_vbox.add_child(container)
	container.setup(self)
	var rows: Array[OptionRow] = []
				
	for i in range(choice_labels.size()):
		var row: OptionRow = row_scene.instantiate()
		container.add_option_rows(row)
		row.setup_atlas_choice(choice_labels[i], i == default_choice)
		rows.append(row)
		container.add_default_option(choice_labels[i])

	container.register_rows(rows)
	active_ui_controls.append(container)
	return container

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	var choice_idx := value as int
	var uv_width := 1.0 / float(columns)
	var uv_height := 1.0 / float(rows)
	var offset := Vector3((choice_idx % columns) * uv_width, (choice_idx / columns) * uv_height, 0.0)
			
	var mesh := character_root.get_node_or_null(mesh_paths[0]) as MeshInstance3D
	if mesh == null: 
		return
	var mat := mesh.get_active_material(surface_index).duplicate()
	if mat is StandardMaterial3D:
		mat.uv1_offset = offset
	elif mat is ShaderMaterial:
		mat.set_shader_parameter(shader_param, Vector2(offset.x, offset.y))
	mesh.set_surface_override_material(surface_index, mat)

## Returns a string with the Texture atlas options settings
func _to_string() -> String:
	return "TextureAtlasOption(%s | meshes:%d | col:%d row:%d)" % [
		display_name, mesh_paths.size(), columns, rows
	]
