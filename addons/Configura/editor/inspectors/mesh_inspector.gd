## Pure, stateless utility that takes a scene, walks the node tree, 
## and returns an Array[OptionDefinition]
@tool
class_name MeshInspector
extends RefCounted

## Swap Slots (Modular Meshes)
## Groups all meshes by the first token of their name, split on _ . , -
static var _splitter := RegEx.create_from_string("[_.,\\-]+")
## Matches the suffix _Atlas_<rows>_<cols> at the end of a material name.
static var _atlas_regex := RegEx.create_from_string("_Atlas_(\\d+)_(\\d+)$")

## The scene is instantiated into a temporary node that lives only for the duration of the call
func inspect(base_model_packed_scene: PackedScene, orig_packed_scene: PackedScene, output_path: String) -> Array[OptionDefinition]:
	var base_model_root := base_model_packed_scene.instantiate()
	var orig_Root := orig_packed_scene.instantiate()
	
	var temp_host := Node.new()
	
	EditorInterface.open_scene_from_path("res://addons/Configura/runtime/creator_controller.tscn")
	EditorInterface.get_edited_scene_root().add_child(temp_host)
	temp_host.add_child(base_model_root)
	temp_host.add_child(orig_Root)
	
	# Global trackers
	var global_seen_colors: Dictionary = {}
	var global_seen_blendshapes: Dictionary = {}
	var global_seen_atlases: Dictionary = {}

	var results: Array[OptionDefinition] = []
	var meshes := _find_model_meshes(base_model_root)
	
	if not meshes.is_empty():
		# Swap grouping is name-based across all meshes, not per-sibling
		results.append_array(_inspect_swap_slots(meshes, base_model_root, output_path))
		
		for mesh in meshes:
			_inspect_blendshapes(mesh, base_model_root, global_seen_blendshapes, results)
			results.append_array(_inspect_materials(mesh, base_model_root, global_seen_colors, global_seen_atlases))
		
		results.append_array(_inspect_pose_animations(base_model_root))
		
	var origSceneMeshes = _filter_meshes(orig_Root)
	
	if not origSceneMeshes.is_empty():
		results.append_array(_inspect_swap_slots(origSceneMeshes, orig_Root, output_path))
		
		for mesh in origSceneMeshes:
			_inspect_blendshapes(mesh, orig_Root, global_seen_blendshapes, results)
			results.append_array(_inspect_materials(mesh, orig_Root, global_seen_colors, global_seen_atlases))
		
	temp_host.get_parent().remove_child(temp_host)
	temp_host.free()
	
	EditorInterface.close_scene()
	return results

func _inspect_swap_slots(meshes: Array[MeshInstance3D], root: Node, output_path: String) -> Array[OptionDefinition]:
	print("Inspecting Mesh Swaps")
	
	var groups: Dictionary[String, Array] = {}
	
	for mesh_node in meshes:
		var parts := _splitter.sub(mesh_node.name, "|", true).split("|", false)
		var is_base_mesh = false
		
		for p in parts:
			if p.to_lower() == "base":
				is_base_mesh = true
				break
		
		var group := parts[0].capitalize() if not is_base_mesh else parts[1].capitalize()
		
		var choice				:= MeshSwapChoice.new()
		choice.mesh_path		= root.get_path_to(mesh_node)
		# Set the string file path location to load this choice's mesh
		choice.file_path 		= output_path + "/meshes/" + mesh_node.name + ".tscn"
		choice.label			= parts[1].capitalize() if not is_base_mesh and parts.size() > 1 else ""
		choice.include			= not is_base_mesh

		if not group in groups:
			groups[group] = []
		groups[group].append(choice)
		
		print("\t%s -> group: %s  label: '%s' file_path: %s" % [mesh_node.name, group, choice.label, choice.file_path])
	
	var results: Array[OptionDefinition] = []
	for group: String in groups:
		var opt				:= MeshSwapOption.new()
		opt.group			= group
		opt.default_choice	= 0
		opt.include			= true
		opt.required		= true
		opt.choices.append_array(groups[group] if groups[group].size() > 1 else [])
		results.append(opt)

	return results

func _filter_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D and node.mesh != null and not found.has(node):
			var is_base_mesh = false
			var node_name_parts = _splitter.sub(node.name, "|", true).split("|", false)
			
			for name in node_name_parts:
				if name.to_lower() == "base":
					is_base_mesh = true
					break
			
			if not is_base_mesh:
				found.append(node)
	return found

## Finds base model meshes
func _find_model_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D and node.mesh != null and not found.has(node):
			found.append(node)
	return found

