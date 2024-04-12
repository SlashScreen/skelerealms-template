class_name Player extends CharacterBody3D
# From https://github.com/rbarongr/GodotFirstPersonController

@export_category("Player")
@export_range(1, 35, 1) var speed: float = 10 # m/s
@export_range(10, 400, 1) var acceleration: float = 100 # m/s^2

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1 # m
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1

var jumping: bool = false
var mouse_captured: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2 # Input direction for movement
var look_dir: Vector2 # Input direction for look/aim

var walk_vel: Vector3 # Walking velocity 
var grav_vel: Vector3 # Gravity velocity 
var jump_vel: Vector3 # Jumping velocity

@onready var camera: Camera3D = $Camera
@onready var ray:RayCast3D = $Camera/RayCast3D

signal update_position(pos:Vector3)
signal update_rotation(rot:Quaternion)
## Called when an interactive object is under the crosshair.
signal interaction_text_detected(verb:String, thing:String)
## Called when there is no longer an object under the crosshair.
signal interaction_text_ended()


func _ready() -> void:
	# Connect to Skelerealms system
	update_position.connect((get_parent().get_parent() as Entity)._on_set_position.bind())
	update_rotation.connect((get_parent().get_parent() as Entity)._on_set_rotation.bind())
	add_to_group("perception_target")
	
	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
	if Input.is_action_just_pressed("jump"): jumping = true
	if Input.is_action_just_pressed("exit"): get_tree().quit()
	if Input.is_action_just_pressed("interact"): _interact()


func _physics_process(delta: float) -> void:
	if mouse_captured: _handle_joypad_camera_rotation(delta)
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	move_and_slide()
	update_position.emit(global_position)
	update_rotation.emit(quaternion)
	_check_interactive_state()


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func _rotate_camera(sens_mod: float = 1.0) -> void:
	camera.rotation.y -= look_dir.x * camera_sens * sens_mod
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * camera_sens * sens_mod, -1.5, 1.5)


func _handle_joypad_camera_rotation(delta: float, sens_mod: float = 1.0) -> void:
	var joypad_dir: Vector2 = Input.get_vector("look_left","look_right","look_up","look_down")
	if joypad_dir.length() > 0:
		look_dir += joypad_dir * delta
		_rotate_camera(sens_mod)
		look_dir = Vector2.ZERO


func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backwards")
	var _forward: Vector3 = camera.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized()
	walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), acceleration * delta)
	return walk_vel


func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
	return grav_vel


func _jump(delta: float) -> Vector3:
	if jumping:
		if is_on_floor(): jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
		jumping = false
		return jump_vel
	jump_vel = Vector3.ZERO if is_on_floor() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
	return jump_vel


# also added for skelerealms to check for interactive items
func _check_interactive_state() -> void:
	if not ray.is_colliding():
		interaction_text_ended.emit()
		return
	var item:Object = ray.get_collider()
	if not item is Node:
		interaction_text_ended.emit()
		return
	var interactive = SkeleRealmsGlobal.get_interactive_node(item)
	if interactive == null:
		interaction_text_ended.emit()
		return
	if not interactive.interactible:
		interaction_text_ended.emit()
		return
	if interactive is InteractiveComponent:
		interaction_text_detected.emit(interactive.interact_verb, interactive.interact_name)
	elif interactive is InteractiveObject:
		interaction_text_detected.emit(interactive.interact_verb, interactive.object_name)
	else:
		interaction_text_ended.emit()


func _interact() -> void:
	if not ray.is_colliding():
		return
	var item:Object = ray.get_collider()
	if not item is Node:
		return
	var interactive = SkeleRealmsGlobal.get_interactive_node(item)
	if interactive == null:
		return
	if not interactive.interactible:
		return
	interactive.interact(&"Player")
