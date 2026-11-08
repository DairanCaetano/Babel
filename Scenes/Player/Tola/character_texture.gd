extends AnimatedSprite2D
class_name CharacterTexture

var _is_on_action: bool = false
var _can_cancel_attack: bool = false
var _is_in_rest_state: bool = false

var target

var _is_transitioning_scene: bool = false

var _is_turning: bool = false  # Apenas para controle visual da animação

var _is_start_run_playing: bool = false
var _is_stop_run_playing: bool = false
var _was_moving: bool = false

var on_parry: bool = false
var on_hook_attack: bool = false

var is_wall_sliding: bool = false

@export_category("Objects")
@export var _character: BaseCharacter
@export var _attack_area_collision: CollisionShape2D
@export var _character_subweapon: Node2D
@export var facing_right = true

# ========== GHOST TRAIL ==========
@export var ghost_trail_scene: PackedScene
var _ghost_timer: float = 0.0
@export var ghost_interval: float = 0.05

func _ready() -> void:
	# Garantir que o material seja único e tenha shader
	if material:
		material = material.duplicate()
	
	set_process(true)

func _process(_delta: float) -> void:
	if _can_cancel_attack and animation == "Attack_1" and (frame == 3 or frame == 4):
		_check_attack_cancellation()
	
	_check_animation_state()
	
	# ✅ PROTEÇÃO: speed_scale correto quando NÃO está na escada
	# (1.0 normal, ou acelerado nos ataques com Olhos de Falcão)
	var _expected_speed: float = _get_expected_speed_scale()
	if _character and not _character._on_ladder:
		if not is_equal_approx(get_speed_scale(), _expected_speed):
			set_speed_scale(_expected_speed)

# ✅ GHOST TRAIL ao atingir velocidade máxima ou ao atacar com Olhos de Falcão
	var _fast_attack: bool = _expected_speed > 1.0 and _is_fast_attack_animation(animation) and is_playing()
	if _fast_attack or (_character and _character._skills and _character._skills.get_speed_boost_ratio() >= 0.8):
		_ghost_timer += get_process_delta_time()
		if _ghost_timer >= ghost_interval:
			_spawn_ghost_trail()
			_ghost_timer = 0.0
	else:
		_ghost_timer = 0.0

# ========== OLHOS DE FALCÃO (velocidade de ataque) ==========
func _is_fast_attack_animation(anim_name: String) -> bool:
	"""Ataques no chão e no ar. Parry e Counter NÃO são acelerados."""
	return anim_name.begins_with("Attack_") or anim_name == "AttackCrounch"

func _get_expected_speed_scale() -> float:
	if _character and _is_fast_attack_animation(animation) and _character.has_method("get_attack_speed_multiplier"):
		return _character.get_attack_speed_multiplier()
	return 1.0

func _check_animation_state() -> void:
	if (animation == "Rolling" or animation == "Back_Dash") and not _is_on_action:
		_is_on_action = true
		print("Corrigindo estado de roll: _is_on_action reativado")
	
	if _character.is_physics_processing() and _is_on_action:
		var movement_animations = ["Idle", "Idle_Combat", "Run", "Jump", "Fall", "Wall_Slide", "Crounch"]
		if animation in movement_animations:
			print("Corrigindo estado inconsistente: _is_on_action resetado para ", animation)
			_is_on_action = false
	
	if not _is_on_action and not _character.is_physics_processing():
		var physics_disabled_animations = ["Dead_Hit", "Dead_Ground", "Petrificado", "Heal", "GetMap", "CloseMap"]
		var valid_exceptions = (
			animation in physics_disabled_animations or 
			_character.is_petrified or 
			_character._skills.is_on_hook() or  # ✅ CORRIGIDO
			_character.is_consuming
		)
		
		if not valid_exceptions:
			print("Corrigindo physics desabilitado incorretamente para ", animation)
			_character.set_physics_process(true)
			animate(_character.velocity)
			
	if _is_transitioning_scene:
		return  # Não fazer nenhuma correção durante transição de cena

func _check_attack_cancellation() -> void:
	var cancel_actions = [
		"jump", "dash", "attack", "sub_weapon", 
		"parry", "hook", "move_down"
	]
	
	for action in cancel_actions:
		if Input.is_action_just_pressed(action):
			_cancel_current_attack()
			_handle_cancel_action(action)
			return
	
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_cancel_current_attack()