## Inspects mesh's blendshapes
func _inspect_blendshapes(mesh_node: MeshInstance3D, root: Node, global_seen: Dictionary, results: Array[OptionDefinition]) -> Array[OptionDefinition]:
	print("Inspecting Mesh Blendshapes")
	var count := mesh_node.get_blend_shape_count()
	print("\tFound ", count, " blendshapes")
	
	# Parse group from mesh name
	var mesh_parts := _splitter.sub(mesh_node.name, "|", true).split("|", false)
	var mesh_group := mesh_parts[0].capitalize()

	for i in range(count):
		var shape_name = mesh_node.mesh.get_blend_shape_name(i)
		# Skip Blender's internal reset shapes
		if shape_name.begins_with("_") or shape_name.to_upper() == "BASIS":
			continue
		
		if global_seen.has(shape_name):
			var existing_opt: BlendshapeOption = global_seen[shape_name]
			existing_opt.mesh_paths.append(root.get_path_to(mesh_node))
			
		else:
			print("\tAdding blendshape ", shape_name)
			# New blendshape: Create option and register
			var parts := _splitter.sub(shape_name, "|", true).split("|", false)
			var group_name: String
			var label : String
			
			if parts.size() > 1:
				group_name = parts[0].capitalize()
				label      = " ".join(parts.slice(1)).capitalize()
			else:
				group_name = "General"
				label      = parts[0].capitalize()
				
			var opt := BlendshapeOption.new()
			opt.display_name		= label
			opt.group				= group_name
			opt.editor_groups		= [group_name]
			opt.mesh_paths			= [root.get_path_to(mesh_node)]
			opt.blend_shape_name	= shape_name
			opt.default_value		= mesh_node.get_blend_shape_value(i)
			opt.min_value			= 0.0
			opt.max_value			= 1.0
			
			global_seen[shape_name] = opt
			results.append(opt)

	return results
	
	
