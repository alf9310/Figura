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

var height_offset = 0.2

var _zoom := 2.0
var _dragging := false

var _tween_speed := 0.6
var _rig_yaw_offset := Vector3(0, 0.3, 0)
# Default camera's _z_distance value: just an arbitrary value on set up
# This will change as the user clicks on the tab to start customizing their character
var _z_distance := 1.7
# vector to offset the camera's zoom on the z axis
var _camera_z_zoom_offset := Vector3(0, 0, _z_distance)

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
	# Get current mouse position in viewport
	var mouse_pos = get_viewport().get_mouse_position()
	# Whether or not mouse is inside the character preview viewport
	var mouse_inside = get_global_rect().has_point(mouse_pos)

	# audrey's old camera implementation
	# Mouse Press / Release
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#if event.pressed and mouse_inside:
				#_dragging = true
			#else:
				#_dragging = false
#
		## Zoom when hovering preview
		#if mouse_inside:
			#if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				#_zoom -= zoom_speed
				#update_camera_distance()
			#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				#_zoom += zoom_speed
				#update_camera_distance()
#
	## Enter while dragging case
	#if event is InputEventMouseMotion:
		#var left_held = event.button_mask & MOUSE_BUTTON_MASK_LEFT
#
		#if not _dragging and left_held and mouse_inside:
			#_dragging = true
#

	# Allows continuous camera controls on character preview when mouse exits 
	# character preview viewport as long as user is still dragging
	if event is InputEventMouseButton:
		allow_continuous_camera_controls(event)
			
	# Mouse hover inside character preview
	if mouse_inside:
		# Mouse click ONLY when inside character viewport
		if event is InputEventMouseButton:
			# Zoom in/out when mouse hovering character preview
			update_camera_zoom(event)
			
			# Left mouse click enables dragging if held 
			if event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = true if event.pressed else false
	
	# If mouse is dragging
	if event is InputEventMouseMotion and _dragging:
		# Rotate 
		_rig.rotate_y(-event.relative.x * rotation_speed)
		# Pan
		pan_character_preview(event)
		
func allow_continuous_camera_controls(event):
	# If still dragging, allows camera zoom in/out
	if _dragging:
		update_camera_zoom(event)
		
	# On mouse release, stop dragging, which will stop ability to pan/rotate 
	if event.button_index == MOUSE_BUTTON_LEFT and event.is_released() and _dragging:
		_dragging = false

func update_camera_zoom(event):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom -= zoom_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom += zoom_speed
	update_camera_distance()
	
func update_camera_distance():
	_zoom = clamp(_zoom, min_zoom, max_zoom)
	_camera.position.z = _zoom
	
func pan_character_preview(event):
	var pan_delta = (event.relative.y / _viewport.size.y) * pan_speed
		
	_pivot.position.y = clamp(
		_pivot.position.y + pan_delta,
		min_height,
		max_height
	)
	
## Exposes the character node to CreatorManager to call blendshape and material operations.
func get_character_root() -> Node: 
	if _character == null:
		_character = get_node_or_null("SubViewport/Character")
		if _character == null:
			push_warning("[CharacterPreview] SubViewport/Character not found.")
	return _character
	
func set_camera_min_height(in_height: float):
	min_height = in_height - height_offset
	
func set_camera_max_height(in_height: float):
	max_height = in_height + height_offset
	
func calculate_camera_zoom(object_size: float):
	var _camera_view = 2.0 * tan(0.5 * deg_to_rad(_camera.fov))
	_z_distance = 2.0 * object_size / _camera_view
	_z_distance += 1.5 * object_size

func set_camera_focus(focus_point: Vector3):
	var tween_pivot = get_tree().create_tween()
	tween_pivot.set_parallel(true)
	tween_pivot.set_trans(Tween.TRANS_SINE)
	
	_camera_z_zoom_offset = Vector3(0, 0, _z_distance)

	tween_pivot.tween_property(_pivot, "position", focus_point, _tween_speed)
	tween_pivot.tween_property(_rig, "rotation", _rig_yaw_offset, _tween_speed)
	tween_pivot.tween_property(_camera, "position", _camera_z_zoom_offset, _tween_speed)
	
	# update the _zoom to be the new _z_distance for the next time the user clicks onto the character preview
	_zoom = _z_distance