func _cancel_current_attack() -> void:
	_can_cancel_attack = false
	_attack_area_collision.set_deferred("disabled", true)
	_is_on_action = false
	_character.set_physics_process(true)
	print("Ataque cancelado no frame: ", frame)

func _handle_cancel_action(action: String) -> void:
	match action:
		"jump":
			if _character.is_on_floor():
				_character._attack_index = 1
				_character.velocity.y = _character._jump_velocity
				global.spawn_effect(
					"res://Scenes/FX/jump_effect.tscn", 
					Vector2(0, 0), global_position, flip_h
				)
		"dash":
			# ✅ CORRIGIDO: Delegar para CharacterSkills
			if _character.is_on_floor():
				_character._skills.handle_dash_input()
		"attack":
			_character._attack_animation_handler("Attack_", 3)
		"sub_weapon":
			if _character._has_axe and _character._stats.current_stamina >= 3:
				action_animation("Throw_")
		"parry":
			action_animation("Parry")
		"hook":
			# ✅ CORRIGIDO: Delegar para CharacterSkills
			_character._skills.handle_hook_input()
		"move_down":
			if _character.is_on_floor():
				_character._is_crouching = true
				action_animation("Crounch")
				_update_collision_size()

func animate(_velocity: Vector2) -> void:
	# ✅ IGNORAR VERIFICAÇÃO DE DIREÇÃO DURANTE ESTADOS ESPECIAIS
	if animation != "Rolling" and animation != "Back_Dash" and animation != "Grab":
		_verify_direction(_velocity.x)
	
	# ✅ PRIORIDADE MÁXIMA: SE ESTÁ EM LEDGE GRAB, PARAR TUDO
	if _character.on_ledge:
		if animation != "Grab":
			play("Grab")
			_is_on_action = true
		return
	
	# ✅ VERIFICAR SE ESTÁ EM COMBAT STANCE
	if _character._in_combat_stance and animation == "Idle_Combat":
		return
	
	if _is_in_rest_state or _is_on_action:
		return
	
	if _character._is_crouching and _character._on_floor:
		if animation != "Crounch":
			play("Crounch")
		return
	
	# ✅ CALCULAR is_moving BASEADO EM INPUT QUANDO EMPURRANDO
	var is_moving: bool
	if _character.is_pushing_heavy_object:
		var input_dir = Input.get_axis("move_left", "move_right")
		is_moving = abs(input_dir) > 0.1
	else:
		is_moving = abs(_velocity.x) > 0.1
	
	# ✅ CORRIGIDO: Usar CharacterSkills para verificar wall sliding
	var remote_wall_sliding := false
	if _character and _character._skills:
		remote_wall_sliding = _character._skills.is_wall_sliding()
	
	if (is_wall_sliding or remote_wall_sliding) and not _character._on_floor and _velocity.y > 0:
		if animation != "Wall_Slide":
			play("Wall_Slide")
		return
	
	# ✅ MODIFICADO: NÃO CHAMAR StartRun SE ESTÁ EMPURRANDO
	if !_was_moving and is_moving and _character._on_floor:
		if not _character.is_pushing_heavy_object:
			_is_on_action = true
			_is_start_run_playing = true
			play("StartRun")
		else:
			play("Run")
		_was_moving = true
		return
	
	# ✅ MODIFICADO: NÃO CHAMAR StopRun SE ESTÁ EMPURRANDO
	if _was_moving and !is_moving and _character._on_floor:
		if not _character.is_pushing_heavy_object:
			_is_on_action = true
			_is_stop_run_playing = true
			play("StopRun")
		else:
			play("Idle")
		_was_moving = false
		return
	
	if not _character._on_floor:
		if _velocity.y < 0:
			play("Jump")
		else:
			play("Fall")
		return
	
	if is_moving:
		var boost_ratio = _character._skills.get_speed_boost_ratio()
		if boost_ratio >= 0.8:
			if animation != "Run_Fast":
				play("Run_Fast")
		else:
			if animation != "Run" and animation != "Run_Fast":
				play("Run")
			elif animation == "Run_Fast":
				play("Run")
	else:
		play("Idle")

