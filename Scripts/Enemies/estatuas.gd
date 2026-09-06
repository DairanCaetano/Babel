extends CharacterBody2D
class_name Estatuas

var _death_delay_timer: Timer
var _last_hit_entity_position: Vector2 = Vector2.ZERO

@export_category("Objects")
@export var detection_area: Area2D 
@export var texture: AnimatedSprite2D
@export var attack_area: Area2D
@export var particula_pedra: Node2D
@export var particulas_fogo: Node2D
@export var particulas_fogo_realistica: Node2D
@export var particulas_fogo_morte: GPUParticles2D
@export var texture_fire: AnimatedSprite2D

@export_category("Behavior Mode")
enum BehaviorMode { STALKER, STATIC }
@export var behavior_mode: BehaviorMode = BehaviorMode.STALKER

@export_category("Health System")
@export var _enemy_health: int = 10
@export var _hit_knockback_timer: float = 0.3
@export var _dead_knockback_timer: float = 0.5
@export var _knockback_speed: float = 256.0

@export_category("Movement Settings")
@export var move_speed: float = 100.0
@export var chase_duration: float = 2.0
@export var idle_duration: float = 0.5

@export_category("Death Settings")
@export var death_jump_force: float = 100.0
@export var death_horizontal_force: float = 150.0

@export_category("Fire Effects")
@export var enable_texture_fire: bool = true

@export_category("Static Mode Settings")
@export var static_idle_shake_interval: float = 3.0




# ✅ VARIÁVEIS DE DETECÇÃO DO JOGADOR
var _player_in_range: BaseCharacter = null
var _is_activated: bool = false

var is_facing_right: bool = true
var current_state: String = "rest"

var _on_knockback: bool = false
var _is_alive: bool = true
var _knockback_timer: Timer
var _chase_timer: Timer
var _idle_timer: Timer
var _death_timer: Timer
var _static_shake_timer: Timer

var _gravity_enabled: bool = false
var _gravity: float = 980.0
var _current_gravity: float = 0.0
var _gravity_acceleration: float = 980.0  # Acelera até atingir _gravity em ~1 segundo

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	_death_delay_timer = Timer.new()
	add_child(_death_delay_timer)
	_death_delay_timer.one_shot = true
	_death_delay_timer.timeout.connect(_on_death_delay_timeout)

	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	
	_knockback_timer = Timer.new()
	add_child(_knockback_timer)
	_knockback_timer.one_shot = true
	_knockback_timer.timeout.connect(_on_knockback_timer_timeout)
	
	_chase_timer = Timer.new()
	add_child(_chase_timer)
	_chase_timer.one_shot = true
	_chase_timer.timeout.connect(_on_chase_timer_timeout)
	
	_idle_timer = Timer.new()
	add_child(_idle_timer)
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_timer_timeout)
	
	_death_timer = Timer.new()
	add_child(_death_timer)
	_death_timer.one_shot = true
	_death_timer.timeout.connect(_on_death_timer_timeout)
	
	_static_shake_timer = Timer.new()
	add_child(_static_shake_timer)
	_static_shake_timer.one_shot = false
	_static_shake_timer.timeout.connect(_on_static_shake_timer_timeout)
	
	if texture.animation_finished.connect(_on_animation_finished) != OK:
		pass
	
	_initialize_behavior_mode()

func _initialize_behavior_mode():
	match behavior_mode:
		BehaviorMode.STALKER:
			_play_animation("Rest")
			current_state = "rest"
			_gravity_enabled = false
			_set_fire_particles(false)
			_set_realistic_fire_particles(false)
			_set_texture_fire(false)
		
		BehaviorMode.STATIC:
			_play_animation("Idle")
			current_state = "static"
			_gravity_enabled = false
			_set_fire_particles(true)
			_set_realistic_fire_particles(true)
			_set_texture_fire(true)
			_static_shake_timer.wait_time = static_idle_shake_interval
			_static_shake_timer.start()
	
	if particulas_fogo_morte:
		particulas_fogo_morte.visible = false
		particulas_fogo_morte.emitting = false

