## Drops into project where character creation happens.
## Wires its children together and exposes a two-signal public API to the rest of the game.
@tool
class_name CreatorController
extends Node

## Emitted when the player presses Confirm.
## The developer connects to this and receives the final CharacterState.
signal character_confirmed(state: CharacterState)
## Emitted when the player presses Cancel.
signal character_cancelled()

## Set directly by SceneGenerator after the tree is built
@export var config:   CharacterConfig
@export var ui:       CreatorUI
@export var manager: CreatorManager
@export var preview:  CharacterPreview
@export var loader:   CharacterLoader

enum CompatResult { 
	COMPAT_FULL, 
	COMPAT_PARTIAL, 
	COMPAT_NONE,
}

## Where all the connections are made. 
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	preview._add_skybox_shader(config.skybox_resource)
	ui.option_changed.connect(manager.apply_option)
	
	# Footer actions
	ui.save_pressed.connect(_on_save)
	ui.load_pressed.connect(_on_toggle)
	loader.back_pressed.connect(_on_toggle)
	loader.character_selected.connect(_on_load)
	# Randomize buttons
	if config.allow_randomize:
		ui.randomize_pressed.connect(_on_randomize)
	else:
		ui.hide_randomize_button()
	
	# Seed the manager with defaults and sync the UI to match
	manager.initialize(config, preview, ui)
	
	# If a previous save exists and should be restored, load it now
	if config.save_state_on_confirm:
		_try_restore_saved_state()

## Create a file dialogue pop-up for the user the save the character to their local data
func _on_save() -> void:
	var state: CharacterState = manager.get_current_state()
	var save_path :String
	
	# Take a photo of character and save it to the state
	var viewport:SubViewport = preview.get_child(0)
	var icon = viewport.get_texture().get_image()
	icon.resize(180,180,1)
	state.icon = icon
	
	# Get the save folder from output path, make folder if no folder is found
	var dir := DirAccess.open("user://")
	var char_path = config.output_path + "/saved_characters/"
	if not dir.dir_exists_absolute(char_path):
		dir.make_dir_absolute(char_path)
		
	# Dynamically name the save of the resource based on the number of saved characters in the file system.
	var count:int = get_file_count(char_path)
	if count == null or count == 0:
		save_path = char_path +"character.tres"
		state.metadata["name"] = "character"
	else:
		save_path = char_path +"character_%s.tres" % [count]
		state.metadata["name"] = "character_%s" % [count]

	var err := ResourceSaver.save(state,save_path)
	if err != OK:
		push_warning("[CharacterCreator] Failed to save state to %s: %d" % [save_path, err])
	else:
		print("[CharacterCreator] Saved character to: ", save_path)
	pass

func get_file_count(path) -> int:
	var dir := DirAccess.open(path)
	var count = 0
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			count +=1
	dir.list_dir_end()
	return count

## Toggle the load menu on and off, this is the loop of what the load button and back button will do.
func _on_toggle() -> void:
	loader.visible = !loader.visible
	if loader.visible:
		loader.load_saved_characters()
	ui.visible = !ui.visible

## Load character state from a recived signal
func _on_load(state:CharacterState) -> void:
		if state == null:
			push_warning("[CharacterCreator] Failed to load CharacterState from %s" % state)
			return

		var compat := _validate_state_compatibility(state)

		if compat == CompatResult.COMPAT_FULL:
			manager.load_state(state)
			print("[CharacterCreator] Loaded character (full match)")
		elif compat == CompatResult.COMPAT_PARTIAL:
			manager.load_state_partial(state)
			push_warning("[CharacterCreator] Loaded character (partial match)")
		else:
			push_warning("[CharacterCreator] Loaded file incompatible with current config")
		_on_toggle()


func _on_randomize() -> void:
	var state := CharacterState.randomized(config)

	# Preserve current pose (excluded from randomization)
	var current_state := manager.get_current_state()
	for opt in config.options:
		if opt is AnimationOption:
			var key := opt.resource_name
			if current_state.values.has(key):
				state.values[key] = current_state.values[key]

	manager.load_state(state)
	
## When the creator scene opens and save_state_on_confirm is true, 
## the root node checks for a previously saved state and restores it 
## so returning players see their last character.
func _try_restore_saved_state() -> void:
	var path := "user://" + config.state_save_path
	if not ResourceLoader.exists(path):
		return

	var state := ResourceLoader.load(path) as CharacterState
	if state == null:
		push_warning("[CharacterCreator] Could not load saved state from %s" % path)
		return

	# Validate that the saved state is compatible with the current config
	var compat := _validate_state_compatibility(state)
	if compat == CompatResult.COMPAT_FULL:
		manager.load_state(state)
	elif compat == CompatResult.COMPAT_PARTIAL:
		# Apply what we can, leave unrecognised keys as defaults
		manager.load_state_partial(state)
		push_warning("[CharacterCreator] Saved state partially compatible — some options reset to defaults.")
	else:
		push_warning("[CharacterCreator] Saved state incompatible with current config — starting fresh.")

## Checks whether the saved state's keys still exist in the current config.
func _validate_state_compatibility(state: CharacterState) -> CompatResult:
	var config_ids := {}
	for opt in config.options:
		config_ids[opt.resource_name] = true

	var state_keys: Array = state.values.keys()

	if state_keys.is_empty():
		return CompatResult.COMPAT_NONE

	var matched := 0
	for key in state_keys:
		if config_ids.has(key):
			matched += 1

	if matched == state_keys.size():
		return CompatResult.COMPAT_FULL
	elif matched > 0:
		return CompatResult.COMPAT_PARTIAL
	else:
		return CompatResult.COMPAT_NONE