func _verify_direction(_direction: float) -> void:
	# ✅ NOVA LÓGICA: Flip IMEDIATO + Turn como efeito visual
	
	if _direction > 0:
		# Detectar mudança de direção
		if not facing_right and _character.is_on_floor() and not _is_on_action:
			print("🔄 Mudança detectada: virando para DIREITA")
			
			# ✅ 1. ATUALIZAR DIREÇÃO IMEDIATAMENTE
			facing_right = true
			flip_h = false
			_update_positions_for_right()
			
			# ✅ 2. EXECUTAR TURN COMO EFEITO VISUAL
			_trigger_turn_animation()
			return
		
		# Atualização normal sem Turn
		facing_right = true
		flip_h = false
		_update_positions_for_right()
		
	elif _direction < 0:
		# Detectar mudança de direção
		if facing_right and _character.is_on_floor() and not _is_on_action:
			print("🔄 Mudança detectada: virando para ESQUERDA")
			
			# ✅ 1. ATUALIZAR DIREÇÃO IMEDIATAMENTE
			facing_right = false
			flip_h = true
			_update_positions_for_left()
			
			# ✅ 2. EXECUTAR TURN COMO EFEITO VISUAL
			_trigger_turn_animation()
			return
		
		# Atualização normal sem Turn
		facing_right = false
		flip_h = true
		_update_positions_for_left()
	
	_update_collision_size()

# ✅ CORRIGIDO: Usar valores do Inspector
# ✅ CORRIGIDO: Usar valores do Inspector
func _update_positions_for_right() -> void:
	_attack_area_collision.position.x = 20
	_character._wall_ray.target_position = Vector2(10, 0)
	_character._character_collision.position.x = -1
	_character._neck_anchor.position.x = -3
	
	# ✅ LADDER RAY - Direção DIREITA
	if _character._ladder_ray:
		_character._ladder_ray.target_position = Vector2(7, 0)
	
	# ✅ LEDGE GRAB - Direção DIREITA (valores do Inspector)
	if _character._ledge_grab_hit:
		_character._ledge_grab_hit.position = Vector2(2, -14)
		_character._ledge_grab_hit.target_position = Vector2(5, 0)
	
	if _character._ledge_grab_miss:
		_character._ledge_grab_miss.position = Vector2(1, -22)
		_character._ledge_grab_miss.target_position = Vector2(10, 0)

# ✅ CORRIGIDO: Usar valores do Inspector
func _update_positions_for_left() -> void:
	_attack_area_collision.position.x = -20
	_character._wall_ray.target_position = Vector2(-10, 0)
	_character._character_collision.position.x = 1
	_character._neck_anchor.position.x = 3
	
	# ✅ LADDER RAY - Direção ESQUERDA
	if _character._ladder_ray:
		_character._ladder_ray.target_position = Vector2(-7, 0)
	
	# ✅ LEDGE GRAB - Direção ESQUERDA (valores invertidos)
	if _character._ledge_grab_hit:
		_character._ledge_grab_hit.position = Vector2(-2, -14)
		_character._ledge_grab_hit.target_position = Vector2(-5, 0)
	
	if _character._ledge_grab_miss:
		_character._ledge_grab_miss.position = Vector2(-1, -22)
		_character._ledge_grab_miss.target_position = Vector2(-10, 0)
	

func _trigger_turn_animation() -> void:
	# ✅ Turn agora é APENAS cosmético - direção já está correta!
	print("✨ Executando Turn (cosmético) - facing_right:", facing_right)
	_is_turning = true
	_is_on_action = true
	play("Turn")

func _update_collision_size() -> void:
	if _character._is_crouching:
		_character._character_collision.shape.size.y = 20
		_character._character_collision.position.y = 6
	else:
		_character._character_collision.shape.size.y = 30
		_character._character_collision.position.y = 1

func set_wall_sliding(sliding: bool) -> void:
	is_wall_sliding = sliding
	animate(_character.velocity)

