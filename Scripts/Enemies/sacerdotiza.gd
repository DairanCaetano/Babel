extends CharacterBody2D
class_name SacerdotisaEgito

const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")

# --- Posições padrão (assumindo _direction = 1, olhando pra direita) ---
const BODY_DEFAULT_POS: Vector2 = Vector2(0, 11)
const HURTBOX_DEFAULT_POS: Vector2 = Vector2(0, 5)
const ATTACK_AREA_DEFAULT_POS: Vector2 = Vector2(-19, 9)
const ATTACK_AREA_DEFAULT_ROT: float = 90.0
const CHASE_AREA_DEFAULT_POS: Vector2 = Vector2(-35, 0)
const DETECTION_COLLISION_DEFAULT_POS: Vector2 = Vector2(-38, 8)
const BLOOD_PARTICLES_POS: Vector2 = Vector2(13, 2)
const BLOOD_PARTICLES_2_POS: Vector2 = Vector2(0, 7)
const GROUND_RAY_DEFAULT_POS: Vector2 = Vector2(-21, 28)
const WALL_RAY_DEFAULT_POS: Vector2 = Vector2(-22, 0)

const ATTACK_ADVANCE_DISTANCE: float = 45.0
const ATTACK_3_ADVANCE_DISTANCE: float = 90.0

# Attack_1
const ATTACK_1_BODY_POS: Vector2 = Vector2(-2, 11)
const ATTACK_1_HURTBOX_POS: Vector2 = Vector2(-2, 5)

# Attack_2
const ATTACK_2_BODY_POS: Vector2 = Vector2(-5, 11)
const ATTACK_2_HURTBOX_POS: Vector2 = Vector2(-5, 5)
const ATTACK_2_AREA_POS: Vector2 = Vector2(-22, 9)
const ATTACK_2_AREA_ROT: float = 0.0

# Attack_3
const ATTACK_3_BODY_POS: Vector2 = Vector2(-6, 11)
const ATTACK_3_HURTBOX_POS: Vector2 = Vector2(-6, 11)
const ATTACK_3_AREA_POS: Vector2 = Vector2(-20, 13)

# --- Direção inicial (controlável no Inspector) ---
enum StartingDirection { LEFT, RIGHT }

@export_category("Direção Inicial")
@export var _starting_direction: StartingDirection = StartingDirection.LEFT

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _body_collision: CollisionShape2D
@export var _hurtbox_collision: CollisionShape2D
@export var _attack_collision: CollisionShape2D
@export var _detection_collision: CollisionShape2D
@export var _chase_area: Area2D
@export var _detection_area: Area2D
@export var _attack_area: Area2D
@export var _hurtbox_detection: Area2D
@export var _dodge_timer: Timer
@export var _dodge_cooldown_timer: Timer
@export var _ground_ray: RayCast2D
@export var _wall_ray: RayCast2D

@export_category("Partículas")
@export var _blood_particles: GPUParticles2D
@export var _blood_particles_2: GPUParticles2D
@export var _fade_fx: GPUParticles2D
@export var _enable_fade_fx: bool = true  # desliga pra testar sem o efeito

@export_category("Movimento")
@export var _uses_gravity: bool = false
@export var _move_speed: float = 100.0
@export var _attack_advance_duration: float = 0.15   # tempo do avanço no Ataque 1 e 2
@export var _attack_3_advance_duration: float = 0.30  # tempo do avanço no Ataque 3
@export var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Virada e Perseguição")
## Distância horizontal (px) em que ela NÃO vira: com a Tola quase na mesma linha (em cima/embaixo dela) o lado é ambíguo
@export var _turn_deadzone: float = 6.0
## Tempo mínimo (s) entre uma virada e outra
@export var _turn_cooldown: float = 0.2
## Tempo (s) que ela continua perseguindo depois que a Tola sai da área de perseguição
@export var _lose_target_time: float = 2.0

