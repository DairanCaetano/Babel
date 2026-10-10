extends CharacterBody2D
class_name Serpopardo

# =============================================
# VARIÁVEIS DE ESTADO
# =============================================

var _is_alive: bool = true
var _queued_to_die: bool = false
var _is_running_cycle: bool = false
var _is_facing_right: bool = false
var _attack_2_requested: bool = false
var _executing_attack_1: bool = false

var _player_in_range: BaseCharacter = null
var _player_in_attack_range: bool = false
var _attack_damage: int = 10
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# =============================================
# REFERÊNCIAS AOS NÓS
# =============================================

var _segments: Array = []

@export var _anim: AnimationPlayer
@export var _blood_particles: GPUParticles2D
@export var _collision: CollisionShape2D
@export var _detection_area: Area2D
@export var _hurtbox_body: Area2D
@export var _attack_area: Area2D
@export var _head_hurtbox: Area2D
@export var _head_damage_area: Area2D
@export var _atk2_fx_marker: Marker2D

# =============================================
# MULTIPLICADORES E POSIÇÕES
# =============================================

var _multipliers: Array = [
	1.0,   # Head
	0.02,  # Neck_1 — quase imóvel
	0.15,  # Neck_2
	0.35,  # Neck_3
	0.55,  # Neck_4
	0.75   # Neck_5
]

var _idle_phase_offsets: Array = [
	0.0,   # Head
	2.0,   # Neck_1
	1.6,   # Neck_2
	1.2,   # Neck_3
	0.8,   # Neck_4
	0.4    # Neck_5
]

var _idle_positions: Array = [
	Vector2(-59, -37),  # Head
	Vector2(-31,   0),  # Neck_1
	Vector2(-40,  -9),  # Neck_2
	Vector2(-39, -21),  # Neck_3
	Vector2(-39, -35),  # Neck_4
	Vector2(-42, -40)   # Neck_5
]

# --- ATTACK_ANTICIPATION ---
var _antic_kf1: Array = [
	Vector2(-60, -13),  # Head
	Vector2(-28,   6),  # Neck_1
	Vector2(-29,  -5),  # Neck_2
	Vector2(-26, -17),  # Neck_3
	Vector2(-32, -25),  # Neck_4
	Vector2(-45, -23),  # Neck_5
]
var _antic_kf2: Array = [
	Vector2(-48,  24),  # Head
	Vector2(-31,  17),  # Neck_1
	Vector2(-19,  13),  # Neck_2
	Vector2(-13,  23),  # Neck_3
	Vector2(-23,  28),  # Neck_4
	Vector2(-34,  29),  # Neck_5
]

# --- ATTACK disparo baixo ---
var _atk_low_kf1: Array = [
	Vector2( -81,  32),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -38,  26),  # Neck_2
	Vector2( -46,  31),  # Neck_3
	Vector2( -56,  34),  # Neck_4
	Vector2( -68,  34),  # Neck_5
]
var _atk_low_kf2: Array = [
	Vector2(-143,  32),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -47,  29),  # Neck_2
	Vector2( -72,  34),  # Neck_3
	Vector2( -97,  37),  # Neck_4
	Vector2(-119,  37),  # Neck_5
]
var _atk_low_kf3: Array = [
	Vector2( -67,  -2),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -40,  16),  # Neck_2
	Vector2( -44,   7),  # Neck_3
	Vector2( -43,  -3),  # Neck_4
	Vector2( -54,  -5),  # Neck_5
]

# --- RECUO entre disparo baixo e alto ---
var _atk_recoil: Array = [
	Vector2( -48,  11),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -35,  13),  # Neck_2
	Vector2( -26,   8),  # Neck_3
	Vector2( -28,   1),  # Neck_4
	Vector2( -40,   4),  # Neck_5
]

# --- ATTACK disparo alto ---
var _atk_high_kf1: Array = [
	Vector2(-143,  -7),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -21,  -1),  # Neck_2
	Vector2( -50,  -2),  # Neck_3
	Vector2( -79,  -4),  # Neck_4
	Vector2(-107,  -5),  # Neck_5
]
var _atk_high_kf2: Array = [
	Vector2( -67,  -2),  # Head
	Vector2( -31,  17),  # Neck_1
	Vector2( -40,  16),  # Neck_2
	Vector2( -44,   7),  # Neck_3
	Vector2( -43,  -3),  # Neck_4
	Vector2( -54,  -5),  # Neck_5
]

