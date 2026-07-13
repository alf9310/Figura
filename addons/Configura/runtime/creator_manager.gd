## Serializes CharacterState and applies it to the live mesh.
@tool
extends Node
class_name CreatorManager

static var _splitter := RegEx.create_from_string("[_.,\\-]+")

var _config:			CharacterConfig
var _current_state:		CharacterState
var _character_root:	Node
var _anim_tree:       AnimationTree   # null if no AnimationTree in scene
var _ui:				Control       # held for load_state UI sync
var _option_map:		Dictionary[String, OptionDefinition] = {}

## Cached node paths resolved once in initialize() rather than on every apply call.
var _mesh_cache:		Dictionary[NodePath, MeshInstance3D] = {}
var _blend_idx_cache:	Dictionary[String, int] = {}
var _player_cache:		Dictionary[NodePath, AnimationPlayer] = {}
var _mat_cache:			Dictionary[String, Material] = {}
var _skeleton_cache: 	Dictionary[NodePath, Skeleton3D] = {}
var _modifier_cache:	Dictionary[NodePath, DeformModifier3D] = {}

## Keeps track of currently active accessories in a dictionary
var _active_accessories: Dictionary[String, MeshInstance3D] = {}
var _cur_mesh: MeshInstance3D

## Reference to the character's skeleton rig
var _character_skeleton = Skeleton3D.new()

## Called once by CharacterCreator._ready() before any player input arrives
func initialize(config: CharacterConfig, preview: CharacterPreview, ui: Control) -> void:
	_config         = config
	_ui             = ui
	_current_state  = CharacterState.from_config(config)
	_character_root = preview.get_character_root()
	
	# Set the reference to the character's skeleton
	for node in _character_root.find_children("*", "Skeleton3D", true):
		if node is Skeleton3D:
			_character_skeleton = node
	
	# Resolve the AnimationTree if one was built into the scene
	if get_parent().has_meta("animation_tree_path"):
		_anim_tree = get_parent().get_node(
			get_parent().get_meta("animation_tree_path")
		) as AnimationTree

	# Build option map and warm caches in a single pass
	for opt in config.options:
		print("mapping: '%s' -> %s" % [opt.resource_name, opt.get_class()])
		_option_map[opt.resource_name] = opt
		_warm_cache(opt)
		if not opt.include:
				_current_state.values[opt.resource_name] = -1

	# Apply defaults (every option starts at its config default value)
	_apply_full_state(_current_state)

## Caches data from option for all subtypes
func _warm_cache(opt: OptionDefinition) -> void:
	var paths_to_check : Array[NodePath] = []
	
	if opt.get("mesh_paths"): paths_to_check.append_array(opt.get("mesh_paths"))
	elif opt.get("mesh_path"): paths_to_check.append_array(opt.get("mesh_path"))
	
	for path in paths_to_check:
		if path != NodePath("") and not _mesh_cache.has(path):
			var node := _character_root.get_node_or_null(path)
			if node is MeshInstance3D:
				_mesh_cache[path] = node
				
	if opt is BlendshapeOption:
		for path in opt.mesh_paths:
			if path != NodePath("") and not _mesh_cache.has(path):
				var node := _character_root.get_node_or_null(path)
				if node is MeshInstance3D:
					_mesh_cache[path] = node

	if opt is ColorOption or opt is TextureAtlasOption:
		for path in opt.mesh_paths:
			var mesh := _mesh_cache.get(path) as MeshInstance3D
			if mesh:
				var key := "%s:%d" % [path, opt.surface_index]
				if not _mat_cache.has(key):
					_mat_cache[key] = mesh.get_active_material(opt.surface_index)

	if opt is MeshSwapOption:
		for choice: MeshSwapChoice in opt.choices:
			if not _mesh_cache.has(choice.mesh_path):
				var node := _character_root.get_node_or_null(choice.mesh_path)
				if node is MeshInstance3D:
					_mesh_cache[choice.mesh_path] = node
	
	if opt is AnimationOption:
		var path : NodePath = opt.animation_player_path
		if not _player_cache.has(path):
			var node := _character_root.get_node_or_null(path)
			if node is AnimationPlayer:
				_player_cache[path] = node
				
	if opt is DeformOption:
		var path := NodePath(opt.skeleton_path)
		if path != NodePath("") and not _skeleton_cache.has(path):
			var node := _character_root.get_node_or_null(path)
			if node is Skeleton3D:
				_skeleton_cache[path] = node
		if _skeleton_cache.has(path) and not _modifier_cache.has(path):
			var skeleton := _skeleton_cache[path]
			var modifier := skeleton.get_node_or_null("DeformModifier3D") as DeformModifier3D
			if modifier:
				_modifier_cache[path] = modifier
			else:
				push_warning("[CharacterExporter] No DeformModifier3D found under skeleton at %s" % path)