func _physics_process(delta):
	if _gravity_enabled:
		# Aumenta gradualmente a gravidade até atingir o valor máximo
		if _current_gravity < _gravity:
			_current_gravity += _gravity_acceleration * delta
			_current_gravity = min(_current_gravity, _gravity)
		
		velocity.y += _current_gravity * delta
	
	if _on_knockback:
		move_and_slide()
		return
	
	if _is_alive == false:
		move_and_slide()
		return
	
	match current_state:
		"rest":
			velocity = Vector2.ZERO
		
		"static":
			velocity = Vector2.ZERO
		
		"chase":
			if _player_in_range and is_instance_valid(_player_in_range):
				_move_towards_player()
			else:
				_player_in_range = null
				_transition_to_idle()
		
		"idle":
			velocity = Vector2.ZERO
	
	move_and_slide()
	_update_animation()

func _move_towards_player():
	if not _player_in_range or not is_instance_valid(_player_in_range):
		return
	
	var direction_to_player = (_player_in_range.global_position - global_position).normalized()
	velocity = direction_to_player * move_speed
	_update_direction(direction_to_player.x)

func _update_direction(x_direction: float):
	var should_face_right = x_direction > 0
	if should_face_right != is_facing_right:
		is_facing_right = should_face_right
	texture.flip_h = is_facing_right

func _update_animation():
	match current_state:
		"rest":
			if texture.animation != "Rest":
				_play_animation("Rest")
		"static":
			if texture.animation != "Idle":
				_play_animation("Idle")
		"chase", "idle":
			if texture.animation != "Idle":
				_play_animation("Idle")

func _play_animation(animation_name: String):
	if texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)

func _on_detection_entered(body):
	if body is BaseCharacter and _is_alive:
		# STATIC MODE NÃO REAGE AO JOGADOR
		if behavior_mode == BehaviorMode.STATIC:
			return
		
		_player_in_range = body
		_is_activated = true
		
		# ✅ VERIFICA A DIREÇÃO INICIAL DO JOGADOR
		var direction_to_player = (_player_in_range.global_position - global_position).x
		_update_direction(direction_to_player)
		
		_transition_to_chase()

func _on_detection_exited(body):
	if body == _player_in_range:
		pass

func _transition_to_chase():
	if current_state == "chase":
		return
	
	current_state = "chase"
	_play_animation("Idle")
	_set_fire_particles(true)
	_set_realistic_fire_particles(true)
	_set_texture_fire(true)
	_chase_timer.wait_time = chase_duration
	_chase_timer.start()

func _transition_to_idle():
	if current_state == "idle":
		return
	
	current_state = "idle"
	_play_animation("Idle")
	_set_fire_particles(true)
	_set_realistic_fire_particles(true)
	_set_texture_fire(true)
	_start_idle_tween()
	_idle_timer.wait_time = idle_duration
	_idle_timer.start()

func _start_idle_tween():
	var shakes = 2  
	var shake_duration = idle_duration / float(shakes)
	
	var tween = get_tree().create_tween()
	
	for i in range(shakes):
		var random_offset = Vector2(
			randf_range(-3, 3),
			randf_range(-3, 3)
		)
		
		var target_position = global_position + random_offset
		
		tween.tween_property(
			self, "global_position",
			target_position,
			shake_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		self, "global_position",
		global_position,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _transition_to_rest():
	if current_state == "rest":
		return
	
	if not _is_activated:
		current_state = "rest"
		_play_animation("Rest")
		velocity = Vector2.ZERO
		_set_fire_particles(false)
		_set_realistic_fire_particles(false)
		_set_texture_fire(false)
	else:
		_transition_to_idle()

func _on_chase_timer_timeout():
	if current_state == "chase":
		_transition_to_idle()

func _on_idle_timer_timeout():
	if current_state == "idle":
		if _player_in_range and is_instance_valid(_player_in_range):
			var distance_to_player = global_position.distance_to(_player_in_range.global_position)
			
			if distance_to_player < 500:
				_transition_to_chase()
			else:
				_player_in_range = null
				_transition_to_rest()
		else:
			_player_in_range = null
			_transition_to_rest()

func _on_static_shake_timer_timeout():
	if current_state == "static" and _is_alive:
		_start_idle_tween()

func _on_knockback_timer_timeout():
	_on_knockback = false
	
	if _is_alive:
		if behavior_mode == BehaviorMode.STATIC:
			# VOLTA PARA STATIC APÓS KNOCKBACK
			current_state = "static"
		elif _player_in_range and is_instance_valid(_player_in_range):
			_transition_to_chase()
		else:
			_transition_to_idle()

func _on_death_timer_timeout():
	queue_free()

func _on_animation_finished():
	if texture.animation == "Dead" and _is_alive == false:
		pass

func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		return
		
	_last_hit_entity_position = _entity.global_position
	
	# NO MODO STATIC NÃO SOFRE KNOCKBACK
	if behavior_mode != BehaviorMode.STATIC:
		_knockback(_entity)
	
	_enemy_health -= _damage
	
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)
	
	if _enemy_health <= 0:
		_stop_all_timers()
		# NO MODO STATIC NÃO INICIA O KNOCKBACK TIMER NA MORTE
		if behavior_mode != BehaviorMode.STATIC:
			_knockback_timer.start(_dead_knockback_timer)
		_kill()
		return
	
	# NO MODO STATIC NÃO INICIA O KNOCKBACK TIMER
	if behavior_mode != BehaviorMode.STATIC:
		_knockback_timer.start(_hit_knockback_timer)

