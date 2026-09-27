extends CharacterBody2D
class_name BaseCharacter

const _AXE_PROJECTILE: PackedScene = preload("res://Scenes/Projectile/projectile_axe.tscn")
const PLATFORM_DESCENT_DURATION: float = 0.4
const COYOTE_TIME_DURATION: float = 0.15  # Tempo em segundos após sair do chão


var _coyote_time_remaining: float = 0.0
var _was_on_floor_last_frame: bool = false

var on_ledge: bool = false
var ledge_direction: float = 0.0

var _on_ladder: bool = false
var _current_ladder: Ladder = null
var _ladder_climb_speed: float = 100.0

var _delta_cache: float = 0.0

var is_pushing_heavy_object: bool = false

var stun_area: StunArea

var is_petrified: bool = false
var is_consuming: bool = false

var action_count: int = 0

var _can_play_dead_animation: bool = true

var _has_axe: bool = false
var _has_map: bool = false

var _on_floor: bool = true
var _on_hook: bool = false

var _is_invincible: bool = false

var _is_descending_platform: bool = false
var _platform_descent_timer: float = 0.0

var _is_starting_run: bool = false
var _was_moving_last_frame: bool = false

var _is_alive: bool = true
var _in_combat_stance: bool = false

var _is_crouching: bool = false

var _attack_index: int = 1
var _attack_air_count: int = 0

var _is_frozen_by_effect: bool = false

signal attack_started

var jump_origin: Vector2 = Vector2.ZERO

var _gravity_multiplier: float = 1.0

var _direction = Input.get_axis("move_left", "move_right")

var _gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _additional_attributes: Dictionary = {
	"move_speed": 0,
	"defense": 0,
	"attack": 0,
	"health": 0  # ← NOVO: bônus de vida vindo de equipamento
}

var _collider

@export_category("variables")
@export var _speed: float = 200.0
@export var _jump_velocity: float = -300.0

@export var _is_in_cinematic: bool = true

@export_category("Objects")
@export var _inventory: CharacterInventory
@export var _attack_combo: Timer
@export var _character_texture: CharacterTexture
@export var _stats: Node2D
@export var _particle_2d: GPUParticles2D
@export var _roll_timer: Timer
@export var _roll_cooldown_timer: Timer
@export var _wall_ray: RayCast2D
@export var _combat_stance_timer: Timer
@export var _character_collision: CollisionShape2D
@export var _ladder_ray: RayCast2D
@export var _combo_timer: Timer
@export var _atk_1_timer: Timer
@export var _ground_ray: RayCast2D
@export var _subweapons: CharacterSubweapon
@export var _invencibility_timer: Timer
@export var _skills: CharacterSkills
@export var _heal_1: GPUParticles2D
@export var _heal_2: GPUParticles2D
@export var _ledge_grab_hit: RayCast2D
@export var _ledge_grab_miss: RayCast2D
@export var _audio: CharacterAudio  
@export var _parry_voice_timer: Timer
@export var _neck_anchor: Marker2D


func _ready() -> void:
	# ✅ GARANTIR QUE O PLAYER PAUSE QUANDO O JOGO PAUSAR
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# ✅ FORÇAR ROTAÇÃO ZERO NOS RAYCASTS DE LEDGE GRAB (PRIMEIRO!)
	if _ledge_grab_hit:
		_ledge_grab_hit.rotation = 0.0
		_ledge_grab_hit.rotation_degrees = 0.0
		print("📍 LedgeGrabHit - Rotação forçada para 0°")
	
	if _ledge_grab_miss:
		_ledge_grab_miss.rotation = 0.0
		_ledge_grab_miss.rotation_degrees = 0.0
		print("📍 LedgeGrabMiss - Rotação forçada para 0°")
	
	# ✅ CRÍTICO: BLOQUEAR SAVES IMEDIATAMENTE SE FOR LOAD
	if serialization.should_apply_save:
		await get_tree().process_frame
		if global.inventory:
			global.inventory._is_loading_save = true
	
	set_physics_process(true)
	global.character = self
	
	if !_combat_stance_timer:
		_combat_stance_timer = Timer.new()
		_combat_stance_timer.one_shot = true
		_combat_stance_timer.wait_time = 1.0
		_combat_stance_timer.connect("timeout", _on_combat_stance_timer_timeout)
		add_child(_combat_stance_timer)
	
	_in_combat_stance = false
	
	# ✅ O save é aplicado APENAS pelo game.gd (_load_initial_level),
	# depois que a fase carrega. Antes rodava aqui também, em paralelo.
	
	await get_tree().process_frame
	jump_origin = global_position

