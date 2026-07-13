## A bridge between the editor and runtime.
## Takes a finalized CharacterConfig and writes a fully-wired .tscn file to disk 
## that the developer can drop into their project.

@tool
class_name SceneGenerator
extends RefCounted

var _config: CharacterConfig

## Root node is constructed entirely in memory until _save() packs and writes it
func generate(config: CharacterConfig, output_scene: String) -> Error:
	_config = config

	if not _validate():
		return ERR_INVALID_PARAMETER

	var root := _build_base_tree()
	_generate_ui(root)
	_generate_load(root)
	var err := _save(root, output_scene)
	root.free()
	return err

## Creates the four runtime nodes and configures each from config
func _build_base_tree() -> Node:
	print("Building the base CharacterCreator Scene tree")
	var root := Control.new()
	root.name = "CharacterCreator"
	root.set_script(
		load("res://addons/Configura/runtime/creator_controller.gd")
	)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_meta("character_config", _config)
	
	# Store config as a typed property
	root.config = _config

	var hbox := HBoxContainer.new()
	hbox.name = "Layout"
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)
	hbox.owner = root

	# CreatorUI (VBoxContainer — populated in stage 2)
	print("\tAdding the CreatorUI")
	var ui := VBoxContainer.new()
	ui.name = "CreatorUI"
	ui.set_script(
		load("res://addons/Configura/runtime/creator_ui.gd")
	)
	
	## Anchor the UI
	ui.anchor_left   = 0.0
	ui.anchor_top    = 0.0
	ui.anchor_right  = _config.ui_panel_width
	ui.anchor_bottom = 1.0
	ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.size_flags_stretch_ratio = 1.0
	
	hbox.add_child(ui)
	ui.owner = root
	root.ui   = ui
	
	print("\tAdding the LoaderUI")
	var loader := VBoxContainer.new()
	loader.name = "LoaderUI"
	loader.set_script(
		load("res://addons/Configura/runtime/character_loader.gd")
	)
	# Give Inital conditions and set visibility to false, while not in use
	loader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loader.size_flags_stretch_ratio = 1.0
	loader.visible = false
	hbox.add_child(loader)
	loader.owner = root
	root.loader = loader
	

	# CharacterPreview (SubViewportContainer + internals)
	print("\tAdding the CharacterPreview")
	var preview := preload(
		   "res://addons/Configura/runtime/character_preview.tscn"
	).instantiate()
	preview.name = "CharacterPreview"
	var viewport := preview.get_node_or_null("SubViewport")

	if viewport == null:
		push_error("[SceneGenerator] CharacterPreview.tscn has no SubViewport node — check the scene.")
		return root

	if _config.character_scene == null:
		push_error("[SceneGenerator] _config.character_scene is null — was the config saved correctly?")
		return root
		
	# Inject the character mesh as a child of the SubViewport
	print("\tCharacter scene path: ", _config.character_scene.resource_path)
	var character := _config.character_scene.instantiate()
	if character == null:
		push_error("[SceneGenerator] Failed to instantiate character scene.")
		return root
	
	character.name = "Character"
		
	print("\tCharacter instantiated: ", character.name)
	viewport.add_child(character)
	hbox.add_child(preview)
		
	# Unwrap the CharacterPreview so Godot is allowed to save the character inside its SubViewport
	_unwrap_and_bind(preview, root, character)
		
	# Bind the character instance to the root (but don't unwrap its internals!)
	character.owner = root
		
	# Build AnimationTree and add it as a sibling of the character
	# inside the SubViewport so it shares the same scene world.
	var tree_builder := AnimationTreeBuilder.new()
	var tree_result := tree_builder.build(character, _config, root)

	if not tree_result.is_empty():
		var anim_tree: AnimationTree    = tree_result["tree"]
		var player:    AnimationPlayer  = tree_result["player"]
		
		viewport.add_child(anim_tree)
		anim_tree.anim_player = anim_tree.get_path_to(player)
		anim_tree.active      = true
		anim_tree.owner       = root
		
		# Store the path so CreatorManager can find the tree
		# without a find_children() search on every initialize() call.
		root.set_meta(
			"animation_tree_path",
			root.get_path_to(anim_tree)
		)
		
	print("\tAnimation tree owners set")

	preview.owner = root
		
	# Set owners
	preview.owner = root
	_set_owners(character, root)
		
	root.preview = preview
	print("\tOwners set on character subtree")

	# CreatorManager
	print("\tAdding the CreatorManager")
	var manager := Node.new()
	manager.name = "CreatorManager"
	manager.set_script(
		load("res://addons/Configura/runtime/creator_manager.gd")
	)
	root.add_child(manager)
	manager.owner = root
	root.manager   = manager

	return root

