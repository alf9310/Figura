@tool
extends Control
class_name ConfiguraDock

signal scene_generated(path: String)

const GROUP_CONTAINER_SCENE = preload("res://addons/Configura/editor/docks/group_container.tscn")
const OPTION_ROW_SCENE = preload("res://addons/Configura/editor/docks/option_row.tscn")

static var _splitter := RegEx.create_from_string("[_.,\\-]+")

## Inspector nodes (set in .tscn)
@onready var _status_label:		Label			= %StatusLabel

@onready var _character_resource_picker: Container = %CharacterResourcePicker
@onready var _character_scene_container: HBoxContainer = %CharacterSceneContainer
@onready var _palette_resource_picker: Container = %PaletteResourcePicker

@onready var _theme_resource_picker: 	 Container = %ThemeResourcePicker
@onready var _skybox_resource_picker:	 Container = %SkyboxResourcePicker

@onready var _categories_list: VBoxContainer   = %CategoriesList

@onready var _allow_random:		CheckBox		= %AllowRandomize
@onready var _save_state:		CheckBox		= %SaveState

@onready var _output_path:		LineEdit		= %OutputPath
@onready var _output_dialog:	FileDialog		= %OutputDialog
@onready var _generate_btn:		Button			= %GenerateButton

@onready var _bone_deforms_container:	FoldableContainer = %BoneDeformsContainer
@onready var _deform_list: 				VBoxContainer 	= %DeformList

@onready var _options_context: 	Label		 	= %OptionsContext

var _current_character_scene: PackedScene
var _detected_options: Array[OptionDefinition] = []

## Stores the theme before the [CharacterConfig] is created
var _current_theme_resource: Theme
var _current_skybox_shader: ShaderMaterial
var _current_color_palette: ColorSwatchPalette

## Flat reference list for O(N) harvesting during generation
var _active_ui_controls: Array[Control] = []

## Path for base model file
var _base_model_file_path
var _skeleton_path:	String = ""

var _deform_options: Array[DeformOption] = []

var _mesh_pos_dict := {}
var _mesh_size_dict := {}

## Connect resource signals on ready
func _ready() -> void:
	_bone_deforms_container.visible = false
	_character_resource_picker.picker.resource_changed.connect(_on_input_resource_selected)
	_theme_resource_picker.picker.resource_changed.connect(_on_theme_resource_selected)
	_skybox_resource_picker.picker.resource_changed.connect(_on_skybox_resource_selected)
	_palette_resource_picker.picker.resource_changed.connect(_on_palette_resource_selected)

func _on_input_resource_selected(resource: PackedScene) -> void:
	_current_character_scene = resource
	
func _on_theme_resource_selected(resource: Theme) -> void:
	_current_theme_resource = resource
  
func _on_skybox_resource_selected(resource: ShaderMaterial) -> void:
	_current_skybox_shader = resource
	
func _on_palette_resource_selected(resource: ColorSwatchPalette) -> void:
	_current_color_palette = resource
	if resource == null:
		return
	var is_real_file := resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::")
	if is_real_file:
		return
	_create_new_folder("resources")
	var save_path := _output_path.text + "/resources/color_palette.tres"
	var err := ResourceSaver.save(resource, save_path)
	if err == OK:
		_current_color_palette = ResourceLoader.load(save_path) as ColorSwatchPalette
		_palette_resource_picker.picker.edited_resource = _current_color_palette
	else:
		push_warning("[ConfiguraDock] Failed to save color palette: %d" % err)
			
