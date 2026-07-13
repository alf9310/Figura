## Builds the animation tree
@tool
class_name AnimationTreeBuilder
extends RefCounted

## Entry point. Called by SceneGenerator after the character scene has been
## instantiated inside the SubViewport. Returns the built AnimationTree node,
## which SceneGenerator adds to the SubViewport and sets .owner on.
func build(
		character_root: Node,
		config: CharacterConfig,
		scene_root: Node) -> Dictionary:

	var player := _find_animation_player(character_root)
	if player == null:
		push_warning("[AnimationTreeBuilder] No AnimationPlayer found in character scene.")
		return {}

	var poses = _parse_animation_library(player)   # Array of anim path strings

	var anim_tree := AnimationTree.new()
	anim_tree.name       = "CharacterAnimationTree"
	anim_tree.active     = true

	var blend_tree := AnimationNodeBlendTree.new()
	anim_tree.tree_root  = blend_tree

	# Pose transition
	var transition := AnimationNodeTransition.new()
	blend_tree.add_node("PoseTransition", transition)
	blend_tree.connect_node("output", 0, "PoseTransition")

	var pose_index := 0
	for pose_path in poses:
		var display_name: String = pose_path.get_file()
		var node_name    := _sanitize(display_name)

		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = pose_path
		blend_tree.add_node(node_name, anim_node)

		transition.add_input(node_name)
		blend_tree.connect_node("PoseTransition", pose_index, node_name)

		## Write tree_node_name back onto the matching AnimationOption resource.
		_stamp_anim_option(config, display_name, node_name)

		pose_index += 1

	return { "tree": anim_tree, "player": player }

## --- Animation library parser (mirrors _parse_animation_library from user code) --- 
func _parse_animation_library(player: AnimationPlayer) -> Array:
	var poses:  Array      = []

	for anim_path in player.get_animation_list():
		var anim_name: String = anim_path.get_file()

		poses.append(anim_path)

	return poses

## --- Utilities --- 
func _find_animation_player(root: Node) -> AnimationPlayer:
	var results := root.find_children("*", "AnimationPlayer", true, false)
	return results[0] if results.size() > 0 else null

static func sanitize(name: String) -> String:
	return name.replace("/", "_").replace(".", "_").replace(" ", "_")

func _sanitize(name: String) -> String:
	return AnimationTreeBuilder.sanitize(name)

## Write the resolved blend tree node name back onto the matching AnimationOption.
func _stamp_anim_option(
		config: CharacterConfig,
		display_name: String,
		node_name: String) -> void:

	for opt in config.options:
		if opt is AnimationOption:
			if (opt as AnimationOption).animation_name == display_name:
				(opt as AnimationOption).tree_node_name = node_name
				return