func action_animation(_action_name: String, _previous_frame: int = 0) -> void:
	if _action_name == "FrontFlip":
		_is_on_action = true
		play(_action_name)
		return
	
	if _action_name == "Crounch":
		play(_action_name)
		return
	
	if _action_name == "Land":
		_is_on_action = true
		play(_action_name)
		return
	
	if _action_name == "Rest":
		_is_in_rest_state = true
		_is_on_action = true
		play(_action_name)
		return
	
	if _action_name == "Rise":
		_is_in_rest_state = false
		_is_on_action = true
		play(_action_name)
		return
	
	if _action_name == "Resting":
		_is_in_rest_state = true
		play(_action_name)
		return
	
	if _action_name == "Rolling" or _action_name == "Back_Dash":
		_is_on_action = true
		play(_action_name)
		return
	
	if _action_name == "Fire":
		_is_on_action = true
		play(_action_name)
		return
	
	_is_on_action = true
	
	if _action_name == "Attack_1":
		_can_cancel_attack = true
	else:
		_can_cancel_attack = false
	
	if (
		_action_name == "Hit" or
		_action_name == "Dead_Hit" or 
		_action_name == "Dead_Ground"
	):
		_attack_area_collision.set_deferred("disabled", true)
	
	if _action_name == "Throw_":
		play(_action_name)
		return
	
	# ✅ SPAWNAR EFEITOS DE FOGO DURANTE ATAQUES
	if _character_subweapon:
		var attack_type = ""
		if _action_name == "Attack_1" or _action_name == "Attack_Crit":
			attack_type = "Attack_1"
		elif _action_name.contains("Attack_Air"):
			attack_type = "Attack_Air"
		elif _action_name == "Attack_2":
			attack_type = "Attack_2"
		elif _action_name == "Counter":
			attack_type = "Counter"
		
		if attack_type != "":
			_character_subweapon.spawn_fire_attack_effect(attack_type)
	
	# ✅ TOCAR ANIMAÇÃO
	play(_action_name)
	
	# 💥 Crítico aéreo: área de dano liga já no frame 0
	if _action_name == "Attack_Air_Crit":
		_attack_area_collision.set_deferred("disabled", false)
	
	# ✅ OLHOS DE FALCÃO: acelera só os ataques no chão e no ar
	if _character and not _character._on_ladder:
		set_speed_scale(_get_expected_speed_scale())
	
	if _previous_frame != 0:
		frame = 14 - _previous_frame
	
	# ✅ RESETAR LISTA DE HITS NO INÍCIO DE QUALQUER ATAQUE
	if _action_name.begins_with("Attack_") or _action_name == "Counter" or _action_name == "AttackCrounch":
		var attack_area = _attack_area_collision.get_parent()
		if attack_area and attack_area.has_method("start_new_attack"):
			attack_area.start_new_attack()
	