## Saving and loading dock info
func get_persistent_state() -> Dictionary:
	var state := {
		"output_path":  _output_path.text,
		"allow_random": _allow_random.button_pressed,
		"save_state":   _save_state.button_pressed,
	}
	if _current_character_scene:
		state["character_scene_path"] = _current_character_scene.resource_path
	if _current_theme_resource:
		state["theme_path"] = _current_theme_resource.resource_path
	if _current_skybox_shader:
		state["skybox_path"] = _current_skybox_shader.resource_path
	if _current_color_palette:
		state["palette_path"] = _current_color_palette.resource_path

	state["headers"] = []
	for header in _categories_list.get_children():
		if not header is FoldableContainer:
			continue
		var header_state := {
			"title": header.title,
			"folded": header.folded,
			"groups": [],
		}
		for group_ui in _find_group_containers(header):
			header_state["groups"].append(group_ui.get_group_state())
		state["headers"].append(header_state)

	state["deform_count"] = _deform_options.size()

	return state

## Loading of saved information
func apply_persistent_state(state: Dictionary) -> void:
	# Apply scene paths + settings
	if state.has("output_path"):
		_output_path.text = state["output_path"]
	if state.has("allow_random"):
		_allow_random.button_pressed = state["allow_random"]
	if state.has("save_state"):
		_save_state.button_pressed = state["save_state"]
	if state.has("theme_path") and ResourceLoader.exists(state["theme_path"]):
		_current_theme_resource = load(state["theme_path"])
		_theme_resource_picker.picker.edited_resource = _current_theme_resource
	if state.has("skybox_path") and ResourceLoader.exists(state["skybox_path"]):
		_current_skybox_shader = load(state["skybox_path"])
		_skybox_resource_picker.picker.edited_resource = _current_skybox_shader
	if state.has("palette_path") and ResourceLoader.exists(state["palette_path"]):
		_current_color_palette = load(state["palette_path"])
		_palette_resource_picker.picker.edited_resource = _current_color_palette
	if state.has("character_scene_path") and ResourceLoader.exists(state["character_scene_path"]):
		_current_character_scene = load(state["character_scene_path"])
		_character_resource_picker.picker.edited_resource = _current_character_scene

		# Rerun options list building with saved information
		_base_model_file_path = _output_path.text + "/baseModel.tscn"
		if ResourceLoader.exists(_base_model_file_path):
			var inspector := MeshInspector.new()
			var base_model_resource = load(_base_model_file_path)
			_detected_options = inspector.inspect(base_model_resource, _current_character_scene, _output_path.text)
			_options_context.hide()
			_status_label.visible = true
			_rebuild_options_list()
			_bone_deforms_container.visible = true
			_apply_header_states(state.get("headers", []))
	
	# Apply existing bone deforms
	if state.has("deform_count"):
		for i in int(state["deform_count"]):
			var path := _output_path.text + "/resources/deform_%d.tres" % i
			if ResourceLoader.exists(path):
				var opt := load(path) as DeformOption
				_deform_options.append(opt)
				_build_deform_row(opt, i)

## Apply header options
func _apply_header_states(headers: Array) -> void:
	var header_nodes := _categories_list.get_children().filter(
		func(c): return c is FoldableContainer
	)
	for saved_header in headers:
		for header_node in header_nodes:
			if header_node.title == saved_header.get("title", ""):
				if saved_header.has("folded"):
					header_node.folded = saved_header["folded"]
				var group_nodes := _find_group_containers(header_node)
				var saved_groups: Array = saved_header.get("groups", [])
				for i in min(saved_groups.size(), group_nodes.size()):
					group_nodes[i].apply_group_state(saved_groups[i])
				break

## Helper for applying the states in each group
func _find_group_containers(root: Node) -> Array[GroupContainer]:
	var result: Array[GroupContainer] = []
	for child in root.get_children():
		if child is GroupContainer:
			result.append(child)
		result.append_array(_find_group_containers(child))
	return result
	
		
