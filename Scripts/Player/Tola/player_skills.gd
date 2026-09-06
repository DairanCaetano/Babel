extends Node2D
class_name CharacterSkills

# ========== REFERÊNCIAS (EXPORTAR NO INSPECTOR) ==========
@export var _character: BaseCharacter
@export var _character_texture: CharacterTexture
@export var _stats: PlayerStats

# ========== ESTADOS DAS HABILIDADES ==========
var _has_dash_skill: bool = false      # Forward Dash (para frente)
var _has_hook_skill: bool = false      # Hook/Gancho
var _has_wall_jump_skill: bool = false # Wall Jump

# ========== VARIÁVEIS DE DASH ==========
var _is_rolling: bool = false
var _roll_direction: Vector2 = Vector2.ZERO
var _can_roll: bool = true
var _roll_speed: float = 200.0
var _roll_duration: float = 0.2
var _roll_cooldown: float = 0.5
var _saved_flip_h: bool = false
var _dash_cancel_frame_reached: bool = false
var _is_dash_jumping: bool = false
var _is_dash_jump_launched: bool = false
var _is_dash_jump_flip: bool = false
var _dash_jump_momentum_timer: float = 0.0
var _ghost_trail_timer: float = 0.0  # ✅ NOVO
const _DASH_JUMP_MOMENTUM_DURATION: float = 0.25

@export var ghost_trail_scene: PackedScene  # ✅ NOVO
@export var ghost_trail_interval: float = 0.03  # ✅ NOVO

# ========== VARIÁVEIS DE HOOK ==========
var _on_hook: bool = false
var _on_hook_dash: bool = false
var _collider = null

@export_category("Hook Variables")
@export var _hook_dash_speed_x: float = 300.0
@export var _hook_dash_speed_y: float = -150.0

# ========== VARIÁVEIS DE WALL JUMP ==========
var _is_wall_sliding: bool = false
var _is_wall_jumping: bool = false
var _can_wall_slide: bool = true
var _can_auto_wall_jump: bool = false  # ✅ NOVO: permite wall jump sem pressionar direção após o primeiro

# ========== VARIÁVEIS DE ENEMY STEP (MODIFICAR) ==========
var _has_enemy_step_skill: bool = false
var _can_enemy_step: bool = true
var _is_enemy_stepping: bool = false  # ✅ NOVA FLAG
var _enemy_step_force_x: float = 150.0   # ✅ Aumentei para 500
var _enemy_step_force_y: float = -250.0
var _enemy_step_cooldown: float = 0.5

# ========== VARIÁVEIS DE SPEED BOOST ==========
var _has_speed_boost_skill: bool = false

var _speed_boost_time: float = 0.0        # Contador de tempo se movendo
var _speed_boost_idle_time: float = 0.0   # Contador de tempo parado

const _SPEED_BOOST_RAMP_DURATION: float = 2.0   # Segundos para atingir velocidade máxima
const _SPEED_BOOST_IDLE_RESET: float = 0.5       # Segundos parado para zerar
const _SPEED_BOOST_MULTIPLIER: float = 1.667  # 120 * 1.667 ≈ 200

@onready var _enemy_step_cooldown_timer: Timer

@export_category("Wall Jump Variables")
@export var _wall_slide: float = 10.0
@export var _wall_x_force: float = 400.0
@export var _wall_y_force: float = -350.0
@export var _wall_jump_duration: float = 0.3
@export var _wall_slide_cooldown: float = 0.4

@export_category("Dash Variables")
@export var _dash_jump_cancel_force_x: float = 600.0   # Impulso horizontal
@export var _dash_jump_cancel_force_y: float = -500.0  # Altura do pulo

# ========== TIMERS ==========
@onready var _roll_timer: Timer
@onready var _roll_cooldown_timer: Timer
@onready var _hook_timer: Timer
@onready var _wall_jump_timer: Timer


# ========== GRAVITY ==========
var _gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	_setup_timers()
	
	

