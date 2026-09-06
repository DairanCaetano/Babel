extends CharacterBody2D
class_name Sha

const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")

# --- Posições padrão (assumindo _direction = 1, olhando pra direita) ---
# ⚠️ PLACEHOLDER — me passa os valores reais de Collision (root), ChaseArea/Collision e HurtBox/Collision
const BODY_DEFAULT_POS: Vector2 = Vector2(-4, 6)
const HURTBOX_DEFAULT_POS: Vector2 = Vector2(-4, 1)
const CHASE_AREA_DEFAULT_POS: Vector2 = Vector2(-50, 0)

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _body_collision: CollisionShape2D
@export var _hurtbox_collision: CollisionShape2D
@export var _hurtbox_detection: Area2D
@export var _chase_area: Area2D
@export var _chase_lost_timer: Timer  # atribuir no Inspector

@export_category("Movimento")
@export var _uses_gravity: bool = false
@export var _move_speed: float = 130.0
@export var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var _turn_duration: float = 0.3
@export var _chase_lost_duration: float = 3.0  # tempo sem ver o player até desistir

@export_category("Partículas")
@export var _fire_particles: GPUParticles2D

@export_category("Health System")
@export var _enemy_health: int = 10

@export_category("Sound")
@export var _dead_audio: AudioStreamPlayer
@export var _dead_scream_audio: AudioStreamPlayer
@export var _attack_audio: AudioStreamPlayer  # toca 1x ao começar a perseguir
@export var _run_audio: AudioStreamPlayer     # loop enquanto corre (Loop ativado no import do stream)

var _direction: float = -1.0

var _chase_target: BaseCharacter = null
var _is_chasing: bool = false
var _is_turning: bool = false

var _is_alive: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if _hurtbox_detection:
		_hurtbox_detection.add_to_group("enemy_hitbox")

	_chase_area.body_entered.connect(_on_chase_area_body_entered)
	_chase_area.body_exited.connect(_on_chase_area_body_exited)
	_texture.animation_finished.connect(_on_texture_animation_finished)

	if _chase_lost_timer:
		_chase_lost_timer.one_shot = true
		_chase_lost_timer.wait_time = _chase_lost_duration
		_chase_lost_timer.timeout.connect(_on_chase_lost_timeout)

	_apply_facing()
	_reset_collisions_to_default()
	_texture.play("Idle")


func _physics_process(delta: float) -> void:
	if _uses_gravity and not is_on_floor():
		velocity.y += _gravity * delta

	if _is_alive == false:
		move_and_slide()
		return

	if _is_turning:
		velocity.x = 0
		move_and_slide()
		return

	if _is_chasing and is_instance_valid(_chase_target):
		var _to_player: float = _chase_target.global_position.x - global_position.x
		var _new_direction: float = 1.0 if _to_player > 0 else -1.0

		if _new_direction != _direction and not _is_turning:
			_start_turn(_new_direction)
			move_and_slide()
			return

		velocity.x = _direction * _move_speed
	else:
		velocity.x = 0

	move_and_slide()
	_update_movement_animation()


func _update_movement_animation() -> void:
	if _is_turning:
		return

	if absf(velocity.x) > 1.0:
		if _texture.animation != "Run":
			_texture.play("Run")
		if _run_audio and not _run_audio.playing:
			_run_audio.play()
	else:
		if _texture.animation != "Idle":
			_texture.play("Idle")
		if _run_audio and _run_audio.playing:
			_run_audio.stop()


# --- FLIP (roda "Turn" antes de virar de fato) ---
func _start_turn(new_direction: float) -> void:
	_is_turning = true
	velocity.x = 0
	if _run_audio and _run_audio.playing:
		_run_audio.stop()
	_texture.play("Turn")

	var turn_timer := get_tree().create_timer(_turn_duration)
	turn_timer.timeout.connect(_on_turn_finished.bind(new_direction))


func _on_turn_finished(new_direction: float) -> void:
	_direction = new_direction
	_apply_facing()
	_is_turning = false


func _apply_facing() -> void:
	_texture.flip_h = _direction > 0.0
	_chase_area.position = _mirrored_pos(CHASE_AREA_DEFAULT_POS)


func _mirrored_pos(base: Vector2) -> Vector2:
	var mirror: float = -1.0 if _texture.flip_h else 1.0
	return Vector2(base.x * mirror, base.y)


func _reset_collisions_to_default() -> void:
	_body_collision.position = _mirrored_pos(BODY_DEFAULT_POS)
	_hurtbox_collision.position = _mirrored_pos(HURTBOX_DEFAULT_POS)


# --- PERSEGUIÇÃO, com tolerância de 3s antes de desistir ---
func _on_chase_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		if not _is_chasing and _attack_audio:
			_attack_audio.play()

		_is_chasing = true
		_chase_target = body

		if _chase_lost_timer and not _chase_lost_timer.is_stopped():
			_chase_lost_timer.stop()


func _on_chase_area_body_exited(body: Node2D) -> void:
	if body == _chase_target:
		if _chase_lost_timer:
			_chase_lost_timer.start()


func _on_chase_lost_timeout() -> void:
	_is_chasing = false
	_chase_target = null
	if _run_audio and _run_audio.playing:
		_run_audio.stop()


# --- HEALTH / KILL ---
func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		return
	_enemy_health -= _damage

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)

	var blink_tween := create_tween()
	blink_tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)

	if _enemy_health <= 0:
		HitStopManager.hit_stop_short()
		_stop_all_actions()
		_kill()


func _set_shader_blink_intensity(new_value: float) -> void:
	if not _texture:
		return
	if not _texture.material:
		return
	if not _texture.material.shader:
		return

	_texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	_texture.material.set_shader_parameter("blink_intensity", new_value)


func _stop_all_actions() -> void:
	_is_chasing = false
	_is_turning = false
	if _run_audio and _run_audio.playing:
		_run_audio.stop()
	if _chase_lost_timer and not _chase_lost_timer.is_stopped():
		_chase_lost_timer.stop()


func _kill() -> void:
	velocity = Vector2.ZERO
	_texture.play("Dead")

	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)

	_is_alive = false
	_chase_target = null

	_body_collision.set_deferred("disabled", true)

	if _hurtbox_detection:
		_hurtbox_detection.set_deferred("monitoring", false)
		_hurtbox_detection.set_deferred("monitorable", false)

	if _chase_area:
		_chase_area.set_deferred("monitoring", false)
		_chase_area.set_deferred("monitorable", false)

	_drop_items()

	if _fire_particles:
		_fire_particles.visible = true
		_fire_particles.restart()
		_fire_particles.emitting = true

	if _dead_audio:
		_dead_audio.play()
	if _dead_scream_audio:
		_dead_scream_audio.play()


func _on_texture_animation_finished() -> void:
	if _texture.animation == "Dead":
		queue_free()


# --- DROPS ---
func _get_drop_items() -> Dictionary:
	return {
		"small_shards": {
			"name": "Small Shards",
			"path": "res://sprites/Items/small_fragment.png",
			"type": "resource",
			"description": "Descrição aqui",
			"value": 5,
			"spawn_probability": 0.90
		},
	}


func _drop_items() -> void:
	var drop_data = _get_drop_items()

	for item_key in drop_data:
		var item = drop_data[item_key]
		if randf() < item["spawn_probability"]:
			var _collectable: CollectableItem = _COLLECTABLE_ITEM.instantiate()
			_collectable.item_texture = item["path"]
			_collectable.item_data = item
			_collectable.global_position = global_position
			get_tree().current_scene.call_deferred("add_child", _collectable)