## Phase 1: Mesh Loading
## When the developer picks a file, run MeshInspector and populates the options list:
func _on_confirm_button_pressed() -> void:
	if _output_path.text.is_empty() or not _current_character_scene:
		print_rich("[color=red][b][u]CharacterCreatorDock:[/u][/b] Output path and character scene required[/color]")
		_status_label.visible = true
		_status_label.text = "Output path and character scene required"
		_status_label.add_theme_color_override(
			"font_color",
			Color.RED
		)
		return
	_bone_deforms_container.visible = true

	var base_model_scene = _build_base_scene(_current_character_scene)
	_base_model_file_path = _output_path.text + "/baseModel.tscn"
	
	# Create a meshes folder if it does not already exist
	_create_new_folder("meshes")
	
	var base_save_err = _save_node(base_model_scene, _base_model_file_path)
	
	if base_save_err != OK:
		print("Save failed - Error: %d" % base_save_err)
		return
		
	print("Save success! Base model scene created")
		
	# Extract swappable meshes and update base model scene
	_mesh_pos_dict.clear()
	_mesh_size_dict.clear()
	var updated_base_model_scene = _extract_meshes(_current_character_scene)

	# Adding DeformModifier3D to Base Model scene before saving
	var deform_modifier := DeformModifier3D.new()
	deform_modifier.name = "DeformModifier3D"
	updated_base_model_scene.get_node(_skeleton_path).add_child(deform_modifier)
	deform_modifier.owner = updated_base_model_scene
	
	var update_save_err = _save_node(updated_base_model_scene, _base_model_file_path)
		
	if update_save_err != OK:
		print("Save failed - Error: %d" % update_save_err)
		return
		
	print("Save success! Base model scene updated")
	EditorInterface.get_resource_filesystem().scan()
	
	var inspector := MeshInspector.new()
	var base_model_resource = load(_base_model_file_path)
	_detected_options = inspector.inspect(base_model_resource, _current_character_scene, _output_path.text)
	_status_label.visible = true
	
	if _detected_options.size() > 0:
		print_rich("[color=green][b][u]CharacterCreatorDock:[/u][/b] %d options detected[/color]" % _detected_options.size())
		_status_label.text = "%d options detected" % _detected_options.size()
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		print_rich("[color=yellow][b][u]CharacterCreatorDock:[/u][/b] No options detected[/color]")
		_status_label.text = "No options detected"
		_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	_options_context.hide()
	_rebuild_options_list()

## Helper method that checks if a meshes folder exists in the user provided output_path
## Creates one if it doesn't
func _create_new_folder(folder_name: String):
	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("[ConfiguraDock] Could not open res:// to create folder '%s'" % folder_name)
		return
	var path := _output_path.text + "/" + folder_name
	if not dir.dir_exists_absolute(path):
		var err := dir.make_dir_absolute(path + "/")
		if err != OK:
			push_error("[ConfiguraDock] Failed to create folder '%s': %d" % [path, err])

## Phase 2: Options List
## Each detected OptionDefinition gets its own OptionRow scene 
func _rebuild_options_list() -> void:
	# 1. Clean up old UI
	for child in _categories_list.get_children():
		child.queue_free()
	_active_ui_controls.clear()
	
	# 2. Group all detected options by their 'group' string
	var grouped: Dictionary = {}
	for opt in _detected_options:
		var groups_to_add_to: Array[String] = []
		
		if opt is MeshSwapOption or opt is TextureAtlasOption and opt.get_editor_groups() != null and opt.get_editor_groups().size() > 0:
			groups_to_add_to.append_array(opt.get_editor_groups())
		else:
			groups_to_add_to.append(opt.group if not opt.group.is_empty() else "General")	
			
		for g in groups_to_add_to:
			if not grouped.has(g):
				grouped[g] = []
			grouped[g].append(opt)
	
	# 3. Build the UI hierarchy dynamically
	for group_name in grouped:
		# If grouped option has no TextureAtlas and Blendshape options AND no Mesh Swap choices, SKIP creating a group tab option
		if grouped[group_name].size() == 1 and grouped[group_name][0] is MeshSwapOption and grouped[group_name][0].choices.is_empty():
			continue
			
		var header := FoldableContainer.new()
		header.title = group_name
		header.folded = true
		_categories_list.add_child(header)

		var margin := MarginContainer.new()
		var content_vbox := VBoxContainer.new()

		header.add_child(margin)
		margin.add_child(content_vbox)
		
		var group_has_atlas : bool = grouped[group_name].any(func(o: OptionDefinition) -> bool: return o.get_option_category() == "atlas")
		var group_ui: GroupContainer = null

		# Populate the category with its options
		for opt in grouped[group_name]:
			group_ui = opt.create_editor_rows(
				content_vbox, group_ui, group_name,
				group_has_atlas, _active_ui_controls,
				GROUP_CONTAINER_SCENE, OPTION_ROW_SCENE
			)
				