@export_category("Esquiva (Dash)")
@export var _dodge_chance: float = 0.6
@export var _dodge_speed: float = 200.0
@export var _dodge_vertical_boost: float = 80.0
@export var _dodge_duration: float = 0.35
@export var _attack_cooldown_duration: float = 2.0
@export var _combo_cooldown_duration: float = 1.5
@export var _attack_3_chance: float = 0.6
@export var _ghost_trail_scene: PackedScene
@export var _ghost_interval: float = 0.03

@export_category("Health System")
@export var _enemy_health: int = 10

@export_category("Morte")
@export var _death_fade_duration: float = 1.0  # tempo pra sumir totalmente após o frame 19

@export_category("Parry")
@export var _stagger_duration: float = 1.0

@export_category("Sound")
@export var _dead_audio: AudioStreamPlayer
@export var _dead_scream_audio: AudioStreamPlayer
@export var _hit_audio: AudioStreamPlayer
@export var _attack_audio: AudioStreamPlayer
@export var _voice_attack_audio: AudioStreamPlayer
@export var _attack_3_audio: AudioStreamPlayer

# Valor padrão aqui não importa muito: é sobrescrito em _ready() com base em _starting_direction.
var _direction: float = -1.0
var _last_turn_ms: int = -100000
var _target_outside: bool = false
var _target_lost_elapsed: float = 0.0
# Posições do golpe atual (para reaplicar se ela virar no meio do ataque)
var _attack_layout: Dictionary = {}

var _chase_target: BaseCharacter = null
var _player_in_attack: BaseCharacter = null

var _is_chasing: bool = false
var _is_attacking_sequence: bool = false
var _is_dodging: bool = false
var _can_attack: bool = true

var _dodge_base_y: float = 0.0
var _dodge_elapsed: float = 0.0
var _ghost_timer: float = 0.0

var _is_staggered: bool = false
var _has_advanced_this_attack: bool = false
var _death_fade_started: bool = false

var _is_alive: bool = true

var _ground_ray_default_target: Vector2 = Vector2.ZERO
var _wall_ray_default_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Define a direção inicial de acordo com a opção escolhida no Inspector.
	_direction = 1.0 if _starting_direction == StartingDirection.RIGHT else -1.0

	if _hurtbox_detection:
		_hurtbox_detection.add_to_group("enemy_hitbox")

	_chase_area.body_entered.connect(_on_chase_area_body_entered)
	_chase_area.body_exited.connect(_on_chase_area_body_exited)

	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_detection_area.body_exited.connect(_on_detection_area_body_exited)

	_texture.animation_finished.connect(_on_texture_animation_finished)
	_texture.frame_changed.connect(_on_texture_frame_changed)

	_dodge_timer.one_shot = true
	_dodge_timer.timeout.connect(_on_dodge_timer_timeout)

	_dodge_cooldown_timer.one_shot = true
	_dodge_cooldown_timer.timeout.connect(_on_dodge_cooldown_timer_timeout)

	if _ground_ray:
		_ground_ray_default_target = _ground_ray.target_position
	if _wall_ray:
		_wall_ray_default_target = _wall_ray.target_position

	_apply_facing()
	_reset_collisions_to_default()
	_texture.play("Idle")


func _physics_process(delta: float) -> void:
	if _uses_gravity and not is_on_floor():
		velocity.y += _gravity * delta

	if _is_alive == false:
		move_and_slide()
		return

	if _is_staggered:
		move_and_slide()
		return

	if _is_dodging:
			_dodge_elapsed += delta
			var t: float = clamp(_dodge_elapsed / _dodge_duration, 0.0, 1.0)
			var height_offset: float = sin(t * PI) * _dodge_vertical_boost

			velocity.y = 0
			move_and_slide()
			global_position.y = _dodge_base_y - height_offset

			_ghost_timer += delta
			if _ghost_timer >= _ghost_interval:
				_spawn_ghost_trail()
				_ghost_timer = 0.0
			return

	if is_instance_valid(_player_in_attack) and not _is_attacking_sequence:
		velocity.x = 0
		_start_attack()
		if not _is_attacking_sequence:
			_update_movement_animation()
		move_and_slide()
		return

	if _is_attacking_sequence:
		velocity.x = 0
		_update_facing_during_attack()
		move_and_slide()
		return

	_update_lose_target(delta)

	if _is_chasing and is_instance_valid(_chase_target):
		# Sempre virada para a Tola; bloqueada (beira/parede) ou em cima dela: para
		_update_facing_to_target()
		var _dx: float = absf(_chase_target.global_position.x - global_position.x)
		if _is_path_blocked() or _dx <= _turn_deadzone:
			velocity.x = 0
		else:
			velocity.x = _direction * _move_speed
	else:
		velocity.x = 0

	move_and_slide()
	_update_movement_animation()


