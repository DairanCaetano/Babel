@tool
extends Node2D
class_name BossDoor

# Porta de sala de chefe — UMA cena serve para todos os chefes.
#
# Como usar na fase:
#   1. Instancie boss_door.tscn em cada entrada da sala do chefe.
#   2. Em todas as portas da mesma sala, coloque o MESMO boss_id
#      (ex.: "ra", "baal_berith" — igual ao boss_id do chefe).
#   3. flip_h desligado = o player entra andando da ESQUERDA para a DIREITA.
#      flip_h ligado    = o player entra da DIREITA para a ESQUERDA.
#      (no editor só o desenho vira; as áreas são espelhadas quando o jogo roda)
#   4. boss_room_sound = o som ambiente daquele chefe, tocado perto da porta.
#
# A porta NÃO spawna o chefe — quem faz isso é o spawner da sala (BerithTree,
# Disco do Rá...). A porta só cuida da entrada e some quando a sala é
# resolvida (chefe derrotado OU aliança), via BossEventManager.boss_resolved.
# Se a sala já estiver resolvida quando a fase carrega, a porta nem aparece.

enum State { CLOSED, OPENING, WALKING, CLOSING, LOCKED, VANISHING }

@export_category("Boss Settings")
@export var boss_id: String = ""

@export_category("Direção")
## Desligado: entra da esquerda pra direita. Ligado: da direita pra esquerda.
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_apply_texture_flip()

@export_category("Player Movement")
## Quantos pixels o player anda além do centro da porta antes de ela fechar
@export var walk_past_distance: float = 72.0
## Tempo máximo andando (segurança, caso o player fique preso)
@export var walk_duration: float = 3.0

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var door_collision: StaticBody2D
@export var door_collision_shape: CollisionShape2D
@export var interaction_area: Area2D
@export var interaction_prompt: AnimatedSprite2D
## Área de vibração (maior que a interaction_area)
@export var rumble_area: Area2D

@export_category("Audio")
## Som ambiente da sala deste chefe (cada instância da porta pode ter o seu)
@export var boss_room_sound: AudioStream
@export var open_gate_audio: AudioStreamPlayer
@export var close_gate_audio: AudioStreamPlayer
@export var boss_area_audio: AudioStreamPlayer2D
@export var door_quake_audio: AudioStreamPlayer

@export_category("Audio Settings")
@export var max_audio_distance: float = 1000.0

@export_category("Controller Rumble")
## Intensidade fixa da vibração (0.0 a 1.0)
@export var rumble_strength: float = 0.3
## Ativar/desativar vibração
@export var enable_rumble: bool = true
## Duração do fade out da vibração (em segundos)
@export var rumble_fade_duration: float = 1.0

var _state: State = State.CLOSED
var _player_in_range: bool = false
var _is_rumbling: bool = false
var _direction: float = 1.0   # 1 = entra andando pra direita, -1 = pra esquerda

# Posições como foram desenhadas na cena (flip_h desligado)
var _default_positions: Dictionary = {}


func _ready() -> void:
	_find_nodes()
	_apply_texture_flip()
	if Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("boss_door")

	if boss_id == "":
		push_error("⚠️ BossDoor: boss_id não foi definido!")

	# Sala já resolvida (derrota ou aliança) → a porta nem existe
	if boss_id != "" and BossEventManager.is_boss_resolved(boss_id):
		queue_free()
		return

	_direction = -1.0 if flip_h else 1.0
	_capture_and_mirror()

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	if rumble_area:
		rumble_area.body_entered.connect(_on_rumble_area_body_entered)
		rumble_area.body_exited.connect(_on_rumble_area_body_exited)
	else:
		enable_rumble = false
	if texture:
		texture.animation_finished.connect(_on_animation_finished)

	BossEventManager.boss_resolved.connect(_on_boss_resolved)

	if interaction_prompt:
		interaction_prompt.visible = false

	if boss_area_audio:
		if boss_room_sound:
			boss_area_audio.stream = boss_room_sound
		boss_area_audio.max_distance = max_audio_distance
		if boss_area_audio.stream:
			boss_area_audio.play()

	_state = State.CLOSED
	enable_collision()
	_play("Closed")


func _find_nodes() -> void:
	if not texture:
		texture = get_node_or_null("Texture")
	if not door_collision:
		door_collision = get_node_or_null("BossCollision")
	if not door_collision_shape:
		door_collision_shape = get_node_or_null("BossCollision/Collision")
	if not interaction_area:
		interaction_area = get_node_or_null("InteractionArea")
	if not interaction_prompt:
		interaction_prompt = get_node_or_null("InteractionPrompt")
	if not rumble_area:
		rumble_area = get_node_or_null("RumbleArea")
	if not open_gate_audio:
		open_gate_audio = get_node_or_null("OpenGateAudio")
	if not close_gate_audio:
		close_gate_audio = open_gate_audio
	if not boss_area_audio:
		boss_area_audio = get_node_or_null("BossAreaAudio")
	if not door_quake_audio:
		door_quake_audio = get_node_or_null("BossQuakeAudio")


func _apply_texture_flip() -> void:
	if not is_inside_tree():
		return
	var tex: AnimatedSprite2D = texture if texture else get_node_or_null("Texture")
	if tex:
		tex.flip_h = flip_h


