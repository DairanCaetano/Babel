extends Area2D
class_name ObjectTriggeredWall

@export var tilemap_layer: TileMapLayer

@export_category("Objects")
@export var cracks_sprite: AnimatedSprite2D
@export var impact_audio: AudioStreamPlayer
@export var break_audio: AudioStreamPlayer
@export var break_particles: GPUParticles2D

@export_category("Trigger Settings")
@export var trigger_object_group: String = "trigger_object"  # Grupo do objeto que vai destruir
@export var destroy_on_first_contact: bool = true  # Se true, destrói instantaneamente
@export var hits_required: int = 1  # Se destroy_on_first_contact for false

@export_category("Debris")
@export var spawn_debris: bool = true
@export var pottery_shards_count: int = 4
@export var wall_shards_count: int = 4

@export_category("Persistence")
@export var wall_id: String = ""

const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")
const _WALL_SHARD: PackedScene = preload("res://Scenes/FX/destructible_wall_shards.tscn")

const POTTERY_SHARD_TEXTURES = [
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v01.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v02.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v03.png"),
	preload("res://sprites/Interactables/INTERACTABLE_CERÂMICA_PEDAÇOS__v04.png"),
]

const WALL_SHARD_TEXTURE: Texture2D = preload("res://sprites/Interactables/DestructableRock_FX.png")

var hit_count: int = 0

func _ready():
	if not tilemap_layer:
		push_error("❌ Arraste o TileMapLayer no Inspector!")
		return
	
	if wall_id.is_empty():
		wall_id = tilemap_layer.name + "_" + name
	
	# ✅ ADICIONAR AO GRUPO PARA O BaseLevel ENCONTRAR
	add_to_group("breakable_wall")
	
	if _was_already_destroyed():
		print("🚫 Parede já foi destruída antes: ", wall_id)
		if is_instance_valid(tilemap_layer):
			tilemap_layer.queue_free()
		queue_free()
		return
	
	print("✅ ObjectTriggeredWall configurada")
	print("   - ID: ", wall_id)
	print("   - Grupo esperado: ", trigger_object_group)
	print("   - Collision Layer: ", collision_layer)
	print("   - Collision Mask: ", collision_mask)
	
	# ✅ CONFIGURAR VISUAL
	if cracks_sprite:
		cracks_sprite.play("idle")
	
	if break_particles:
		break_particles.visible = false
		break_particles.emitting = false
	
	# ✅ CONECTAR SINAIS
	body_entered.connect(_on_trigger_collision)
	area_entered.connect(_on_trigger_collision)
	print("   - Sinais conectados!")

func _on_trigger_collision(trigger):
	print("🔍 ALGO COLIDIU COM A PAREDE!")
	print("   - Nome: ", trigger.name)
	print("   - Tipo: ", trigger.get_class())
	print("   - Grupos: ", trigger.get_groups())
	
	# ✅ VERIFICA SE É O OBJETO CORRETO
	if not trigger.is_in_group(trigger_object_group):
		print("❌ Objeto NÃO está no grupo: ", trigger_object_group)
		return
	
	print("✅ Grupo correto! Processando destruição...")
	
	if destroy_on_first_contact:
		_destroy_wall()
	else:
		hit_count += 1
		
		if hit_count < hits_required:
			_handle_impact()
		
		if hit_count >= hits_required:
			_destroy_wall()

func _handle_impact():
	# ✅ FEEDBACK DE IMPACTO (sem destruir ainda)
	if impact_audio:
		impact_audio.play()
	
	if break_particles:
		break_particles.visible = true
		break_particles.emitting = true
		break_particles.restart()
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(2, 0.2)
	
	if HitStopManager:
		HitStopManager.hit_stop_short()
	
	# ✅ ATUALIZA RACHADURA (se tiver animação)
	if cracks_sprite and hit_count <= 3:
		_update_crack_animation()

func _update_crack_animation():
	if not cracks_sprite:
		return
	
	match hit_count:
		1: cracks_sprite.play("Rachadura1")
		2: cracks_sprite.play("Rachadura2")
		3: cracks_sprite.play("Rachadura3")