func _setup_timers() -> void:
	"""Configura todos os timers necessários"""
	
	# Roll Timer
	_roll_timer = Timer.new()
	_roll_timer.name = "RollTimer"
	_roll_timer.one_shot = true
	_roll_timer.wait_time = _roll_duration
	_roll_timer.timeout.connect(_on_roll_timer_timeout)
	add_child(_roll_timer)
	
	# Roll Cooldown Timer
	_roll_cooldown_timer = Timer.new()
	_roll_cooldown_timer.name = "RollCooldownTimer"
	_roll_cooldown_timer.one_shot = true
	_roll_cooldown_timer.wait_time = _roll_cooldown
	_roll_cooldown_timer.timeout.connect(_on_roll_cooldown_timeout)
	add_child(_roll_cooldown_timer)
	
	# Hook Timer
	_hook_timer = Timer.new()
	_hook_timer.name = "HookTimer"
	_hook_timer.one_shot = true
	_hook_timer.wait_time = 0.8
	_hook_timer.timeout.connect(_on_hook_timer_timeout)
	add_child(_hook_timer)
	
	# Wall Jump Timer
	_wall_jump_timer = Timer.new()
	_wall_jump_timer.name = "WallJumpTimer"
	_wall_jump_timer.one_shot = true
	_wall_jump_timer.wait_time = _wall_jump_duration
	_wall_jump_timer.timeout.connect(_on_wall_jump_timer_timeout)
	add_child(_wall_jump_timer)
	
	# ✅ NOVO: Wall Slide Cooldown Timer
	var _wall_slide_cooldown_timer = Timer.new()
	_wall_slide_cooldown_timer.name = "WallSlideCooldownTimer"
	_wall_slide_cooldown_timer.one_shot = true
	_wall_slide_cooldown_timer.wait_time = _wall_slide_cooldown
	_wall_slide_cooldown_timer.timeout.connect(_on_wall_slide_cooldown_timeout)
	add_child(_wall_slide_cooldown_timer)
	
		# Enemy Step Cooldown Timer
	_enemy_step_cooldown_timer = Timer.new()
	_enemy_step_cooldown_timer.name = "EnemyStepCooldownTimer"
	_enemy_step_cooldown_timer.one_shot = true
	_enemy_step_cooldown_timer.wait_time = _enemy_step_cooldown
	_enemy_step_cooldown_timer.timeout.connect(_on_enemy_step_cooldown_timeout)
	add_child(_enemy_step_cooldown_timer)

# ========== LÓGICA DE DASH ==========
func handle_dash_input() -> bool:
	"""Verifica e executa dash - retorna true se executou"""
	
	if not Input.is_action_just_pressed("dash"):
		return false
	
	if not _can_roll or not _character.is_on_floor():
		return false
	
	_character.set_collision_mask_value(4, false)
	_character.set_collision_mask_value(7, false)
	
	# ✅ FORWARD DASH - REQUER HABILIDADE (senão executa Back Dash)
	if _character.velocity.x != 0:
		if not _has_dash_skill:
			# ❌ SEM HABILIDADE: EXECUTAR BACK DASH AO INVÉS DE BLOQUEAR
			print("⚠️ Forward Dash não disponível - executando Back Dash")
			_execute_back_dash()
			return true
		
		# ✅ COM HABILIDADE: EXECUTAR FORWARD DASH
		_execute_forward_dash()
		return true
	
	# ✅ BACK DASH - SEMPRE DISPONÍVEL
	else:
		_execute_back_dash()
		return true

# ✅ NOVA FUNÇÃO: Separar lógica do Forward Dash
func _execute_forward_dash() -> void:
	_roll_direction = Vector2(sign(_character.velocity.x), 0)
	_character_texture.action_animation("Rolling")
	
	# ✅ SOM DE DASH PARA FRENTE
	if _character and _character._audio:
		_character._audio.play_roll()
	
	global.spawn_effect(
		"res://Scenes/FX/dash_effect.tscn", 
		Vector2(0, 0), _character.global_position, _character_texture.flip_h
	)
	
	_roll_timer.wait_time = 0.5
	_is_rolling = true
	_can_roll = false
	_roll_timer.start()

