## Drives an AnimationPlayer, used to let the player choose an idle pose or expression preset. 
## It generates a row of buttons.
@tool
class_name AnimationOption
extends OptionDefinition

## NodePath to the AnimationPlayer. Relative to SubViewport root.
@export var animation_player_path: NodePath

## The animation to play. Must match a name in the AnimationPlayer's library.
@export var animation_name: String = ""

## If true, the animation loops and keeps playing in the preview.
## If false, it plays once and holds the final frame (useful for poses).
@export var loop_in_preview: bool = false

## If true, the animation is baked into the exported CharacterState
## as a pose (the player's choice persists in-game).
## If false, it's preview-only and not saved to CharacterState.
@export var include_in_export: bool = true

## Set by AnimationTreeBuilder after the tree is built.
## Used by CreatorManager to set the PoseTransition transition_request parameter.
@export var tree_node_name: String = ""

## If true, this animation is applied when the character creator first opens.
@export var is_default: bool = false

func get_option_category() -> String:
	return "anim"

func get_default_value() -> Variant:
	return animation_name if is_default else null

func apply_to_preview(manager: CreatorManager, value: Variant, force_full_pass: bool = false) -> void:
	if value == null:
		return
	manager._apply_animation(self)

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	if value == null:
		return
	var player := character_root.get_node(animation_player_path) as AnimationPlayer
	if player == null:
		return
	if player.has_animation(value):
		player.play(value)
		player.advance(player.get_animation(value).length)
		player.pause()

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

## Returns a string with animation options settings
func _to_string() -> String:
	return "AnimationOption(%s | %s → %s | loop: %s | export: %s)" % [
		display_name, animation_player_path, animation_name,
		loop_in_preview, include_in_export
	]
