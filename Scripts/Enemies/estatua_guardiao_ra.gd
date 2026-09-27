extends CharacterBody2D
class_name EstatuaGuardiaoRa

# --- Posições padrão (estado inicial: flip_h = false / _direction = -1) ---
const BODY_DEFAULT_POS: Vector2 = Vector2(5, 16.5)
const HURTBOX_DEFAULT_POS: Vector2 = Vector2(5, 13)
const ATTACK_AREA_DEFAULT_POS: Vector2 = Vector2(-28, 21)
const ATTACK_AREA_DEFAULT_ROT: float = 0.0

# Posição/rotação do hitbox especificamente durante o dash do Ataque 2
const ATTACK_2_AREA_POS: Vector2 = Vector2(-6, 3)
const ATTACK_2_AREA_ROT: float = 90.0
const DETECTION_AREA_DEFAULT_POS: Vector2 = Vector2(-26.5, 28.5)
const SPECIAL_DETECTION_AREA_DEFAULT_POS: Vector2 = Vector2(-162, 23.5)
const CHASE_AREA_DEFAULT_POS: Vector2 = Vector2(-12.5, 19)

# Posição do Marker2D onde o projétil especial é instanciado (estado padrão, sem flip).
const SPECIAL_ATTACK_MARKER_DEFAULT_POS: Vector2 = Vector2(-73, 53)

# Cena do projétil instanciado ao final da animação de ataque especial.
const FIRE_PILLAR_SCENE: PackedScene = preload("res://Scenes/Projectile/projectile_fire_pillar.tscn")

# FX de impacto instanciado no frame 1 de qualquer ativação da AttackArea.
const ATTACK_FX_SCENE: PackedScene = preload("res://Scenes/FX/dust_explosion_fx.tscn")
const ATTACK_FX_MARKER_DEFAULT_POS: Vector2 = Vector2(-27, 54)

# --- Direção inicial (controlável no Inspector) ---
enum StartingDirection { LEFT, RIGHT }

@export_category("Direção Inicial")
@export var _starting_direction: StartingDirection = StartingDirection.LEFT

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _body_collision: CollisionShape2D                # node "Collision" (raiz)
@export var _detection_area: Area2D                          # node "DetectionArea"
@export var _attack_area: Area2D                              # node "AttackArea"
@export var _attack_area_collision: CollisionShape2D          # filho "Collision" da AttackArea — DEIXE A POSITION DELE ZERADA
@export var _special_detection_area: Area2D                   # node "SpecialDetectionArea"
@export var _chase_area: Area2D                                # node "ChaseArea"
@export var _hurtbox_area: Area2D                               # node "Hurtbox"
@export var _audio: AudioStreamPlayer                            # node "Audio"
@export var _special_attack_spawn_marker: Marker2D               # AINDA NÃO EXISTE — criar na cena
@export var _attack_fx_marker: Marker2D                           # AINDA NÃO EXISTE — criar na cena (novo Marker2D dedicado)

@export_category("Combate - Ataque 1 (Melee)")
@export var _attack_1_repeats: int = 2  # "pelo menos 2x" antes de partir pro Ataque 2

@export_category("Combate - Ataque 2 (Dash)")
@export var _dash_speed: float = 440.0  # 2x o valor original (220)
@export var _dash_vertical_boost: float = 0.0  # deixe 0 se não quiser arco vertical no dash
@export var _dash_duration: float = 0.35
@export var _ghost_trail_scene: PackedScene
@export var _ghost_interval: float = 0.03

@export_category("Combate - Ataque Especial")
@export var _special_attack_projectile_speed: float = 150.0

@export_category("Combate - Anti-Enrolação")
# Se o player ficar na ChaseArea sem entrar na DetectionArea por esse tempo,
# força um Ataque 2 (dash) pra fechar a distância — evita o player "trancar"
# o inimigo num ponto seguro fora do alcance do melee e dentro do alcance
# que bloqueia o especial.
@export var _chase_stall_duration: float = 0.5

@export_category("Cooldowns")
@export var _attack_cooldown_duration: float = 1.5
@export var _special_attack_cooldown_duration: float = 1.0

@export_category("Movimento")
@export var _uses_gravity: bool = false
@export var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Health System")
@export var _enemy_health: int = 10

@export_category("Sound")
@export var _hit_audio: AudioStreamPlayer
@export var _attack_audio: AudioStreamPlayer
@export var _special_attack_audio: AudioStreamPlayer
@export var _dead_audio: AudioStreamPlayer

var _direction: float = -1.0

var _chase_target: BaseCharacter = null
var _detection_target: BaseCharacter = null
var _special_detection_target: BaseCharacter = null