# --- ATTACK_2 ANTICIPATION ---
var _atk2_antic_start: Array = [
	Vector2(-22, -52),  # Head
	Vector2(-27,   0),  # Neck_1
	Vector2(-21, -15),  # Neck_2
	Vector2(-12, -30),  # Neck_3
	Vector2( -6, -42),  # Neck_4
	Vector2( -9, -51),  # Neck_5
]
var _atk2_antic_kf1: Array = [
	Vector2(-21, -38),  # Head
	Vector2(-27,   0),  # Neck_1
	Vector2(-29, -10),  # Neck_2
	Vector2(-16, -18),  # Neck_3
	Vector2( -2, -27),  # Neck_4
	Vector2(  7, -36),  # Neck_5
]

# --- ATTACK_2 strike keyframes ---
var _atk2_strike_kf1: Array = [
	Vector2(-56, -50),  # Head
	Vector2(-27,   0),  # Neck_1
	Vector2(-29, -10),  # Neck_2
	Vector2(-31, -25),  # Neck_3
	Vector2(-35, -41),  # Neck_4
	Vector2(-43, -49),  # Neck_5
]
var _atk2_strike_kf2: Array = [
	Vector2(-60,  -4),  # Head
	Vector2(-27,   0),  # Neck_1
	Vector2(-29, -10),  # Neck_2
	Vector2(-31, -25),  # Neck_3
	Vector2(-46, -37),  # Neck_4
	Vector2(-54, -22),  # Neck_5
]
var _atk2_strike_kf3: Array = [
	Vector2(-66,  37),  # Head
	Vector2(-33,  11),  # Neck_1
	Vector2(-43,  -5),  # Neck_2
	Vector2(-61,  -8),  # Neck_3
	Vector2(-56,   7),  # Neck_4
	Vector2(-61,  22),  # Neck_5
]
var _atk2_strike_kf4: Array = [
	Vector2(-66,  37),  # Head
	Vector2(-33,  11),  # Neck_1
	Vector2(-43,  -5),  # Neck_2
	Vector2(-61,  -8),  # Neck_3
	Vector2(-73,   7),  # Neck_4
	Vector2(-66,  22),  # Neck_5
]

# =============================================
# EXPORTS
# =============================================

@export_category("Stats")
@export var _enemy_health: int = 40
@export var _move_speed: float = 50.0
@export var _knockback_speed: float = 256.0

@export_category("Serpopardo Audio")
@export var _attack_start_audio: AudioStreamPlayer
@export var _attack1_audio: AudioStreamPlayer
@export var _attack2_anticipation_audio: AudioStreamPlayer
@export var _attack2_audio: AudioStreamPlayer
@export var _hit_audio: AudioStreamPlayer
@export var _dead_audio: AudioStreamPlayer

var _knockback_timer: Timer
var _neck_idle_time: float = 0.0

# =============================================
# READY
# =============================================

func _ready() -> void:
	add_to_group("enemies")
	process_mode = Node.PROCESS_MODE_PAUSABLE

	print("🐆 === SERPOPARDO INICIANDO ===")
	print("🐆 Posição global: ", global_position)

	_segments = [
		$Head,
		$Neck_1,
		$Neck_2,
		$Neck_3,
		$Neck_4,
		$Neck_5
	]

	print("🐆 Segmentos: ", _segments.size(), " | _anim: ", _anim)

	_knockback_timer = Timer.new()
	_knockback_timer.one_shot = true
	add_child(_knockback_timer)

	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_detection_area.body_exited.connect(_on_detection_area_body_exited)
	_hurtbox_body.body_entered.connect(_on_hurtbox_body_body_entered)
	
	# ✅ HURTBOXES NO PADRÃO DO JOGO: as armas do player procuram o grupo
	# "enemy_hitbox" (camada 4) e aplicam o dano já escalado (força, fogo, itens).
	# A cabeça é filha do sprite Head → a meta aponta o dano para o Serpopardo.
	_hurtbox_body.add_to_group("enemy_hitbox")

	if _attack_area:
		_attack_area.body_entered.connect(_on_attack_area_body_entered)
		_attack_area.body_exited.connect(_on_attack_area_body_exited)

	if _head_hurtbox:
		_head_hurtbox.add_to_group("enemy_hitbox")
		_head_hurtbox.set_meta("damage_target", self)

	# (a cena já conecta body_entered/exited da DamageArea — evitar conexão dupla)
	if _head_damage_area and not _head_damage_area.body_entered.is_connected(_on_damage_area_body_entered):
		_head_damage_area.body_entered.connect(_on_damage_area_body_entered)

	for i in range(_segments.size()):
		_segments[i].position = _idle_positions[i]

	_anim.play("Idle")


