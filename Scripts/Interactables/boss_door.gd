extends Node2D
class_name BossDoor

@export_category("Boss Settings")
@export var boss_id: String = ""
@export var boss_scene: PackedScene
@export var boss_spawn_point: Marker2D

@export_category("Player Movement")
@export_enum("Left:-1", "Right:1") var entry_direction: int = 1
@export var walk_duration: float = 2.5

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var door_collision: StaticBody2D
@export var door_collision_shape: CollisionShape2D
@export var interaction_area: Area2D
@export var interaction_prompt: AnimatedSprite2D
## ✅ NOVO: Área específica para vibração (maior que interaction_area)
@export var rumble_area: Area2D

@export_category("Audio")
@export var open_gate_audio: AudioStreamPlayer
@export var close_gate_audio: AudioStreamPlayer
@export var boss_area_audio: AudioStreamPlayer2D
@export var door_quake_audio: AudioStreamPlayer

@export_category("Audio Settings")
@export var max_audio_distance: float = 500.0
@export var attenuation_distance: float = 200.0

@export_category("Controller Rumble")
## Intensidade fixa da vibração (0.0 a 1.0)
@export var rumble_strength: float = 0.3
## Ativar/desativar vibração
@export var enable_rumble: bool = true
## Duração do fade out da vibração (em segundos)
@export var rumble_fade_duration: float = 1.0

var player_in_range: bool = false
var is_open: bool = false
var boss_instance: Node = null
var is_boss_defeated: bool = false
var is_animating: bool = false
var is_moving_player: bool = false

# ✅ Controle de vibração simplificado
var player_in_rumble_area: bool = false
var is_rumbling: bool = false
var rumble_proximity_disabled: bool = false

func _ready() -> void:
	if boss_id == "":
		push_error("⚠️ BossDoor: boss_id não foi definido!")
		return
	
	if not door_collision_shape:
		push_error("⚠️ BossDoor: door_collision_shape não foi configurado!")
	
	# Conectar área de interação
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# ✅ Conectar área de vibração (se existir)
	if rumble_area:
		rumble_area.body_entered.connect(_on_rumble_area_body_entered)
		rumble_area.body_exited.connect(_on_rumble_area_body_exited)
		print("✅ [BossDoor] Rumble Area configurada")
	else:
		print("⚠️ [BossDoor] Rumble Area não configurada - vibração desabilitada")
		enable_rumble = false
	
	if texture:
		texture.animation_finished.connect(_on_animation_finished)
	
	if interaction_prompt:
		interaction_prompt.visible = false
	
	if boss_area_audio:
		boss_area_audio.max_distance = max_audio_distance
		boss_area_audio.attenuation = 2.0
	
	_check_boss_status()
	
	if is_boss_defeated:
		texture.play("Open")
		is_open = true
		disable_collision()
		rumble_proximity_disabled = true
		if boss_area_audio:
			boss_area_audio.stop()
	else:
		texture.play("Closed")
		if boss_area_audio:
			boss_area_audio.play()

func _check_boss_status() -> void:
	if global.defeated_bosses.has(boss_id):
		is_boss_defeated = true

func _process(delta: float) -> void:
	# Atualizar prompt
	if interaction_prompt and player_in_range:
		var should_show = not is_open and not is_boss_defeated and not is_animating
		if interaction_prompt.visible != should_show:
			interaction_prompt.visible = should_show
	
	# Input check
	if player_in_range and not is_open and not is_boss_defeated and not is_animating:
		if Input.is_action_just_pressed("move_up"):
			start_boss_encounter()

# ========== ✅ VIBRAÇÃO BASEADA EM ÁREA (SEM _process!) ==========

func _on_rumble_area_body_entered(body: Node2D) -> void:
	"""Player entrou na área de vibração"""
	if not body.is_in_group("player"):
		return
	
	# Não vibrar se boss já foi derrotado ou vibração desabilitada
	if is_boss_defeated or not enable_rumble or rumble_proximity_disabled:
		return
	
	player_in_rumble_area = true
	_start_rumble()
	print("🎮 [BossDoor] Player entrou na rumble area - vibração INICIADA")

func _on_rumble_area_body_exited(body: Node2D) -> void:
	"""Player saiu da área de vibração"""
	if not body.is_in_group("player"):
		return
	
	player_in_rumble_area = false
	_stop_rumble()
	print("🎮 [BossDoor] Player saiu da rumble area - vibração PARADA")

func _start_rumble() -> void:
	"""Inicia vibração contínua"""
	if is_rumbling:
		return
	
	is_rumbling = true
	# Vibração CONTÍNUA (duração = 999 segundos, vai ser cancelada quando sair da área)
	Input.start_joy_vibration(0, rumble_strength * 0.5, rumble_strength, 999.0)
	print("🎮 Vibração contínua iniciada (força: ", rumble_strength, ")")

