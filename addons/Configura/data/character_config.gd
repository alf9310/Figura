## Source of truth for character creator configuration:
## which mesh scene to use, which options to expose, and how the runtime scene should behave. 
@tool
@icon("res://addons/Configura/icons/character_creater_config_icon.svg")
class_name CharacterConfig
extends Resource

## The character scene to instantiate inside CharacterPreview.
@export var character_scene: PackedScene

## Output path for the generated scene and exported meshes.
@export var output_path: String = ""

## All options the developer has chosen to expose to the player.
## Populated by MeshInspector, curated by CharacterCreatorDock.
@export var options: Array[OptionDefinition] = []

@export var skeleton_path: String = ""

@export var mesh_pos_dict:= {}

@export var mesh_size_dict:= {}

## --- Runtime behaviour flags ---
## Expose a Randomize button in the generated scene footer.
@export var allow_randomize: bool = true

## Emit a CharacterState .tres file when the player confirms.
@export var save_state_on_confirm: bool = true

## Where to write the CharacterState .tres on confirm.
## Relative to the user:// directory.
@export var state_save_path: String = "character_state.tres"


## --- Preview settings ---
## Distance of the preview camera from the character origin.
@export_range(0.5, 10.0, 0.1) var preview_camera_distance: float = 2.0

## Vertical offset of the preview camera's look-at target.
## Useful for framing faces (positive) vs full body (zero).
@export_range(-2.0, 2.0, 0.05) var preview_camera_height: float = 0.8

## Fraction of screen width the UI panel occupies (0.0–1.0).
@export_range(0.0, 1.0, 0.05) var ui_panel_width: float = 0.5

## Whether the player can orbit the preview camera.
@export var allow_preview_orbit: bool = true

## --- Theme settings ---
## Custom theme applied to generated UI
@export var theme_resource: Theme
## Skybox shader applied to preview viewport
@export var skybox_resource: ShaderMaterial
## Shared color palette for swatches
@export var color_swatch_palette: ColorSwatchPalette

## Returns a string with a summary of Character config settings
func _to_string() -> String:
	var option_summary := ", ".join(
		options.map(func(o: OptionDefinition) -> String: return str(o))
	)
	return (
		"CharacterConfig(\n"
		+ "  scene: %s\n"            % (character_scene.resource_path.get_file() if character_scene else "none")
		+ "  options: [%s]\n"        % option_summary
		+ "  allow_randomize: %s\n"  % allow_randomize
		+ "  save_state: %s -> %s\n"  % [save_state_on_confirm, state_save_path]
		+ "  camera: dist=%.1f height=%.2f orbit=%s\n" % [preview_camera_distance, preview_camera_height, allow_preview_orbit]
		+ ")"
	)
