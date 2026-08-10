## Creates one slider in character creator to drive all its [BoneTarget]s with bone deformation.
@tool
@icon("res://addons/Configura/icons/bone_deform_icon.svg")
class_name DeformOption
extends OptionDefinition

enum DeformType { 
	SINGLE, 
	BIDIRECTIONAL,
}

## SINGLE: deform is driven by one transform (slider range: 0.0-1.0)
## BIDIRECTIONAL: deform is driven by two transforms (slider range: −1.0-1.0)
@export var deform_type: DeformType = DeformType.SINGLE
## NodePath to the Skeleton node. Local path in character scene uploaded to dock.
@export var skeleton_path: String = ""
## Array that holds all the bones (BoneTargets) that this DeformOption affects.
@export var bones: Array[BoneTarget] = []
## The default slider value of this deform option
@export var default_value := 0.0
@export var min_value = -1.0 if deform_type == DeformType.BIDIRECTIONAL else 0.0
@export var max_value = 1.0

## Returns the min float value for this deform option (SINGLE: 0.0, BIDIRECTIONAL: -1.0)
func get_min_value() -> float:
	return min_value

## Returns the max float value for this deform option (Always 1.0)
func get_max_value() -> float:
	return max_value

func get_option_category() -> String:
	return "deform"
	
func get_default_value() -> float:
	return default_value

func get_random_value() -> float:
	return randf_range(min_value, max_value)

func apply_to_preview(manager: CreatorManager, value: Variant, should_camera_focus: bool = false, force_full_pass: bool = false) -> void:
	manager._apply_deform(self, value as float)

func apply_to_character(character_root: Node, skeleton: Node, value: Variant) -> void:
	apply(skeleton as Skeleton3D, value as float)

func get_editor_groups() -> Array[String]:
	return [group if not group.is_empty() else "General"]

func create_editor_rows(content_vbox, group_ui, group_name, group_has_atlas, active_ui_controls, group_scene, row_scene) -> GroupContainer:
	return group_ui

## For each bone target, call _lerp function and set bone pose
func apply(skeleton: Skeleton3D, t: float) -> void:
	for bone_target in bones:
		var idx := skeleton.find_bone(bone_target.bone_name)
		if idx == -1:
			push_warning("[DeformOption] Bone not found: %s" % bone_target.bone_name)
			continue
		var rest = skeleton.get_bone_rest(idx)
		var pose: Transform3D
		if t >= 0.0:
			pose = _lerp(rest, bone_target.max_position_offset, 
						bone_target.max_rotation_degrees, bone_target.max_scale_multiplier, t)
		else:
			pose = _lerp(rest, bone_target.min_position_offset, 
						bone_target.min_rotation_degrees, bone_target.min_scale_multiplier, -t)
		skeleton.set_bone_pose(idx, pose)

## Interpolates a bone's rest transform toward the given deltas by factor [param t].
static func _lerp(rest: Transform3D, 
					pos: Vector3,
					rot_deg: Vector3,
					scale_mult: Vector3,
					t: float) -> Transform3D:
	var origin := rest.origin + pos * t
	
	var rot    := rest.basis.get_rotation_quaternion() * Quaternion.from_euler(rot_deg * (PI / 180.0) * t)
	var scale  := rest.basis.get_scale().lerp(rest.basis.get_scale() * scale_mult, t)
	return Transform3D(Basis(rot).scaled(scale), origin)
