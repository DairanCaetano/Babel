extends Area2D
class_name ProjectileChakram

@export var attack_damage: int = 2 # por acerto, com ataque base 5 (escala com a força do Tola)
@export var move_speed: float = 400.0
@export var _deceleration: float = 200.0
@export var max_distance: float = 300.0

var direction: Vector2 = Vector2.RIGHT
var initial_position: Vector2
var is_returning: bool = false
var return_speed: float = 400.0  # Velocidade constante para o retorno
var lifetime: float = 5.0
var current_lifetime: float = 0.0

# Controle de dano - para evitar spam de dano no mesmo inimigo
var damaged_enemies: Array = []
var damage_cooldown_per_enemy: float = 0.5
var enemy_damage_timers: Dictionary = {}

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _collision: CollisionShape2D
@export var _hitbox: Area2D  # Área de hitbox para controle por frame

var duration_timer: Timer
var has_started_moving: bool = false
var current_speed: float  # Para armazenar a velocidade atual

# Ghost Trail
var ghost_timer: float = 0.0
var ghost_interval: float = 0.03
@export var ghost_trail_scene: PackedScene

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ghost_timer = 0.0  # 👈 ADICIONE ISSO
	
	print("Chakram collision_layer: ", collision_layer)
	print("Chakram collision_mask: ", collision_mask)

	# Debug das layers dos inimigos próximos
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("update_health"):
			print("Inimigo ", enemy.name, " collision_layer: ", enemy.collision_layer)
			
	print("=== CHAKRAM CRIADO ===")
	print("Posição inicial: ", global_position)
	print("Direção: ", direction)
	print("Tempo de vida: ", lifetime, " segundos")
	
	# Aguardar alguns frames antes de definir posição inicial
	await get_tree().process_frame
	await get_tree().process_frame
	
	initial_position = global_position
	current_speed = move_speed  # Inicializar velocidade atual
	print("Posição inicial definida: ", initial_position)
	
	# Configurar textura
	if not _texture:
		_texture = find_child("AnimatedSprite2D", true, false)
	
	if _texture:
		if direction.x < 0:
			_texture.flip_h = true
		else:
			_texture.flip_h = false
		
		# Garantir animação
		if _texture.sprite_frames:
			var anims = _texture.sprite_frames.get_animation_names()
			if anims.size() > 0:
				_texture.play(anims[0])  # Normalmente será "Idle"
		
		# CONECTAR O SINAL DE MUDANÇA DE FRAME
		if not _texture.frame_changed.is_connected(_on_frame_changed):
			_texture.frame_changed.connect(_on_frame_changed)
	
	# Configurar hitbox
	if not _hitbox:
		_hitbox = find_child("Hitbox", true, false) as Area2D
	
	if _hitbox:
		# Conectar sinal da hitbox para detectar colisões com inimigos
		if not _hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			_hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Configurar timer para destruição automática
	duration_timer = find_child("*Timer*", true, false) as Timer
	if not duration_timer:
		duration_timer = Timer.new()
		duration_timer.name = "DurationTimer"
		duration_timer.one_shot = true
		add_child(duration_timer)
	
	duration_timer.timeout.connect(_on_duration_timeout)
	duration_timer.start(lifetime)
	
	# Configurar colisões - CORRIGIDO
	collision_layer = 8  # Layer 4
	collision_mask = 6   # Layers 2 + 3 (enemies + walls)
	
	# Conectar sinal para body_entered (paredes e outros bodies)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Conectar sinal para area_entered (área de ataque do jogador)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	# Aguardar antes de começar
	await get_tree().create_timer(0.1).timeout
	has_started_moving = true
	print("Chakram pronto para se mover!")
	print("=====================")

# NOVA FUNÇÃO: Controlar colisão baseada no frame da animação
func _on_frame_changed() -> void:
	if not _texture or not _hitbox:
		return
	
	# Verificar se está na animação "Idle" (ou a animação base do chakram)
	if _texture.animation == "Idle":
		var current_frame = _texture.frame
		
		# Ativar hitbox nos frames 1 e 3, desativar nos frames 0 e 2
		if current_frame == 1 or current_frame == 3:
			_enable_hitbox()
		elif current_frame == 0 or current_frame == 2:
			_disable_hitbox()
		
		# Debug opcional
		#print("Chakram frame: ", current_frame, " - Hitbox ativa: ", not _hitbox.get_child(0).disabled)