func _set_shader_blink_intensity(new_value: float) -> void:
	if not texture:
		return
	
	if not texture.material:
		return
	
	if not texture.material.shader:
		return
	
	# Ativar/desativar blink + definir intensidade
	texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	texture.material.set_shader_parameter("blink_intensity", new_value)

func _knockback(_entity) -> void:
	var _knockback_direction: Vector2 = _entity.global_position.direction_to(global_position)
	velocity.x = _knockback_direction.x * _knockback_speed
	velocity.y = -1 * _knockback_speed
	_knockback_timer.start(0.2)
	_on_knockback = true

func _kill() -> void:
	_play_animation("Dead")
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	_is_alive = false
	_player_in_range = null
	_set_fire_particles(false)
	_set_realistic_fire_particles(false)
	_set_texture_fire(false)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)
	
	if particula_pedra:
		particula_pedra.visible = true
		for child in particula_pedra.get_children():
			if child is GPUParticles2D:
				child.emitting = true
	
	if particulas_fogo_morte:
		particulas_fogo_morte.visible = true
		particulas_fogo_morte.emitting = true
	
	if _static_shake_timer and not _static_shake_timer.is_stopped():
		_static_shake_timer.stop()
	
	# ✅ ATIVA GRAVIDADE IMEDIATAMENTE, SEM DELAY
	_gravity_enabled = true
	_current_gravity = 0.0
	_apply_death_jump()
	_death_timer.wait_time = 0.5
	_death_timer.start()

func _apply_death_jump():
	var jump_direction = Vector2.ZERO
	
	if _last_hit_entity_position != Vector2.ZERO:
		var direction_to_attacker = (global_position - _last_hit_entity_position).normalized()
		jump_direction = direction_to_attacker
	else:
		jump_direction.x = 1.0 if randf() > 0.5 else -1.0
		jump_direction.y = -0.5
	
	velocity.x = jump_direction.x * death_horizontal_force
	velocity.y = jump_direction.y * death_jump_force

func _stop_all_timers() -> void:
	if not _chase_timer.is_stopped():
		_chase_timer.stop()
	if not _idle_timer.is_stopped():
		_idle_timer.stop()
	if _static_shake_timer and not _static_shake_timer.is_stopped():
		_static_shake_timer.stop()

func _on_death_delay_timeout():
	_gravity_enabled = true
	_current_gravity = 0.0  # Começa com gravidade zero
	_apply_death_jump()
	_death_timer.wait_time = 0.5
	_death_timer.start()

# FUNÇÃO PARA CONTROLAR EMISSÃO DE PARTÍCULAS DE FOGO
func _set_fire_particles(enabled: bool) -> void:
	if not particulas_fogo:
		return
	
	for child in particulas_fogo.get_children():
		if child is GPUParticles2D:
			child.emitting = enabled
			return

# FUNÇÃO PARA CONTROLAR EMISSÃO DE PARTÍCULAS DE FOGO REALÍSTICAS
func _set_realistic_fire_particles(enabled: bool) -> void:
	if not particulas_fogo_realistica:
		return
	
	for child in particulas_fogo_realistica.get_children():
		if child is GPUParticles2D:
			child.emitting = enabled
			return

# FUNÇÃO PARA CONTROLAR VISIBILIDADE DA TEXTURA DE FOGO
func _set_texture_fire(enabled: bool) -> void:
	if not texture_fire or not enable_texture_fire:
		return
	
	texture_fire.visible = enabled
	if enabled and texture_fire.sprite_frames:
		texture_fire.play()