## Builds base scene with animation player, skeleton rig and base model meshes.
## Swappable meshes are saved by _extract_meshes()
func _build_base_scene(character_tscn: PackedScene) -> Node3D:
	var root = character_tscn.instantiate()
	print("Building the base model scene")
	
	var base_scene_root = Node3D.new()
	base_scene_root.name = "BaseModel"
	
	# Metarig and Skeleton3D
	_find_skeleton_node(root, base_scene_root)
	
	# Animation Player
	for node in root.find_children("*", "AnimationPlayer", true, false):
		if node is AnimationPlayer:
			var anim_player = node.duplicate()
			base_scene_root.add_child(anim_player)
			anim_player.owner = base_scene_root
			break
			
	return base_scene_root
	
## Helper method that recursively searches the character scene for the Skeleton3D node
## Duplicates it for the base model scene and finds it's "metarig" parent node
func _find_skeleton_node(root: Node3D, base_scene_root: Node3D):
	if root == null:
		return
	
	for node in root.find_children("*", "Skeleton3D", true, false):
		var skeleton_node = node.duplicate()
		var temp_parent = node.get_parent()
		if temp_parent != null:
			var metarig_node = temp_parent.duplicate()
			base_scene_root.add_child(metarig_node)
			metarig_node.owner = base_scene_root
			
			metarig_node.add_child(skeleton_node)
			skeleton_node.owner = base_scene_root
			# Temporarily rename it to "Skeleton" to avoid naming collision
			# when extracting from character scene
			skeleton_node.name = "Skeleton"
	
## Adds base model meshes to the base model scene
## Saves swappable meshes into their own respective scenes
func _extract_meshes(character_tscn: PackedScene) -> Node3D:
	print("Extracting meshes")
	var root = character_tscn.instantiate()
	
	var base_model_scene = load(_base_model_file_path)
	var base_model = base_model_scene.instantiate()
	
	var skeleton_node
	for node in base_model.find_children("*", "Skeleton3D", true):
		if node is Skeleton3D:
			skeleton_node = node
	# Rename it back to "Skeleton3D" here because the node is not linked to the character scene anymore
	skeleton_node.name = "Skeleton3D"
	
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D and node.mesh != null):
			continue
		
		var is_base_mesh = false
		var node_name_parts = _splitter.sub(node.name, "|", true).split("|", false)
		
		for part in node_name_parts:
			if part.to_lower() == "base":
				is_base_mesh = true
				break
					
		# Filter the mesh search and add those MeshInstance3D into the baseSceneRoot
		if is_base_mesh:
			var mesh_node = node.duplicate()
			if skeleton_node.find_child(mesh_node.name) == null:
				skeleton_node.add_child(mesh_node)
				mesh_node.owner = base_model
				
			if node_name_parts.size() > 1:
				if !_mesh_pos_dict.has(node_name_parts[1]):
					_mesh_pos_dict[node_name_parts[1]] = []
					_mesh_pos_dict[node_name_parts[1]].append(node.get_aabb().get_center())
				
				if !_mesh_size_dict.has(node_name_parts[1]):
					_mesh_size_dict[node_name_parts[1]] = []
					var min_bounds = node.get_aabb().position
					var max_bounds = node.get_aabb().end
					
					var object_size = max_bounds - min_bounds
					_mesh_size_dict[node_name_parts[1]].append(object_size)
		else:
			# Extract meshes (base model, accessories, clothing) into their own scenes
			var save_path = _output_path.text + "/meshes/" + node.name + ".tscn"
			var mesh_node = node.duplicate()
			var mesh_save_err = _save_mesh(mesh_node, save_path)
				
			if mesh_save_err == OK:
				print("Save success! %s scene saved" % mesh_node.name)
				
				if !_mesh_pos_dict.has(node_name_parts[0]):
					_mesh_pos_dict[node_name_parts[0]] = []
				_mesh_pos_dict[node_name_parts[0]].append(node.get_aabb().get_center())
				
				if !_mesh_size_dict.has(node_name_parts[0]):
					_mesh_size_dict[node_name_parts[0]] = []
				var min_bounds = node.get_aabb().position
				var max_bounds = node.get_aabb().end
						
				var object_size = max_bounds - min_bounds
				_mesh_size_dict[node_name_parts[0]].append(object_size)
			else:
				print("Save failed - Error: %d" % mesh_save_err)
	
	_skeleton_path = base_model.get_path_to(skeleton_node)
	
	return base_model
			
