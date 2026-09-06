extends CharacterBody2D
class_name Torreta

@export var projectile_speed: float = 300.0

@export_category("Objects")
@export var detection_area: Area2D
@export var texture: AnimatedSprite2D
@export var fire_point: Marker2D
@export var hurt_box: Area2D

@export_category("Health System")
@export var _enemy_health: int = 10

@export_category("Attack Settings")
@export var shot_interval: float = 2.0

@export_category("Direction")
@export var facing_right: bool = false

const PROJECTILE_PATH = "res://Scenes/Projectile/projectile_enemy_arrow.tscn"
var _projectile_scene: PackedScene

var player_detected: BaseCharacter = null
var is_attacking: bool = false
var is_facing_right: bool = false
var _is_alive: bool = true
var _projectile_fired: bool = false

var shot_interval_timer: Timer
var idle_return_timer: Timer

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_projectile_scene = load(PROJECTILE_PATH)

	shot_interval_timer = Timer.new()
	add_child(shot_interval_timer)
	shot_interval_timer.one_shot = true
	shot_interval_timer.timeout.connect(_on_shot_interval_timeout)

	idle_return_timer = Timer.new()
	add_child(idle_return_timer)
	idle_return_timer.one_shot = true
	idle_return_timer.wait_time = 0.5
	idle_return_timer.timeout.connect(_on_idle_return_timeout)

	texture.animation_finished.connect(_on_animation_finished)
	texture.frame_changed.connect(_on_frame_changed)

	is_facing_right = facing_right
	_apply_direction()
	_play_animation("Idle")

func _apply_direction():
	if is_facing_right:
		texture.flip_h = true
		fire_point.position.x = 5
		detection_area.position.x = 226
		$Collision.position.x = -3.5
		hurt_box.position.x = -3.0
	else:
		texture.flip_h = false
		fire_point.position.x = -5
		detection_area.position.x = -226
		$Collision.position.x = 3.5
		hurt_box.position.x = 3.0

func _play_animation(animation_name: String):
	if texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)

func _on_frame_changed():
	if texture.animation == "Attack" and texture.frame == 5 and not _projectile_fired:
		_projectile_fired = true
		_fire_projectile()

func _on_animation_finished():
	if texture.animation == "Attack":
		idle_return_timer.start()

func _on_idle_return_timeout():
	is_attacking = false
	_projectile_fired = false
	_play_animation("Idle")

	if player_detected and _is_alive:
		shot_interval_timer.wait_time = shot_interval
		shot_interval_timer.start()

func _on_shot_interval_timeout():
	if player_detected and _is_alive:
		_trigger_attack()

func _trigger_attack():
	is_attacking = true
	_projectile_fired = false
	_play_animation("Attack")

func _fire_projectile():
	if not _projectile_scene:
		return
	var projectile = _projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = fire_point.global_position
	var direction = Vector2(1 if is_facing_right else -1, 0)
	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_speed)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter and _is_alive:
		player_detected = body
		if not is_attacking:
			_trigger_attack()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_detected:
		player_detected = null

func update_health(_damage: int, _entity) -> void:
	if not _is_alive:
		return

	_enemy_health -= _damage

	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)

	if _enemy_health <= 0:
		_kill()

func _set_shader_blink_intensity(new_value: float) -> void:
	if not texture or not texture.material or not texture.material.shader:
		return
	texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	texture.material.set_shader_parameter("blink_intensity", new_value)

func _kill() -> void:
	_is_alive = false
	is_attacking = false
	player_detected = null
	shot_interval_timer.stop()
	idle_return_timer.stop()
	_play_animation("Dead")
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	if hurt_box:
		hurt_box.monitoring = false
		hurt_box.monitorable = false
	get_tree().create_timer(2.0).timeout.connect(queue_free)