# ✅ NOVA FUNÇÃO: Separar lógica do Back Dash
func _execute_back_dash() -> void:
	_roll_direction = Vector2(-1 if _character_texture.facing_right else 1, 0)
	_saved_flip_h = _character_texture.flip_h
	_character_texture.action_animation("Back_Dash")
	_character.velocity.y = -100.0
	
	# ✅ SOM DE DASH PARA TRÁS
	if _character and _character._audio:
		_character._audio.play_dash()
	
	global.spawn_effect(
		"res://Scenes/FX/dash_effect.tscn", 
		Vector2(0, 0), _character.global_position, !_character_texture.flip_h
	)
	
	_roll_timer.wait_time = 0.2
	_is_rolling = true
	_can_roll = false
	_roll_timer.start()

func process_dash_movement(delta: float) -> bool:
	"""Processa movimento do dash - retorna true se está dashando"""
	
	if not _is_rolling:
		return false
	
	_character.velocity.x = _roll_direction.x * _roll_speed
	_character.velocity.y += _gravity * delta
	_character.move_and_slide()
	
	return true

func is_rolling() -> bool:
	"""Retorna se está executando dash"""
	return _is_rolling

func cancel_dash_with_jump() -> void:
	if not _is_rolling:
		return
	
	_roll_timer.stop()
	_is_rolling = false
	_dash_cancel_frame_reached = false
	_character.set_collision_mask_value(4, true)
	_character.set_collision_mask_value(7, true)
	
	_roll_cooldown_timer.wait_time = _roll_cooldown
	_roll_cooldown_timer.start()
	
	_character.velocity.x = _roll_direction.x * _dash_jump_cancel_force_x
	_character.velocity.y = _dash_jump_cancel_force_y
	
	# ✅ ATIVAR PROTEÇÃO DO MOMENTUM
	_is_dash_jumping = true
	_is_dash_jump_launched = false
	_dash_jump_momentum_timer = 2.0
	
	_is_dash_jump_flip = true
	_character_texture._is_on_action = false
	_character_texture.action_animation("FrontFlip")
	_character.set_physics_process(true)
	
	if _character._audio:
		_character._audio.play_jump()
	
	global.spawn_effect(
		"res://Scenes/FX/jump_effect.tscn",
		Vector2(0, 0),
		_character.global_position,
		_character_texture.flip_h
	)
	
	print("🚀 Dash-jump! vel.x=", _character.velocity.x, " vel.y=", _character.velocity.y)

func cancel_dash_with_attack() -> void:
	"""Cancela o dash e inicia ataque normal"""
	if not _is_rolling:
		return
	
	_is_rolling = false
	_roll_cooldown_timer.start()
	_character.set_collision_mask_value(4, true)
	_character.set_collision_mask_value(7, true)
	_character.set_physics_process(true)
	
	# ✅ Preservar momentum horizontal durante o ataque
	_character._attack_animation_handler("Attack_", 3)
	
	print("⚔️ Dash cancelado com ataque!")


func notify_dash_frame(frame: int) -> void:
	"""Chamado pelo CharacterTexture para avisar em qual frame o dash está"""
	if frame >= 2 and not _dash_cancel_frame_reached:
		_dash_cancel_frame_reached = true

func is_dash_jumping() -> bool:
	return _is_dash_jumping

func process_dash_jump_momentum(delta: float) -> void:
	if not _is_dash_jumping:
		return
	
	if not _character.is_on_floor():
		_is_dash_jump_launched = true
	
	if _is_dash_jump_launched and _character.is_on_floor():
		_is_dash_jumping = false
		_is_dash_jump_launched = false
		_ghost_trail_timer = 0.0
		return
	
	# ✅ GHOST TRAIL durante o dash-jump
	_ghost_trail_timer += delta
	if _ghost_trail_timer >= ghost_trail_interval:
		_spawn_dash_jump_ghost_trail()
		_ghost_trail_timer = 0.0
	
	_dash_jump_momentum_timer -= delta
	if _dash_jump_momentum_timer <= 0.0:
		_is_dash_jumping = false
		_is_dash_jump_launched = false
		_ghost_trail_timer = 0.0