## Every slider move, button press, and color pick arrives here.
func apply_option(option_id: String, value: Variant) -> void:
	print("Manager received signal for: ", option_id, " -> ", value)
	
	var opt := _option_map.get(option_id)
	if opt == null:
		push_error("[CreatorManager] Option ID '%s' not found in option_map!" % option_id)
		return

	if opt.get_option_category() == "anim":
		for other_id in _option_map:
			var other := _option_map[other_id]
			if other.get_option_category() == "anim" and other.group == opt.group and other_id != option_id:
				_current_state.record(other_id, null)
				
	opt.apply_to_preview(self, value)
	
	# State stays in sync with what the player intended rather than what the mesh actually reflects.
	_current_state.record(option_id, value)

## Dynamically loads and unloads meshes when selected by player
func _apply_swap(opt: MeshSwapOption, choice_index: int, force_full_pass: bool = false) -> void:
	var prev_index
	
	if force_full_pass:
		# On initialize
		prev_index = -1
	else:
		prev_index = _current_state.values.get(opt.resource_name, -1)

	# Early exit if the choice hasn't changed (or initializing none)
	if prev_index == choice_index:
		return
		
	# Otherwise, load in mesh
	var is_none := opt.choices[choice_index].file_path.is_empty()
	var cur_group := ""
	
	if is_none:
		_cur_mesh = null
		cur_group = opt.group.capitalize()
	else:
		var scene = load(opt.choices[choice_index].file_path)
		_cur_mesh = scene.instantiate()
		var cur_parts := _splitter.sub(_cur_mesh.name, "|", true).split("|", false)
		cur_group = cur_parts[0].capitalize()
	
	# Unload the previous mesh
	if _active_accessories.has(cur_group):
		if _active_accessories[cur_group] != null:
			_active_accessories[cur_group].free()

	# Add new mesh to skeleton and to dictionary
	if not is_none and _cur_mesh != null and choice_index >= 0 and choice_index < opt.choices.size():
		_cur_mesh.set_skeleton_path(_character_skeleton.get_path()) 
		_character_skeleton.add_child(_cur_mesh)
		_cur_mesh.owner = _character_root
		
		_active_accessories[cur_group] = _cur_mesh
		
		# Add node path to to apply blendshape values
		opt.choices[choice_index].mesh_path = _character_root.get_path_to(_cur_mesh)
		var key = opt.choices[choice_index].mesh_path
		_mesh_cache[key] = _cur_mesh
		
		var option_lists: Array[VBoxContainer] = []
		for ol in _ui.find_children("OptionList", "VBoxContainer", true, false):
			option_lists.append(ol)
		
		apply_current_option_values(option_lists, cur_group, key)
							
