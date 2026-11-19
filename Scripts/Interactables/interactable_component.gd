extends Area2D
class_name InteractableComponent

const _NON_COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")
const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")

var _item_data: Dictionary = {}

# ✅ NOVO: Armazenar direção do último ataque
var _last_attack_direction: float = 0.0

# ✅ Evita destruir duas vezes (dois hits no mesmo frame)
var _is_destroyed: bool = false

@export_category("Variables")
@export var _health: int = 5
@export var _is_static: bool = true
@export var _is_interactable: bool = true
@export var _is_special: bool = false
## Ao quebrar, troca para a animação "Broken" e fica na cena (sem colisão), em vez de sumir.
@export var _keep_broken: bool = false

@export_category("Shards")
@export var _interactable_pieces: Array
@export_group("Shard Groups")
@export var _shard_group: ShardGroup = ShardGroup.POTTERY

# ✅ NOVO: Configurar força dos fragmentos
@export_group("Shard Physics")
@export var _shard_force_x_min: float = 10.0
@export var _shard_force_x_max: float = 100.0
@export var _shard_force_y_min: float = -20.0
@export var _shard_force_y_max: float = -120.0
@export var _shard_torque_min: float = -100.0
@export var _shard_torque_max: float = 200.0

@export_category("Persistence")
@export var _unique_id: String = ""
@export var _should_persist: bool = false

@export_category("Objects")
@export var _sprite: AnimatedSprite2D
@export var _body_collision: CollisionShape2D
@export var _broken_audio: AudioStreamPlayer
@export var _interaction_area: CollisionShape2D

enum ShardGroup {
	CUSTOM,
	POTTERY,
	WOOD,
	STONE,
	METAL,
	CRYSTAL,
}

const SHARD_TEXTURES = {
	ShardGroup.POTTERY: [
		"res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v01.png",
		"res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v02.png",
		"res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v03.png",
		"res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v04.png",
	],
	ShardGroup.WOOD: [
		"res://sprites/Shards/Wood/wood_shard_01.png",
		"res://sprites/Shards/Wood/wood_shard_02.png",
		"res://sprites/Shards/Wood/wood_shard_03.png",
		"res://sprites/Shards/Wood/wood_shard_04.png",
	],
	ShardGroup.STONE: [
		"res://sprites/Shards/Stone/stone_shard_01.png",
		"res://sprites/Shards/Stone/stone_shard_02.png",
		"res://sprites/Shards/Stone/stone_shard_03.png",
	],
	ShardGroup.METAL: [
		"res://sprites/Shards/Metal/metal_shard_01.png",
		"res://sprites/Shards/Metal/metal_shard_02.png",
		"res://sprites/Shards/Metal/metal_shard_03.png",
	],
	ShardGroup.CRYSTAL: [
		"res://sprites/Shards/Crystal/crystal_shard_01.png",
		"res://sprites/Shards/Crystal/crystal_shard_02.png",
		"res://sprites/Shards/Crystal/crystal_shard_03.png",
		"res://sprites/Shards/Crystal/crystal_shard_04.png",
		"res://sprites/Shards/Crystal/crystal_shard_05.png",
	],
}

func _ready() -> void:
	_item_data = _get_interactable_items()
	
	if not _is_static:
		_body_collision.disabled = true
	
	if _should_persist and _unique_id != "":
		if global.is_object_destroyed(_unique_id):
			if _keep_broken:
				_set_broken_state()
			else:
				queue_free()

func _get_interactable_items() -> Dictionary:
	return {}

func _drop_items(_spawn_position: Vector2, _level: Node) -> void:
	# ✅ SEM await: o jarro é destruído logo depois, e um await aqui
	# faria a função morrer no meio (só o primeiro item nascia)
	for _item in _item_data:
		var _randf: float = randf()
		if _randf < _item_data[_item]["spawn_probability"]:
			var _amount_range: Array = _item_data[_item]["amount_to_drop"]
			var _amount: int = randi_range(_amount_range[0], _amount_range[1])
			
			for _i in _amount:
				var _collectable: CollectableItem = _COLLECTABLE_ITEM.instantiate()
				_collectable.item_texture = _item_data[_item]["path"]
				_collectable.item_data = _item_data[_item]
				
				# ✅ PRIMEIRO entra na árvore, DEPOIS define a posição global
				# (antes: a posição era aplicada como local e somava o offset do level)
				_level.add_child(_collectable)
				_collectable.global_position = _spawn_position
				_apply_item_physics(_collectable)

func _on_interactable_area_entered(_area: Area2D) -> void:
	if not _is_interactable:
		return
	
	if _area is CharacterAttackArea:
		_interact(_area)