# =============================================
# PROCESS
# =============================================

func _process(delta: float) -> void:
	if _queued_to_die or not _is_alive:
		return

	if not _is_running_cycle:
		_neck_idle_time += delta
		_animate_neck_idle(_neck_idle_time)

	if is_instance_valid(_player_in_range) and not _is_running_cycle:
		_is_running_cycle = true
		_run_combat_cycle()


# =============================================
# PHYSICS PROCESS
# =============================================

func _physics_process(delta: float) -> void:
	if _queued_to_die:
		return

	if not is_on_floor():
		velocity.y += _gravity * delta

	move_and_slide()


# =============================================
# OSCILAÇÃO IDLE
# =============================================

func _animate_neck_idle(time: float) -> void:
	for i in range(_segments.size()):
		var phase: float = _idle_phase_offsets[i]
		var amplitude: float = 4.0 * _multipliers[i]
		var freq: float = 1.8
		var offset_y: float = sin(time * freq + phase) * amplitude
		var base: Vector2 = _idle_positions[i]
		_segments[i].position = Vector2(base.x, base.y + offset_y)


# =============================================
# CICLO PRINCIPAL DE COMBATE
# =============================================

func _run_combat_cycle() -> void:
	while is_instance_valid(_player_in_range) and _is_alive and not _queued_to_die:

		await _check_and_turn()

		# Verifica se Ataque 2 foi solicitado antes de andar
		if _attack_2_requested:
			_attack_2_requested = false
			await _execute_attack_2()
			_anim.play("Idle")
			await get_tree().create_timer(2.0).timeout
			continue

		# Anda para frente
		_walk_forward()
		await get_tree().create_timer(0.5).timeout
		velocity.x = 0.0

		# Ataque 1
		_executing_attack_1 = true
		await _execute_attack_1()
		_executing_attack_1 = false

		if not is_instance_valid(_player_in_range) or not _is_alive:
			break

		_anim.play("Idle")
		await get_tree().create_timer(2.0).timeout

		# Se Ataque 2 foi solicitado durante o Ataque 1, executa agora
		if _attack_2_requested:
			_attack_2_requested = false
			await _check_and_turn()
			await _execute_attack_2()
			_anim.play("Idle")
			await get_tree().create_timer(2.0).timeout
			continue

		await _check_and_turn()

		# Captura estado da AttackArea ANTES de andar para trás
		var should_do_attack_2: bool = _player_in_attack_range
		if not should_do_attack_2 and _attack_area and is_instance_valid(_player_in_range):
			for b in _attack_area.get_overlapping_bodies():
				if b is BaseCharacter:
					should_do_attack_2 = true
					break

		# Anda para trás
		_walk_back()
		await get_tree().create_timer(0.5).timeout
		velocity.x = 0.0

		if should_do_attack_2 or _attack_2_requested:
			_attack_2_requested = false
			await _execute_attack_2()
		else:
			_anim.play("Idle")
			_return_neck_to_idle()

		_anim.play("Idle")
		await get_tree().create_timer(2.0).timeout

	_is_running_cycle = false
	_executing_attack_1 = false
	velocity.x = 0.0
	_anim.play("Idle")
	_return_neck_to_idle()


# =============================================
# TURN
# =============================================

func _check_and_turn() -> void:
	if not is_instance_valid(_player_in_range):
		return

	var player_is_right: bool = _player_in_range.global_position.x > global_position.x

	if player_is_right == _is_facing_right:
		return

	velocity.x = 0.0
	_is_facing_right = player_is_right
	_apply_flip()

	_anim.play("Turn")
	await _anim.animation_finished


func _apply_flip() -> void:
	for seg in _segments:
		if seg:
			seg.flip_h = _is_facing_right


# =============================================
# MOVIMENTO
# =============================================

func _walk_forward() -> void:
	_anim.play("Walk")
	velocity.x = (_move_speed if _is_facing_right else -_move_speed)


func _walk_back() -> void:
	_anim.play("Walk_Back")
	velocity.x = (-_move_speed if _is_facing_right else _move_speed)


# =============================================
# ATAQUE 1
# =============================================

