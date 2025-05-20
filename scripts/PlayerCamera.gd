# Edit file: res://scripts/PlayerCamera.gd
extends Camera3D

@export var move_speed := 5.0
@export var rotation_speed := 0.003
@export var zoom_speed := 2.0

var _mouse_captured := false
var _rotation := Vector2.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event.is_action_pressed("capture_mouse"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_mouse_captured = true
	elif event.is_action_released("capture_mouse"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mouse_captured = false
	
	if _mouse_captured and event is InputEventMouseMotion:
		# Invert the mouse movement by removing the negative signs
		_rotation += -event.relative * rotation_speed  # Changed from -= to +
		_rotation.y = clamp(_rotation.y, -PI/2, PI/2)
		
		transform.basis = Basis()
		rotate_object_local(Vector3.UP, _rotation.x)  # Changed from -_rotation.x to _rotation.x
		rotate_object_local(Vector3.RIGHT, _rotation.y)  # Changed from -_rotation.y to _rotation.y

func _physics_process(delta):
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	if input_dir != Vector3.ZERO:
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
		position += direction * move_speed * delta
