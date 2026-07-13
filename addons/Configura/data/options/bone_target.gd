## Stores per-bone transform deltas. Used in conjunction with [DeformOption].
## Holds information for single bone deformation.
@tool 
class_name BoneTarget
extends Resource

## The bone that is being deformed. Must match name in Skeleton3D hierarchy.
@export var bone_name: String = ""

## Final transform for bone deformation. Applied at slider max (1.0). Used whether deform type is single or bidirectional.
@export_group("Positive Delta")
## Position offset applied when slider is at max (1.0).
@export var max_position_offset: Vector3 = Vector3.ZERO
## Rotation offset in degrees applied when slider is at max (1.0).
@export var max_rotation_degrees: Vector3 = Vector3.ZERO
## Scale multiplier applied when slider is at max (1.0).
@export var max_scale_multiplier: Vector3 = Vector3.ONE

## Final transform for bone deformation. Applied at slider min (-1.0). Only used when deform type is bidirectional.
@export_group("Negative Delta")
## Position offset applied when slider is at min (-1.0).
@export var min_position_offset: Vector3 = Vector3.ZERO
## Rotation offset in degrees applied when slider is at min (-1.0).
@export var min_rotation_degrees: Vector3 = Vector3.ZERO
## Scale multiplier applied when slider is at min (-1.0).
@export var min_scale_multiplier: Vector3 = Vector3.ONE