func _execute_attack_1() -> void:
	if not _is_alive or _queued_to_die:
		return

	if _attack_start_audio:
		_attack_start_audio.play()

	_anim.play("Attack_Anticipation")
	_move_to_keyframe(_antic_kf1, 0.15)
	await get_tree().create_timer(0.2).timeout
	_move_to_keyframe(_antic_kf2, 0.15)
	await get_tree().create_timer(0.6).timeout

	# Disparo baixo
	if _attack1_audio:
		_attack1_audio.play()
	_anim.play("Attack")
	_move_to_keyframe(_atk_low_kf1, 0.5)
	await get_tree().create_timer(0.4).timeout
	_move_to_keyframe(_atk_low_kf2, 0.3)
	await get_tree().create_timer(0.4).timeout
	_move_to_keyframe(_atk_low_kf3, 0.3)
	await get_tree().create_timer(0.8).timeout

	# Recuo
	_move_to_keyframe(_atk_recoil, 0.3)
	await get_tree().create_timer(0.4).timeout

	# Disparo alto
	if _attack1_audio:
		_attack1_audio.play()
	_anim.play("Attack")
	_move_to_keyframe(_atk_high_kf1, 0.5)
	await get_tree().create_timer(0.4).timeout
	_move_to_keyframe(_atk_high_kf2, 0.3)
	await get_tree().create_timer(0.6).timeout

	_return_neck_to_idle()


# =============================================
# ATAQUE 2
# =============================================

func _execute_attack_2() -> void:
	if not _is_alive or _queued_to_die:
		return

	if _attack_start_audio:
		_attack_start_audio.play()

	# Antecipação — parte do idle suavemente
	if _attack2_anticipation_audio:
		_attack2_anticipation_audio.play()
	_anim.play("Attack_2_Anticipation")
	_move_to_keyframe(_atk2_antic_start, 0.4)
	await get_tree().create_timer(0.4).timeout
	_move_to_keyframe(_atk2_antic_kf1, 0.6)
	await _anim.animation_finished

	# Strike
	if _attack2_audio:
		_attack2_audio.play()

	_anim.play("Attack_2")

	# Instancia FX após 0.3s sem bloquear o fluxo
	get_tree().create_timer(0.3).timeout.connect(func():
		var fx_scene = load("res://Scenes/FX/dust_explosion_fx.tscn")
		if fx_scene:
			var fx = fx_scene.instantiate()
			get_tree().current_scene.add_child(fx)
			fx.global_position = _atk2_fx_marker.global_position if _atk2_fx_marker else global_position
	)
	_move_to_keyframe(_atk2_strike_kf1, 0.15)
	await get_tree().create_timer(0.1).timeout
	_move_to_keyframe(_atk2_strike_kf2, 0.1)
	await get_tree().create_timer(0.1).timeout
	_move_to_keyframe(_atk2_strike_kf3, 0.1)
	await get_tree().create_timer(0.2).timeout
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.shake_camera(1.5, 0.3)
	_move_to_keyframe(_atk2_strike_kf4, 0.1)
	await _anim.animation_finished

	# Finalização — retorna ao idle começando pelo Neck_1
	_anim.play("Attack_2_End")
	_return_neck_to_idle_from_neck1()
	await _anim.animation_finished


# =============================================
# HELPER — cascata Head → Neck_5 → ... → Neck_1
# =============================================

func _move_to_keyframe(positions: Array, duration: float) -> void:
	var tw0 := get_tree().create_tween()
	tw0.tween_property(_segments[0], "position", positions[0], duration).set_ease(Tween.EASE_IN_OUT)

	for i in range(_segments.size() - 1, 0, -1):
		await get_tree().create_timer(0.05).timeout
		var tw := get_tree().create_tween()
		tw.tween_property(_segments[i], "position", positions[i], duration).set_ease(Tween.EASE_IN_OUT)


func _return_neck_to_idle() -> void:
	var tw0 := get_tree().create_tween()
	tw0.tween_property(_segments[0], "position", _idle_positions[0], 0.5).set_ease(Tween.EASE_IN_OUT)

	for i in range(_segments.size() - 1, 0, -1):
		await get_tree().create_timer(0.05).timeout
		var tw := get_tree().create_tween()
		tw.tween_property(_segments[i], "position", _idle_positions[i], 0.5).set_ease(Tween.EASE_IN_OUT)