func _physics_process(_delta: float) -> void:
	_delta_cache = _delta

	if _is_frozen_by_effect:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_nan(global_position.x) or is_nan(global_position.y):
		print("🚨🚨🚨 POSITION VIROU NaN! 🚨🚨🚨")
		print("  Animação atual: ", _character_texture.animation)
		print("  Velocity: ", velocity)
		print("  On floor: ", is_on_floor())
		print("  Physics enabled: ", is_physics_processing())
		print("  Stack trace:")
		print(get_stack())
		return

	if is_on_floor() or _platform_descent_timer <= 0:
		_is_descending_platform = false

	if _platform_descent_timer > 0:
		_platform_descent_timer -= _delta

	if Input.is_action_just_pressed("UseConsumable") and not _is_in_cinematic and is_on_floor():
		if not global.ui_equipments:
			return

		var equipped_consumable = global.ui_equipments._equipments_inventory["consumable"]

		if equipped_consumable.is_empty():
			return

		if equipped_consumable["type"] != "consumable":
			return

		if equipped_consumable.get("key", "") == "ITEM_POTION_EMPTY":
			return

		if equipped_consumable.get("amount", 0) <= 0:
			return

		if equipped_consumable.get("key", "") == "ITEM_POTION_NAME" and _stats.current_health >= _stats.max_health:
			return

		if is_consuming:
			return

		consume(equipped_consumable)
		global.ui_equipments.use_consumable()

	if _on_ladder:
		if not _ladder_ray.is_colliding():
			print("🪜 Raycast perdeu contato com a escada - saindo automaticamente")
			_exit_ladder()
		else:
			if Input.is_action_just_pressed("jump"):
				_exit_ladder()
				velocity.y = _jump_velocity
				global.spawn_effect(
					"res://Scenes/FX/jump_effect.tscn",
					Vector2(0, 0), global_position, _character_texture.flip_h
				)
				apply_push_force()
				move_and_slide()
				return

			_ladder_climb(_delta)
			apply_push_force()
			move_and_slide()
			return

	if not _on_ladder:
		_check_ladder_entry()

	if _skills.is_on_hook_dash():
		if _skills.process_hook_dash(_delta):
			return

	if _skills.handle_enemy_step_logic():
		apply_push_force()
		move_and_slide()
		return

	# ✅ CANCELAMENTO DO DASH — antes do early return do is_rolling
	if _skills.is_rolling() and _skills._dash_cancel_frame_reached:
		if not _is_in_cinematic:
			if Input.is_action_just_pressed("jump"):
				_skills.cancel_dash_with_jump()
				return
			if Input.is_action_just_pressed("attack"):
				_skills.cancel_dash_with_attack()
				return

	if _skills.is_rolling():
		_skills.process_dash_movement(_delta)
		return

	_crouch_handler()

	if on_ledge:
		_character_texture.is_wall_sliding = false
		velocity = Vector2.ZERO
		_handle_ledge_input()

		if _character_texture.animation != "Grab":
			_character_texture.play("Grab")
			_character_texture._is_on_action = true

		return

	_ledge_logic()

	if on_ledge:
		velocity = Vector2.ZERO
		return

	_vertical_movement(_delta)

	if _is_alive == false:
		apply_push_force()
		move_and_slide()
		return

	_skills.process_dash_jump_momentum(_delta)

	if not _is_in_cinematic:
		if _skills.handle_hook_input():
			return

		_horizontal_movement()
		_attack_handler()
		_skills.handle_dash_input()
		_skills.handle_wall_logic(_delta)
	else:
		velocity.x = move_toward(velocity.x, 0, _speed)

	move_and_slide()
	apply_push_force()
	_character_texture.animate(velocity)

	if _audio:
		_audio.update_run_audio()
		_audio.update_wall_slide_audio()

	var movement_input = Input.get_axis("move_left", "move_right")

	var action_input = (
		Input.is_action_just_pressed("move_left") or
		Input.is_action_just_pressed("move_right") or
		Input.is_action_just_pressed("jump") or
		Input.is_action_just_pressed("attack") or
		Input.is_action_just_pressed("dash") or
		Input.is_action_just_pressed("sub_weapon")
	)

	if _in_combat_stance and movement_input != 0:
		_in_combat_stance = false
		_combat_stance_timer.stop()
	elif action_input and animation_includes_combat():
		_in_combat_stance = true
		_combat_stance_timer.stop()
		_combat_stance_timer.start()

func freeze() -> void:
	_is_frozen_by_effect = true
	velocity = Vector2.ZERO

func unfreeze() -> void:
	_is_frozen_by_effect = false


func apply_dash_impulse(direction_aux: Vector2) -> void:
	_skills.apply_dash_impulse(direction_aux)

func _process(_delta: float) -> void:
	_skills.process_hook_logic(_delta)
	
	if is_petrified:
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
			action_count += 1
			_shake_character()
		
		if action_count >= 10:
			$Texture.offset = Vector2.ZERO
			action_count = 0
			if is_instance_valid(stun_area):
				stun_area.reset()
			
			is_petrified = false
			set_physics_process(true)
			_character_texture._is_on_action = false
			_character_texture.animate(velocity)
	

func _push_towards_wall(wall_position: Vector2) -> void:
	var push_force = 1500.0
	var push_force_y = -500.0
	var push_direction = global_position.direction_to(wall_position)
	
	velocity.x = push_direction.x * push_force
	velocity.y = push_force_y