func _enable_hitbox() -> void:
	"""Ativa a área de colisão do hitbox"""
	if _hitbox and _hitbox.get_child_count() > 0:
		var collision_shape = _hitbox.get_child(0) as CollisionShape2D
		if collision_shape:
			collision_shape.disabled = false

func _disable_hitbox() -> void:
	"""Desativa a área de colisão do hitbox"""
	if _hitbox and _hitbox.get_child_count() > 0:
		var collision_shape = _hitbox.get_child(0) as CollisionShape2D
		if collision_shape:
			collision_shape.disabled = true

func _physics_process(delta: float) -> void:
	# Atualizar tempo de vida
	current_lifetime += delta
	
	# Limpar timers de dano expirados
	_cleanup_damage_timers(delta)
	
	# 👻 GHOST TRAIL - CORRIGIDO
	if has_started_moving:
		ghost_timer += delta  # 👈 MUDADO DE -= PARA +=
		if ghost_timer >= ghost_interval:  # 👈 MUDADO DE <= PARA >=
			spawn_ghost_trail()
			ghost_timer = 0.0
	
	# Não se mover até estar pronto
	if not has_started_moving:
		return
	
	var distance_traveled = initial_position.distance_to(global_position)
	
	if not is_returning:
		# Fase de ida
		if distance_traveled >= max_distance:
			print("Distância máxima atingida - Iniciando retorno")
			start_return()
			return
		
		# Verificar se está próximo da distância máxima para começar a desacelerar
		var distance_remaining = max_distance - distance_traveled
		var deceleration_distance = 80.0  # Distância para começar a desacelerar
		
		if distance_remaining <= deceleration_distance:
			# Começar desaceleração gradual
			var deceleration_factor = distance_remaining / deceleration_distance
			current_speed = move_speed * deceleration_factor
			
			# Velocidade mínima antes de retornar
			if current_speed < 50:
				current_speed = 50
		else:
			# Manter velocidade constante
			current_speed = move_speed
		
		# Mover para frente
		global_position += direction * current_speed * delta
		
	else:
		# Fase de retorno - acelerar rapidamente até velocidade constante
		if current_speed < return_speed:
			current_speed += _deceleration * 2.0 * delta  # Acelerar 2x mais rápido
			if current_speed > return_speed:
				current_speed = return_speed
		
		# Mover na direção de retorno
		global_position += direction * current_speed * delta
		
		# Ajustar sprite para a direção atual
		if _texture:
			_texture.flip_h = (direction.x < 0)

# NOVA FUNÇÃO: Detectar colisões com áreas (incluindo CharacterAttackArea)
func _on_area_entered(_area) -> void:
	print("=== COLISÃO COM ÁREA DETECTADA ===")
	print("Chakram colidiu com área: ", _area.name, " (", _area.get_class(), ")")
	
	# Verificar se é a área de ataque do jogador
	if _area is CharacterAttackArea:
		print("Colidiu com ataque do jogador - Invertendo direção")
		
		# Spawn do efeito de hit usando a direção atual do chakram
		var chakram_is_flipped = (direction.x < 0)
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(36, 0), global_position, chakram_is_flipped
		)
		
		# Inverter direção (mesma lógica das paredes)
		invert_direction()
		
		print("Chakram rebatido pelo ataque do jogador!")
	
	print("========================")

func _on_body_entered(_body) -> void:
	print("=== COLISÃO DETECTADA (GERAL) ===")
	print("Chakram colidiu com: ", _body.name, " (", _body.get_class(), ")")
	
	# Spawn do efeito sempre que houver colisão válida
	var should_spawn_effect = false
	
	# Colisão com paredes - permitir múltiplas colisões
	if _body is TileMapLayer or _body is StaticBody2D:
		print("Colidiu com parede - Invertendo direção")
		should_spawn_effect = true
		invert_direction()  # Nova função para inverter direção
	
	# IGNORAR colisões com jogador - não fazer nada
	elif _body == global.character:
		print("Colidiu com jogador - Ignorando (não desaparece)")
	
	# Spawn do efeito apenas quando necessário
	if should_spawn_effect:
		# Usar a direção atual do chakram para o flip do efeito
		var chakram_is_flipped = (direction.x < 0)
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(36, 0), global_position, chakram_is_flipped
		)
	
	print("========================")

