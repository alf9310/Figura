## Applying state outside the creator scene to a character mesh elsewhere in the game
@tool
class_name CharacterStateApplier
extends RefCounted

## Would be used if spawning the player character
static func apply(
		state: CharacterState,
		config: CharacterConfig,
		character_root: Node) -> void:
	
	var skeleton = character_root.find_child("Skeleton3D")
	if skeleton == null:
		push_error("ERROR: Could not find Skeleton3D node on the base model.")
		return
	
	# Build option map from config
	var option_map: Dictionary = {}
	for opt in config.options:
		option_map[opt.resource_name] = opt
		
	# Add BaseMesh via warm_cache bypass
	for mesh_path in state.active_meshes:
		var packed:= load(mesh_path) as PackedScene
		if packed == null: 
			push_warning("Active mesh null")
			continue
		var model_root = packed.instantiate()
		skeleton.add_child(model_root)
		model_root.owner = character_root

	for option_id in state.values:
		var opt := option_map.get(option_id) as OptionDefinition
		if opt == null:
			continue
		opt.apply_to_character(character_root, skeleton, state.values[option_id])