## Creates and saves a Node scene to the out_path
func _save_node(root: Node, out_path: String) -> Error:
	var packed_scene := PackedScene.new()
	var packed_err := packed_scene.pack(root)
	if packed_err != OK:
		push_error("Failed to pack scene: %d" % packed_err)
		return packed_err
		
	var scene_err := ResourceSaver.save(packed_scene, out_path)
	if scene_err != OK:
		push_error("Failed to save scene to %s: %d" % [out_path, scene_err])
		return scene_err
			
	return OK
	
## Creates and saves a MeshInstance3D scene to the out_path
func _save_mesh(root: MeshInstance3D, out_path: String) -> Error:
	var packed_scene := PackedScene.new()
	var packed_err := packed_scene.pack(root)
	if packed_err != OK:
		push_error("Failed to pack scene: %d" % packed_err)
		return packed_err
		
	var scene_err := ResourceSaver.save(packed_scene, out_path)
	if scene_err != OK:
		push_error("Failed to save scene %s: %d" % [out_path, scene_err])
		return scene_err
		
	return OK
	
## Bone Deformation Functions
func _on_add_deform_button_pressed() -> void:
	var idx := _deform_options.size()
	var opt := DeformOption.new()
	opt.skeleton_path = _skeleton_path
	opt.display_name = "New Bone Deform"
	opt.group = "Body"
	opt.resource_name = "deform_%d" % idx
	
	_create_new_folder("resources")
	var save_path := _output_path.text + "/resources/" + opt.resource_name + ".tres"
	ResourceSaver.save(opt, save_path)
	opt = ResourceLoader.load(save_path) as DeformOption
	
	_deform_options.append(opt)
	_build_deform_row(opt, idx)

func _build_deform_row(opt: DeformOption, index: int) -> void:
	var row := HBoxContainer.new()
	_deform_list.add_child(row)

	var picker := EditorResourcePicker.new()
	picker.base_type = "DeformOption"
	picker.edited_resource = opt
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.resource_changed.connect(func(new_res: Resource):
		_deform_options[index] = new_res as DeformOption
	)
	row.add_child(picker)
	
	var inspect_btn := Button.new()
	inspect_btn.text = "Edit"
	inspect_btn.pressed.connect(func():
		EditorInterface.inspect_object(_deform_options[index])
	)
	row.add_child(inspect_btn)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		_deform_options.erase(_deform_options[index])
		row.queue_free()
	)
	row.add_child(remove_btn)
		
## Phase 3: Character Config
func _on_output_button_pressed() -> void:
	_output_dialog.popup_centered_ratio(0.6)

func _on_output_dialog_dir_selected(dir) -> void:
	_output_path.text = dir

func _on_clear_output_button_pressed() -> void:
	_output_path.text = ""
	