func _stop_rumble() -> void:
	"""Para a vibração imediatamente"""
	if not is_rumbling:
		return
	
	Input.stop_joy_vibration(0)
	is_rumbling = false
	print("🎮 Vibração parada")

func _fade_out_rumble() -> void:
	"""Diminui gradualmente a vibração"""
	if not is_rumbling:
		return
	
	print("🎮 Iniciando fade out da vibração...")
	
	var fade_time = 0.0
	var initial_strength = rumble_strength
	
	while fade_time < rumble_fade_duration:
		fade_time += get_process_delta_time()
		var fade_progress = fade_time / rumble_fade_duration
		var faded_strength = initial_strength * (1.0 - fade_progress)
		
		Input.start_joy_vibration(0, faded_strength * 0.5, faded_strength, 0.1)
		
		await get_tree().process_frame
	
	_stop_rumble()
	print("✅ Fade out da vibração concluído")

# ========== ÁREA DE INTERAÇÃO (PROMPT) ==========

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

# ========== BOSS ENCOUNTER ==========

func start_boss_encounter() -> void:
	if is_open or is_boss_defeated or is_animating:
		return
	
	is_animating = true
	
	if door_quake_audio:
		door_quake_audio.play()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player._is_in_cinematic = true
	
	if interaction_prompt:
		interaction_prompt.visible = false
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 0.5)
	
	await get_tree().create_timer(0.5).timeout
	
	if open_gate_audio:
		open_gate_audio.play()
	
	texture.play("Open")

func _on_animation_finished() -> void:
	if texture.animation == "Open":
		disable_collision()
		await get_tree().process_frame
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			await move_player_automatically(player)
		
		# ✅ Fade out da vibração após movimento
		_fade_out_rumble()
		
		if close_gate_audio:
			close_gate_audio.play()
		
		texture.play("Closing")
		enable_collision()
		is_open = false
	
	elif texture.animation == "Closing":
		# ✅ Desabilitar vibração permanentemente
		rumble_proximity_disabled = true
		_stop_rumble()
		
		if boss_area_audio:
			boss_area_audio.stop()
			boss_area_audio.process_mode = Node.PROCESS_MODE_DISABLED
		
		texture.play("Closed")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player._is_in_cinematic = false
		
		spawn_boss()
		is_animating = false

func move_player_automatically(player: Node) -> void:
	player._is_in_cinematic = false
	is_moving_player = true
	
	var action_name = "move_right" if entry_direction == 1 else "move_left"
	var elapsed_time = 0.0
	
	while elapsed_time < walk_duration:
		var delta = get_process_delta_time()
		Input.action_press(action_name)
		elapsed_time += delta
		await get_tree().process_frame
	
	Input.action_release(action_name)
	await get_tree().process_frame
	
	if player.has_node("CharacterTexture"):
		var char_texture = player.get_node("CharacterTexture")
		player.velocity.x = 0
		if char_texture.sprite_frames and char_texture.sprite_frames.has_animation("Idle"):
			char_texture.play("Idle")
	
	player._is_in_cinematic = true
	is_moving_player = false

func spawn_boss() -> void:
	if not boss_scene or not boss_spawn_point:
		push_error("⚠️ BossDoor: boss_scene ou boss_spawn_point não definido!")
		return
	
	boss_instance = boss_scene.instantiate()
	get_tree().current_scene.add_child(boss_instance)
	boss_instance.global_position = boss_spawn_point.global_position
	
	if boss_instance.has_signal("boss_defeated"):
		boss_instance.boss_defeated.connect(_on_boss_defeated)
	else:
		_start_boss_health_monitoring()

func _start_boss_health_monitoring() -> void:
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = 1.0
	check_timer.timeout.connect(_check_if_boss_dead)
	check_timer.start()

func _check_if_boss_dead() -> void:
	if not boss_instance or not is_instance_valid(boss_instance):
		_on_boss_defeated()
		return
	
	if "_is_alive" in boss_instance:
		if not boss_instance._is_alive:
			_on_boss_defeated()

func _on_boss_defeated() -> void:
	is_boss_defeated = true
	
	if not global.defeated_bosses.has(boss_id):
		global.defeated_bosses.append(boss_id)
	
	if global.has_node("serialization"):
		var serialization_node = global.get_node("serialization")
		serialization_node.save_data()
	
	await get_tree().create_timer(2.0).timeout
	open_gate_permanently()

func open_gate_permanently() -> void:
	if open_gate_audio:
		open_gate_audio.play()
	
	texture.play("Open")
	is_open = true
	disable_collision()

func disable_collision() -> void:
	if door_collision_shape:
		door_collision_shape.set_deferred("disabled", true)

func enable_collision() -> void:
	if door_collision_shape:
		door_collision_shape.set_deferred("disabled", false)

func _exit_tree() -> void:
	_stop_rumble()
