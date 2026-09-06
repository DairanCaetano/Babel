extends Area2D
class_name DestructibleWall

@export var tilemap_layer: TileMapLayer

@export_category("Objects")
@export var cracks_sprite: AnimatedSprite2D
@export var impact_audio: AudioStreamPlayer2D
@export var break_audio: AudioStreamPlayer2D
@export var break_particles: GPUParticles2D

@export_category("Debris")
@export var spawn_debris: bool = true
@export var pottery_shards_count: int = 4
@export var wall_shards_count: int = 4

@export_category("Persistence")
@export var wall_id: String = ""  # ✅ Configure MANUALMENTE no Inspector

const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")
const _WALL_SHARD: PackedScene = preload("res://Scenes/FX/destructible_wall_shards.tscn")

const POTTERY_SHARD_TEXTURES = [
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v01.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v02.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v03.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v04.png"),
]

const WALL_SHARD_TEXTURE: Texture2D = preload("res://sprites/Interactables/DestructableRock_FX.png")

var attack_count: int = 0
const ATTACKS_TO_BREAK: int = 4

func _ready():
	# ✅ VALIDAÇÃO DE ERRO DETALHADA
	if not tilemap_layer:
		push_error("❌ DestructibleWall: TileMapLayer não configurado em ", name)
		return
	
	# ✅ GERAR ID AUTOMÁTICO SE VAZIO (mas avisar)
	if wall_id.is_empty():
		wall_id = _generate_auto_id()
		push_warning("⚠️ DestructibleWall sem ID manual! Gerado automaticamente: ", wall_id)
		push_warning("   Recomendado: Configure manualmente no Inspector para garantir persistência")
	
	# ✅ VERIFICAR SE JÁ FOI DESTRUÍDA (ANTES DE QUALQUER COISA)
	if _was_already_destroyed():
		print("  🔨 Parede já destruída removida: ", wall_id)
		
		# Remover TileMapLayer e self
		if is_instance_valid(tilemap_layer):
			tilemap_layer.queue_free()
		
		queue_free()
		return
	
	# ✅ ADICIONAR AO GRUPO (para BaseLevel encontrar se precisar)
	add_to_group("breakable_wall")
	
	# Setup visual
	if cracks_sprite:
		cracks_sprite.play("idle")
	
	if break_particles:
		break_particles.visible = false
		break_particles.emitting = false
	
	# Conectar sinal
	area_entered.connect(_on_area_entered)
	
	print("  🧱 DestructibleWall configurada: ", wall_id)

func _generate_auto_id() -> String:
	"""Gera ID automático baseado na hierarquia (fallback)"""
	var level_name = "unknown"
	
	# Tentar pegar nome do level
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.has_method("get") and game_main.get("current_level"):
		var level = game_main.current_level
		if level:
			level_name = level.name
	
	# Gerar ID: level_tilemap_timestamp
	return level_name + "_" + tilemap_layer.name + "_" + str(Time.get_ticks_msec())

func _on_area_entered(area: Area2D):
	if not area.is_in_group("player_attack"):
		return
	
	attack_count += 1
	
	# ✅ Áudio de impacto (todos os ataques exceto o último)
	if attack_count < ATTACKS_TO_BREAK:
		if impact_audio:
			impact_audio.play()
	
	# ✅ Partículas de impacto
	if attack_count < ATTACKS_TO_BREAK:
		if break_particles:
			break_particles.visible = true
			break_particles.emitting = true
			break_particles.restart()
	
	# ✅ Shake da câmera
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		var shake_intensity = attack_count * 1
		camera.shake_camera(shake_intensity, 0.2)
	
	# ✅ Hit stop
	if HitStopManager:
		HitStopManager.hit_stop_short()
	
	# ✅ Atualizar rachadura
	if attack_count <= 3:
		_update_crack_animation()
	
	# ✅ Destruir parede
	if attack_count >= ATTACKS_TO_BREAK:
		_destroy_wall()

func _update_crack_animation():
	if not cracks_sprite:
		return
	
	match attack_count:
		1: cracks_sprite.play("Rachadura1")
		2: cracks_sprite.play("Rachadura2")
		3: cracks_sprite.play("Rachadura3")