func _crouch_handler() -> void:
	if not is_on_floor() or _character_texture._is_on_action:
		if _is_crouching:
			_is_crouching = false
			_character_texture._is_on_action = false
			_character_texture._update_collision_size()
		return
	
	var action_pressed = (
		Input.is_action_just_pressed("jump") or
		Input.is_action_just_pressed("dash") or
		Input.is_action_just_pressed("parry") or
		Input.is_action_just_pressed("hook")
	)
	
	if action_pressed and _is_crouching:
		_is_crouching = false
		_character_texture._is_on_action = false
		return
	
	if Input.is_action_pressed("move_down") and not _is_crouching:
		_is_crouching = true
		_character_texture.action_animation("Crounch")
		_character_texture._update_collision_size()
		velocity.x = 0
	
	elif not Input.is_action_pressed("move_down") and _is_crouching:
		_is_crouching = false
		_character_texture._is_on_action = false
		_character_texture._update_collision_size()

func _ledge_logic() -> void:
	if on_ledge or is_on_floor():
		return
	
	if velocity.y < 0:
		return
	
	var current_direction = Input.get_axis("move_left", "move_right")
	
	if current_direction == 0:
		return
	
	if not _ledge_grab_hit or not _ledge_grab_miss:
		return
	
	var hit_colliding = _ledge_grab_hit.is_colliding()
	var miss_colliding = _ledge_grab_miss.is_colliding()
	
	if !hit_colliding or miss_colliding:
		return
	
	print("🎯 LEDGE GRAB ATIVADO!")
	
	ledge_direction = sign(current_direction)
	velocity = Vector2.ZERO
	_character_texture.play("Grab")
	_character_texture._is_on_action = true
	on_ledge = true
	_skills.cancel_dash_jump_momentum()   # ✅ NOVO: mata o momentum do dash-jump ao agarrar

func _handle_ledge_input() -> void:
	# ✅ APENAS PULAR - Subir na plataforma
	if Input.is_action_just_pressed("jump"):
		velocity.y = _jump_velocity
		on_ledge = false
		_character_texture._is_on_action = false
		print("⬆️ Pulando da borda (subindo)")
		return
	
	# ✅ NENHUMA OUTRA AÇÃO PERMITIDA
	# O personagem fica pendurado até apertar pulo

func _ladder_climb(delta: float) -> void:
	# Movimento vertical (cima/baixo)
	var vertical_input = Input.get_axis("move_up", "move_down")
	
	if vertical_input != 0:
		velocity.y = vertical_input * _ladder_climb_speed
		
		# ✅ SE NÃO ESTÁ TOCANDO A ANIMAÇÃO, INICIA
		if _character_texture.animation != "Climb" or _character_texture.get_speed_scale() == 0.0:
			_character_texture.play("Climb")
			_character_texture.unfreeze_animation()
	else:
		velocity.y = 0
		
		# ✅ CONGELA NO FRAME ATUAL
		if _character_texture.animation == "Climb":
			_character_texture.freeze_animation()
	
	# Bloquear movimento horizontal completamente
	velocity.x = 0

func _check_ladder_entry() -> void:
	# ✅ ENTRAR NA ESCADA COM "move_up" (aceita input diagonal)
	if Input.is_action_pressed("move_up") and _current_ladder:
		if _current_ladder.is_player_inside():
			_enter_ladder()

func _enter_ladder() -> void:
	print("🪜 Entrando no modo escalada")
	
	_on_ladder = true
	_character_texture._is_on_action = true
	
	# ✅ ALINHAR PERSONAGEM COM A ESCADA
	if _current_ladder:
		# Usar interpolação suave para não ser brusco
		var target_x = _current_ladder.get_ladder_x_position()
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "global_position:x", target_x, 0.15)
		
		# Definir velocidade de escalada
		_ladder_climb_speed = _speed * _current_ladder.get_climb_speed()
	
	# Zerar velocidade
	velocity = Vector2.ZERO
	
	# Iniciar animação
	_character_texture.play("Climb")

func _exit_ladder() -> void:
	print("🪜 Saindo do modo escalada")
	
	_on_ladder = false
	_character_texture._is_on_action = false
	
	# ✅ CRÍTICO: Garantir que speed_scale volte ao normal
	_character_texture.set_speed_scale(1.0)
	
	# ✅ NÃO PRECISA REABILITAR - nunca desabilitamos!
	
	# Limpar referência
	_current_ladder = null

func _shake_character() -> void:
	var _shake_length: float = 0.2
	while _shake_length > 0:
		$Texture.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		_shake_length -= get_process_delta_time()
		await get_tree().physics_frame
	
	$Texture.offset = Vector2.ZERO

func play_cinematic_animation(_anim_name: String) -> void:
	_character_texture.play(_anim_name)

func _reset_bonus_attributes() -> void:
	_additional_attributes = {
		"move_speed": 0,
		"defense": 0,
		"attack": 0,
		"health": 0  # ← NOVO
	}

func _increase_bonus_attributes(_attributes: Dictionary) -> void:
	for _type in _attributes:
		for _attribute in _attributes[_type]:
			_additional_attributes[_attribute] += _attributes[_type][_attribute]