var _is_alive: bool = true
var _is_attacking_sequence: bool = false
var _can_attack: bool = true
var _can_special_attack: bool = true

var _attack_1_current_count: int = 0

var _is_dashing: bool = false
var _dash_base_y: float = 0.0
var _dash_elapsed: float = 0.0
var _ghost_timer: float = 0.0

# --- Turn (giro antes do flip) ---
var _is_turning: bool = false
var _pending_direction: float = 0.0
var _pending_turn_callback: Callable = Callable()

var _attack_cooldown_timer: Timer
var _special_attack_cooldown_timer: Timer
var _dash_timer: Timer
var _chase_stall_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_direction = 1.0 if _starting_direction == StartingDirection.RIGHT else -1.0

	if _hurtbox_area:
		_hurtbox_area.add_to_group("enemy_hitbox")

	# Os sinais das áreas (Detection/SpecialDetection/Chase/Hurtbox) e também
	# animation_finished/frame_changed da Texture já vêm conectados pelo
	# editor às funções _on_... abaixo. Por isso NÃO conectamos eles de novo
	# aqui via código (evita disparo duplicado).

	_attack_cooldown_timer = Timer.new()
	_attack_cooldown_timer.one_shot = true
	_attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	add_child(_attack_cooldown_timer)

	_special_attack_cooldown_timer = Timer.new()
	_special_attack_cooldown_timer.one_shot = true
	_special_attack_cooldown_timer.timeout.connect(_on_special_attack_cooldown_timer_timeout)
	add_child(_special_attack_cooldown_timer)

	_dash_timer = Timer.new()
	_dash_timer.one_shot = true
	_dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(_dash_timer)

	_chase_stall_timer = Timer.new()
	_chase_stall_timer.one_shot = true
	_chase_stall_timer.timeout.connect(_on_chase_stall_timer_timeout)
	add_child(_chase_stall_timer)

	_apply_facing()
	_set_attack_area(false, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)
	_texture.play("Idle")


func _physics_process(delta: float) -> void:
	if _uses_gravity and not is_on_floor():
		velocity.y += _gravity * delta

	if not _is_alive:
		move_and_slide()
		return

	if _is_dashing:
		_dash_elapsed += delta
		var t: float = clamp(_dash_elapsed / _dash_duration, 0.0, 1.0)
		var height_offset: float = sin(t * PI) * _dash_vertical_boost

		velocity.y = 0
		move_and_slide()
		global_position.y = _dash_base_y - height_offset

		_ghost_timer += delta
		if _ghost_timer >= _ghost_interval:
			_spawn_ghost_trail()
			_ghost_timer = 0.0
		return

	if _is_attacking_sequence:
		velocity.x = 0
		move_and_slide()
		return

	if _is_turning:
		velocity.x = 0
		move_and_slide()
		return

	# Parado (estátua não persegue) — sempre acompanha o lado do player pra
	# virar, mesmo fora de qualquer área de detecção (usa o grupo "player"
	# como referência quando nenhuma área está detectando).
	velocity.x = 0
	var facing_reference: BaseCharacter = _get_facing_reference()
	if facing_reference:
		_face_target_then(facing_reference, Callable())

	move_and_slide()


# Prioriza os alvos das áreas (mais confiáveis, já validados como
# BaseCharacter); cai pro grupo "player" quando nenhuma área detecta nada.
func _get_facing_reference() -> BaseCharacter:
	if is_instance_valid(_chase_target):
		return _chase_target
	if is_instance_valid(_detection_target):
		return _detection_target
	if is_instance_valid(_special_detection_target):
		return _special_detection_target

	var player := get_tree().get_first_node_in_group("player")
	if player is BaseCharacter:
		return player

	return null


# --- FACING / GIRO / ESPELHAMENTO ---
# Sempre que a direção precisa mudar, toca "Turn" primeiro e SÓ DEPOIS de
# ela terminar aplica o flip_h/espelhamento. Se já está olhando pro lado
# certo, chama on_ready() na hora (sem girar). on_ready pode ser vazio
# (Callable()) para o caso "idle" (só vira e volta pro Idle sozinho).
func _face_target_then(target: BaseCharacter, on_ready: Callable) -> void:
	if not is_instance_valid(target):
		if on_ready.is_valid():
			on_ready.call()
		return

	var _to_target: float = target.global_position.x - global_position.x
	var new_direction: float = _direction
	if _to_target > 0:
		new_direction = 1.0
	elif _to_target < 0:
		new_direction = -1.0

	if _is_turning:
		# Já está girando por outro motivo (ex: idle tracking) — não reinicia
		# a animação, mas garante que o callback mais recente seja o que
		# executa ao final do giro. Sem isso, uma chamada concorrente (ex:
		# começar a atacar no meio de um giro de idle) era descartada e
		# deixava _is_attacking_sequence travado em true pra sempre.
		_pending_turn_callback = on_ready
		return

	if new_direction == _direction:
		if on_ready.is_valid():
			on_ready.call()
		return

	_is_turning = true
	_pending_direction = new_direction
	_pending_turn_callback = on_ready
	_texture.play("Turn")  # TODO: confirmar se o nome real da animação é esse


