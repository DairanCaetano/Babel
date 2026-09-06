extends BaseEnemy
class_name Snake

var _can_attack: bool = true
var _queued_to_die: bool = false
var _attack_state: int = 0
var _is_player_on_right: bool = false  # ✅ NOVA VARIÁVEL
var _current_facing_right: bool = false  # ✅ Rastreia direção atual para evitar mudanças bruscas

@onready var _objects: Array = [
	$HeadNNeck/Head, $HeadNNeck/Neck1, $HeadNNeck/Neck2, $HeadNNeck/Neck3, $HeadNNeck/Neck4, $HeadNNeck/Neck5
]

var _multipliers_data: Array = [
	64, 40, 24, 10, 2, 1 
]

var _attack_multipliers: Array = [
	1.0,    # Head - movimento completo (100%)
	0.786,  # Neck1 - ~78.6% do movimento
	0.572,  # Neck2 - ~57.2% do movimento
	0.358,  # Neck3 - ~35.8% do movimento
	0.144,  # Neck4 - ~14.4% do movimento
	0.02    # Neck5 - APENAS 2% do movimento (quase imóvel)
]

var _idle_positions: Array = [
	Vector2(-45, -2),  # Head
	Vector2(-24, 0),   # Neck1
	Vector2(-12, 0),   # Neck2
	Vector2(-4, 0),    # Neck3
	Vector2(13, 0),    # Neck4
	Vector2(20, 0)     # ✅ Neck5 - mais próximo do corpo
]

var _special_attack_positions: Array = [
	Vector2(15, -90),   # Head
	Vector2(10, -65),   # Neck1
	Vector2(5, -45),    # Neck2
	Vector2(0, -25),    # Neck3
	Vector2(13, -2),    # Neck4
	Vector2(20, -1)     # ✅ Neck5 - movimento mínimo
]

# ✅ POSIÇÕES DO ATAQUE 2 - PÊNDULO CIRCULAR
var _attack_2_positions: Array = [
	Vector2(100, -4),   # Pos 1: Direita baixo
	Vector2(10, -100),  # Pos 2: Centro alto
	Vector2(-100, -4),  # Pos 3: Esquerda baixo
	Vector2(10, -100),  # Pos 4: Centro alto (volta)
	Vector2(100, -4)    # Pos 5: Direita baixo (completa ciclo)
]

var _attack_2_rotations: Array = [0, 90, 180, 270, 360]


@export_category("Snake Audio")
@export var _attack_start_audio: AudioStreamPlayer
@export var _attack_1_audio: AudioStreamPlayer
@export var _attack_2_audio: AudioStreamPlayer
@export var _attack_special_audio: AudioStreamPlayer

@export_category("Stats")
@export var _attack_damage: int = 10
@export var snake_health: int = 30

func _ready() -> void:
	super._ready()
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_enemy_health = snake_health
	
	print("🐍 === SNAKE INICIALIZADA ===")
	
	# ✅ CONECTAR HURTBOX DO CORPO (SnakeHurtbox na raiz)
	print("🐍 === VERIFICANDO HURTBOX DO CORPO ===")
	
	if has_node("SnakeHurtbox"):
		var body_hurtbox = get_node("SnakeHurtbox")
		print("   ✅ CORPO encontrado: SnakeHurtbox")
		print("   - Collision Layer: ", body_hurtbox.collision_layer)
		print("   - Collision Mask: ", body_hurtbox.collision_mask)
		
		# Conectar sinais do corpo
		body_hurtbox.area_entered.connect(_on_snakebody_area_entered)
		body_hurtbox.body_entered.connect(_on_snakebody_body_entered)
		print("✅ Sinais do CORPO conectados!")
	elif _hurtbox_detection:
		print("   ⚠️ Usando _hurtbox_detection como corpo")
		_hurtbox_detection.area_entered.connect(_on_snakebody_area_entered)
		_hurtbox_detection.body_entered.connect(_on_snakebody_body_entered)
		print("✅ Sinais do CORPO conectados via _hurtbox_detection!")
	else:
		print("❌ Hurtbox do corpo NÃO encontrada!")
	
	# ✅ CONECTAR HURTBOX DA CABEÇA
	print("🐍 === VERIFICANDO HURTBOX DA CABEÇA ===")
	
	if $HeadNNeck/Head.has_node("Hurtbox"):
		var head_hurtbox = $HeadNNeck/Head.get_node("Hurtbox")
		print("   ✅ CABEÇA encontrada: HeadNNeck/Head/Hurtbox")
		print("   - Collision Layer: ", head_hurtbox.collision_layer)
		print("   - Collision Mask: ", head_hurtbox.collision_mask)
		
		# Conectar sinais da cabeça
		head_hurtbox.area_entered.connect(_on_snakehead_area_entered)
		head_hurtbox.body_entered.connect(_on_snakehead_body_entered)
		print("✅ Sinais da CABEÇA conectados!")
	else:
		print("❌ Hurtbox da cabeça NÃO encontrada!")
	
	# ✅ DEFINIR POSIÇÕES INICIAIS
	for i in range(_objects.size()):
		_objects[i].position = _idle_positions[i]