# Move segmentos em cascata reversa: Neck_1 → Neck_2 → ... → Neck_5 → Head
func _move_to_keyframe_reverse(positions: Array, duration: float) -> void:
	var tw1 := get_tree().create_tween()
	tw1.tween_property(_segments[1], "position", positions[1], duration).set_ease(Tween.EASE_IN_OUT)
	for i in range(2, _segments.size()):
		await get_tree().create_timer(0.05).timeout
		var tw := get_tree().create_tween()
		tw.tween_property(_segments[i], "position", positions[i], duration).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.05).timeout
	var tw0 := get_tree().create_tween()
	tw0.tween_property(_segments[0], "position", positions[0], duration).set_ease(Tween.EASE_IN_OUT)


# Retorno ao idle começando pelo Neck_1 (mais próximo do corpo)
func _return_neck_to_idle_from_neck1() -> void:
	# Neck_1 primeiro, depois Neck_2 → Neck_5 → Head
	var tw1 := get_tree().create_tween()
	tw1.tween_property(_segments[1], "position", _idle_positions[1], 0.5).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.05).timeout
	for i in range(2, _segments.size()):
		await get_tree().create_timer(0.05).timeout
		var tw := get_tree().create_tween()
		tw.tween_property(_segments[i], "position", _idle_positions[i], 0.5).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.05).timeout
	var tw0 := get_tree().create_tween()
	tw0.tween_property(_segments[0], "position", _idle_positions[0], 0.5).set_ease(Tween.EASE_IN_OUT)


func _get_adjusted(base_pos: Vector2) -> Vector2:
	return base_pos


# =============================================
# DANO E MORTE
# =============================================

func update_health(_damage: int, _entity) -> void:
	if not _is_alive or _queued_to_die:
		return

	_enemy_health -= _damage

	if _enemy_health <= 0:
		_die()
		return

	if _hit_audio:
		_hit_audio.play()

	var tween := get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.shake_camera(1, 0.1)

	_blood_particles.restart()
	_blood_particles.emitting = true


func _die() -> void:
	if _queued_to_die:
		return

	_queued_to_die = true
	_is_alive = false
	_is_running_cycle = false
	_executing_attack_1 = false
	velocity = Vector2.ZERO

	for tw in get_tree().get_processed_tweens():
		if tw.is_valid():
			tw.kill()

	_collision.set_deferred("disabled", true)
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)

	if _hurtbox_body:
		_hurtbox_body.set_deferred("monitoring", false)
		_hurtbox_body.set_deferred("monitorable", false)

	if _detection_area:
		_detection_area.set_deferred("monitoring", false)
		_detection_area.set_deferred("monitorable", false)

	if _head_hurtbox:
		_head_hurtbox.set_deferred("monitoring", false)
		_head_hurtbox.set_deferred("monitorable", false)

	if _head_damage_area:
		_head_damage_area.set_deferred("monitoring", false)
		_head_damage_area.set_deferred("monitorable", false)

	if _attack_area:
		_attack_area.set_deferred("monitoring", false)
		_attack_area.set_deferred("monitorable", false)

	_blood_particles.visible = true
	_blood_particles.restart()
	_blood_particles.emitting = true

	_drop_items()

	if _dead_audio:
		_dead_audio.play()

	_anim.play("Dead")

	# Posições iniciais do Dead
	var dead_pos_a: Array = [
		Vector2(-73, -44),  # Head
		Vector2(-33,  11),  # Neck_1
		Vector2(-40,   6),  # Neck_2 — proporcional
		Vector2(-50,  -5),  # Neck_3
		Vector2(-58, -16),  # Neck_4
		Vector2(-65, -27),  # Neck_5
	]
	var dead_pos_b: Array = [
		Vector2( -5, -46),  # Head
		Vector2(-33,  11),  # Neck_1 — quase imóvel
		Vector2(-25,   4),  # Neck_2
		Vector2(-10,  -5),  # Neck_3
		Vector2(  5, -14),  # Neck_4
		Vector2( 19, -23),  # Neck_5
	]

	# Move para posição inicial do Dead
	_move_to_keyframe(dead_pos_a, 0.3)
	await get_tree().create_timer(0.5).timeout

	# Balanceio entre pos_a e pos_b por 2 segundos
	var elapsed: float = 0.0
	var on_pos_a: bool = false
	while elapsed < 2.0 and not is_queued_for_deletion():
		if on_pos_a:
			_move_to_keyframe_reverse(dead_pos_a, 0.5)
		else:
			_move_to_keyframe_reverse(dead_pos_b, 0.5)
		on_pos_a = not on_pos_a
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5

	# Fade out opacidade + escala X → 0 em 1 segundo
	var fade_tween := get_tree().create_tween()
	fade_tween.set_parallel(true)

	var all_nodes: Array = _segments.duplicate()
	if has_node("Body"):
		all_nodes.append($Body)

	for node in all_nodes:
		if node and node is CanvasItem:
			fade_tween.tween_property(node, "modulate:a", 0.0, 1.0)
			fade_tween.tween_property(node, "scale:x", 0.0, 1.0)

	await fade_tween.finished
	queue_free()


