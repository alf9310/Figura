## "Abstract" parent of Option classes: 
## [AnimationOption], [BlendshapeOption], [ColorOption], [DeformOption], [MeshSwapOption], [TextureAtlasOption]
@tool
class_name OptionDefinition
extends Resource

## Human-readable label shown in the generated UI.
@export var display_name: String = ""

## Icon selected for option to be shown in generated UI.
@export var icon_to_display: Texture2D = null

## Whether this Option appears in the generated UI
@export var include: bool = true

## Which tab this option appears under in the TabContainer.
@export var group: String = ""

func get_option_category() -> String:
	return "unknown"

func get_default_value() -> Variant:
	return null

func get_random_value() -> Variant:
	return null
	
func get_mesh_paths() -> Array[NodePath]:
	return []

func get_surface_index() -> int:
	return -1

func apply_to_preview(manager: CreatorManager, value: Variant, force_full_pass: bool = false) -> void:
	pass

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	pass

## Returns which groups this option should appear under in the editor dock.
func get_editor_groups() -> Array[String]:
	return [group if not group.is_empty() else "General"]

func create_editor_rows(
		content_vbox: VBoxContainer,
		group_ui: GroupContainer,
		group_name: String,
		group_has_atlas: bool,
		active_ui_controls: Array[Control],
		group_scene: PackedScene,
		row_scene: PackedScene) -> GroupContainer:
	return group_ui

## resource_name is inherited from Resource. 
## Used by CreatorManager to route UI events.
## Set by CharacterCreatorDock before passing config to SceneGenerator.
## Must be unique within a CharacterConfig.

func _to_string() -> String:
	return "Option(%s | group: %s | include: %s)" % [display_name, group, include]