# ✅ NOVA FUNÇÃO: Atualiza direção baseada na posição do player (SEM teleporte)
func _update_facing_direction(smooth: bool = true) -> void:
	if not is_instance_valid(_player_in_range):
		return
	
	# Verifica se o player está à direita
	var player_direction = _player_in_range.global_position.x - global_position.x
	_is_player_on_right = player_direction > 0
	
	# ✅ SE A DIREÇÃO MUDOU, faz transição suave
	if _current_facing_right != _is_player_on_right:
		_current_facing_right = _is_player_on_right
		
		# ✅ APLICAR FLIP.H em todos os segmentos (exceto no Attack 2)
		for obj in _objects:
			if obj:
				obj.flip_h = _is_player_on_right
		
		# ✅ TRANSIÇÃO SUAVE para as novas posições idle
		if smooth:
			for i in range(_objects.size()):
				var target_pos = _get_adjusted_position(_idle_positions[i])
				var tween = get_tree().create_tween()
				tween.tween_property(_objects[i], "position", target_pos, 0.3).set_ease(Tween.EASE_IN_OUT)


# ✅ NOVA FUNÇÃO: Retorna posições ajustadas baseado na direção
func _get_adjusted_position(base_position: Vector2) -> Vector2:
	if _is_player_on_right:
		return Vector2(-base_position.x, base_position.y)
	return base_position


func _get_limited_neck_position(neck_index: int, target_pos: Vector2) -> Vector2:
	# ✅ APENAS O NECK5 É LIMITADO
	if neck_index == 5:  # Neck5 - movimento mínimo
		var idle_pos = _idle_positions[neck_index]
		var delta = target_pos - idle_pos
		delta.x = clamp(delta.x, -2, 2)  # Máximo 2px
		delta.y = clamp(delta.y, -2, 2)
		return idle_pos + delta
	else:
		return target_pos


func _physics_process(_delta: float) -> void:
	pass