# =============================================
# SHADER BLINK
# =============================================

func _set_shader_blink_intensity(new_value: float) -> void:
	for seg in _segments:
		if not seg or not seg.material:
			continue
		if not seg.material.shader:
			continue
		seg.material.set_shader_parameter("blink_active", new_value > 0.0)
		seg.material.set_shader_parameter("blink_intensity", new_value)


# =============================================
# SINAIS — DETECÇÃO
# =============================================

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_in_range = body
		print("🐆 Player detectado!")


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_in_range = null
		print("🐆 Player saiu do range")


# AttackArea — dispara Ataque 2 com prioridade
func _on_attack_area_body_entered(body: Node2D) -> void:
	if not (body is BaseCharacter):
		return
	_player_in_attack_range = true
	print("🐆 Player entrou na AttackArea")

	# Só solicita Ataque 2 se o ciclo já está rodando e não está no Ataque 1
	if _is_running_cycle and not _executing_attack_1:
		_attack_2_requested = true
		print("🐆 Ataque 2 solicitado!")


func _on_attack_area_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_in_attack_range = false
		print("🐆 Player saiu da AttackArea")


# =============================================
# SINAIS — HURTBOX DO CORPO
# =============================================

func _on_hurtbox_body_area_entered(area: Area2D) -> void:
	if _queued_to_die or not _is_alive:
		return
	if area.get_parent() == self or area.owner == self:
		return
	if area.is_in_group("player_attack"):
		var damage = area.get("damage")
		if damage == null:
			damage = 10
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


func _on_hurtbox_body_body_entered(body: Node2D) -> void:
	if _queued_to_die or not _is_alive:
		return
	if body is BaseCharacter and body.is_in_group("player"):
		body.update_health(_attack_damage, self)


# =============================================
# SINAIS — CABEÇA
# =============================================

func _on_head_hurtbox_area_entered(area: Area2D) -> void:
	if _queued_to_die or not _is_alive:
		return
	if area.get_parent() == self or area.owner == self:
		return
	if area.is_in_group("player_attack"):
		var damage = area.get("damage")
		if damage == null:
			damage = 10
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


func _on_damage_area_body_entered(body: Node2D) -> void:
	if _queued_to_die or not _is_alive:
		return
	if body is BaseCharacter and body.is_in_group("player"):
		body.update_health(_attack_damage, self)


# =============================================
# DROP DE ITENS
# =============================================

func _drop_items() -> void:
	var drop_data := _get_drop_items()
	for item_key in drop_data:
		var item = drop_data[item_key]
		if randf() < item["spawn_probability"]:
			var amount := randi_range(item["amount_to_drop"][0], item["amount_to_drop"][1])
			for i in range(amount):
				var col = load("res://Scenes/Collectables/collectable_item.tscn").instantiate()
				col.item_texture = item["path"]
				col.item_data = {
					"name": item["name"],
					"type": item["type"],
					"description": item["description"],
					"value": item["value"],
					"amount": 1
				}
				col.global_position = global_position
				get_tree().current_scene.call_deferred("add_child", col)


func _get_drop_items() -> Dictionary:
	return {
		"small_shards": {
			"name": "Small Shards",
			"path": "res://sprites/Items/small_fragment.png",
			"type": "resource",
			"description": "A small shard, sells for money",
			"value": 1,
			"spawn_probability": 0.80,
			"amount_to_drop": [3, 7]
		},
		"medium_shards": {
			"name": "Medium Shards",
			"path": "res://sprites/Items/medium_fragment.png",
			"type": "resource",
			"description": "A shard, sells for money",
			"value": 10,
			"spawn_probability": 0.20,
			"amount_to_drop": [1, 2]
		}
	}