## Applies all current option values (blendshapes, atlas, colors) to the current newly loaded mesh
func apply_current_option_values(option_lists: Array[VBoxContainer], cur_group: String, key: NodePath) -> void:
	if option_lists.is_empty(): 
		return
		
	for o in option_lists:
		for child in o.get_children():
			var opt_parts = _splitter.sub(child.option_id, "|", true).split("|", false)
			
			# Apply current blendshape values to the newly loaded mesh
			if opt_parts[0] == "blendshape":
				apply_current_blendshape_value(child.option_id)
			elif opt_parts[0] == "color" or opt_parts[0] == "atlas":
				var color_option = _option_map[child.option_id]
					
				# Get group name to compare option group with cur group
				var opt_group: String = _create_opt_group_name(cur_group, opt_parts)
					
				if opt_group.to_lower() == cur_group.to_lower():
					var mat_key = "%s:%d" % [key, color_option.surface_index]
						
					if not _mat_cache.has(mat_key):
						_mat_cache[mat_key] = _cur_mesh.get_active_material(color_option.surface_index)
					apply_current_color_value(child.option_id)

## Helper method to concatenate option group name parts together
func _create_opt_group_name(cur_group: String, opt_parts: Array[String]) -> String:
	var cur_group_len = cur_group.split(" ").size()
	var res: String
	
	for i in range(cur_group_len):
		if i == cur_group_len - 1:
			res += opt_parts[i+1]
		else:
			res += opt_parts[i+1] + " "
	
	return res
	
func apply_current_blendshape_value(blendshape_name: String) -> void:
	var option = _option_map[blendshape_name]
	_apply_blendshape(option, _current_state.values.get(blendshape_name, 0.0))

## Loops through meshes attached to this option and applies blend shapes
func _apply_blendshape(opt: BlendshapeOption, value: float) -> void:
	for path in opt.mesh_paths:
		if(_mesh_cache.get(path) != null):
			var mesh := _mesh_cache.get(path) as MeshInstance3D
			if mesh == null:
				return
				
			# Index lookup is cached separately to avoid find_blend_shape_by_name() on every slider frame.
			var cache_key := "%s::%s" % [path, opt.blend_shape_name]
			var idx: int = _blend_idx_cache.get(cache_key, -2)

			if idx == -2:   # -2 = not yet looked up; -1 = missing/null
				idx = mesh.find_blend_shape_by_name(opt.blend_shape_name)
				_blend_idx_cache[cache_key] = idx
			
			if idx >= 0:
				mesh.set_blend_shape_value(idx, value)

## Applies current color values to newly loaded mesh
func apply_current_color_value(color_name: String) -> void:
	var option = _option_map[color_name]
	_apply_color(option, _current_state.values.get(color_name, Color.WHITE))
	
## Applied color to mesh material
func _apply_color(opt: ColorOption, color: Color) -> void:
	for path in opt.mesh_paths:
		var key := "%s:%d" % [path, opt.surface_index]
		var mat := _mat_cache.get(key) as Material
	
		if mat == null:
			continue

		if opt.surface_index == -1:
			# Apply to every surface on this mesh
			var mesh := _mesh_cache.get(path) as MeshInstance3D
			if mesh == null:
				continue
			for i in range(mesh.get_surface_override_material_count()):
				_write_color(mesh.get_active_material(i), opt.shader_param, color)
			continue
		
		# Duplicates on first write and then updates _mat_cache[key] to point at the duplicate.
		if not opt.apply_to_shared_material:
			mat = mat.duplicate()
			var mesh := _mesh_cache.get(path) as MeshInstance3D
			if mesh:
				mesh.set_surface_override_material(opt.surface_index, mat)
			_mat_cache[key] = mat

		_write_color(mat, opt.shader_param, color)

func _write_color(mat: Material, param: String, color: Color) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter(param, color)
	elif mat is StandardMaterial3D:
		match param:
			"albedo_color": mat.albedo_color = color
			"emission":     mat.emission     = color
			_: push_warning("[CharacterExporter] Unknown param '%s'" % param)