## Click "Generate Scene": The dock gathers the state of all rows into a CharacterConfig resource, 
## then hands it to SceneGenerator
func _on_generate_button_pressed() -> void:
	if not _current_character_scene:
		push_error("No character scene selected.")
		return

	var config := CharacterConfig.new()
	config.character_scene  		= load(_base_model_file_path)
	config.allow_randomize  		= _allow_random.button_pressed
	config.save_state_on_confirm	= _save_state.button_pressed
	config.theme_resource 			= _current_theme_resource
	config.skybox_resource			= _current_skybox_shader
	config.color_swatch_palette		= _current_color_palette
	config.output_path				= _output_path.text
	config.skeleton_path			= _skeleton_path
	config.mesh_pos_dict 			= _mesh_pos_dict
	config.mesh_size_dict			= _mesh_size_dict
	
	# Tracker to ensure we don't add the same shared blendshape twice
	var processed_options: Dictionary = {}
		
	# Harvest options
	for control in _active_ui_controls:
		if control is GroupContainer:
			var opt: OptionDefinition = control.get_config_option()
			if opt != null:
				config.options.append(opt)
			else:
				var excluded : OptionDefinition = control.get_excluded_option()
				if excluded != null:
					config.options.append(excluded)

		elif control is OptionRow:
			var include_checkbox := control.get_node_or_null("%IncludeOption") as CheckBox
			if include_checkbox and include_checkbox.button_pressed:
				var parent_group := control.get_parent()
				while parent_group != null and not parent_group is GroupContainer:
					parent_group = parent_group.get_parent()
				if parent_group is GroupContainer and not parent_group._include_group.button_pressed:
					continue

				var opt: OptionDefinition = control.get_meta("source_option")
				
				# Skip if we already harvested this exact resource from a different tab
				if processed_options.has(opt):
					continue
				processed_options[opt] = true
				
				# Assign the runtime group based on the UI category it was checked in
				opt.group = control.get_meta("category")

				var name_edit := control.get_node_or_null("%DisplayName") as LineEdit
				if name_edit:
					opt.display_name = name_edit.text

				config.options.append(opt)
				
	# Save and reload DeformOptions to ensure all edits are saved
	for i in _deform_options.size():
		var opt_res := _deform_options[i]
		var opt_path :=  _output_path.text + "/resources/" + opt_res.resource_name + ".tres"
		ResourceSaver.save(opt_res, opt_path)
		var opt := ResourceLoader.load(opt_path, "", ResourceLoader.CACHE_MODE_IGNORE) as DeformOption
		if !opt:
			push_error("Failed to load %s" % opt_path)
			continue
		config.options.append(opt)

	if config.options.is_empty():
		push_error("No options selected.")
		return
	
	# Assigns resource_name to any unnamed options before passing the config to SceneGenerator
	for opt in config.options:
		if opt.resource_name.is_empty():
			opt.resource_name = _slugify(opt)
	
	print("Generating a new Character Creator Scene to ", _output_path.text)
	print("With CharacterConfig ", config)

	var generator := SceneGenerator.new()
	var err := generator.generate(config, _output_path.text + "/character_creator.tscn")
	
	if err == OK:
		print_rich("[color=green][b][u]CharacterCreatorDock:[/u][/b] Scene saved to %s[/color]" % _output_path.text)
		_status_label.text = "Scene saved to %s" % _output_path.text
		scene_generated.emit(_output_path.text)
	else:
		print_rich("[color=red][b][u]CharacterCreatorDock:[/u][/b] Generation failed (error %d)" % err)
		_status_label.text = "Generation failed (error %d)" % err

## Generates unique resource_name for OptionDefinition
func _slugify(opt: OptionDefinition) -> String:
	# 1. Clean the strings for safe dictionary keys
	var group_str := opt.group.to_lower().replace(" ", "_").replace(".", "").replace("-", "_")
	var name_str  := opt.display_name.to_lower().replace(" ", "_").replace(".", "").replace("-", "_")

	# 2. Generate truly unique IDs based on the specific subclass
	if group_str.is_empty(): 
		return opt.get_option_category() + "_%s" % name_str
	return opt.get_option_category() + "_%s_%s" % [group_str, name_str]