func _check_platform_descent(old_position: float) -> void:
	if abs(position.y - old_position) < 1.0:
		if is_on_floor():
			_attack_index = 1
			velocity.y = _jump_velocity
			
			global.spawn_effect(
				"res://Scenes/FX/jump_effect.tscn", 
				Vector2(0, 0), global_position, _character_texture.flip_h
			)
	else:
		_is_descending_platform = true
		_platform_descent_timer = PLATFORM_DESCENT_DURATION

func _vertical_movement(_delta: float) -> void:
	if is_on_floor():
		if _is_alive == false:
			if _can_play_dead_animation:
				_character_texture.action_animation("Dead_Hit")
				_can_play_dead_animation = false
				
				set_collision_layer_value(1, false)
				set_collision_mask_value(4, false)
				set_collision_layer_value(9, true)
				set_collision_mask_value(9, true)
			
			velocity.x = 0
			return
	
	# ✅ COYOTE TIME - Atualizar timer
	if is_on_floor():
		_coyote_time_remaining = COYOTE_TIME_DURATION
		_was_on_floor_last_frame = true
	else:
		if _was_on_floor_last_frame and velocity.y >= 0:
			_coyote_time_remaining = COYOTE_TIME_DURATION
			_was_on_floor_last_frame = false
		elif _coyote_time_remaining > 0.0:
			_coyote_time_remaining -= _delta
			if _coyote_time_remaining < 0.0:
				_coyote_time_remaining = 0.0
		
		if _was_on_floor_last_frame and velocity.y < 0:
			_coyote_time_remaining = 0.0
			_was_on_floor_last_frame = false
	
	if is_on_floor():
		_attack_air_count = 0
		if _on_floor == false:
			var has_movement_input = (
				Input.is_action_pressed("move_left") or 
				Input.is_action_pressed("move_right")
			)
			
			var has_action_input = (
				Input.is_action_just_pressed("jump") or
				Input.is_action_just_pressed("attack") or
				Input.is_action_just_pressed("dash") or
				Input.is_action_just_pressed("sub_weapon") or
				Input.is_action_just_pressed("parry") or
				Input.is_action_just_pressed("hook") or
				Input.is_action_pressed("move_down")
			)
			
			var just_finished_back_dash = (_character_texture.animation == "Back_Dash")
			
			global.spawn_effect(
				"res://Scenes/FX/fall_effect.tscn", 
				Vector2(0, 0), global_position, false
			)
			
			if _audio:
				_audio.play_land()
			
			ControllerVibration.vibrate_on_land()
			
			if (not has_movement_input and not has_action_input and not _character_texture._is_on_action) or just_finished_back_dash:
				_character_texture.action_animation("Land")
			
			_on_floor = true
	
	if not is_on_floor():
		velocity.y += _gravity * _gravity_multiplier * _delta
		_on_floor = false
	
	# ✅ BLOQUEAR SOLTAR PULO DURANTE CINEMÁTICA
	if not _is_in_cinematic:
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y = _jump_velocity/4
	
	# ✅ BLOQUEAR DESCIDA DE PLATAFORMA DURANTE CINEMÁTICA
	if not _is_in_cinematic:
		if Input.is_action_pressed("move_down") and Input.is_action_pressed("jump") and is_on_floor():
			if _ground_ray.is_colliding():
				var collider = _ground_ray.get_collider()
				if collider is TileMapLayer:
					var old_position = position.y
					position.y += 5
					call_deferred("_check_platform_descent", old_position)
					return
	
	# ✅ COYOTE TIME - Verificar se pode pular
	var can_jump = is_on_floor() or (_coyote_time_remaining > 0.0)
	
	# ✅ BLOQUEAR PULO DURANTE CINEMÁTICA
	if not _is_in_cinematic:
		if Input.is_action_just_pressed("jump") and (can_jump or _ground_ray.is_colliding()):
			if _is_crouching:
				_is_crouching = false
				_character_texture._is_on_action = false
			
			jump_origin = global_position 
			_attack_index = 1
			velocity.y = _jump_velocity
			
			# ✅ COYOTE TIME - Consumir o tempo ao pular
			_coyote_time_remaining = 0.0
			_was_on_floor_last_frame = false
			
			if _audio:
				_audio.play_jump()
			
			global.spawn_effect(
				"res://Scenes/FX/jump_effect.tscn", 
				Vector2(0, 0), global_position, _character_texture.flip_h
			)
	
	if is_on_floor() and _on_floor:
		_character_texture._update_collision_size()
	
	_character_texture._update_collision_size()

func _horizontal_movement() -> void:
	if _is_crouching:
		velocity.x = 0
		return
	
	if _skills.is_wall_jumping():
		return
	
	if _skills.is_enemy_stepping():
		return
	
	# ✅ NOVO: preservar momentum do dash-jump
	if _skills.is_dash_jumping():
		return
	
	
	# ✅ SEMPRE processar o boost (precisa rodar mesmo parado para o reset funcionar)
	var speed_bonus: float = _skills.process_speed_boost(_delta_cache)
	
	var _direction_aux = Input.get_axis("move_left", "move_right")
	if _direction_aux != 0:
		var target_speed = _speed + _additional_attributes["move_speed"] + speed_bonus
		
		if is_pushing_heavy_object:
			target_speed *= 0.25
		
		velocity.x = _direction_aux * target_speed
		_was_moving_last_frame = true
		return
	
	velocity.x = move_toward(velocity.x, 0, _speed)

