extends CharacterBody2D
class_name PushableObjects

const PUSH_SPEED = 100.0
const ACCELERATION = 600.0
const FRICTION = 0.75
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_hanging: bool = false
var is_being_pushed: bool = false


func _physics_process(delta):
	velocity.y += gravity * delta
	
	if not is_being_pushed:
		velocity.x *= FRICTION
		if abs(velocity.x) < 5.0:
			velocity.x = 0
	
	is_being_pushed = false
	move_and_slide()


func slide_object(direction):
	is_being_pushed = true
	var target_speed = direction.x * PUSH_SPEED
	velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * get_physics_process_delta_time())


func apply_lift() -> void:
	global_position.y -= 9.0
	set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	set_physics_process(true)