func _apply_facing() -> void:
	_texture.flip_h = _direction > 0.0

	if _body_collision:
		_body_collision.position = _mirrored_pos(BODY_DEFAULT_POS)

	if _hurtbox_area:
		_hurtbox_area.position = _mirrored_pos(HURTBOX_DEFAULT_POS)

	if _detection_area:
		_detection_area.position = _mirrored_pos(DETECTION_AREA_DEFAULT_POS)

	if _special_detection_area:
		_special_detection_area.position = _mirrored_pos(SPECIAL_DETECTION_AREA_DEFAULT_POS)

	if _chase_area:
		_chase_area.position = _mirrored_pos(CHASE_AREA_DEFAULT_POS)

	if _special_attack_spawn_marker:
		_special_attack_spawn_marker.position = _mirrored_pos(SPECIAL_ATTACK_MARKER_DEFAULT_POS)

	if _attack_fx_marker:
		_attack_fx_marker.position = _mirrored_pos(ATTACK_FX_MARKER_DEFAULT_POS)


func _mirrored_pos(base: Vector2) -> Vector2:
	var mirror: float = -1.0 if _texture.flip_h else 1.0
	return Vector2(base.x * mirror, base.y)


func _mirrored_rot(base_deg: float) -> float:
	var mirror: float = -1.0 if _texture.flip_h else 1.0
	return base_deg * mirror


# --- DETECÇÃO (sinais já conectados pelo editor) ---
func _on_special_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_special_detection_target = body
		_try_start_special_attack()


func _on_special_detection_area_body_exited(body: Node2D) -> void:
	if body == _special_detection_target:
		_special_detection_target = null


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_detection_target = body
		_chase_stall_timer.stop()  # já entrou no melee, não precisa mais forçar dash
		_try_start_melee_combo()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == _detection_target:
		_detection_target = null
		_update_chase_stall_timer()


func _on_chase_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_chase_target = body
		_update_chase_stall_timer()


func _on_chase_area_body_exited(body: Node2D) -> void:
	if body == _chase_target:
		_chase_target = null
		_chase_stall_timer.stop()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Neste projeto o dano normalmente é aplicado de fora pra dentro,
	# chamando update_health() diretamente (mesmo padrão da Sacerdotisa),
	# então esse handler fica vazio por padrão. Se o seu sistema de arma
	# depender desse sinal específico, me avisa que eu preencho.
	pass


# Liga o timer de "enrolação" só quando faz sentido: player na ChaseArea,
# mas ainda fora da DetectionArea, e o inimigo livre pra agir.
func _update_chase_stall_timer() -> void:
	var should_wait: bool = is_instance_valid(_chase_target) \
		and not is_instance_valid(_detection_target) \
		and _is_alive and not _is_attacking_sequence

	if should_wait:
		if _chase_stall_timer.is_stopped():
			_chase_stall_timer.start(_chase_stall_duration)
	else:
		_chase_stall_timer.stop()


func _on_chase_stall_timer_timeout() -> void:
	if not _is_alive or _is_attacking_sequence:
		return
	if not is_instance_valid(_chase_target) or is_instance_valid(_detection_target):
		return

	# Mesmo com o player na ChaseArea, se ele ainda está no alcance do
	# especial, prioriza o especial em vez do dash forçado.
	if is_instance_valid(_special_detection_target) and _can_special_attack:
		_start_special_attack()
	elif _can_attack:
		_start_forced_dash_attack()


# --- COMBATE: ATAQUE 1 (MELEE, EM LOOP) + ATAQUE 2 (DASH) ---
func _try_start_melee_combo() -> void:
	if not _is_alive or _is_attacking_sequence or not _can_attack:
		return
	if not is_instance_valid(_detection_target):
		return
	_start_melee_combo()


func _start_melee_combo() -> void:
	_is_attacking_sequence = true
	_attack_1_current_count = 0
	_face_target_then(_detection_target, Callable(self, "_begin_attack_anticipation"))