func _on_animation_finished():
	if animation == "Grab":
		return
	
	if animation == "FrontFlip":
		_is_on_action = false
		
		if _character._skills:
			if _character._skills._is_dash_jump_flip:
				_character._skills._is_dash_jump_flip = false
			else:
				_character._skills.reset_enemy_step_state()
		
		if _character.is_on_floor():
			if _character.velocity.length() > 0.1:
				play("Run")
			else:
				play("Idle")
		else:
			if _character.velocity.y > 0:
				play("Fall")
			else:
				play("Jump")
		return
	
	if animation == "StartRun":
		_is_start_run_playing = false
		_is_on_action = false
		if abs(_character.velocity.x) > 0.1 and _character._on_floor:
			play("Run")
		else:
			play("Idle")
		return
	
	if animation == "StopRun":
		_is_stop_run_playing = false
		_is_on_action = false
		if abs(_character.velocity.x) > 0.1 and _character._on_floor:
			play("Run")
		else:
			play("Idle")
		return
	
	if animation == "Rolling" or animation == "Back_Dash":
		_is_on_action = false
		_character.set_physics_process(true)
		
		var current_input = Input.get_axis("move_left", "move_right")
		if current_input != 0:
			_verify_direction(current_input)
		
		if _character.velocity.length() > 0.1:
			if _character.velocity.y > 0:
				play("Fall")
			elif _character.velocity.y < 0:
				play("Jump")
			else:
				play("Run")
		else:
			if _character.is_on_floor():
				if _character._in_combat_stance:
					play("Idle_Combat")
				else:
					play("Idle")
			else:
				play("Fall")
		return
	
	if animation == "Throw_":
		_is_on_action = false
		_character.set_physics_process(true)
		if _character.velocity.length() < 0.1:
			play("Idle_Combat")
		return

	if animation == "Throw_Spear":
		_is_on_action = false
		_character.set_physics_process(true)
		if _character.velocity.length() < 0.1:
			play("Idle_Combat")
		return
	
	if animation == "Fire":
		_is_on_action = false
		_character.set_physics_process(true)
		if _character.velocity.length() < 0.1:
			play("Idle")
		else:
			animate(_character.velocity)
		return
	
	if animation == "Hit":
		_is_on_action = false
		_character.set_physics_process(true)
		
		if _character.is_player_alive():
			_character._activate_invincibility(1.5)
		
		if not _character.is_on_floor():
			if _character.velocity.y > 0:
				play("Fall")
			else:
				play("Jump")
		else:
			if abs(_character.velocity.x) > 0.1:
				play("Run")
			else:
				play("Idle")
		return
	
	_can_cancel_attack = false
	
	if animation == "Land":
		_is_on_action = false
		play("Idle")
		return
	
	if animation.begins_with("Attack_"):
		_attack_area_collision.set_deferred("disabled", true)
	
	if animation.begins_with("Whip_") and animation != "Whip_Spin":
			if _character_subweapon and _character_subweapon.has_method("try_continue_into_spin"):
				if _character_subweapon.try_continue_into_spin():
					return  # ✅ entrou no giro, não retorna ao idle
			
			_is_on_action = false
			_character.set_physics_process(true)
			if _character.velocity.length() < 0.1:
				play("Idle_Combat")
			else:
				animate(_character.velocity)
			return
	
	if animation == "HookRope":
		_character.get_node("HookRay/Animation").play("RESET")
		_is_on_action = false
	
	if animation == "Hook":
		action_animation("HookRope")
		return
	
	if animation == "HookPuxao" or animation == "RollingSpecial":
		_is_on_action = false
		_character.set_physics_process(true)
		return
	
	if animation == "Rest":
		_is_on_action = false
		return
	
	if animation == "Rise":
		_is_in_rest_state = false
		_is_on_action = false
		_character.is_consuming = false
		return
	
	if animation == "Idle_Combat":
		play("Idle")
		return
	
	if animation == "Turn":
		_is_turning = false
		_is_on_action = false
		
		var current_velocity = _character.velocity
		if abs(current_velocity.x) > 0.1:
			play("Run")
		else:
			play("Idle")
		return
	
	_is_on_action = false
	_character.set_physics_process(true)
	_character.is_consuming = false
	
	if animation.begins_with("Attack_") or animation == "Counter" or animation == "Parry":
		if on_hook_attack:
			on_hook_attack = false
			_trigger_hook_back_dash()
			return
		
		on_parry = false
		on_hook_attack = false
		_character._in_combat_stance = true
		_character._combat_stance_timer.stop()
		_character._combat_stance_timer.start()
		
		if _character.velocity.length() < 0.1 and _character.is_on_floor() and animation != "Attack_Crounch_Crit":
			play("Idle_Combat")
	
	if animation == "AttackCrounch" or animation == "Attack_Crounch_Crit":
		_attack_area_collision.set_deferred("disabled", true)