func _interact(_area) -> void:
	var _damage: int = _area.get_damaged()
	
	# ✅ NOVO: Capturar direção do ataque
	_calculate_attack_direction(_area)
	
	if _is_special:
		var character = global.character
		if not character or not character.has_node("CharacterSubweapon"):
			return
		
		var subweapons = character.get_node("CharacterSubweapon")
		if not subweapons.is_fire_active():
			return
	
	if _is_destroyed:
		return
	
	_health -= _damage
	if _health <= 0:
		_is_destroyed = true
		if _keep_broken:
			_sprite.play("Broken")
		else:
			_sprite.play("Destroyed")
		# ✅ Deferred: estamos dentro de um sinal de física (area_entered),
		# e adicionar RigidBody2D aqui gera erro de "flushing queries"
		call_deferred("_destroyed")

# ✅ NOVA FUNÇÃO: Calcular direção do ataque
func _calculate_attack_direction(_area: Area2D) -> void:
	"""Calcula a direção de onde veio o ataque"""
	# Tenta pegar o CharacterAttackArea
	var attack_owner = _area.get_parent()
	
	if attack_owner and attack_owner.has_method("get_parent"):
		var character = attack_owner.get_parent()
		
		if character:
			# Calcula direção: se personagem está à esquerda, empurra para direita
			if character.global_position.x < global_position.x:
				_last_attack_direction = 1.0  # Empurra para direita
			else:
				_last_attack_direction = -1.0  # Empurra para esquerda
			return
	
	# Fallback: usar direção do global.character
	if global.character:
		if global.character.global_position.x < global_position.x:
			_last_attack_direction = 1.0
		else:
			_last_attack_direction = -1.0
	else:
		_last_attack_direction = 1.0  # Padrão: direita

func _destroyed() -> void:
	if _should_persist and _unique_id != "":
		global.register_destroyed_object(_unique_id)
	
	var shards_to_spawn = _get_shard_textures()
	var level = _get_current_level()
	var spawn_position: Vector2 = global_position
	
	for _piece in shards_to_spawn:
		var shard = _NON_COLLECTABLE_ITEM.instantiate()
		shard.is_collectable = false
		shard.item_texture = _piece
		# ✅ PRIMEIRO entra na árvore, DEPOIS define a posição global
		level.add_child(shard)
		shard.global_position = spawn_position
		_apply_shard_physics(shard)
	
	_drop_items(spawn_position, level)
	
	if _broken_audio:
		_broken_audio.play()
	
	if _keep_broken:
		_set_broken_state()
		return
	
	queue_free()  # sem await do áudio — ele continua tocando independente

func _set_broken_state() -> void:
	"""Versão quebrada que fica na cena: só decoração, sem colisão nem golpes."""
	_is_destroyed = true
	_is_interactable = false
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Broken"):
		_sprite.play("Broken")
	if _body_collision:
		_body_collision.set_deferred("disabled", true)
	if _interaction_area:
		_interaction_area.set_deferred("disabled", true)
	var hit_collision := get_node_or_null("Collision") as CollisionShape2D
	if hit_collision:
		hit_collision.set_deferred("disabled", true)

# ✅ NOVA FUNÇÃO: Aplicar física aos fragmentos
func _apply_shard_physics(shard: Node) -> void:
	"""Aplica física aos fragmentos baseado na direção do ataque"""
	if not shard is RigidBody2D:
		return
	
	# Força horizontal na direção oposta ao ataque
	var force_x = randf_range(_shard_force_x_min, _shard_force_x_max) * _last_attack_direction
	
	# Força vertical (sempre para cima)
	var force_y = randf_range(_shard_force_y_min, _shard_force_y_max)
	
	# Aplicar impulso e rotação
	shard.apply_central_impulse(Vector2(force_x, force_y))
	shard.apply_torque_impulse(randf_range(_shard_torque_min, _shard_torque_max))

# ✅ NOVA FUNÇÃO: Aplicar física aos itens dropados
func _apply_item_physics(item: Node) -> void:
	"""Aplica física leve aos itens coletáveis dropados"""
	if not item is RigidBody2D:
		return
	
	# Força mais leve que os fragmentos
	var force_x = randf_range(50.0, 150.0) * _last_attack_direction
	var force_y = randf_range(-100.0, -200.0)
	
	item.apply_central_impulse(Vector2(force_x, force_y))
	item.apply_torque_impulse(randf_range(-200.0, 200.0))

func _get_shard_textures() -> Array:
	if _shard_group == ShardGroup.CUSTOM:
		return _interactable_pieces
	
	if SHARD_TEXTURES.has(_shard_group):
		return SHARD_TEXTURES[_shard_group]
	
	return _interactable_pieces

func _get_current_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.current_level:
		return game_main.current_level
	return get_tree().current_scene

func _wait_for_broken_audio() -> void:
	var audio_duration: float = 0.0
	
	if _broken_audio and _broken_audio.stream:
		audio_duration = _broken_audio.stream.get_length()
	
	if audio_duration == 0.0:
		audio_duration = 0.5
	
	await get_tree().create_timer(audio_duration).timeout

func _on_texture_animation_finished() -> void:
	if _sprite.animation == "Destroyed":
		queue_free()
