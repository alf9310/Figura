@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/Configura/editor/docks/configura_dock.tscn")
const NAME = "Configura"
var _dock: ConfiguraDock

## @deprecated Add autoloads here.
func _enable_plugin() -> void:
	
	pass

## @deprecated Remove autoloads here.
func _disable_plugin() -> void:
	pass
	
## Instantiate and add the dock to the editor UI
func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	
	add_custom_type("CharacterConfig",      "Resource", preload("data/character_config.gd"),       preload("icons/character_config.svg"))
	add_custom_type("BlendshapeOption",     "Resource", preload("data/options/blendshape_option.gd"), preload("icons/option.svg"))
	add_custom_type("MeshSwapOption",       "Resource", preload("data/options/mesh_swap_option.gd"),  preload("icons/option.svg"))
	add_custom_type("ColorOption",          "Resource", preload("data/options/color_option.gd"),       preload("icons/option.svg"))
	add_custom_type("AnimationOption",      "Resource", preload("data/options/animation_option.gd"),   preload("icons/option.svg"))
	add_custom_type("TextureAtlasOption",      "Resource", preload("data/options/texture_atlas_option.gd"),   preload("icons/option.svg"))
	add_custom_type("DeformOption", "Resource", preload("data/options/deform_option.gd"), preload("icons/option.svg"))

func _get_window_layout(configuration: ConfigFile) -> void:
	var state: Dictionary = _dock.get_persistent_state()
	if _dock:
		configuration.set_value(NAME, "state", _dock.get_persistent_state())

func _set_window_layout(configuration: ConfigFile) -> void:
	var dock_node := _dock
	if dock_node and configuration.has_section_key(NAME, "state"):
		dock_node.apply_persistent_state(configuration.get_value(NAME, "state"))

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
		
	remove_custom_type("CharacterConfig")
	remove_custom_type("BlendshapeOption")
	remove_custom_type("MeshSwapOption")
	remove_custom_type("ColorOption")
	remove_custom_type("AnimationOption")
	remove_custom_type("TextureAtlasOption")
	remove_custom_type("DeformOption")