func apply_push_force():
	is_pushing_heavy_object = false
	
	for objects in get_slide_collision_count():
		var collision = get_slide_collision(objects)
		var collider = collision.get_collider()
		
		
		if collider is Pushables or collider is PushableObjects:
			var normal = collision.get_normal()
			
			if abs(normal.x) > 0.7:
				is_pushing_heavy_object = true
				collider.slide_object(-normal)

func update_axe_state(_state: bool) -> void:
	_has_axe = _state

# ✅ ADICIONAR ESTAS FUNÇÕES:
func update_spear_state(_state: bool) -> void:
	if _subweapons:
		_subweapons.update_spear_state(_state)

func update_chakram_state(_state: bool) -> void:
	if _subweapons:
		_subweapons.update_chakram_state(_state)

func _attack_handler() -> void:
	if Input.is_action_just_pressed("attack"):
		attack_started.emit()
	
	if Input.is_action_just_pressed("sub_weapon"):
		print("🔘 SUB_WEAPON PRESSIONADO | _is_on_action: ", _character_texture._is_on_action, " | physics_processing: ", is_physics_processing())
	
	if Input.is_action_just_pressed("parry"):
		_character_texture.action_animation("Parry")
		
		# ✅ SOM MECÂNICO DO PARRY (imediato)
		if _audio:
			_audio.play_parry()
		
		set_physics_process(false)
		return
	
	if Input.is_action_just_pressed("sub_weapon") and not _character_texture._is_on_action:
		var used_subweapon = _subweapons.handle_sub_weapon_input()
		if used_subweapon:
			set_physics_process(false)
			return
	
	# ✅ ATAQUE NA PAREDE
	if Input.is_action_just_pressed("attack") and _skills.is_wall_sliding():
		_character_texture.action_animation("Attack_wall")
		
		if _audio:
			_audio.play_attack_voice()  # ✅ Grito
			_audio.play_attack_light()
		
		set_physics_process(false)
		_attack_combo.start()
		
		_in_combat_stance = true
		_combat_stance_timer.stop()
		_combat_stance_timer.start()
		return
	
	# ✅ ATAQUE AGACHADO
	if Input.is_action_just_pressed("attack") and is_on_floor():
		if _is_crouching:
			_character_texture.action_animation("AttackCrounch")
			
			if _audio:
				_audio.play_attack_voice()  # ✅ Grito
				_audio.play_attack_light()
			
			set_physics_process(false)
			_attack_combo.start()
			
			_in_combat_stance = true
			_combat_stance_timer.stop()
			_combat_stance_timer.start()
			return
		else:
			_attack_animation_handler("Attack_", 3)
			return
	
	# ✅ ATAQUE AÉREO
	if (
		Input.is_action_just_pressed("attack") and 
		not is_on_floor() and 
		not _skills.is_wall_sliding() and
		_attack_air_count < 2
	):
		_attack_animation_handler("Attack_Air_", 2, true)

func _attack_animation_handler(_prefix: String, index_limit: int, _on_air: bool = false) -> void:
	_character_texture.action_animation(_prefix + str(_attack_index))
	
	if _audio:
		# ✅ GRITO DO PERSONAGEM (40% de chance)
		_audio.play_attack_voice()
		
		# Som do swing do ataque
		if _on_air:
			_audio.play_attack_air()
		elif _attack_index == 3:
			_audio.play_attack_heavy()
		else:
			_audio.play_attack_light()
	
	_attack_index += 1
	if _attack_index == index_limit:
		_attack_index = 1
	
	set_physics_process(false)
	if _on_air:
		set_physics_process(true)
		_attack_air_count += 1
	_attack_combo.start()
	
	_in_combat_stance = true
	_combat_stance_timer.stop()
	_combat_stance_timer.start()

func play_animation(_anim_name: String) -> void:
	$Texture.action_animation(_anim_name)

func throw_axe(_is_flipped: bool) -> void:
	var _axe: ProjectileAxe = _AXE_PROJECTILE.instantiate()
	get_tree().root.call_deferred("add_child", _axe)
	_axe.global_position = global_position
	
	if _is_flipped:
		_axe.direction = Vector2(-1, 0)
		return
	
	_axe.direction = Vector2(1, 0)

# ✅ FRAGMENTO ATUALIZADO PARA Character.gd
# Cole este código substituindo as funções update_health, _handle_death e _respawn_at_save_point

# ✅ FRAGMENTO ATUALIZADO PARA Character.gd
# Cole este código substituindo as funções update_health, _handle_death e _respawn_at_save_point

