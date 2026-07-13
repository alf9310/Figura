## Saves all player's character creator selections. 
## Holds no references to nodes, meshes, or materials. 
## Can be applied to any character mesh with the same option names. 
@tool
@icon("res://addons/Configura/icons/character_save_file_logo.svg")
class_name CharacterState
extends Resource

## Key = option resource_name, value = choice
@export var values: Dictionary[String, Variant] = {}

## Timestamp of the last modification. Useful for save slot UIs.
@export var last_modified: int = 0

## All mesh scenes on character. 
## Used by [CharacteStateApplier] for fast lookup of values
@export var active_meshes: Array[String] = []

## Icon for the load tab
@export var icon : Image

## Arbitrary developer-defined metadata. Use this to attach things like
## character name, class, or faction without subclassing CharacterState.
@export var metadata: Dictionary = {}

## Reads the options from the character config and returns a new Character state
static func from_config(config: CharacterConfig) -> CharacterState:
	var state := CharacterState.new()
	for opt in config.options:
		state.values[opt.resource_name] = opt.get_default_value()
	state.last_modified = Time.get_unix_time_from_system()
	return state

## Writes a value into the dictionary
## Called by CreatorManager on every UI interaction to keep state in sync.
func record(option_id: String, value: Variant) -> void:
	values[option_id] = value
	last_modified = Time.get_unix_time_from_system()

## Generates new values for each OptionDefinition, with constraints (include flag and value range).
static func randomized(config: CharacterConfig) -> CharacterState:
	var state := CharacterState.new()
	for opt in config.options:
		if opt.include:
			state.values[opt.resource_name] = opt.get_random_value()
	state.last_modified = Time.get_unix_time_from_system()
	return state