# Espelha no eixo X tudo que depende do lado de entrada
func _capture_and_mirror() -> void:
	var nodes: Array[Node2D] = []
	if door_collision_shape:
		nodes.append(door_collision_shape)
	if interaction_area:
		for child in interaction_area.get_children():
			if child is Node2D:
				nodes.append(child)
	if rumble_area:
		for child in rumble_area.get_children():
			if child is Node2D:
				nodes.append(child)
	if interaction_prompt:
		nodes.append(interaction_prompt)

	for node in nodes:
		_default_positions[node] = node.position
		node.position = Vector2(node.position.x * _direction, node.position.y)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var can_enter: bool = _state == State.CLOSED and _player_in_range
	if interaction_prompt and interaction_prompt.visible != can_enter:
		interaction_prompt.visible = can_enter
		if can_enter and interaction_prompt.sprite_frames and interaction_prompt.sprite_frames.has_animation("Idle"):
			interaction_prompt.play("Idle")

	if can_enter and Input.is_action_just_pressed("move_up"):
		start_boss_encounter()


# ========== ÁREA DE INTERAÇÃO (PROMPT) ==========

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


# ========== ENTRADA NA SALA ==========

func start_boss_encounter() -> void:
	if _state != State.CLOSED:
		return
	_state = State.OPENING

	if interaction_prompt:
		interaction_prompt.visible = false

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player._is_in_cinematic = true
		player.velocity = Vector2.ZERO

	if door_quake_audio:
		door_quake_audio.play()
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 0.5)

	await get_tree().create_timer(0.5, false).timeout
	if _state != State.OPENING:
		return

	if open_gate_audio:
		open_gate_audio.play()
	_play("Open")


func _on_animation_finished() -> void:
	match texture.animation:
		"Open":
			if _state == State.OPENING:
				_walk_player_in()
		"Closing":
			if _state == State.CLOSING:
				_finish_closing()
		"Dead":
			if _state == State.VANISHING:
				queue_free()


func _walk_player_in() -> void:
	_state = State.WALKING
	disable_collision()
	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")
	if player:
		await _move_player_automatically(player)
	if _state != State.WALKING:
		return

	_fade_out_rumble()

	_state = State.CLOSING
	if close_gate_audio:
		close_gate_audio.play()
	enable_collision()
	_play("Closing")


func _finish_closing() -> void:
	_state = State.LOCKED
	_play("Closed")

	# Todas as portas desta sala param o som e a vibração
	for door in get_tree().get_nodes_in_group("boss_door"):
		if door is BossDoor and door.boss_id == boss_id:
			door._on_room_locked()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player._is_in_cinematic = false


func _on_room_locked() -> void:
	if _state == State.CLOSED:
		_state = State.LOCKED
	if interaction_prompt:
		interaction_prompt.visible = false
	enable_rumble = false
	_stop_rumble()
	if boss_area_audio:
		boss_area_audio.stop()


# Leva a Tola para dentro da sala sem soltar o controle: o modo de cena fica
# ligado o tempo todo e ela anda pelo cinematic_walk_dir do player
# (nenhum botão — agachar, pular, atacar, dash — interfere).
func _move_player_automatically(player: Node) -> void:
	player._is_in_cinematic = true
	if "cinematic_walk_dir" in player:
		player.cinematic_walk_dir = _direction
	var elapsed: float = 0.0

	while elapsed < walk_duration:
		if not is_instance_valid(player):
			break
		var passed: float = (player.global_position.x - global_position.x) * _direction
		if passed >= walk_past_distance:
			break
		elapsed += get_process_delta_time()
		await get_tree().process_frame

	if is_instance_valid(player):
		if "cinematic_walk_dir" in player:
			player.cinematic_walk_dir = 0.0
		player.velocity.x = 0
		player._is_in_cinematic = true


# ========== SALA RESOLVIDA (derrota ou aliança) ==========

func _on_boss_resolved(resolved_id: String) -> void:
	if resolved_id != boss_id or _state == State.VANISHING:
		return
	_state = State.VANISHING
	_player_in_range = false
	if interaction_prompt:
		interaction_prompt.visible = false
	enable_rumble = false
	_stop_rumble()
	if boss_area_audio:
		boss_area_audio.stop()
	disable_collision()

	if texture and texture.sprite_frames and texture.sprite_frames.has_animation("Dead"):
		_play("Dead")   # sem som: não atrapalhar o fluxo depois da luta
		if texture.sprite_frames.get_animation_loop("Dead"):
			get_tree().create_timer(1.0, false).timeout.connect(queue_free)
	else:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)


# ========== VIBRAÇÃO ==========

func _on_rumble_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and enable_rumble and _state == State.CLOSED:
		_start_rumble()

func _on_rumble_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_stop_rumble()

func _start_rumble() -> void:
	if _is_rumbling:
		return
	_is_rumbling = true
	# Vibração contínua (cancelada quando o player sai da área)
	Input.start_joy_vibration(0, rumble_strength * 0.5, rumble_strength, 999.0)

func _stop_rumble() -> void:
	if not _is_rumbling:
		return
	Input.stop_joy_vibration(0)
	_is_rumbling = false

func _fade_out_rumble() -> void:
	if not _is_rumbling:
		return
	var fade_time: float = 0.0
	while fade_time < rumble_fade_duration and _is_rumbling:
		fade_time += get_process_delta_time()
		var faded_strength: float = rumble_strength * (1.0 - fade_time / rumble_fade_duration)
		Input.start_joy_vibration(0, faded_strength * 0.5, faded_strength, 0.1)
		await get_tree().process_frame
	_stop_rumble()


# ========== UTIL ==========

func _play(animation_name: String) -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)

func disable_collision() -> void:
	if door_collision_shape:
		door_collision_shape.set_deferred("disabled", true)

func enable_collision() -> void:
	if door_collision_shape:
		door_collision_shape.set_deferred("disabled", false)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_stop_rumble()