func update_health(_value: int, _entity) -> void:
	# ✅ VERIFICAR INVENCIBILIDADE PRIMEIRO
	if _is_invincible:
		global.spawn_effect(
			"res://Scenes/FX/parry_effect.tscn", 
			Vector2(0, 0), global_position, _character_texture.flip_h
		)
		return
	
	# ✅ PARRY BEM-SUCEDIDO (momento exato do bloqueio)
	if _character_texture.on_parry:
		HitStopManager.hit_stop_short()
		
		var camera = get_tree().get_first_node_in_group("camera")
		camera.shake_camera(1, 0.5)
		
		if _audio:
			_audio.play_parry_success()
		
		global.spawn_effect(
			"res://Scenes/FX/parry_effect.tscn", 
			Vector2(0, 0), global_position, _character_texture.flip_h
		)
		
		if _entity.has_method("apply_parry_effect"):
			_entity.apply_parry_effect()
		
		if _parry_voice_timer:
			_parry_voice_timer.start(0.3)
		
		_character_texture.action_animation("Counter")
		return
	
	# ✅ ROLLING EVITA DANO
	if _skills.is_rolling():
		return
	
# ✅ SOM E EFEITOS DE HIT
	if _audio:
		_audio.play_hit()
	
	_particle_2d.restart()
	_particle_2d.emitting = true
	
	var camera = get_tree().get_first_node_in_group("camera")
	
	# ✅ SHAKE MENOR QUANDO NO AR (evita bug de zona)
	if not is_on_floor():
		camera.shake_camera(2, 0.15)  # ← REDUZIDO (era 5, 0.2)
	else:
		camera.shake_camera(5, 0.2)   # ← NORMAL NO CHÃO
	
	HitStopManager.hit_stop_medium()
	
	# ✅ VIBRAÇÃO DO CONTROLE AO RECEBER DANO
	ControllerVibration.vibrate_on_damage(_value, true)
	
	var _new_value: int = _value - _additional_attributes["defense"]
	_stats.current_health -= _new_value
	
	get_tree().call_group("bar_container", "update_bar", "HealthBar", _stats.current_health)
	
	# ✅ VERIFICAR SE A VIDA CHEGOU A ZERO
	if _stats.current_health <= 0:
		_is_alive = false
		_handle_death()
		return
	
	# ✅ INVENCIBILIDADE TEMPORÁRIA APÓS LEVAR DANO (evita múltiplos hits da mesma fonte)
	_activate_invincibility(0.6)
	
	print("🔍 ANTES DE TOCAR HIT:")
	print("  Position: ", global_position)
	print("  Velocity: ", velocity)
	
	# ✅ CRÍTICO: INVERTER A ORDEM - FÍSICA PRIMEIRO!
	var was_in_air = not is_on_floor()
	
	# ✅ SE ESTAVA NO AR, ATIVAR FÍSICA **ANTES** DA ANIMAÇÃO
	if was_in_air:
		set_physics_process(true)
		print("🔧 Hit no ar detectado - forçando física ativa ANTES da animação")
	
	# Tocar animação de hit
	_character_texture.action_animation("Hit")
	print("🔍 DEPOIS DE TOCAR HIT:")
	print("  Position: ", global_position)
	print("  Velocity: ", velocity)


# ✅ VERSÃO ATUALIZADA: Compatível com sistema Game.tscn
func _handle_death() -> void:
	if _audio:
		_audio.play_death()
	
	# ✅ CRÍTICO: Armazenar referência da árvore ANTES dos await
	var tree = get_tree()
	if not tree:
		return
	
	# ✅ NOVO: RESETAR MOEDAS PARA O VALOR DO ÚLTIMO SAVE
	if serialization.game_data.has("currencies"):
		# Restaurar para o valor que estava no último save
		global.currencies = serialization.game_data["currencies"].duplicate()
		global.currency_changed.emit("shards", global.currencies.get("shards", 0))
		print("💀 Morte: Moedas resetadas para último save: ", global.currencies)
	else:
		# Se não tem save, zerar
		global.currencies = {"shards": 0}
		global.currency_changed.emit("shards", 0)
		print("💀 Morte: Moedas zeradas (sem save)")
	
	# Desabilitar input do player
	set_physics_process(false)
	set_process_input(false)
	
	# Aguardar a animação de morte terminar
	await tree.create_timer(1.5).timeout
	
	# ✅ Verificar se ainda está válido após await
	if not is_instance_valid(self) or not tree:
		return
	
	# ✅ FADE IN (tela escurece)
	TransitionScreen.fade_out()
	await TransitionScreen.transition_finished
	
	# ✅ Verificar novamente após segundo await
	if not is_instance_valid(self) or not tree:
		return
	
	# Verificar se existe um save
	if not FileAccess.file_exists(serialization.save_path):
		_restart_from_beginning()
		return
	
	# Carregar os dados do save
	serialization.load_data()
	
	# ✅ NOVO: Verificar se a cena salva existe
	var saved_scene = serialization.game_data.get("current_scene", "")
	if saved_scene == "" or not ResourceLoader.exists(saved_scene):
		print("⚠️ Cena salva inválida ou inexistente: ", saved_scene)
		_restart_from_beginning()
		return
	
	print("🔄 Respawnando no save:")
	print("  - Cena: ", saved_scene)
	print("  - Save Area ID: ", serialization.game_data.get("save_area_id", "nenhuma"))
	print("  - Posição: ", serialization.game_data.get("position", Vector2.ZERO))
	
	# ✅ DESTRUIR MINIONS DO BAAL BERITH AO MORRER
	get_tree().call_group("berith_minions", "queue_free")
	
	# ✅ NOVO: Usar sistema Game.tscn em vez de trocar cena completa
	_respawn_at_save_point(saved_scene)