func _process(_delta: float) -> void:
	if _queued_to_die or not _is_alive:
		return
	
	# ✅ ATUALIZAR DIREÇÃO CONTINUAMENTE DURANTE IDLE (com transição suave)
	if _can_attack and is_instance_valid(_player_in_range):
		_update_facing_direction(true)
	
	if is_instance_valid(_player_in_range) and _can_attack:
		var _moving_direction: Vector2 = global_position.direction_to(
			_player_in_range.global_position
		)
		
		var _moving_distance: float = global_position.distance_to(
			_player_in_range.global_position
		) * 0.8
		
		# ✅ SOM DE ANTECIPAÇÃO
		if _attack_start_audio:
			_attack_start_audio.play()
		
		$Animation.play("attack_anticipation")
		_can_attack = false
		
		await $Animation.animation_finished
		
		# ✅ ATAQUE 1 - Linear com pescoço proporcional
		if _attack_state == 0:
			await _execute_attack_1(_moving_direction, _moving_distance)
			_attack_state += 1
			return
		
		# ✅ ATAQUE 2 - PÊNDULO (SEM MUDAR FLIP.H)
		if _attack_state == 1:
			if _attack_2_audio:
				_attack_2_audio.play()
			
			await _perform_pendulum_attack()
			_attack_state += 1
			return
			
		# ✅ ATAQUE ESPECIAL - Subida com StunArea
		if _attack_state == 2:
			if _attack_special_audio:
				_attack_special_audio.play()
			
			for i in range(_objects.size()):
				var _tween: Tween = get_tree().create_tween()
				var _delay: float = i * 0.05
				
				_tween.tween_property(
					_objects[i], "position", _special_attack_positions[i], 0.3 + _delay
				).set_ease(Tween.EASE_OUT)
			
			$Animation.play("special_attack")
			$CooldownTimer.start(3.0)
	
			if is_instance_valid(_player_in_range):
				var target_position: Vector2 = _player_in_range.global_position
				var _stun_area: StunArea = load("res://Scenes/Inimigos/stun_area.tscn").instantiate()
				get_tree().root.call_deferred("add_child", _stun_area)
				_stun_area.global_position = target_position