func _spawn_dash_jump_ghost_trail() -> void:
	if not ghost_trail_scene:
		return
	
	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = _character.global_position
	ghost.global_rotation = _character.global_rotation
	ghost.setup(_character_texture)


func cancel_dash_jump_momentum() -> void:
	"""Cancela imediatamente o momentum do dash-jump (usado ao agarrar quina, etc.)"""
	if not _is_dash_jumping:
		return
	_is_dash_jumping = false
	_is_dash_jump_launched = false
	_dash_jump_momentum_timer = 0.0
	_ghost_trail_timer = 0.0


# ========== LÓGICA DE HOOK ==========
func handle_hook_input() -> bool:
	"""Verifica e executa hook - retorna true se executou"""
	
	if not Input.is_action_just_pressed("hook"):
		return false
	
	if _on_hook:
		return false
	
	if not _has_hook_skill:
		return false  # Bloqueia se não tiver a habilidade
	
	cancel_dash_jump_momentum()
	
	_character.set_physics_process(false)
	_character_texture.action_animation("Hook")
	_hook_timer.start()
	_on_hook = true
	
	return true

func process_hook_logic(delta: float) -> void:
	"""Processa lógica do hook (chamar no _process do BaseCharacter)"""
	
	if not _on_hook:
		return
	
	if not _character.has_node("HookRay"):
		return
	
	var hook_ray = _character.get_node("HookRay")
	
	if not hook_ray.is_colliding():
		return
	
	_collider = hook_ray.get_collider()
	
	hook_ray.get_node("Animation").play("hit")
	_character_texture.action_animation("HookPuxao", _character_texture.frame)
	hook_ray.get_node("Animation").play("RESET")
	
	if _collider is TileMapLayer:
		var collision_point = hook_ray.get_collision_point()
		var collision_normal = hook_ray.get_collision_normal()
		var safe_position = collision_point + (collision_normal * 8.0)
		
		if _character.global_position.distance_to(safe_position) < 6.0:
			_push_towards_wall(collision_point)
			_on_hook = false
			return
		
		var _tween: Tween = _character.get_tree().create_tween()
		_tween.tween_property(_character, "global_position", safe_position, 0.2)
		await _tween.finished
	else:
		var _tween: Tween = _character.get_tree().create_tween()
		_tween.tween_property(_character, "global_position", hook_ray.get_collision_point(), 0.2)
		await _tween.finished
	
	if is_instance_valid(_collider):
		if _collider.has_method("apply_parry_effect"):  # Assumindo que é um inimigo
			_character_texture.target = _collider.global_position
			_character_texture.action_animation("Attack_Air_1")
			_character_texture.on_hook_attack = true
	
	_on_hook = false

func _push_towards_wall(wall_position: Vector2) -> void:
	"""Empurra personagem em direção à parede"""
	var push_force = 1500.0
	var push_force_y = -500.0
	var push_direction = _character.global_position.direction_to(wall_position)
	
	_character.velocity.x = push_direction.x * push_force
	_character.velocity.y = push_force_y

func apply_dash_impulse(direction_aux: Vector2) -> void:
	"""Aplica impulso do hook dash"""
	_roll_direction = direction_aux
	_on_hook_dash = true
	
	_character.velocity.x = _roll_direction.x * _hook_dash_speed_x
	_character.velocity.y = _hook_dash_speed_y

func process_hook_dash(delta: float) -> bool:
	"""Processa movimento do hook dash - retorna true se está em hook dash"""
	
	if not _on_hook_dash:
		return false
	
	if _character.is_on_floor():
		_on_hook_dash = false
		return false
	
	_character.velocity.y += _gravity * delta
	_character.move_and_slide()
	_character_texture.action_animation("RollingSpecial")
	
	return true

func is_on_hook() -> bool:
	"""Retorna se está usando hook"""
	return _on_hook

func is_on_hook_dash() -> bool:
	"""Retorna se está em hook dash"""
	return _on_hook_dash