func _respawn_at_save_point(saved_level_path: String) -> void:
	"""Respawna o player no último save point com cena e posição corretas"""
	
	print("🔄 ========== INICIANDO RESPAWN ==========")
	
	# Pega referência ao Game.tscn
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		push_error("❌ Game main não encontrado!")
		_restart_from_beginning()
		return
	
	# ✅ 1. RESTAURAR VIDA E ESTADO DO PLAYER
	_stats.current_health = _stats.max_health
	_is_alive = true
	_can_play_dead_animation = true
	
	# Atualizar UI da barra de vida
	if global.ui_bars:
		global.ui_bars.update_bar("HealthBar", _stats.max_health)
	
	print("  ✓ Vida restaurada: ", _stats.max_health)
	
	# ✅ 2. REABILITAR COLISÕES E FÍSICA
	set_collision_layer_value(1, true)
	set_collision_mask_value(4, true)
	set_collision_layer_value(9, false)
	set_collision_mask_value(9, false)
	
	set_physics_process(true)
	set_process_input(true)
	
	print("  ✓ Física e input reabilitados")
	
	# ✅ 3. CARREGAR A CENA SALVA
	print("  🗺️ Carregando cena: ", saved_level_path)
	
	if game_main.has_method("load_level"):
		game_main.load_level(saved_level_path, "")
	else:
		push_error("❌ Game main não possui método load_level!")
		_restart_from_beginning()
		return
	
	# ✅ 4. AGUARDAR CENA CARREGAR
	await get_tree().create_timer(0.3).timeout
	
	# ✅ 5. VERIFICAR SE A CENA FOI CARREGADA CORRETAMENTE
	if global.current_scene_path != saved_level_path:
		push_error("❌ Falha ao carregar cena salva!")
		print("  - Esperado: ", saved_level_path)
		print("  - Atual: ", global.current_scene_path)
		_restart_from_beginning()
		return
	
	print("  ✓ Cena carregada com sucesso: ", global.current_scene_path)
	
	# ✅ 6. POSICIONAR PLAYER NA POSIÇÃO SALVA
	if serialization.game_data.has("position"):
		var saved_position = serialization.game_data["position"]
		global_position = saved_position
		print("  ✓ Player posicionado em: ", saved_position)
	else:
		push_warning("⚠️ Nenhuma posição salva encontrada")
	
	# ✅ 7. APLICAR TODOS OS DADOS DO SAVE (inventário, equipamentos, habilidades, etc)
	print("  🔄 Aplicando dados do save...")
	serialization.apply_loaded_data()
	
	# ✅ 8. FADE IN (tela clareia)
	await get_tree().create_timer(0.2).timeout
	TransitionScreen.fade_in_level()
	await TransitionScreen.transition_finished
	
	print("✅ ========== RESPAWN COMPLETO ==========")

func _restart_from_beginning() -> void:
	"""Reinicia o jogo do zero quando não há save válido"""
	
	print("🔄 ========== REINICIANDO DO INÍCIO ==========")
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		# Fallback: recarregar cena completa
		get_tree().reload_current_scene()
		return
	
	# Limpa dados do save
	serialization.reset_to_new_game()
	
	# Restaura vida
	_stats.current_health = _stats.max_health
	_is_alive = true
	_can_play_dead_animation = true
	
	# Atualizar UI
	if global.ui_bars:
		global.ui_bars.update_bar("HealthBar", _stats.max_health)
	
	# Reabilitar física
	set_physics_process(true)
	set_process_input(true)
	
	# Reabilitar colisões
	set_collision_layer_value(1, true)
	set_collision_mask_value(4, true)
	set_collision_layer_value(9, false)
	set_collision_mask_value(9, false)
	
	# ✅ CARREGAR PRIMEIRA FASE
	var initial_level = "res://Scenes/Fases/Tebes/tebes_1_1.tscn"
	print("  🗺️ Carregando fase inicial: ", initial_level)
	
	if game_main.has_method("load_level"):
		game_main.load_level(initial_level, "")
	
	# Fade in
	await get_tree().create_timer(0.3).timeout
	TransitionScreen.fade_in_level()
	
	print("✅ ========== JOGO REINICIADO ==========")

func _activate_invincibility(duration: float) -> void:
	if _is_invincible:
		return
	
	_is_invincible = true
	set_collision_mask_value(4, false)
	# layer 7 (Enemy Body) permanece ativa — bloqueia HazardBlocker
	
	if not _character_texture or not _character_texture.material:
		_invencibility_timer.wait_time = duration
		_invencibility_timer.start()
		return
	
	_character_texture.modulate.a = 0.7
	_start_blink_effect(duration)
	_invencibility_timer.wait_time = duration
	_invencibility_timer.start()