func _begin_attack_anticipation() -> void:
	_texture.play("Attack_Anticipation")


# Disparado pelo _chase_stall_timer quando o player fica "enrolando" dentro
# da ChaseArea sem entrar na DetectionArea. Pula direto pro dash (Ataque 2).
func _start_forced_dash_attack() -> void:
	_is_attacking_sequence = true
	_face_target_then(_chase_target, Callable(self, "_begin_forced_dash_anticipation"))


func _begin_forced_dash_anticipation() -> void:
	_texture.play("Attack_2_anticipation")


# Reconfere a direção logo ANTES de cada ação seguinte começar (o player
# pode ter atravessado pro outro lado com o dash de invencibilidade durante
# a ação anterior). Usa _get_facing_reference() — a mesma prioridade do
# rastreamento idle — pra decidir se precisa de Turn antes de prosseguir.
func _face_reference_then(callback: Callable) -> void:
	var target: BaseCharacter = _get_facing_reference()
	if target:
		_face_target_then(target, callback)
	else:
		callback.call()


func _prepare_next_attack_1() -> void:
	_face_reference_then(Callable(self, "_begin_attack_anticipation"))


func _prepare_attack_2_anticipation() -> void:
	_face_reference_then(Callable(self, "_begin_attack_2_anticipation"))


func _begin_attack_2_anticipation() -> void:
	_texture.play("Attack_2_anticipation")


func _start_attack_2_dash() -> void:
	_texture.play("Attack_2")

	if _attack_audio:
		_attack_audio.play()

	_is_dashing = true
	_dash_base_y = global_position.y
	_dash_elapsed = 0.0
	_ghost_timer = 0.0

	velocity.x = _direction * _dash_speed
	velocity.y = 0

	_dash_timer.start(_dash_duration)


func _on_dash_timer_timeout() -> void:
	_is_dashing = false
	velocity = Vector2.ZERO
	_set_attack_area(false, ATTACK_2_AREA_POS, ATTACK_2_AREA_ROT)
	_finish_attack_sequence(false)


# --- COMBATE: ATAQUE ESPECIAL ---
func _try_start_special_attack() -> void:
	if not _is_alive or _is_attacking_sequence:
		return
	if not _special_attack_allowed():
		return
	_start_special_attack()


# O especial é um ataque de longo alcance — se o player já está perto o
# suficiente pra entrar na ChaseArea, não faz mais sentido disparar ele.
func _special_attack_allowed() -> bool:
	return is_instance_valid(_special_detection_target) and _can_special_attack and not is_instance_valid(_chase_target)


func _start_special_attack() -> void:
	_is_attacking_sequence = true
	_face_target_then(_special_detection_target, Callable(self, "_begin_special_attack_anim"))


func _begin_special_attack_anim() -> void:
	_texture.play("Attack_Special")

	if _special_attack_audio:
		_special_attack_audio.play()


func _spawn_special_attack_scene() -> void:
	if not _special_attack_spawn_marker:
		push_warning("⚠️ _special_attack_spawn_marker não foi atribuído no Inspector.")
		return

	var instance := FIRE_PILLAR_SCENE.instantiate()
	instance.global_position = _special_attack_spawn_marker.global_position
	get_tree().current_scene.call_deferred("add_child", instance)

	if instance.has_method("setup"):
		var fire_direction: Vector2 = Vector2(_direction, 0)
		instance.setup(fire_direction, _special_attack_projectile_speed, _texture.flip_h)


# --- TRANSIÇÕES DE ANIMAÇÃO ---
func _on_texture_animation_finished() -> void:
	match _texture.animation:
		"Turn":
			_direction = _pending_direction
			_apply_facing()
			_is_turning = false

			var callback: Callable = _pending_turn_callback
			_pending_turn_callback = Callable()

			if callback.is_valid():
				callback.call()
			else:
				_texture.play("Idle")

		"Attack_Anticipation":
			_texture.play("Attack")

		"Attack":
			_set_attack_area(false, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)
			_attack_1_current_count += 1
			_texture.play("Attack_Return")

		"Attack_Return":
			if _attack_1_current_count < _attack_1_repeats:
				_prepare_next_attack_1()
			else:
				_prepare_attack_2_anticipation()

		"Attack_2_anticipation":
			_start_attack_2_dash()

		"Attack_2":
			pass  # o fim do dash é controlado pelo _dash_timer, não pela animação

		"Attack_Special":
			_spawn_special_attack_scene()
			_texture.play("Attack_Special_Return")

		"Attack_Special_Return":
			_finish_attack_sequence(true)

		"Dead":
			_start_death_fade_sequence()