# ✅ FUNÇÃO: Executa o Ataque 1
func _execute_attack_1(_moving_direction: Vector2, _moving_distance: float) -> void:
	# ===== ANTECIPAÇÃO DO ATAQUE 1 =====
	# Movimento em cascata: Neck5 → Neck4 → Neck3 → Neck2 → Neck1 → Head
	for neck_index in range(_objects.size() - 1, 0, -1):
		var neck = _objects[neck_index]
		var proportion = _attack_multipliers[neck_index]
		var neck_target = _get_adjusted_position(Vector2(-9, -10)) * proportion
		
		# ✅ APLICAR LIMITAÇÃO NO NECK5
		neck_target = _get_limited_neck_position(neck_index, neck_target)
		
		var neck_tween = get_tree().create_tween()
		neck_tween.tween_property(neck, "position", neck_target, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		await get_tree().create_timer(0.05).timeout
	
	# Cabeça vai para posição de antecipação
	var head = _objects[0]
	var anticipation_tween = get_tree().create_tween()
	anticipation_tween.tween_property(head, "position", _get_adjusted_position(Vector2(-9, -10)), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	await anticipation_tween.finished
	await get_tree().create_timer(0.1).timeout  # Pequena pausa
	
	# ===== ATAQUE LINEAR =====
	if _attack_1_audio:
		_attack_1_audio.play()
	
	for i in range(_objects.size()):
		var _tween: Tween = get_tree().create_tween()
		var _segment_distance: float = _moving_distance * _attack_multipliers[i]
		var target = _moving_direction * _segment_distance
		
		# ✅ APLICAR LIMITAÇÃO NO NECK5
		if i == 5:
			target = _get_limited_neck_position(i, target)
		
		_tween.parallel().tween_property(
			_objects[i], "position", target, 0.4
		).set_ease(Tween.EASE_IN_OUT)
		
		await get_tree().create_timer(0.0825).timeout
		
	$Animation.play("attack")


func _perform_pendulum_attack() -> void:
	var head = _objects[0]
	
	$Animation.play("attack_anticipation")
	
	# ✅ DESABILITAR FLIP.H DURANTE O ATAQUE 2
	var saved_flip_states = []
	for obj in _objects:
		saved_flip_states.append(obj.flip_h)
		obj.flip_h = false  # Desabilita para evitar conflito com rotation
	
	# ===== ANTECIPAÇÃO DO ATAQUE 2 =====
	for neck_index in range(_objects.size() - 1, 0, -1):
		var neck = _objects[neck_index]
		var proportion = _attack_multipliers[neck_index]
		var neck_target = Vector2(-9, -40) * proportion
		neck_target = _get_limited_neck_position(neck_index, neck_target)
		
		var neck_tween = get_tree().create_tween()
		neck_tween.tween_property(neck, "position", neck_target, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.05).timeout
	
	var anticipation_tween = get_tree().create_tween()
	anticipation_tween.set_parallel(true)
	anticipation_tween.tween_property(head, "position", Vector2(-9, -40), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	anticipation_tween.tween_property(head, "rotation_degrees", 0, 0.3).set_ease(Tween.EASE_OUT)
	await anticipation_tween.finished
	await get_tree().create_timer(0.1).timeout
	
	# Movimento 2: posição inicial do pêndulo
	for neck_index in range(_objects.size() - 1, 0, -1):
		var neck = _objects[neck_index]
		var proportion = _attack_multipliers[neck_index]
		var neck_target = Vector2(-100, 5) * proportion
		neck_target = _get_limited_neck_position(neck_index, neck_target)
		
		var neck_tween = get_tree().create_tween()
		neck_tween.tween_property(neck, "position", neck_target, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.05).timeout
	
	var start_tween = get_tree().create_tween()
	start_tween.set_parallel(true)
	start_tween.tween_property(head, "position", Vector2(-100, 5), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	start_tween.tween_property(head, "rotation_degrees", 0, 0.4).set_ease(Tween.EASE_IN_OUT)
	await start_tween.finished
	
	var speed_normal = 0.3
	var speed_fast = 0.15
	
	if _attack_2_audio:
		_attack_2_audio.play()
	
	for cycle in range(2):
		# ===== IDA: Esquerda → Centro → Direita =====
		for neck_index in range(_objects.size() - 1, 0, -1):
			var neck = _objects[neck_index]
			var proportion = _attack_multipliers[neck_index]
			var mid_pos = Vector2(10, -100) * proportion
			mid_pos = _get_limited_neck_position(neck_index, mid_pos)
			
			var tween_neck_1 = get_tree().create_tween()
			tween_neck_1.tween_property(neck, "position", mid_pos, speed_normal).set_trans(Tween.TRANS_LINEAR)
			await get_tree().create_timer(0.05).timeout
		
		var tween_head_1 = get_tree().create_tween()
		tween_head_1.set_parallel(true)
		tween_head_1.tween_property(head, "position", Vector2(10, -100), speed_normal).set_trans(Tween.TRANS_LINEAR)
		tween_head_1.tween_property(head, "rotation_degrees", 90, speed_normal).set_trans(Tween.TRANS_LINEAR)
		await tween_head_1.finished
		
		for neck_index in range(_objects.size() - 1, 0, -1):
			var neck = _objects[neck_index]
			var proportion = _attack_multipliers[neck_index]
			var end_pos = Vector2(100, 5) * proportion
			end_pos = _get_limited_neck_position(neck_index, end_pos)
			
			var tween_neck_2 = get_tree().create_tween()
			tween_neck_2.tween_property(neck, "position", end_pos, speed_fast).set_trans(Tween.TRANS_LINEAR)
			await get_tree().create_timer(0.05).timeout
		
		var tween_head_2 = get_tree().create_tween()
		tween_head_2.set_parallel(true)
		tween_head_2.tween_property(head, "position", Vector2(100, 5), speed_fast).set_trans(Tween.TRANS_LINEAR)
		tween_head_2.tween_property(head, "rotation_degrees", 180, speed_fast).set_trans(Tween.TRANS_LINEAR)
		await tween_head_2.finished
		
		if _attack_2_audio:
			_attack_2_audio.play()
		
		var camera = get_tree().get_first_node_in_group("camera")
		if camera:
			camera.shake_camera(0.5, 0.15)
		await get_tree().create_timer(0.1).timeout
		
		# ===== VOLTA: Direita → Centro → Esquerda =====
		for neck_index in range(_objects.size() - 1, 0, -1):
			var neck = _objects[neck_index]
			var proportion = _attack_multipliers[neck_index]
			var mid_pos = Vector2(10, -100) * proportion
			mid_pos = _get_limited_neck_position(neck_index, mid_pos)
			
			var tween_neck_1 = get_tree().create_tween()
			tween_neck_1.tween_property(neck, "position", mid_pos, speed_fast).set_trans(Tween.TRANS_LINEAR)
			await get_tree().create_timer(0.05).timeout
		
		var tween_head_volta_1 = get_tree().create_tween()
		tween_head_volta_1.set_parallel(true)
		tween_head_volta_1.tween_property(head, "position", Vector2(10, -100), speed_fast).set_trans(Tween.TRANS_LINEAR)
		tween_head_volta_1.tween_property(head, "rotation_degrees", 90, speed_fast).set_trans(Tween.TRANS_LINEAR)
		await tween_head_volta_1.finished
		
		for neck_index in range(_objects.size() - 1, 0, -1):
			var neck = _objects[neck_index]
			var proportion = _attack_multipliers[neck_index]
			var end_pos = Vector2(-100, 5) * proportion
			end_pos = _get_limited_neck_position(neck_index, end_pos)
			
			var tween_neck_2 = get_tree().create_tween()
			tween_neck_2.tween_property(neck, "position", end_pos, speed_normal).set_trans(Tween.TRANS_LINEAR)
			await get_tree().create_timer(0.05).timeout
		
		var tween_head_volta_2 = get_tree().create_tween()
		tween_head_volta_2.set_parallel(true)
		tween_head_volta_2.tween_property(head, "position", Vector2(-100, 5), speed_normal).set_trans(Tween.TRANS_LINEAR)
		tween_head_volta_2.tween_property(head, "rotation_degrees", 0, speed_normal).set_trans(Tween.TRANS_LINEAR)
		await tween_head_volta_2.finished
		
		if _attack_2_audio:
			_attack_2_audio.play()
		
		if camera:
			camera.shake_camera(0.5, 0.15)
		await get_tree().create_timer(0.1).timeout
	
	# ✅ RESTAURAR FLIP.H APÓS ATTACK 2
	for i in range(_objects.size()):
		_objects[i].flip_h = saved_flip_states[i]
	
	$Animation.play("attack")


# ✅ NOVA FUNÇÃO: Detecta quando a espada atinge a hurtbox
func _on_hurtbox_area_entered(area: Area2D) -> void:
	print("🎯 Snake detectou área: ", area.name, " | Grupos: ", area.get_groups())
	
	if _queued_to_die or not _is_alive:
		return
	
	# Verificar se é ataque do player
	if area.is_in_group("player_attack") or "Attack" in area.name:
		var damage = area.get("damage")
		if damage == null:
			damage = 10
		
		print("💥 Snake recebeu ", damage, " de dano!")
		
		# ✅ Usar a função update_health customizada do Snake
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


func update_health(_damage: int, _entity) -> void:
	if not _is_alive or _queued_to_die:
		return
		
	_enemy_health -= _damage
	
	if _enemy_health <= 0:
		_die()
		return
	
	if _hit_audio:
		_hit_audio.play()
		
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.shake_camera(1, 0.1)
	
	_particle_2d.restart()
	_particle_2d.emitting = true


func _die() -> void:
	if _queued_to_die:
		return
		
	_queued_to_die = true
	_is_alive = false
	_can_attack = false
	
	# ✅ Cancelar tweens e resetar posições
	for obj in _objects:
		if obj:
			var tweens = get_tree().get_processed_tweens()
			for tween in tweens:
				if tween.is_valid():
					tween.kill()
	
	if $Animation.is_playing():
		$Animation.stop()
	
	var head = _objects[0]
	head.rotation_degrees = 0
	for i in range(_objects.size()):
		_objects[i].position = _idle_positions[i]
	
	# ✅ Desabilitar colisões da cabeça
	if $HeadNNeck/Head.has_node("DamageArea"):
		var head_damage_area = $HeadNNeck/Head.get_node("DamageArea")
		if head_damage_area.has_node("Collision"):
			head_damage_area.get_node("Collision").set_deferred("disabled", true)
	
	# ✅ USAR _hurtbox_detection (não _hurtbox)
	if _hurtbox_detection and _hurtbox_detection.has_node("Collision"):
		_hurtbox_detection.get_node("Collision").set_deferred("disabled", true)
	
	# ✅ ADICIONAR ISSO AQUI:
	if has_node("SnakeHurtbox"):
		var snake_hurtbox = get_node("SnakeHurtbox")
		if snake_hurtbox.has_node("Collision"):
			snake_hurtbox.get_node("Collision").set_deferred("disabled", true)
	
	
	if has_node("AttackArea"):
		var attack_area = get_node("AttackArea")
		if attack_area.has_node("Collision"):
			attack_area.get_node("Collision").set_deferred("disabled", true)
	
	if has_node("DetectionArea"):
		var detection_area = get_node("DetectionArea")
		if detection_area.has_node("Collision"):
			detection_area.get_node("Collision").set_deferred("disabled", true)
	
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.shake_camera(1, 0.1)
	
	# ✅ Ativar partículas
	if _particle_2d:
		_particle_2d.visible = true
		_particle_2d.restart()
		_particle_2d.emitting = true
	
	_drop_items()
	
	$Animation.play("death")
	
	# ✅ Áudio de morte
	if _dead_audio:
		_dead_audio.play()
		await _dead_audio.finished
	
	queue_free()


func _set_shader_blink_intensity(newValue: float) -> void:
	if $Body and $Body.material:
		if $Body.material.shader:
			$Body.material.set_shader_parameter("blink_active", newValue > 0.0)
			$Body.material.set_shader_parameter("blink_intensity", newValue)
	
	for _object in _objects:
		if not _object:
			continue
			
		if not _object.material:
			continue
			
		if not _object.material.shader:
			continue
		
		_object.material.set_shader_parameter("blink_active", newValue > 0.0)
		_object.material.set_shader_parameter("blink_intensity", newValue)
		
		
func _on_cooldown_timer_timeout() -> void:
	if _queued_to_die or not _is_alive:
		return
	
	# ✅ VERIFICAÇÃO APÓS ATAQUE ESPECIAL
	if _attack_state == 2:
		# ✅ VERIFICAR SE O PLAYER ESTÁ PETRIFICADO
		var is_player_petrified = false
		
		if is_instance_valid(_player_in_range):
			var player = _player_in_range as BaseCharacter
			if player and "is_petrified" in player:
				is_player_petrified = player.is_petrified
		
		# ✅ SE ESTÁ PETRIFICADO, FORÇA ATAQUE 1 IMEDIATO
		if is_player_petrified:
			print("🐍 Player petrificado detectado após Special Attack! Forçando Ataque 1...")
			_attack_state = 0  # Volta para Ataque 1
			_return_to_idle()
			$Animation.play("idle")
			
			# ✅ AGUARDAR UM MOMENTO CURTO E ATACAR
			await get_tree().create_timer(0.3).timeout
			_can_attack = true  # Libera para atacar imediatamente
			return
		
		# ✅ SE NÃO ESTÁ PETRIFICADO, CONTINUA CICLO NORMAL
		_attack_state = 0
		_return_to_idle()
		$Animation.play("idle")
		$CooldownTimer.start(2.0)
		return
		
	_can_attack = true


func _return_to_idle() -> void:
	var head = _objects[0]
	
	# ✅ RESETAR ROTAÇÃO DA CABEÇA
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(head, "rotation_degrees", 0, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(head, "position", _get_adjusted_position(_idle_positions[0]), 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# Retornar demais segmentos
	for i in range(1, _objects.size()):
		var _segment_tween: Tween = get_tree().create_tween()
		_segment_tween.tween_property(
			_objects[i], "position", _get_adjusted_position(_idle_positions[i]), 0.5
		).set_ease(Tween.EASE_IN_OUT)
	
	
func _on_animation_finished(_anim_name: StringName) -> void:
	if _anim_name == "death":
		return
		
	if _queued_to_die or not _is_alive:
		return
		
	if _anim_name == "attack":
		$Animation.play("idle")
		
		# ✅ RESETAR ROTAÇÃO DA CABEÇA E VOLTAR PARA IDLE AJUSTADO
		var head = _objects[0]
		var head_tween = get_tree().create_tween()
		head_tween.set_parallel(true)
		head_tween.tween_property(head, "rotation_degrees", 0, 1.0).set_ease(Tween.EASE_IN_OUT)
		head_tween.tween_property(head, "position", _get_adjusted_position(_idle_positions[0]), 1.0).set_ease(Tween.EASE_IN_OUT)
		
		for i in range(1, _objects.size()):
			var _tween: Tween = get_tree().create_tween()
			_tween.parallel().tween_property(
				_objects[i], "position", _get_adjusted_position(_idle_positions[i]), 1.0
			).set_ease(Tween.EASE_IN_OUT)
			
			await get_tree().create_timer(0.0825).timeout
			
		await get_tree().create_timer(1.0).timeout
		_can_attack = true


func _on_damage_area_body_entered(_body: Node2D) -> void:
	if _queued_to_die or not _is_alive:
		return
		
	if _body is BaseCharacter:
		_body.update_health(_attack_damage, self)


func _drop_items() -> void:
	"""Dropa itens quando o inimigo morre"""
	var drop_data = _get_drop_items()
	
	for item_key in drop_data:
		var item = drop_data[item_key]
		var rand_value = randf()
		
		# Verifica probabilidade de spawn
		if rand_value < item["spawn_probability"]:
			var amount_range = item["amount_to_drop"]
			var amount = randi_range(amount_range[0], amount_range[1])
			
			# Spawna cada fragmento
			for i in range(amount):
				var collectable_item = load("res://Scenes/Collectables/collectable_item.tscn").instantiate()
				collectable_item.item_texture = item["path"]
				collectable_item.item_data = {
					"name": item["name"],
					"type": item["type"],
					"description": item["description"],
					"value": item["value"],
					"amount": 1  # Cada instância vale 1
				}
				collectable_item.global_position = global_position
				
				get_tree().current_scene.call_deferred("add_child", collectable_item)


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





# ===== HURTBOX DO CORPO (SnakeHurtbox na raiz) =====
func _on_snakebody_area_entered(area: Area2D) -> void:
	print("🎯 CORPO detectou área: ", area.name, " | Grupos: ", area.get_groups())
	
	if _queued_to_die or not _is_alive:
		return
	
	if area.is_in_group("player_attack") or "Attack" in area.name:
		var damage = area.get("damage")
		if damage == null:
			damage = 10
		
		print("💥 CORPO recebeu ", damage, " de dano!")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


func _on_snakebody_body_entered(body: Node2D) -> void:
	print("🎯 CORPO detectou body: ", body.name, " | Classe: ", body.get_class())
	
	if _queued_to_die or not _is_alive:
		return
	
	if body is ProjectileSpear:
		var spear := body as ProjectileSpear
		var damage := spear._attack_damage
		
		print("💥 CORPO recebeu ", damage, " de dano da lança!")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


# ===== HURTBOX DA CABEÇA (Head/Hurtbox) =====
func _on_snakehead_area_entered(area: Area2D) -> void:
	print("🎯 CABEÇA detectou área: ", area.name, " | Grupos: ", area.get_groups())
	
	if _queued_to_die or not _is_alive:
		return
	
	if area.is_in_group("player_attack") or "Attack" in area.name:
		var damage = area.get("damage")
		if damage == null:
			damage = 10
		
		print("💥 CABEÇA recebeu ", damage, " de dano!")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)


func _on_snakehead_body_entered(body: Node2D) -> void:
	print("🎯 CABEÇA detectou body: ", body.name, " | Classe: ", body.get_class())
	
	if _queued_to_die or not _is_alive:
		return
	
	if body is ProjectileSpear:
		var spear := body as ProjectileSpear
		var damage := spear._attack_damage
		
		print("💥 CABEÇA recebeu ", damage, " de dano da lança!")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			update_health(damage, player)