func _start_blink_effect(duration: float) -> void:
	var blink_interval = 0.1
	var elapsed_time = 0.0
	
	while elapsed_time < duration:
		if not _is_invincible:
			_set_shader_blink_intensity(0.0)
			return
		
		# Piscar ON
		_set_shader_blink_intensity(1.0)
		await get_tree().create_timer(blink_interval).timeout
		elapsed_time += blink_interval
		
		if not _is_invincible or elapsed_time >= duration:
			_set_shader_blink_intensity(0.0)
			return
		
		# Piscar OFF
		_set_shader_blink_intensity(0.0)
		await get_tree().create_timer(blink_interval).timeout
		elapsed_time += blink_interval
	
	# Garantir que volta ao normal
	_set_shader_blink_intensity(0.0)

func _set_shader_blink_intensity(new_value: float) -> void:
	if not _character_texture:
		return
	
	if not _character_texture.material:
		return
	
	if not _character_texture.material.shader:
		return
	
	# Ativar/desativar blink + definir intensidade
	_character_texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	_character_texture.material.set_shader_parameter("blink_intensity", new_value)

func _on_invencibility_timer_timeout() -> void:
	_is_invincible = false
	set_collision_mask_value(4, true)
	# layer 7 já estava ativa, não precisa reativar
	
	if _character_texture:
		_character_texture.modulate.a = 1.0


func petrify(_area) -> void:
	_character_texture.action_animation("Petrificado")
	set_physics_process(false)
	is_petrified = true
	stun_area = _area

func consume(_item_data: Dictionary) -> void:
	if is_consuming:
		return
	
	is_consuming = true
	
	# ✅ ATIVAR PARTÍCULAS DE CURA
	if _heal_1:
		_heal_1.emitting = true
	if _heal_2:
		_heal_2.emitting = true
	
	_character_texture.action_animation("Heal")
	set_physics_process(false)
	
	# ✅ AGUARDAR ANIMAÇÃO HEAL TERMINAR
	await _character_texture.animation_finished
	
	# ✅ CURAR APÓS A ANIMAÇÃO
	if _item_data.has("value"):
		_stats.update_health("increase", _item_data["value"])
	
	# ✅ DESATIVAR PARTÍCULAS APÓS CURA
	if _heal_1:
		_heal_1.emitting = false
	if _heal_2:
		_heal_2.emitting = false
	
	is_consuming = false
	set_physics_process(true)

func collect_item(_item: Dictionary, _equip_directly: bool = false) -> void:
	_inventory.add_item(_item, _equip_directly)
	

func get_additional_attack() -> int:
	return _additional_attributes["attack"]

func _on_attack_combo_timeout():
	_attack_index = 1

func is_player_alive() -> bool:
	return _is_alive


func _on_throw_cooldown_timeout() -> void:
	_has_axe = true

func animation_includes_combat() -> bool:
	var anim = _character_texture.animation
	return (anim.begins_with("Attack_") or 
			anim.begins_with("Throw_") or 
			anim == "Rolling" or 
			anim == "Back_Dash" or 
			anim == "AttackCrounch")

func _on_combat_stance_timer_timeout() -> void:
	# ✅ VERIFICAR INPUT DE MOVIMENTO (mais confiável que velocity.x)
	var movement_input = Input.get_axis("move_left", "move_right")
	
	var any_input = (
		Input.is_action_pressed("move_left") or 
		Input.is_action_pressed("move_right") or
		Input.is_action_pressed("jump") or
		Input.is_action_pressed("attack") or
		Input.is_action_pressed("dash") or
		Input.is_action_pressed("sub_weapon")
	)
	
	# ✅ SAIR DO COMBAT STANCE apenas se:
	# - NÃO tem input nenhum
	# - NÃO está se movendo (velocity.x)
	# - NÃO tem input de movimento (mais importante)
	# - Está no chão
	if not any_input and velocity.x == 0 and movement_input == 0 and is_on_floor():
		_in_combat_stance = false
	else:
		_combat_stance_timer.start()

func _on_hook_timer_timeout() -> void:
	_on_hook = false

func _on_combo_timer_timeout() -> void:
	pass

func _on_attack_1_timer_timeout() -> void:
	pass
	
	
func update_fire_state(state: bool) -> void:
	if _subweapons:
		_subweapons.update_fire_state(state)


func _on_parry_voice_timer_timeout() -> void:
	"""Toca a voz do counter após 0.3 segundos do parry bem-sucedido"""
	if _audio:
		_audio.play_counter_voice()  # ✅ Novo nome

func update_map_state(state: bool) -> void:
	_has_map = state

func update_dagger_state(_state: bool) -> void:
	if _subweapons:
		_subweapons.update_dagger_state(_state)

func trigger_rainbow_shine(duration: float = 1.0) -> void:
	_activate_rainbow_shine(duration)
	RainbowEcho.spawn(_character_texture, get_tree().current_scene)

func _activate_rainbow_shine(duration: float) -> void:
	if not _character_texture or not _character_texture.material:
		return
	
	if not _character_texture.material.shader:
		return
	
	_character_texture.material.set_shader_parameter("rainbow_active", true)
	
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_end_rainbow_shine)

func _end_rainbow_shine() -> void:
	if not is_instance_valid(self):
		return
	
	if _character_texture and _character_texture.material:
		_character_texture.material.set_shader_parameter("rainbow_active", false)
