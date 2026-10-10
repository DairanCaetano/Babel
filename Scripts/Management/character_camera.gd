# character_camera.gd

extends Camera2D

class_name CharacterCamera

## Mostra no console as mensagens de debug da câmera (inclui o bloco a cada 1 s).
@export var debug_logs: bool = false

# ===== CONFIGURAÇÕES =====
@export var camera: camera_state = camera_state.FOLLOW
@export var camera_move_speed: float = 120.0
@export var follow_smoothness: float = 5.0
@export var look_ahead_distance: float = 50.0
@export var look_ahead_smoothness: float = 3.0

# ===== OFFSET MANUAL =====
@export_group("Camera Offset")
@export var base_offset: Vector2 = Vector2(0, -30)
@export var max_camera_offset_up: float = 80.0
@export var max_camera_offset_down: float = -60.0

# ===== REFERÊNCIAS =====
var _subject: Node2D = null

# ===== ESTADO =====
var target_camera_offset: float = 0.0
var current_camera_offset: float = 0.0
var look_ahead_offset: Vector2 = Vector2.ZERO

# ===== SHAKE =====
var rng = RandomNumberGenerator.new()
var duration = 0
var force = 0

# 🔍 DEBUG
var debug_frame_count: int = 0

enum camera_state {
	FOLLOW,
	PANNING
}

func _ready() -> void:
	add_to_group("camera")
	position_smoothing_enabled = false
	
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	
	_find_subject()
	
	if debug_logs: print("✅ CharacterCamera pronta")
	if debug_logs: print("  📏 Base Offset: ", base_offset)
	if debug_logs: print("  📏 Limites iniciais: L=", limit_left, " R=", limit_right, " T=", limit_top, " B=", limit_bottom)
	if _subject:
		if debug_logs: print("  📌 Seguindo: ", _subject.name)
	else:
		push_warning("  ⚠️ Subject não encontrado!")

func _find_subject() -> void:
	if global.character and is_instance_valid(global.character):
		_subject = global.character
		if debug_logs: print("  ✓ Subject encontrado via Global")
		return
	
	var game = get_parent()
	if game and game.has_node("Player/Character"):
		_subject = game.get_node("Player/Character")
		if debug_logs: print("  ✓ Subject encontrado via árvore")
		return
	
	push_warning("  ⚠️ Subject não encontrado!")

func _process(delta: float) -> void:
	if not _subject or not is_instance_valid(_subject):
		return
	
	# 🔍 DEBUG: Print a cada 60 frames (~1 segundo)
	debug_frame_count += 1
	if debug_frame_count >= 60:
		debug_frame_count = 0
		if debug_logs: print("🎥 Camera Debug:")
		if debug_logs: print("   Subject pos: ", _subject.global_position)
		if debug_logs: print("   Camera pos: ", global_position)
		if debug_logs: print("   Camera state: ", camera_state.keys()[camera])
		if debug_logs: print("   Limites: L=", limit_left, " R=", limit_right, " T=", limit_top, " B=", limit_bottom)
		if debug_logs: print("   Offset atual: ", offset)
		if debug_logs: print("   ---")
	
	handle_camera_offset_input(delta)
	
	match camera:
		camera_state.FOLLOW:
			camera_follow(delta)
		camera_state.PANNING:
			camera_panning()
	
	apply_visual_offsets()

func handle_camera_offset_input(delta: float) -> void:
	if Input.is_action_pressed("move_camera_up"):
		target_camera_offset = max_camera_offset_down
	elif Input.is_action_pressed("move_camera_down"):
		target_camera_offset = max_camera_offset_up
	else:
		target_camera_offset = 0.0
	
	current_camera_offset = move_toward(
		current_camera_offset, 
		target_camera_offset, 
		camera_move_speed * delta
	)
	
	if abs(current_camera_offset) < 1.0:
		current_camera_offset = 0.0

func camera_follow(delta: float) -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	
	if not _subject:
		return
	
	# Look ahead
	var target_look_ahead = Vector2.ZERO
	if _subject.has_method("get_facing_direction"):
		var facing = _subject.get_facing_direction()
		target_look_ahead.x = facing * look_ahead_distance
	
	look_ahead_offset = look_ahead_offset.lerp(
		target_look_ahead, 
		look_ahead_smoothness * delta
	)
	
	# ✅ Posição base (subject + offset base)
	var target_position = _subject.global_position + base_offset
	
	if follow_smoothness > 0:
		global_position = global_position.lerp(target_position, follow_smoothness * delta)
	else:
		global_position = target_position

func apply_visual_offsets() -> void:
	"""Aplica shake, look ahead e offset manual no Camera2D.offset"""
	var final_offset = Vector2.ZERO
	
	# Shake
	if duration > 0:
		final_offset.x += rng.randf_range(-1, 1) * force
		final_offset.y += rng.randf_range(-1, 1) * force
		duration -= get_process_delta_time()
	
	# Offset manual (olhar pra cima/baixo)
	final_offset.y += current_camera_offset
	
	# Look ahead
	final_offset += look_ahead_offset
	
	offset = final_offset

func camera_panning() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	
	if not _subject:
		return
	
	var target_x = floor(_subject.global_position.x / 480) * 480
	var target_y = floor(_subject.global_position.y / 270) * 270
	
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", Vector2(target_x, target_y), 0.14)

func shake_camera(shake_force: float, shake_duration: float) -> void:
	duration = shake_duration
	force = shake_force

func set_subject(new_subject: Node2D) -> void:
	_subject = new_subject
	if debug_logs: print("📌 Câmera agora segue: ", _subject.name if _subject else "null")

func get_subject() -> Node2D:
	return _subject

func enable_look_ahead(enable: bool) -> void:
	if not enable:
		look_ahead_offset = Vector2.ZERO

func set_camera_state(new_state: camera_state) -> void:
	camera = new_state
	if debug_logs: print("📹 Estado da câmera alterado para: ", camera_state.keys()[new_state])

func snap_to_subject() -> void:
	"""Posiciona câmera instantaneamente no subject sem transição"""
	if not _subject:
		push_error("❌ snap_to_subject: _subject é null!")
		return
	
	if debug_logs: print("📷 ===== SNAP TO SUBJECT =====")
	if debug_logs: print("  Subject position: ", _subject.global_position)
	if debug_logs: print("  Base offset: ", base_offset)
	
	global_position = _subject.global_position + base_offset
	offset = Vector2.ZERO
	look_ahead_offset = Vector2.ZERO
	current_camera_offset = 0.0
	target_camera_offset = 0.0
	
	if debug_logs: print("  Câmera snap para: ", global_position)
	if debug_logs: print("  Limites atuais: L=", limit_left, " R=", limit_right, " T=", limit_top, " B=", limit_bottom)
	if debug_logs: print("==============================")