func _destroy_wall():
	monitoring = false
	monitorable = false
	print("💥 ObjectTriggeredWall destruída por objeto do grupo: ", trigger_object_group)
	
	var audio_duration: float = 0.0
	
	if impact_audio:
		impact_audio.play()
	
	if break_audio:
		break_audio.play()
		if break_audio.stream:
			audio_duration = break_audio.stream.get_length()
	
	if break_particles:
		break_particles.visible = true
		break_particles.emitting = true
		break_particles.restart()
	
	if HitStopManager:
		HitStopManager.hit_stop_medium()
	
	await get_tree().create_timer(1.0).timeout
	
	if spawn_debris:
		_spawn_debris()
	
	# ✅ FADE OUT DO TILEMAP COM SONS EM INTERVALOS ESPECÍFICOS
	if tilemap_layer:
		var fade_duration = 0.5
		var tween = create_tween()
		tween.tween_property(tilemap_layer, "modulate:a", 0.0, fade_duration)
		
		# ✅ FUNÇÃO AUXILIAR PARA TOCAR ÁUDIO SEM SOBRESCREVER
		var play_impact_copy = func():
			if impact_audio and impact_audio.stream:
				var temp_player = AudioStreamPlayer.new()
				temp_player.stream = impact_audio.stream
				temp_player.volume_db = impact_audio.volume_db
				temp_player.pitch_scale = impact_audio.pitch_scale
				temp_player.bus = impact_audio.bus
				add_child(temp_player)
				temp_player.play()
				
				# Auto-destruir após tocar
				temp_player.finished.connect(func():
					temp_player.queue_free()
				)
		
		# ✅ TOCAR SOM EM 50% alpha - 0.25s (metade do fade)
		get_tree().create_timer(fade_duration * 0.50).timeout.connect(func():
			if is_instance_valid(self):
				play_impact_copy.call()
				print("🔊 Impact audio tocado em 50% alpha")
		)
		
		# ✅ TOCAR SOM EM 70% alpha - 0.15s 
		get_tree().create_timer(fade_duration * 0.30).timeout.connect(func():
			if is_instance_valid(self):
				play_impact_copy.call()
				print("🔊 Impact audio tocado em 70% alpha")
		)
		
		# ✅ TOCAR SOM EM 90% alpha - 0.05s
		get_tree().create_timer(fade_duration * 0.10).timeout.connect(func():
			if is_instance_valid(self):
				play_impact_copy.call()
				print("🔊 Impact audio tocado em 90% alpha")
		)
		
		await tween.finished
		tilemap_layer.enabled = false
	
	if cracks_sprite:
		cracks_sprite.modulate.a = 0.0
	
	# ✅ SALVAR ESTADO ANTES DE DESTRUIR
	_save_destroyed_state()
	
	var final_wait = max(audio_duration - 1.0, 0.5)
	await get_tree().create_timer(final_wait).timeout
	
	if is_instance_valid(tilemap_layer):
		tilemap_layer.queue_free()
	
	# ✅ REMOVER A PRÓPRIA AREA2D
	queue_free()

func _spawn_debris():
	var level = _get_current_level()
	
	for i in range(pottery_shards_count):
		_spawn_pottery_shard(level)
	
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
	
	var debris_direction: float = 1.0
	if cracks_sprite and cracks_sprite.flip_h:
		debris_direction = -1.0
	
	shard.shard_texture_preloaded = WALL_SHARD_TEXTURE
	shard.shard_scale = random_scale
	shard.global_position = global_position
	
	level.add_child(shard)
	
	await get_tree().process_frame
	
	if is_instance_valid(shard):
		var force_x = randf_range(60, 180) * debris_direction
		var force_y = randf_range(-180, -80)
		shard.apply_central_impulse(Vector2(force_x, force_y))
		shard.apply_torque_impulse(randf_range(-300, 300))

func _get_current_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.has_method("get") and game_main.get("current_level"):
		return game_main.current_level
	return get_tree().current_scene

func _save_destroyed_state():
	if not serialization.game_data.has("destroyed_walls"):
		serialization.game_data["destroyed_walls"] = []
	
	if not serialization.game_data["destroyed_walls"].has(wall_id):
		serialization.game_data["destroyed_walls"].append(wall_id)
		print("💾 Parede salva como destruída: ", wall_id)

func _was_already_destroyed() -> bool:
	return serialization.game_data.get("destroyed_walls", []).has(wall_id)