func _destroy_wall():
	print("💥 Parede destruída: ", wall_id)
	
	# ✅ 1. SALVAR ESTADO (PRIMEIRO!)
	_save_destroyed_state()
	
	# ✅ 2. Áudios
	var audio_duration: float = 0.0
	
	if impact_audio:
		impact_audio.play()
	
	if break_audio:
		break_audio.play()
		if break_audio.stream:
			audio_duration = break_audio.stream.get_length()
	
	# ✅ 3. Spawnar destroços
	if spawn_debris:
		_spawn_debris()
	
	# ✅ 4. Esconder visual
	if tilemap_layer:
		tilemap_layer.modulate.a = 0.0
		tilemap_layer.enabled = false
	
	if cracks_sprite:
		cracks_sprite.modulate.a = 0.0
	
	# ✅ 5. Hit stop médio
	if HitStopManager:
		HitStopManager.hit_stop_medium()
	
	# ✅ 6. Desabilitar colisões
	monitoring = false
	monitorable = false
	
	# ✅ 7. Esperar áudio terminar
	var wait_time = max(audio_duration, 0.5)
	await get_tree().create_timer(wait_time).timeout
	
	# ✅ 8. Remover da cena
	if is_instance_valid(tilemap_layer):
		tilemap_layer.queue_free()
	
	queue_free()

func _spawn_debris():
	var level = _get_current_level()
	
	# Spawnar cerâmica
	for i in range(pottery_shards_count):
		_spawn_pottery_shard(level)
	
	# Spawnar fragmentos de parede
	for i in range(wall_shards_count):
		_spawn_wall_shard(level)

func _spawn_pottery_shard(level: Node):
	var shard_texture = POTTERY_SHARD_TEXTURES[randi() % POTTERY_SHARD_TEXTURES.size()]
	
	var shard: CollectableItem = _COLLECTABLE_ITEM.instantiate()
	shard.is_collectable = false
	shard.item_texture = shard_texture.resource_path
	shard.global_position = global_position
	
	level.call_deferred("add_child", shard)

func _spawn_wall_shard(level: Node):
	var shard: DestructibleWallShards = _WALL_SHARD.instantiate()
	
	var random_scale = randf_range(0.5, 1.5)
	
	# Determinar direção dos destroços
	var debris_direction: float = 1.0
	if cracks_sprite and cracks_sprite.flip_h:
		debris_direction = -1.0
	
	shard.shard_texture_preloaded = WALL_SHARD_TEXTURE
	shard.shard_scale = random_scale
	shard.global_position = global_position
	
	level.add_child(shard)
	
	await get_tree().process_frame
	
	# Aplicar física
	if is_instance_valid(shard):
		var force_x = randf_range(60, 180) * debris_direction
		var force_y = randf_range(-180, -80)
		shard.apply_central_impulse(Vector2(force_x, force_y))
		shard.apply_torque_impulse(randf_range(-300, 300))

func _get_current_level() -> Node:
	"""Pega o level atual"""
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.has_method("get") and game_main.get("current_level"):
		return game_main.current_level
	return get_tree().current_scene

# ===== 💾 SISTEMA DE PERSISTÊNCIA =====

func _save_destroyed_state():
	"""Salva que a parede foi destruída"""
	
	# ✅ Inicializar array se não existir
	if not serialization.game_data.has("destroyed_walls"):
		serialization.game_data["destroyed_walls"] = []
	
	# ✅ Adicionar ID se não estiver na lista
	if not serialization.game_data["destroyed_walls"].has(wall_id):
		serialization.game_data["destroyed_walls"].append(wall_id)
		print("  💾 Parede salva como destruída: ", wall_id)
	
	# ✅ SALVAR IMEDIATAMENTE
	serialization.save_data()

func _was_already_destroyed() -> bool:
	"""Verifica se a parede já foi destruída"""
	
	if not serialization.game_data.has("destroyed_walls"):
		return false
	
	return serialization.game_data["destroyed_walls"].has(wall_id)