func _on_frame_changed() -> void:
	if animation == "Rolling" and frame >= 2:
		_character._skills.notify_dash_frame(frame)
	
	if animation == "Heal":
		if frame == 5 or frame == 6 or frame == 7:
			_set_shader_blink_intensity(1.0)
			await get_tree().create_timer(0.1).timeout
			_set_shader_blink_intensity(0.0)
	
	if animation == "Parry":
		if frame == 2:
			on_parry = true
			_set_shader_blink_intensity(1.0)
			await get_tree().create_timer(0.1).timeout
			_set_shader_blink_intensity(0.0)
		else:
			_set_shader_blink_intensity(0.0)
	
	if animation == "Hook" and frame == 2:
		if flip_h:
			_character.get_node("HookRay/Animation").play("expand_left")
		if not flip_h:
			_character.get_node("HookRay/Animation").play("expand_right")
	
	if animation == "Throw_" and frame == 2:
		if global.ui_equipments._equipments_inventory["weapon"].is_empty():
			return
		
		var weapon_key = global.ui_equipments._equipments_inventory["weapon"].get("key", "")
		
		if weapon_key == "ITEM_AXE_NAME":
			_character._subweapons.throw_axe(flip_h)
		elif weapon_key == "ITEM_CHAKRAM_NAME":
			_character._subweapons.throw_chakram(flip_h)
		elif weapon_key == "ITEM_DAGGER_NAME":
			_character._subweapons.throw_dagger(flip_h)
	
	if animation == "Throw_Spear" and frame == 2:
		_character._subweapons.throw_spear(flip_h)
	
	if animation == "Parry":
		if frame == 2 or frame == 4:
			on_parry = true
	
	if animation == "AttackCrounch":
		if frame == 2:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 4:
			_attack_area_collision.set_deferred("disabled", true)
	
	# 💥 Som de impacto do crítico: frame 1 (depois do 0), padrão dos ataques
	if animation.ends_with("_Crit") and frame == 1:
		if _character and _character._audio and _character._audio.has_method("play_crit_impact"):
			_character._audio.play_crit_impact()
	
	# 💥 CRÍTICOS (antes das regras gerais)
	if animation == "Attack_Air_Crit":       # 3 frames: dano nos frames 0–1
		if frame == 0:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 2:
			_attack_area_collision.set_deferred("disabled", true)
	
	elif animation == "Attack_Crit" or animation == "Attack_Crounch_Crit":   # dano nos frames 1–2
		if frame == 1:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 3:
			_attack_area_collision.set_deferred("disabled", true)
	
	elif animation.begins_with("Attack_Air"):
		if frame == 0:
			_attack_area_collision.set_deferred("disabled", true)
		elif frame == 1:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 2:
			_attack_area_collision.set_deferred("disabled", true)

	elif animation == "Attack_wall" or animation == "Attack_Wall_Crit":
		if frame == 1:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 3:
			_attack_area_collision.set_deferred("disabled", true)

	elif animation.begins_with("Attack_"):  # apenas Attack_1, Attack_2, Attack_3
		if frame == 2:
			_attack_area_collision.set_deferred("disabled", false)
		elif frame == 4:
			_attack_area_collision.set_deferred("disabled", true)
	
	if animation.begins_with("Counter"):
		if frame == 5:
			_attack_area_collision.set_deferred("disabled", false)
			if _character and _character._audio:
				_character._audio.play_counter()
		elif frame == 6:
			_attack_area_collision.set_deferred("disabled", true)
	
	if animation.begins_with("Attack_"):
		if _character and _character._subweapons:
			if _character._subweapons.is_fire_active():
				var impact_frames = {
					"Attack_1": 3,
					"Attack_2": 3,
					"Attack_3": 4,
					"Attack_Air_1": 2,
					"Attack_Air_2": 2,
					"Attack_Crit": 2,
					"Attack_Air_Crit": 1,
					"Attack_Crounch_Crit": 2
				}
				if impact_frames.has(animation) and frame == impact_frames[animation]:
					if _character._audio:
						_character._audio.play_fire_attack_extra()
						print("🔥 Som extra de fogo tocado no frame ", frame)
	
	if animation == "Run":
		if frame == 1 or frame == 4:
			global.spawn_effect(
				"res://Scenes/FX/run_effect.tscn",
				Vector2(0, 0), global_position, self.flip_h
			)
	
	if animation == "Run_Fast":
		if frame == 1 or frame == 4:
			global.spawn_effect(
				"res://Scenes/FX/run_effect.tscn",
				Vector2(0, 0), global_position, self.flip_h
			)
	
	if animation == "Rolling" or animation == "Back_Dash":
		if frame == 0:
			global.spawn_effect(
				"res://Scenes/FX/run_effect.tscn",
				Vector2(0, 0), global_position, self.flip_h
			)

func _set_shader_blink_intensity(new_value: float) -> void:
	if not material:
		return
	
	if not material.shader:
		return
	
	material.set_shader_parameter("blink_active", new_value > 0.0)
	material.set_shader_parameter("blink_intensity", new_value)

func freeze_animation() -> void:
	# ✅ CONGELA A ANIMAÇÃO NO FRAME ATUAL (mantém o frame visível)
	# APENAS para uso na escada!
	set_speed_scale(0.0)

func unfreeze_animation() -> void:
	# ✅ RETORNA A VELOCIDADE NORMAL DA ANIMAÇÃO
	set_speed_scale(1.0)

func _trigger_hook_back_dash() -> void:
	# ✅ CORRIGIDO: Delegar para CharacterSkills
	_character.velocity.x = 0
	_character._skills.handle_dash_input()
	
	await get_tree().process_frame
	_character.velocity.x *= 2.0

func _spawn_ghost_trail() -> void:
	if not ghost_trail_scene:
		return
	
	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(self)