func invert_direction() -> void:
	"""Inverte a direção do chakram quando colide com parede ou ataque do jogador"""
	print(">>> INVERTENDO DIREÇÃO <<<")
	direction = -direction  # Inverter direção
	
	# Se estava desacelerando, parar e usar velocidade constante
	if not is_returning:
		is_returning = true
		current_speed = return_speed
		print("Parou desaceleração - usando velocidade constante: ", return_speed)
	
	# Ajustar sprite para nova direção
	if _texture:
		_texture.flip_h = (direction.x < 0)
	
	print("Nova direção: ", direction)

func start_return_from_wall() -> void:
	"""Inicia retorno imediato quando colide com parede"""
	print(">>> INICIANDO RETORNO IMEDIATO (PAREDE) <<<")
	is_returning = true
	# Parar qualquer desaceleração e usar velocidade de retorno
	current_speed = return_speed
	print("Retorno imediato configurado - velocidade: ", return_speed)

func start_return() -> void:
	"""Inicia retorno normal (por distância máxima)"""
	print(">>> INICIANDO RETORNO NORMAL <<<")
	is_returning = true
	direction = -direction  # Inverter direção para retorno
	current_speed = 50  # Começar devagar e acelerar
	
	# Ajustar sprite para nova direção
	if _texture:
		_texture.flip_h = (direction.x < 0)
	
	print("Retorno normal configurado - direção invertida: ", direction)

func _can_damage_enemy(enemy) -> bool:
	"""Verifica se pode causar dano neste inimigo (cooldown)"""
	var enemy_id = enemy.get_instance_id()
	return not enemy_damage_timers.has(enemy_id) or enemy_damage_timers[enemy_id] <= 0.0

func _register_enemy_damage(enemy) -> void:
	"""Registra que dano foi causado e inicia cooldown"""
	var enemy_id = enemy.get_instance_id()
	enemy_damage_timers[enemy_id] = damage_cooldown_per_enemy
	print("Cooldown de dano iniciado para inimigo: ", enemy.name)

func _cleanup_damage_timers(delta: float) -> void:
	"""Limpa timers de dano expirados"""
	var expired_keys = []
	
	for enemy_id in enemy_damage_timers.keys():
		enemy_damage_timers[enemy_id] -= delta
		if enemy_damage_timers[enemy_id] <= 0.0:
			expired_keys.append(enemy_id)
	
	# Remover timers expirados
	for key in expired_keys:
		enemy_damage_timers.erase(key)

func _on_duration_timeout() -> void:
	print("Tempo de vida do chakram expirado - Destruindo")
	queue_free()

func _exit_tree() -> void:
	print("Chakram removido da árvore")

func spawn_ghost_trail():
	"""Cria ghost trail do chakram"""
	if not ghost_trail_scene or not _texture:
		return
	
	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)  # 👈 MUDADO
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation  # 👈 MUDADO
	
	ghost.setup(_texture)
func _on_hitbox_body_entered(body: Node2D) -> void:
	print("=== COLISÃO COM HITBOX ===")
	print("Chakram hitbox colidiu com: ", body.name, " (", body.get_class(), ")")
	
	# Causar dano APENAS em bodies que possuem o método update_health
	if body.has_method("update_health"):
		# Verificar se pode causar dano (cooldown por inimigo)
		if _can_damage_enemy(body):
			print("Aplicando dano ao inimigo: ", body.name)
			
			# Aplicar dano
			body.update_health(
				global.character.scale_damage(attack_damage),
				global.character
			)
			
			# Registrar que dano foi causado neste inimigo
			_register_enemy_damage(body)
			
			# Spawn do efeito de dano usando a direção do chakram
			var chakram_is_flipped = (direction.x < 0)
			global.spawn_effect(
				"res://Scenes/FX/hit_effect.tscn",
				Vector2(36, 0), global_position, chakram_is_flipped
			)
		else:
			print("Inimigo ainda em cooldown de dano")
	else:
		print("Body não possui método update_health - ignorando")