## Color Parameters & Texture Atlas
## Walks every surface on every MeshInstance3D and looks for color-type shader parameters on ShaderMaterial, falling back to standard albedo/emission on StandardMaterial3D
func _inspect_materials(mesh_node: MeshInstance3D, root: Node, global_colors: Dictionary, global_atlases: Dictionary) -> Array[OptionDefinition]:
	print("Inspecting Materials for ", mesh_node.name)
	var results: Array[OptionDefinition] = []
	
	# Parse group from mesh name
	var parts := _splitter.sub(mesh_node.name, "|", true).split("|", false)
	# Determines whether this node's mesh is a base mesh
	var is_base_mesh = false
	
	# Loop through each part's name to see if it's a base mesh
	for p in parts:
		if p.to_lower() == "base":
			is_base_mesh = true
			break
	
	# Base Mesh: Yes | "Base_Body"    | parts = ["Base", "Body"]     -> group = "Body"
	# Base Mesh: No  | "Shirt_Sweater | parts = ["Shirt", "Sweater"] -> group = "Shirt"
	var mesh_group_name := parts[0].capitalize() if not is_base_mesh else parts[1].capitalize()

	for surface_idx in range(mesh_node.get_surface_override_material_count()):
		var mat := mesh_node.get_active_material(surface_idx)
		if mat == null: continue
		var mat_name := mat.resource_name
		var mat_id := str(mat.get_instance_id())
		
		# Split the material name to be parsed
		var mat_name_parts = _splitter.sub(mat_name, "|", true).split("|", false)
		
		# Atlas Detection  convention: <name>_Atlas_<rows>_<cols>
		var atlas_match := _atlas_regex.search(mat_name)
		if atlas_match:
			var signature := mesh_group_name + "::" + mat_name

			if global_atlases.has(signature):
				var existing_opt: TextureAtlasOption = global_atlases[signature]
				if not root.get_path_to(mesh_node) in existing_opt.mesh_paths:
					existing_opt.mesh_paths.append(root.get_path_to(mesh_node))
				if not mesh_group_name in existing_opt.editor_groups:
					existing_opt.editor_groups.append(mesh_group_name)
				continue

			var opt := TextureAtlasOption.new()
			opt.rows          = atlas_match.get_string(1).to_int()
			opt.columns       = atlas_match.get_string(2).to_int()

			# Display name = everything before the _Atlas_ suffix, separated by spaces
			var prefix        := mat_name.substr(0, atlas_match.get_start())
			opt.display_name  = prefix.replace("_", " ").capitalize()

			opt.group         = mesh_group_name
			opt.editor_groups = [mesh_group_name]
			opt.mesh_paths    = [root.get_path_to(mesh_node)]
			opt.surface_index = surface_idx
			opt.apply_to_shared_material = true

			# ShaderMaterial: the Mapping node Location uniform must be named 'uv_offset'.
			# StandardMaterial3D drives uv1_offset natively1
			opt.shader_param  = "uv_offset" if mat is ShaderMaterial else ""

			if opt.rows <= 0 or opt.columns <= 0:
				push_warning("Material '%s' has invalid atlas dimensions (%d rows, %d cols). Skipping." \
					% [mat_name, opt.rows, opt.columns])
				continue

			var total_options := opt.columns * opt.rows
			for i in range(total_options):
				opt.choice_labels.append("Style " + str(i + 1))

			# Read whichever UV offset the material already has so the dock can
			# pre-tick whichever cell was active in Blender at the time of export.
			var raw_offset: Variant = null
			if mat is ShaderMaterial and not opt.shader_param.is_empty():
				raw_offset = mat.get_shader_parameter(opt.shader_param)
			elif mat is StandardMaterial3D:
				raw_offset = mat.uv1_offset   # Vector3

			var offset := Vector2.ZERO
			if   raw_offset is Vector2: offset = raw_offset
			elif raw_offset is Vector3: offset = Vector2(raw_offset.x, raw_offset.y)

			var active_col := clampi(roundi(offset.x * opt.columns), 0, opt.columns - 1)
			var active_row := clampi(roundi(offset.y * opt.rows),    0, opt.rows    - 1)
			opt.default_choice = active_row * opt.columns + active_col

			global_atlases[signature] = opt
			results.append(opt)

			continue
	
		# Color Detection
		if mat is ShaderMaterial:
			print("Found a ShaderMaterial")
			var shader = mat.shader
			if shader == null: 
				continue
				
			for param in shader.get_shader_uniform_list():
				if param["hint"] == PROPERTY_HINT_COLOR_NO_ALPHA \
				or param["type"] == TYPE_COLOR:
					var pname: String = param["name"]
					
					# Unique signature for this color parameter within this group
					var signature := mat_id +  "::" + pname
					if global_colors.has(signature):
						var existing_opt: ColorOption = global_colors[signature]
						if not root.get_path_to(mesh_node) in existing_opt.mesh_paths:
							existing_opt.mesh_paths.append(root.get_path_to(mesh_node))
						if not mesh_group_name in existing_opt.editor_groups:
							existing_opt.editor_groups.append(mesh_group_name)
						continue
					
					print("\tAdding color ", pname)
					
					var opt := ColorOption.new()
					opt.display_name				= pname.replace("_", " ").capitalize()
					opt.group						= mesh_group_name
					opt.editor_groups				= [mesh_group_name]
					opt.mesh_paths					= [root.get_path_to(mesh_node)]
					opt.shader_param				= pname
					opt.default_color				= mat.get_shader_parameter(pname)
					# Flag this so the manager knows to color all meshes sharing this material!
					opt.apply_to_shared_material	= true
					opt.surface_index				= surface_idx
					
					global_colors[signature] = opt
					results.append(opt)
		
		elif mat is StandardMaterial3D:
			# 1. Signature for standard materials
			var signature := mat_id + "::albedo_color"
			if global_colors.has(signature):
				var existing_opt: ColorOption = global_colors[signature]
				if not root.get_path_to(mesh_node) in existing_opt.mesh_paths:
					existing_opt.mesh_paths.append(root.get_path_to(mesh_node))
				if not mesh_group_name in existing_opt.editor_groups:
					existing_opt.editor_groups.append(mesh_group_name)
				continue
			
			print("Found a StandardMaterial3D")
			
			# Expose albedo and emission as the two most useful color options
			var albedo := ColorOption.new()
			# Dynamic naming (e.g. "Hair Color", "Body Color")
			# If material group and mesh group are the same, display name should be the second string
			# Otherwise, default to the first string in the material name parts
			var display_name = mat_name
			var group_name = "General"
			
			if mat_name_parts.size() > 1: 
				display_name = mat_name_parts[1]
				group_name = mat_name_parts[0] 
			
			print("Group Name: %s | Display Name: %s" % [group_name, display_name])
			albedo.display_name  = display_name + " Color"
			albedo.group         = group_name 
			albedo.editor_groups            = [mesh_group_name]
			albedo.mesh_paths     = [root.get_path_to(mesh_node)]
			albedo.shader_param  = "albedo_color"
			albedo.default_color = mat.albedo_color
			albedo.apply_to_shared_material = true
			albedo.surface_index            = surface_idx
			
			global_colors[signature] = albedo
			results.append(albedo)

	return results
	
## AnimationPlayer nodes are found anywhere in the tree, not just on the root mesh. 
## The inspector then filters the animation list to exclude internal tracks
func _inspect_pose_animations(root: Node) -> Array[OptionDefinition]:
	print("Inspecting Pose animations")
	var results: Array[OptionDefinition] = []

	for player in root.find_children("*", "AnimationPlayer", true, false):
		if not player is AnimationPlayer:
			continue

		for anim_path in player.get_animation_list():
			var anim_name: String = anim_path.get_file()

			# Skip internal animations
			if anim_name == "RESET" \
			or anim_name.begins_with("_"):
				continue

			var opt := AnimationOption.new()
			opt.display_name          = anim_name.replace("_", " ").capitalize()
			opt.animation_player_path = root.get_path_to(player)
			opt.animation_name        = anim_name
			opt.include_in_export     = true
			## tree_node_name is left empty AnimationTreeBuilder fills it in
			results.append(opt)
			print("\tAdding pose animation ", anim_name)

	return results