# ========== LÓGICA DE WALL JUMP ==========
func handle_wall_logic(delta: float) -> void:
	if not _character.has_node("WallRay"):
		return
	
	var wall_ray = _character.get_node("WallRay")
	var pressing_horizontal = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	
	# ✅ Resetar auto wall jump ao tocar o chão
	if _character.is_on_floor():
		_can_auto_wall_jump = false
	
	# ✅ PROCESSAR WALL SLIDE (SE JÁ ESTIVER ATIVO)
	if _is_wall_sliding:
		if Input.is_action_just_pressed("jump"):
			if _has_wall_jump_skill:
				# ✅ COM HABILIDADE: executa wall jump normalmente
				_is_wall_sliding = false
				_character_texture.set_wall_sliding(false)
				
				var wall_direction = sign(wall_ray.target_position.x)
				_character.velocity = Vector2(-wall_direction * _wall_x_force, _wall_y_force)
				_character_texture.action_animation("FrontFlip")
				_execute_wall_jump()
				return
			else:
				# ✅ SEM HABILIDADE: encerra o wall slide ao apertar pulo
				_is_wall_sliding = false
				_character_texture.set_wall_sliding(false)
				print("❌ Wall slide encerrado por pulo (sem habilidade)")
				return
		
		var touched_ground = _character.is_on_floor()
		if _character.has_node("GroundRay"):
			touched_ground = touched_ground or _character.get_node("GroundRay").is_colliding()
		
		var left_wall = not wall_ray.is_colliding()
		
		if touched_ground or left_wall:
			_is_wall_sliding = false
			_character_texture.set_wall_sliding(false)
			print("❌ Wall slide DESATIVADO")
		else:
			_character.velocity.y = min(_character.velocity.y, _wall_slide)
			_character.velocity.x = 0
			
			if wall_ray.target_position.x > 0:
				_character_texture._attack_area_collision.position.x = -20
			else:
				_character_texture._attack_area_collision.position.x = 20
		
		return
	
	# ✅ WALL JUMP DIRETO — sem precisar de wall slide (requer habilidade)
	if (
		_has_wall_jump_skill and
		not _is_wall_jumping and
		not _character.is_on_floor() and
		wall_ray.is_colliding() and
		Input.is_action_just_pressed("jump")
	):
		var wall_direction = sign(wall_ray.target_position.x)
		_character.velocity = Vector2(-wall_direction * _wall_x_force, _wall_y_force)
		_character_texture.action_animation("FrontFlip")
		_execute_wall_jump()
		return
	
	# ✅ ATIVAR WALL SLIDE (SE NÃO ESTIVER ATIVO)
	if (
		not _is_wall_sliding and
		_can_wall_slide and
		wall_ray.is_colliding() and
		not _character.is_on_floor() and
		_character.velocity.y > 50 and
		pressing_horizontal and
		not _character._is_descending_platform
	):
		_is_wall_sliding = true
		_character_texture.set_wall_sliding(true)
		print("✅ Wall slide ATIVADO - Colidindo com:", wall_ray.get_collider().name)


func _cancel_wall_slide_with_cooldown() -> void:
	"""Cancela wall slide e impede novo wall slide por 0.4s"""
	_is_wall_sliding = false
	_character_texture.set_wall_sliding(false)
	_can_wall_slide = false
	
	if has_node("WallSlideCooldownTimer"):
		get_node("WallSlideCooldownTimer").start()
	
	print("🚫 Wall slide em cooldown por ", _wall_slide_cooldown, " segundos")


func _execute_wall_jump() -> void:
	"""Executa o wall jump"""
	_is_wall_jumping = true
	_can_auto_wall_jump = true  # ✅ Habilita o próximo wall jump automático
	_wall_jump_timer.start()
	
	var wall_ray = _character.get_node("WallRay")
	var wall_direction = sign(wall_ray.target_position.x)
	
	_character.velocity = Vector2(-wall_direction * _wall_x_force, _wall_y_force)
	
	print("🚀 Wall Jump: wall_direction=", wall_direction, " velocity.x=", _character.velocity.x)
	
	global.spawn_effect(
		"res://Scenes/FX/wall_jump_effect.tscn",
		Vector2(0, 0),
		_character.global_position,
		_character_texture.flip_h
	)

