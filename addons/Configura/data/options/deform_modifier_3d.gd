## SkeletonModifier3D that applies DeformOption resources to a Skeleton3D.
@tool
class_name DeformModifier3D
extends SkeletonModifier3D

## Maps each active DeformOption to current deformation value.
## Written in by CreatorManager
var _active_deforms: Dictionary[DeformOption, float] = {}

## Called by CreatorManager when deform slider changes.
func set_deform_value(opt: DeformOption, value: float) -> void:
	_active_deforms[opt] = value

## Called by SkeletonModifier3D during modification. Applies every active DeformOption in _active_deforms to Skeleton3D.
func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	for opt in _active_deforms:
		opt.apply(skeleton, _active_deforms[opt])