func _finish_attack_sequence(was_special: bool) -> void:
	_is_attacking_sequence = false
	_attack_1_current_count = 0
	_texture.play("Idle")

	if was_special:
		_can_special_attack = false
		_special_attack_cooldown_timer.start(_special_attack_cooldown_duration)
	else:
		_can_attack = false
		_attack_cooldown_timer.start(_attack_cooldown_duration)

	_update_chase_stall_timer()


func _on_attack_cooldown_timer_timeout() -> void:
	_can_attack = true
	if not _is_alive or _is_attacking_sequence:
		return

	if _special_attack_allowed():
		_start_special_attack()
	elif is_instance_valid(_detection_target):
		_start_melee_combo()
	else:
		_update_chase_stall_timer()


func _on_special_attack_cooldown_timer_timeout() -> void:
	_can_special_attack = true
	if not _is_alive or _is_attacking_sequence:
		return

	if _special_attack_allowed():
		_start_special_attack()
	elif is_instance_valid(_detection_target) and _can_attack:
		_start_melee_combo()
	else:
		_update_chase_stall_timer()


func _set_attack_area(active: bool, pos: Vector2 = ATTACK_AREA_DEFAULT_POS, rot_deg: float = ATTACK_AREA_DEFAULT_ROT) -> void:
	if not _attack_area_collision:
		return
	_attack_area_collision.set_deferred("disabled", not active)
	_attack_area_collision.position = _mirrored_pos(pos)
	_attack_area_collision.rotation_degrees = _mirrored_rot(rot_deg)


# --- ATIVAÇÃO DO HITBOX POR FRAME ---
func _on_texture_frame_changed() -> void:
	match _texture.animation:
		"Attack":
			_handle_attack_frame(_texture.frame)
		"Attack_2":
			_handle_attack_2_frame(_texture.frame)


func _handle_attack_frame(frame: int) -> void:
	match frame:
		1:
			_set_attack_area(true, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)
			_trigger_attack_fx()
		2:
			_set_attack_area(true, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)
		_:
			_set_attack_area(false, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)


func _handle_attack_2_frame(frame: int) -> void:
	match frame:
		1, 2, 3:
			_set_attack_area(true, ATTACK_2_AREA_POS, ATTACK_2_AREA_ROT)
		_:
			_set_attack_area(false, ATTACK_2_AREA_POS, ATTACK_2_AREA_ROT)


# Efeito de impacto + tremor de câmera, disparado no frame 1 do Ataque 1 (Attack).
func _trigger_attack_fx() -> void:
	if _attack_fx_marker:
		var fx = ATTACK_FX_SCENE.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = _attack_fx_marker.global_position

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1.5, 0.3)


func _spawn_ghost_trail() -> void:
	if not _ghost_trail_scene:
		return

	var ghost = _ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(_texture)


# --- HEALTH / KILL ---
func update_health(_damage: int, _entity) -> void:
	if not _is_alive:
		return

	_enemy_health -= _damage

	if _hit_audio:
		_hit_audio.play()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)

	var blink_tween := create_tween()
	blink_tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)

	if _enemy_health <= 0:
		HitStopManager.hit_stop_short()
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


# Segura 1s no último frame da animação "Dead", depois some o corpo aos
# poucos ao longo de 1s, e só então libera o node.
func _start_death_fade_sequence() -> void:
	await get_tree().create_timer(1.0).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(_texture, "modulate:a", 0.0, 1.0)
	await fade_tween.finished

	queue_free()


func _kill() -> void:
	_is_alive = false
	_is_attacking_sequence = false
	_is_dashing = false
	_is_turning = false

	_attack_cooldown_timer.stop()
	_special_attack_cooldown_timer.stop()
	_dash_timer.stop()
	_chase_stall_timer.stop()

	if _body_collision:
		_body_collision.set_deferred("disabled", true)
	_set_attack_area(false, ATTACK_AREA_DEFAULT_POS, ATTACK_AREA_DEFAULT_ROT)

	if _detection_area:
		_detection_area.set_deferred("monitoring", false)
		_detection_area.set_deferred("monitorable", false)

	if _special_detection_area:
		_special_detection_area.set_deferred("monitoring", false)
		_special_detection_area.set_deferred("monitorable", false)

	if _chase_area:
		_chase_area.set_deferred("monitoring", false)
		_chase_area.set_deferred("monitorable", false)

	if _hurtbox_area:
		_hurtbox_area.set_deferred("monitoring", false)
		_hurtbox_area.set_deferred("monitorable", false)

	if _dead_audio:
		_dead_audio.play()

	_texture.play("Dead")