## Delegates to UIGenerator to build the tab/group structure and individual control nodes.
func _generate_ui(root: Node) -> void:
	print("Generating the CharacterCreator UI")
	var ui := root.get_node("Layout/CreatorUI")
	var ui_gen := UIGenerator.new()
	ui_gen.build(ui, _config.options, root,_config.theme_resource,_config.allow_randomize)

func _generate_load(root: Node) -> void:
	print("Generating the CharacterLoader UI")
	var loader : CharacterLoader = root.get_node("Layout/LoaderUI")
	var ui_gen := LoadGenerator.new()
	ui_gen.build(loader, root, _config.theme_resource)
	loader.config = _config

## Serialization
func _save(root: Node, output_scene: String) -> Error:
	print("Serializing CharacterCreator as a PackedScene")
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("[SceneGenerator] Failed to pack scene: %d" % pack_err)
		return pack_err

	var scene_err := ResourceSaver.save(packed, output_scene)
	if scene_err != OK:
		push_error("[SceneGenerator] Failed to save scene to %s: %d" % [output_scene, scene_err])
		return scene_err

	# Save the _config .tres alongside the scene so it can be reloaded
	# by the dock on re-open, and inspected by the developer
	var _config_path := output_scene.get_basename() + "._config.tres"
	var _config_err  := ResourceSaver.save(_config, _config_path)
	if _config_err != OK:
		push_warning("[SceneGenerator] Scene saved but _config .tres failed: %d" % _config_err)

	## Notify the editor filesystem so the new file appears immediately
	EditorInterface.get_resource_filesystem().scan()

	return OK

## Validation 
## Catches _configuration mistakes before any node construction begins
func _validate() -> bool:
	if _config.character_scene == null:
		push_error("[SceneGenerator] Character_config has no character_scene set.")
		return false
	if _config.options.is_empty():
		push_error("[SceneGenerator] Character_config has no options — nothing to generate.")
		return false
	var ids := {}
	for opt in _config.options:
		if opt.resource_name.is_empty():
			push_error("[SceneGenerator] An OptionDefinition has an empty display_name.")
			return false
		if ids.has(opt.resource_name):
			push_error("[Character_config] Duplicate resource_name: '%s'." % opt.resource_name)
			return false
		ids[opt.resource_name] = true
	return true

## Recursively sets node owners to scene_root and clears their scene_file_path 
## so they are saved directly in the .tscn instead of remaining an external instance.
func _unwrap_and_bind(node: Node, scene_root: Node, ignore_node: Node) -> void:
	node.owner = scene_root
	node.scene_file_path = ""

	for child in node.get_children():
		if child != ignore_node:
			_unwrap_and_bind(child, scene_root, ignore_node)

## Walks a subtree and sets .owner on every node that doesn't already have one.
## Nodes from packed scenes carry their own owner so only new nodes need this.
func _set_owners(node: Node, scene_root: Node) -> void:
	if node.owner != null:
		return;
	node.owner = scene_root
	for child in node.get_children():
		_set_owners(child, scene_root)