func _apply_animation(opt: AnimationOption) -> void:
	# With an AnimationTree present, drive the PoseTransition node.
	# Fall back to AnimationPlayer directly if no tree was built.
	if _anim_tree and opt.tree_node_name != "":
		_anim_tree.set(
			"parameters/PoseTransition/transition_request",
			opt.tree_node_name
		)
		return
	var player := _player_cache.get(opt.animation_player_path) as AnimationPlayer
	if player == null:
		return
	if not player.has_animation(opt.animation_name):
		return
	var anim := player.get_animation(opt.animation_name)
	if opt.loop_in_preview:
		player.play(opt.animation_name)
	else:
		# Seek to the last frame and stop. 
		# Holds the final pose without keeping the AnimationPlayer ticking every frame.
		player.play(opt.animation_name)
		player.seek(anim.length, true)
		player.pause()

## Applies bone deformation to mesh
func _apply_deform(opt: DeformOption, value: float) -> void:
	var path := NodePath(opt.skeleton_path)
	var modifier := _modifier_cache.get(path) as DeformModifier3D
	if modifier == null:
		push_warning("[CharacterExporter] No cached DeformModifier3D for option '%s'" % opt.resource_name)
		return
	modifier.set_deform_value(opt, value)

## Applies texture atlas to material shader
func _apply_texture_atlas(opt: TextureAtlasOption, choice_index: int) -> void:
	print("atlas '%s' required=%s choice_index=%d" % [opt.resource_name, opt.required, choice_index])
	if choice_index == -1 or (not opt.required and choice_index == 0):
		for path in opt.mesh_paths:
			var mesh := _mesh_cache.get(path) as MeshInstance3D
			if mesh:
				mesh.visible = false
		return

	var atlas_index := choice_index - (0 if opt.required else 1)
	var uv_width := 1.0 / float(opt.columns)
	var uv_height := 1.0 / float(opt.rows)
	var col : int = atlas_index % opt.columns
	var row : int = atlas_index / opt.columns
	var offset := Vector3(col * uv_width, row * uv_height, 0.0)

	for path in opt.mesh_paths:
		var mesh := _mesh_cache.get(path) as MeshInstance3D
		if mesh:
			mesh.visible = true
			
		var key := "%s:%d" % [path, opt.surface_index]
		var mat := _mat_cache.get(key) as Material
		if mat == null: continue
	
		if not opt.apply_to_shared_material:
			mat = mat.duplicate()
			if mesh:
				mesh.set_surface_override_material(opt.surface_index, mat)
			_mat_cache[key] = mat
		
		if mat is StandardMaterial3D:
			mat.uv1_offset = offset
		elif mat is ShaderMaterial:
			mat.set_shader_parameter(opt.shader_param, Vector2(offset.x, offset.y))

## Bulk Application
## When a CharacterState is loaded from disk and needs to be applied all at once. 
func _apply_full_state(state: CharacterState) -> void:
	for option_id in state.values:
		print(option_id)
		var opt := _option_map.get(option_id)
		if opt == null:
			continue
		opt.apply_to_preview(self, state.values[option_id], true)

## Public entry point
func load_state(state: CharacterState) -> void:
	_current_state = state
	_apply_full_state(state)
	# Sync UI controls to reflect the loaded values without triggering option_changed signals.
	(_ui as CreatorUI).apply_state(state)

## Compatibility load 
func load_state_partial(state: CharacterState) -> void:
	# Build a new state from current defaults,
	# then overlay whatever keys the old state has that still match.
	var merged := CharacterState.from_config(_config)

	for id in state.values:
		if _option_map.has(id):
			merged.values[id] = state.values[id]
	load_state(merged)

## CharacterCreator._on_confirm() calls this to get the state for its signal and optional disk write.
func get_current_state() -> CharacterState:
	_current_state.last_modified = Time.get_unix_time_from_system()
	
	# Loop through the final active accessories and get the path from the filesystem to that model for faster loading
	for items in _active_accessories.values():
		if items != null:
			_current_state.active_meshes.append(String(_config.output_path+"/meshes/"+items.name+".tscn"))
	
	return _current_state