func is_wall_sliding() -> bool:
	"""Retorna se está deslizando na parede"""
	return _is_wall_sliding

func is_wall_jumping() -> bool:
	"""Retorna se está executando wall jump"""
	return _is_wall_jumping

func update_wall_ray_direction(facing_right: bool) -> void:
	"""Atualiza a direção do wall ray baseado na direção do personagem"""
	if not _character.has_node("WallRay"):
		return
	
	var wall_ray = _character.get_node("WallRay")
	
	if facing_right:
		wall_ray.target_position = Vector2(7, 0)
	else:
		wall_ray.target_position = Vector2(-7, 0)

# ========== LÓGICA DE ENEMY STEP (ADICIONAR NOVA SEÇÃO) ==========
func handle_enemy_step_logic() -> bool:
	"""
	Verifica se pode executar Enemy Step
	Retorna true se executou a habilidade
	"""
	
	# ✅ Verificar pré-requisitos
	if not _has_enemy_step_skill:
		return false
	
	if not _can_enemy_step:
		return false
	
	if _character.is_on_floor():
		return false
	
	if not _character.has_node("GroundRay"):
		return false
	
	var ground_ray = _character.get_node("GroundRay")
	
	# ✅ Verificar se está colidindo com Area2D "Step"
	if not ground_ray.is_colliding():
		return false
	
	var collider = ground_ray.get_collider()
	
	# ✅ Verificar se é uma Area2D do grupo "Step"
	if not (collider is Area2D and collider.is_in_group("Step")):
		return false
	
	# ✅ EXECUTAR ENEMY STEP
	_execute_enemy_step()
	return true

func _execute_enemy_step() -> void:
	"""Executa a habilidade Enemy Step"""
	
	cancel_dash_jump_momentum()
	
	print("🎯 Enemy Step ativado!")
	
	# ✅ DETERMINAR DIREÇÃO BASEADA NO FACING DO PERSONAGEM
	var direction_multiplier = 1.0 if _character_texture.facing_right else -1.0
	
	# ✅ APLICAR FORÇA DE IMPULSO NA DIREÇÃO QUE ESTÁ OLHANDO
	_character.velocity.x = _enemy_step_force_x * direction_multiplier
	_character.velocity.y = _enemy_step_force_y
	
	# ✅ ATIVAR FLAG PARA BLOQUEAR CONTROLE HORIZONTAL
	_is_enemy_stepping = true
	
	# ✅ EXECUTAR ANIMAÇÃO FRONTFLIP
	_character_texture.action_animation("FrontFlip")
	
	# ✅ SPAWNAR EFEITO VISUAL NA DIREÇÃO CORRETA
	global.spawn_effect(
		"res://Scenes/FX/jump_effect.tscn", 
		Vector2(0, 0), 
		_character.global_position, 
		_character_texture.flip_h
	)
	
	# ✅ INICIAR COOLDOWN
	_can_enemy_step = false
	_enemy_step_cooldown_timer.start()
	
	print("⏳ Enemy Step em cooldown por ", _enemy_step_cooldown, " segundos")
	print("➡️ Direção: ", "DIREITA" if direction_multiplier > 0 else "ESQUERDA")
	print("🚀 Velocity aplicada: X=", _character.velocity.x, " Y=", _character.velocity.y)

func is_enemy_stepping() -> bool:
	"""Retorna se está executando Enemy Step"""
	return _is_enemy_stepping

func reset_enemy_step_state() -> void:
	"""Reseta o estado do Enemy Step (chamado quando animação termina)"""
	_is_enemy_stepping = false
	print("✅ Enemy Step finalizado - controles liberados")


