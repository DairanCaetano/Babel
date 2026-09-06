extends Node2D
class_name Door

@export var texture: AnimatedSprite2D
@export var door_collision: StaticBody2D
@export var interaction_area: Area2D
@export var interaction_prompt: AnimatedSprite2D
@export var door_hurtbox: Area2D

@export var show_interaction_prompt: bool = true

# ✅ NOVO: Sistema de fragmentos próprio da porta
@export_category("Shards")
@export var shard_textures: Array[Texture2D] = []  # Arraste as texturas aqui no Inspector
@export var shard_count: int = 4  # Quantos pedaços spawnar

# ✅ NOVO: Persistência (opcional)
@export_category("Persistence")
@export var unique_id: String = ""
@export var should_persist: bool = false

# ✅ NOVO: Audio
@export_category("Audio")
@export var break_sound: AudioStreamPlayer2D
@export var open_door_sound: AudioStreamPlayer2D
@export var close_door_sound: AudioStreamPlayer2D  # ✅ Adicionei o som de fechar também


enum DoorState { CLOSED, OPENING, OPEN, CLOSING, BROKEN }

var current_state: DoorState = DoorState.CLOSED
var player_in_range: bool = false
var player_reference: Node2D = null
var is_broken: bool = false
var auto_close_timer: Timer
var stored_flip_direction: bool = false

const PROMPT_POS_RIGHT: float = -20.0
const PROMPT_POS_LEFT: float = 20.0

func _ready() -> void:
	# ✅ Verificar se já foi destruída (persistência)
	if should_persist and unique_id != "":
		if global.is_object_destroyed(unique_id):
			queue_free()
			return
	
	interaction_prompt.visible = false
	
	auto_close_timer = Timer.new()
	auto_close_timer.wait_time = 1.0
	auto_close_timer.one_shot = true
	auto_close_timer.timeout.connect(_on_auto_close_timeout)
	add_child(auto_close_timer)
	
	texture.animation_finished.connect(_on_animation_finished)
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	door_hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _process(_delta: float) -> void:
	if player_in_range and current_state == DoorState.CLOSED:
		update_stored_direction()
		
		if Input.is_action_just_pressed("move_up"):
			open_door()

func _on_interaction_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		update_prompt_position()
		
		if current_state == DoorState.CLOSED and not is_broken and show_interaction_prompt:
			interaction_prompt.visible = true

func _on_interaction_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		interaction_prompt.visible = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack") and (current_state == DoorState.CLOSED or current_state == DoorState.CLOSING):
		break_door()

func update_stored_direction() -> void:
	if not player_reference:
		return
	
	var player_is_on_left: bool = player_reference.global_position.x < global_position.x
	stored_flip_direction = not player_is_on_left

func update_prompt_position() -> void:
	if not player_reference:
		return
	
	var player_is_on_left: bool = player_reference.global_position.x < global_position.x
	
	if player_is_on_left:
		interaction_prompt.position.x = PROMPT_POS_RIGHT
	else:
		interaction_prompt.position.x = PROMPT_POS_LEFT

func open_door() -> void:
	if current_state != DoorState.CLOSED:
		return
	
	current_state = DoorState.OPENING
	interaction_prompt.visible = false
	
	texture.flip_h = stored_flip_direction
	texture.play("Open")
	
	# ✅ Tocar som de abrir
	if open_door_sound:
		open_door_sound.play()
	
	disable_collision()
	disable_hurtbox()

func break_door() -> void:
	if is_broken:
		return
	
	current_state = DoorState.BROKEN
	is_broken = true
	interaction_prompt.visible = false
	
	if auto_close_timer.time_left > 0:
		auto_close_timer.stop()
	
	texture.flip_h = stored_flip_direction
	texture.play("Broken")
	
	# ✅ Tocar som de quebrar
	if break_sound:
		break_sound.play()
	
	disable_collision()
	disable_hurtbox()
	
	# ✅ Spawnar fragmentos
	_spawn_shards()

func _spawn_shards() -> void:
	"""Spawna os fragmentos da porta quando quebrada"""
	if shard_textures.is_empty():
		return
	
	var level = _get_current_level()
	
	# ✅ CALCULAR DIREÇÃO DOS FRAGMENTOS
	var push_direction: float = 1.0  # Padrão: direita
	
	if player_reference:
		# Se jogador está à esquerda, empurra para direita (positivo)
		# Se jogador está à direita, empurra para esquerda (negativo)
		var player_is_on_left: bool = player_reference.global_position.x < global_position.x
		push_direction = 1.0 if player_is_on_left else -1.0
	
	# Spawna a quantidade configurada de fragmentos
	for i in range(shard_count):
		# Escolhe uma textura aleatória do array
		var random_texture = shard_textures[randi() % shard_textures.size()]
		
		var shard: CollectableItem = load("res://Scenes/Collectables/collectable_item.tscn").instantiate()
		shard.is_collectable = false
		
		# Converter Texture2D para caminho de string
		if random_texture:
			shard.item_texture = random_texture.resource_path
		
		shard.global_position = global_position
		
		level.call_deferred("add_child", shard)
		
		# ✅ APLICAR FORÇA APÓS ADICIONAR À CENA
		await get_tree().process_frame
		
		# Força horizontal aleatória na direção oposta ao jogador
		var force_x = randf_range(10.0, 100.0) * push_direction
		
		# Força vertical aleatória (sempre para cima)
		var force_y = randf_range(-50.0, -100.0)
		
		# Aplicar impulso
		if shard is RigidBody2D:
			shard.apply_central_impulse(Vector2(force_x, force_y))

func _get_current_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.has_node("LevelContainer"):
		var level_container = game_main.get_node("LevelContainer")
		if level_container.get_child_count() > 0:
			return level_container.get_child(0)
	return get_tree().current_scene

func _on_animation_finished() -> void:
	match current_state:
		DoorState.OPENING:
			current_state = DoorState.OPEN
			auto_close_timer.start()
		
		DoorState.CLOSING:
			current_state = DoorState.CLOSED
			texture.play("Closed")
			
			# ✅ Tocar som de fechar
			if close_door_sound:
				close_door_sound.play()
			
			enable_collision()
			enable_hurtbox()
			
			if player_in_range and show_interaction_prompt:
				interaction_prompt.visible = true
		
		DoorState.BROKEN:
			# ✅ Registrar como destruída se for persistente
			if should_persist and unique_id != "":
				global.register_destroyed_object(unique_id)
			
			# ✅ REMOVIDO queue_free() - porta quebrada permanece na cena

func _on_auto_close_timeout() -> void:
	if current_state == DoorState.OPEN and not is_broken:
		close_door()

func close_door() -> void:
	current_state = DoorState.CLOSING
	texture.play("Closing")

func disable_collision() -> void:
	door_collision.set_collision_layer_value(5, false)
	door_collision.set_collision_mask_value(1, false)

func enable_collision() -> void:
	door_collision.set_collision_layer_value(5, true)
	door_collision.set_collision_mask_value(1, true)

func disable_hurtbox() -> void:
	door_hurtbox.monitoring = false

func enable_hurtbox() -> void:
	door_hurtbox.monitoring = true
