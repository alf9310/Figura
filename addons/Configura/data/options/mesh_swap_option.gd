## Swaps between meshes by loading and unloading scenes as skeleton children. Used with [MeshSwapChoice]
@tool
class_name MeshSwapOption
extends OptionDefinition

## Whether at least one option must be selected, or this can be set as "None"
@export var required: bool = true

## The individual choices. Contains [MeshSwapChoice](s).
@export var choices: Array[MeshSwapChoice] = []

## Index of the choice shown by default.
@export var default_choice: int = 0

func get_option_category() -> String:
	return "swap"

func get_default_value() -> int:
	return default_choice

func get_random_value() -> Variant:
	if choices.is_empty():
		return -1
	return randi() % choices.size()

func apply_to_preview(manager: CreatorManager, value: Variant, force_full_pass: bool = false) -> void:
	manager._apply_swap(self, value as int, force_full_pass)

func get_editor_groups() -> Array[String]:
	return [group if not group.is_empty() else "General"]

func create_editor_rows(content_vbox, group_ui, group_name, group_has_atlas, active_ui_controls, group_scene, row_scene) -> GroupContainer:
	if group_has_atlas:
		return group_ui
	var container : GroupContainer = group_scene.instantiate()
	content_vbox.add_child(container)
	container.setup(self)
	var rows: Array[OptionRow] = []
					
	for choice: MeshSwapChoice in choices:
		var row: OptionRow = row_scene.instantiate()
		container.add_option_rows(row)
		row.setup_choice(choice, group)
		rows.append(row)
		container.add_default_option(choice.label)			
	container.register_rows(rows)
	active_ui_controls.append(container)
	return container

## Returns a string with the mesh swap options settings
func _to_string() -> String:
	var choice_labels := ", ".join(
		choices.map(func(c: MeshSwapChoice) -> String: return str(c) + "\n")
	)
	return "MeshSwapOption(%s | required: %s | default: %d | choices: [%s])" % [
		display_name, required, default_choice, choice_labels
	]