# ========== LÓGICA DE SPEED BOOST ==========
func process_speed_boost(delta: float) -> float:
	if not _has_speed_boost_skill:
		return 0.0

	var is_moving = Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	var is_stopped_on_floor = not is_moving and _character.is_on_floor()

	if is_moving:
		_speed_boost_idle_time = 0.0
		_speed_boost_time = min(_speed_boost_time + delta, _SPEED_BOOST_RAMP_DURATION)
	elif is_stopped_on_floor:
		_speed_boost_idle_time += delta
		if _speed_boost_idle_time >= _SPEED_BOOST_IDLE_RESET:
			_speed_boost_time = 0.0
			_speed_boost_idle_time = 0.0

	var ramp_ratio: float = _speed_boost_time / _SPEED_BOOST_RAMP_DURATION

	# ✅ PRINT TEMPORÁRIO - remover depois
	print("⚡ boost_time: ", _speed_boost_time, " | ratio: ", ramp_ratio)

	var bonus: float = _character._speed * (_SPEED_BOOST_MULTIPLIER - 1.0) * ramp_ratio
	return bonus

func get_speed_boost_ratio() -> float:
	"""Retorna o ratio atual do speed boost (0.0 a 1.0)"""
	if not _has_speed_boost_skill:
		return 0.0
	return _speed_boost_time / _SPEED_BOOST_RAMP_DURATION

# ========== CALLBACKS DOS TIMERS ==========
func _on_roll_timer_timeout() -> void:
	_is_rolling = false
	_dash_cancel_frame_reached = false  # ✅ garantir reset
	_character.set_collision_mask_value(4, true)
	_character.set_collision_mask_value(7, true)
	_character_texture._is_on_action = false
	_roll_cooldown_timer.start()

func _on_roll_cooldown_timeout() -> void:
	_can_roll = true

func _on_hook_timer_timeout() -> void:
	_on_hook = false

func _on_wall_jump_timer_timeout() -> void:
	_is_wall_jumping = false

# ✅ NOVO: Callback do cooldown de wall slide
func _on_wall_slide_cooldown_timeout() -> void:
	_can_wall_slide = true
	print("✅ Wall slide disponível novamente")

func _on_enemy_step_cooldown_timeout() -> void:
	_can_enemy_step = true
	print("✅ Enemy Step disponível novamente")

# ========== GETTERS E SETTERS (ADICIONAR APÓS WALL JUMP) ==========
func update_enemy_step_state(state: bool) -> void:
	"""Atualiza se o jogador possui a habilidade de Enemy Step"""
	_has_enemy_step_skill = state
	serialization.game_data["has_enemy_step"] = state

func has_enemy_step() -> bool:
	"""Retorna se possui habilidade de Enemy Step"""
	return _has_enemy_step_skill

func can_use_enemy_step() -> bool:
	"""Retorna se o Enemy Step está disponível (não em cooldown)"""
	return _can_enemy_step

# ========== GETTERS E SETTERS ==========
func update_dash_state(state: bool) -> void:
	"""Atualiza se o jogador possui a habilidade de Forward Dash"""
	_has_dash_skill = state
	serialization.game_data["has_dash"] = state

func has_dash() -> bool:
	"""Retorna se possui habilidade de Forward Dash"""
	return _has_dash_skill

func update_hook_state(state: bool) -> void:
	"""Atualiza se o jogador possui a habilidade de Hook"""
	_has_hook_skill = state
	serialization.game_data["has_hook"] = state

func has_hook() -> bool:
	"""Retorna se possui habilidade de Hook"""
	return _has_hook_skill

func update_wall_jump_state(state: bool) -> void:
	"""Atualiza se o jogador possui a habilidade de Wall Jump"""
	_has_wall_jump_skill = state
	serialization.game_data["has_wall_jump"] = state

func has_wall_jump() -> bool:
	"""Retorna se possui habilidade de Wall Jump"""
	return _has_wall_jump_skill

func update_speed_boost_state(state: bool) -> void:
	_has_speed_boost_skill = state
	serialization.game_data["has_speed_boost"] = state
	if not state:
		_speed_boost_time = 0.0
		_speed_boost_idle_time = 0.0

func has_speed_boost() -> bool:
	return _has_speed_boost_skill