func _check_edge_and_wall_collision() -> bool:
	if _wall_ray and _wall_ray.is_colliding():
		_direction *= -1.0
		_apply_facing()
		return true

	if _ground_ray and not _ground_ray.is_colliding():
		_direction *= -1.0
		_apply_facing()
		return true

	return false


# Beira ou parede à frente (sem inverter a direção: isso é só pra patrulha)
func _is_path_blocked() -> bool:
	if _wall_ray and _wall_ray.is_colliding():
		return true
	if _ground_ray and not _ground_ray.is_colliding():
		return true
	return false


# Vira para o alvo só se ele estiver claramente do outro lado e fora do intervalo
# entre viradas. Retorna true se virou.
func _face_toward(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	var dx: float = target.global_position.x - global_position.x
	if absf(dx) <= _turn_deadzone:
		return false
	var new_dir: float = 1.0 if dx > 0.0 else -1.0
	if new_dir == _direction:
		return false
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_turn_ms < int(_turn_cooldown * 1000.0):
		return false
	_direction = new_dir
	_last_turn_ms = now_ms
	_apply_facing()
	return true


# Alvo saiu da área de perseguição: continua por _lose_target_time antes de desistir
func _update_lose_target(delta: float) -> void:
	if not _target_outside or not _is_chasing:
		return
	_target_lost_elapsed += delta
	if _target_lost_elapsed >= _lose_target_time:
		_stop_chasing()


func _stop_chasing() -> void:
	if is_instance_valid(_chase_target) and _chase_target.has_signal("attack_started"):
		if _chase_target.attack_started.is_connected(_on_player_attack_started):
			_chase_target.attack_started.disconnect(_on_player_attack_started)
	_is_chasing = false
	_chase_target = null
	_target_outside = false
	_target_lost_elapsed = 0.0


func _update_facing_to_target() -> void:
	if not is_instance_valid(_chase_target):
		return

	_face_toward(_chase_target)

	if not _is_attacking_sequence and not _is_dodging:
		_reset_collisions_to_default()


# Durante Attack_1/Attack_2 ela acompanha a posição do player (pode virar).
# Durante Attack_3 a direção fica travada desde o início do golpe.
# (Os efeitos de cada frame — som, avanço, área — rodam só no frame_changed.
#  Antes eram chamados aqui a cada quadro e o som reiniciava sem parar.)
func _update_facing_during_attack() -> void:
	if _texture.animation != "Attack_3":
		var target: BaseCharacter = _player_in_attack if is_instance_valid(_player_in_attack) else _chase_target
		if _face_toward(target):
			_reapply_attack_layout()


func _apply_facing() -> void:
	_texture.flip_h = _direction > 0.0

	_chase_area.position = _mirrored_pos(CHASE_AREA_DEFAULT_POS)
	_blood_particles.position = _mirrored_pos(BLOOD_PARTICLES_POS)
	_blood_particles_2.position = _mirrored_pos(BLOOD_PARTICLES_2_POS)

	if _detection_collision:
		_detection_collision.position = _mirrored_pos(DETECTION_COLLISION_DEFAULT_POS)

	if _ground_ray:
		_ground_ray.position = _mirrored_pos(GROUND_RAY_DEFAULT_POS)
		_ground_ray.target_position = _mirrored_pos(_ground_ray_default_target)

	if _wall_ray:
		_wall_ray.position = _mirrored_pos(WALL_RAY_DEFAULT_POS)
		_wall_ray.target_position = _mirrored_pos(_wall_ray_default_target)


func _mirrored_pos(base: Vector2) -> Vector2:
	var mirror: float = -1.0 if _texture.flip_h else 1.0
	return Vector2(base.x * mirror, base.y)


func _mirrored_rot(base_deg: float) -> float:
	var mirror: float = -1.0 if _texture.flip_h else 1.0
	return base_deg * mirror


func _advance_during_attack(distance: float, duration: float = -1.0) -> void:
	var actual_duration: float = duration if duration > 0.0 else _attack_advance_duration
	var target_x: float = global_position.x + (_direction * distance)
	var tween := create_tween()
	tween.tween_property(self, "global_position:x", target_x, actual_duration)
	_spawn_ghost_trail_during_advance(actual_duration)


func _spawn_ghost_trail_during_advance(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration:
		_spawn_ghost_trail()
		await get_tree().create_timer(_ghost_interval).timeout
		elapsed += _ghost_interval


func _update_movement_animation() -> void:
	if _is_attacking_sequence or _is_dodging:
		return

	if absf(velocity.x) > 1.0:
		if _texture.animation != "Walk":
			_texture.play("Walk")
	else:
		if _texture.animation != "Idle":
			_texture.play("Idle")


# --- ATAQUE 1 e 2 ---
func _start_attack() -> void:
	if _is_attacking_sequence or _is_dodging or not _is_alive or not _can_attack or _is_staggered:
		return
	if not is_instance_valid(_player_in_attack):
		return

	_is_attacking_sequence = true
	_has_advanced_this_attack = false
	velocity.x = 0
	_reset_collisions_to_default()
	_texture.play("Attack_1")


func _on_texture_animation_finished() -> void:
	match _texture.animation:
		"Attack_1":
			_reset_collisions_to_default()
			_has_advanced_this_attack = false
			_texture.play("Attack_2")

		"Attack_2":
			_finish_combo()

		"Attack_3":
			_finish_combo()

		"Dash":
			pass

		"Dead":
			pass  # queue_free acontece via fade, disparado no frame 19


func _finish_combo() -> void:
	_is_attacking_sequence = false
	_reset_collisions_to_default()
	_texture.play("Idle")
	_can_attack = false
	_dodge_cooldown_timer.start(_combo_cooldown_duration)


func _on_texture_frame_changed() -> void:
	match _texture.animation:
		"Attack_1":
			_handle_attack_1_frame(_texture.frame)
		"Attack_2":
			_handle_attack_2_frame(_texture.frame)
		"Attack_3":
			_handle_attack_3_frame(_texture.frame)
		"Dead":
			_handle_dead_frame(_texture.frame)


func _handle_attack_1_frame(frame: int) -> void:
	match frame:
		8:
			if _voice_attack_audio:
				_voice_attack_audio.play()
		10:
			if _attack_audio:
				_attack_audio.play()
			if not _has_advanced_this_attack:
				_advance_during_attack(ATTACK_ADVANCE_DISTANCE)
				_has_advanced_this_attack = true
			_set_attack_layout(ATTACK_1_BODY_POS, ATTACK_1_HURTBOX_POS, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)
		11, 12:
			pass


func _handle_attack_2_frame(frame: int) -> void:
	match frame:
		6:
			if _voice_attack_audio:
				_voice_attack_audio.play()
		9:
			if _attack_audio:
				_attack_audio.play()
			if not _has_advanced_this_attack:
				_advance_during_attack(ATTACK_ADVANCE_DISTANCE)
				_has_advanced_this_attack = true
			_set_attack_layout(ATTACK_2_BODY_POS, ATTACK_2_HURTBOX_POS, ATTACK_2_AREA_POS, ATTACK_2_AREA_ROT)
		10:
			pass
		11:
			_reset_collisions_to_default()


func _handle_attack_3_frame(frame: int) -> void:
	match frame:
		4:
			if _voice_attack_audio:
				_voice_attack_audio.play()
		8:
			if _attack_3_audio:
				_attack_3_audio.play()
			if not _has_advanced_this_attack:
				_advance_during_attack(ATTACK_3_ADVANCE_DISTANCE, _attack_3_advance_duration)
				_has_advanced_this_attack = true
			_set_attack_layout(ATTACK_3_BODY_POS, ATTACK_3_HURTBOX_POS, ATTACK_3_AREA_POS, ATTACK_AREA_DEFAULT_ROT)
		9, 10:
			pass
		11:
			_reset_collisions_to_default()


func _set_attack_area(active: bool, pos: Vector2 = ATTACK_AREA_DEFAULT_POS, rot_deg: float = ATTACK_AREA_DEFAULT_ROT) -> void:
	_attack_collision.set_deferred("disabled", not active)
	_attack_collision.position = _mirrored_pos(pos)
	_attack_collision.rotation_degrees = _mirrored_rot(rot_deg)


func _handle_dead_frame(frame: int) -> void:
	match frame:
		10:
			if _blood_particles_2:
				_blood_particles_2.visible = true
				_blood_particles_2.restart()
				_blood_particles_2.emitting = true
		19:
			_start_death_fade_sequence()


func _start_death_fade_sequence() -> void:
	if _death_fade_started:
		return
	_death_fade_started = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_texture, "modulate:a", 0.0, _death_fade_duration)
	if _blood_particles_2:
		tween.tween_property(_blood_particles_2, "modulate:a", 0.0, _death_fade_duration)

	await tween.finished
	queue_free()


func _set_attack_layout(body_pos: Vector2, hurt_pos: Vector2, area_pos: Vector2, area_rot: float) -> void:
	_attack_layout = {"body": body_pos, "hurt": hurt_pos, "area": area_pos, "rot": area_rot}
	_reapply_attack_layout()


func _reapply_attack_layout() -> void:
	if _attack_layout.is_empty():
		return
	_body_collision.position = _mirrored_pos(_attack_layout["body"])
	_hurtbox_collision.position = _mirrored_pos(_attack_layout["hurt"])
	_set_attack_area(true, _attack_layout["area"], _attack_layout["rot"])


func _reset_collisions_to_default() -> void:
	_attack_layout = {}
	_body_collision.position = _mirrored_pos(BODY_DEFAULT_POS)
	_hurtbox_collision.position = _mirrored_pos(HURTBOX_DEFAULT_POS)
	_set_attack_area(false, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)


# --- PERSEGUIÇÃO ---
func _on_chase_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_is_chasing = true
		_chase_target = body
		_target_outside = false
		_target_lost_elapsed = 0.0

		if body.has_signal("attack_started") and not body.attack_started.is_connected(_on_player_attack_started):
			body.attack_started.connect(_on_player_attack_started)


func _on_chase_area_body_exited(body: Node2D) -> void:
	# Não desiste na hora: conta _lose_target_time fora da área (ver _update_lose_target)
	if body == _chase_target:
		_target_outside = true
		_target_lost_elapsed = 0.0


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_in_attack = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == _player_in_attack:
		_player_in_attack = null


# --- ESQUIVA (DASH), 60% de chance ---
func _on_player_attack_started() -> void:
	if not _is_alive:
		return
	if _is_dodging or _is_attacking_sequence or _is_staggered:
		return

	if randf() > _dodge_chance:
		return

	_start_dodge()


func _start_dodge() -> void:
	_is_dodging = true
	_can_attack = false
	_is_attacking_sequence = false
	_reset_collisions_to_default()

	_dodge_base_y = global_position.y
	_dodge_elapsed = 0.0
	_ghost_timer = 0.0

	var _dodge_direction: float = -_direction
	velocity.x = _dodge_direction * _dodge_speed
	velocity.y = 0

	_texture.play("Dash")
	_dodge_timer.start(_dodge_duration)


func _on_dodge_timer_timeout() -> void:
	_is_dodging = false
	velocity.x = 0
	velocity.y = 0

	if not _is_alive or _is_staggered:
		return

	if is_instance_valid(_chase_target) and randf() < _attack_3_chance:
		_start_attack_3()
	else:
		_texture.play("Idle")
		_dodge_cooldown_timer.start(_attack_cooldown_duration)


func _on_dodge_cooldown_timer_timeout() -> void:
	_can_attack = true

	if not _is_alive or _is_staggered or _is_attacking_sequence or _is_dodging:
		return

	if is_instance_valid(_player_in_attack):
		_start_attack()


# --- ATAQUE 3 (direção travada no início) ---
func _start_attack_3() -> void:
	if not _is_alive or _is_staggered:
		return

	_is_attacking_sequence = true
	_has_advanced_this_attack = false
	velocity.x = 0

	if is_instance_valid(_chase_target):
		var _to_player: float = _chase_target.global_position.x - global_position.x
		if _to_player > 0:
			_direction = 1.0
		elif _to_player < 0:
			_direction = -1.0
		_apply_facing()

	_reset_collisions_to_default()
	_texture.play("Attack_3")


# --- PARRY / STAGGER ---
func apply_parry_effect() -> void:
	if not _is_alive or _is_staggered:
		return

	_is_staggered = true
	_can_attack = false
	_is_attacking_sequence = false
	_is_dodging = false

	if not _dodge_timer.is_stopped():
		_dodge_timer.stop()
	if not _dodge_cooldown_timer.is_stopped():
		_dodge_cooldown_timer.stop()

	velocity = Vector2.ZERO

	call_deferred("_apply_parry_visual_reset")


func _apply_parry_visual_reset() -> void:
	_reset_collisions_to_default()
	_texture.stop()

	var stagger_timer := get_tree().create_timer(_stagger_duration)
	stagger_timer.timeout.connect(_on_stagger_finished)


func _on_stagger_finished() -> void:
	_is_staggered = false
	_can_attack = true

	if _is_alive:
		_texture.play("Idle")


# --- HEALTH / KILL ---
func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		return
	_enemy_health -= _damage
	if _hit_audio:
		_hit_audio.play()
	if _blood_particles:
		_blood_particles.restart()
		_blood_particles.emitting = true
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
	_is_attacking_sequence = false
	_is_dodging = false
	_is_chasing = false

	if not _dodge_timer.is_stopped():
		_dodge_timer.stop()
	if not _dodge_cooldown_timer.is_stopped():
		_dodge_cooldown_timer.stop()


func _spawn_ghost_trail() -> void:
	if not _ghost_trail_scene:
		return

	var ghost = _ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(_texture)


func _kill() -> void:
	_texture.play("Dead")

	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)

	_is_alive = false
	_chase_target = null
	_player_in_attack = null

	_body_collision.set_deferred("disabled", true)
	_attack_collision.set_deferred("disabled", true)

	if _hurtbox_detection:
		_hurtbox_detection.set_deferred("monitoring", false)
		_hurtbox_detection.set_deferred("monitorable", false)

	if _detection_area:
		_detection_area.set_deferred("monitoring", false)
		_detection_area.set_deferred("monitorable", false)

	if _attack_area:
		_attack_area.set_deferred("monitoring", false)
		_attack_area.set_deferred("monitorable", false)

	if _chase_area:
		_chase_area.set_deferred("monitoring", false)
		_chase_area.set_deferred("monitorable", false)

	_drop_items()

	if _fade_fx and _enable_fade_fx:
			_fade_fx.visible = true
			_fade_fx.restart()
			_fade_fx.emitting = true

	if _dead_audio:
		_dead_audio.play()
	if _dead_scream_audio:
		_dead_scream_audio.play()


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
