## Sets up camera controls for character preview
@tool
class_name CharacterPreview
extends SubViewportContainer

@export var rotation_speed := 0.01

@export var zoom_speed := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 5.0

@export var pan_speed := 1.0
@export var min_height := 0.0
@export var max_height := 1.5

var _zoom := 2.0
var _dragging := false

## Node references
@onready var _viewport:  SubViewport  = $SubViewport
@onready var _rig:     	 Node3D         = $SubViewport/CameraRig # Horizontal rotation (yaw)
@onready var _pivot:     Node3D       = $SubViewport/CameraRig/CameraPivot # Pan vertically
@onready var _camera:    Camera3D     = $SubViewport/CameraRig/CameraPivot/Camera3D
@onready var _character: Node         = $SubViewport/Character # Injected by SceneGenerator
@onready var _world:	 WorldEnvironment = $SubViewport/WorldEnvironment # For shader injection

## Skybox Setup
func _add_skybox_shader(shader: ShaderMaterial)-> void:
	_world.environment.sky.sky_material = shader

## Camera rig setup
func _ready() -> void:
	update_camera_distance()

func _input(event):
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_inside = get_global_rect().has_point(mouse_pos)

	# Mouse Press / Release
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if mouse_inside:
					_dragging = true
			else:
				_dragging = false

		# Zoom when hovering preview
		if mouse_inside:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom -= zoom_speed
				update_camera_distance()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom += zoom_speed
				update_camera_distance()

	# Enter while dragging case
	if event is InputEventMouseMotion:
		var left_held = event.button_mask & MOUSE_BUTTON_MASK_LEFT

		if not _dragging and left_held and mouse_inside:
			_dragging = true

	# Rotate + Pan
	if event is InputEventMouseMotion and _dragging:
		_rig.rotate_y(-event.relative.x * rotation_speed)

		var pan_delta = (event.relative.y / _viewport.size.y) * pan_speed
		
		_pivot.position.y = clamp(
			_pivot.position.y + pan_delta,
			min_height,
			max_height
		)

func update_camera_distance():
	_zoom = clamp(_zoom, min_zoom, max_zoom)
	_camera.position.z = _zoom

## Exposes the character node to CreatorManager to call blendshape and material operations.
func get_character_root() -> Node: 
	if _character == null:
		_character = get_node_or_null("SubViewport/Character")
		if _character == null:
			push_warning("[CharacterPreview] SubViewport/Character not found.")
	return _character
