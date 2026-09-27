# intro_sequencer.gd
extends Node2D

@export var npc_scene: PackedScene
@export var npc_spawn_point: Marker2D

var _player: Node
var _npc: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	
	if serialization.game_data.get("intro_played", false):
		var p = get_tree().get_first_node_in_group("player")
		if p:
			p._is_in_cinematic = false
		queue_free()
		return
	
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_error("⚠️ [IntroSequencer] Player não encontrado!")
		return
	
	_player._is_in_cinematic = true
	
	var char_texture = _player.get_node_or_null("Texture")
	if char_texture:
		_face_player_towards_npc(char_texture)
		char_texture._is_on_action = true
		char_texture.play("Rise")
		char_texture.frame = 0
		char_texture.stop()
	
	_start_intro()

func _start_intro() -> void:
	PixelTransition.fade_in()
	await get_tree().create_timer(1.6, true).timeout  
	await _play_rise_animation()
	await get_tree().create_timer(0.4, true).timeout
	await _spawn_npc()
	await get_tree().create_timer(0.3, true).timeout
	await _play_dialog()
	await _finish_intro()

func _play_rise_animation() -> void:
	var char_texture = _player.get_node_or_null("Texture")
	if not char_texture:
		push_error("⚠️ [IntroSequencer] Texture não encontrado!")
		return
	
	# ✅ Reforça a direção (o player pode ter sido posicionado no spawn depois do _ready)
	_face_player_towards_npc(char_texture)
	char_texture._is_on_action = true
	char_texture.play("Rise")
	char_texture.frame = 0
	var rise_duration = _get_animation_duration(char_texture, "Rise")
	await get_tree().create_timer(rise_duration, true).timeout

func _face_player_towards_npc(char_texture: AnimatedSprite2D) -> void:
	"""Vira o Tola para o lado onde o Azazel vai aparecer"""
	if not npc_spawn_point or not _player:
		return
	
	var face_right: bool = npc_spawn_point.global_position.x >= _player.global_position.x
	char_texture.facing_right = face_right
	char_texture.flip_h = not face_right
	
	if face_right and char_texture.has_method("_update_positions_for_right"):
		char_texture._update_positions_for_right()
	elif not face_right and char_texture.has_method("_update_positions_for_left"):
		char_texture._update_positions_for_left()

func _get_animation_duration(sprite: AnimatedSprite2D, anim_name: String) -> float:
	var frames = sprite.sprite_frames
	if not frames or not frames.has_animation(anim_name):
		return 1.0
	var frame_count = frames.get_frame_count(anim_name)
	var fps = frames.get_animation_speed(anim_name)
	if fps <= 0:
		return 1.0
	return frame_count / fps

func _spawn_npc() -> void:
	_npc = npc_scene.instantiate()
	get_tree().current_scene.add_child(_npc)
	_npc.global_position = npc_spawn_point.global_position
	
	if _npc.has_method("play_arrive"):
		# ✅ Sprite do Azazel olha para a DIREITA por padrão:
		# se ele estiver à direita do Tola, precisa virar (flip) para olhar para ele
		var npc_is_right_of_player: bool = _npc.global_position.x > _player.global_position.x
		await _npc.play_arrive(npc_is_right_of_player)
	else:
		push_error("⚠️ [IntroSequencer] NPC não tem método play_arrive!")

func _play_dialog() -> void:
	var dialog_data = {
		"dialog_name": "tebes_intro",
		"dialog_type": "intro",
		"lines": [
			{"character": "tola",   "text": tr("DIALOG_TEBES_INTRO_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_INTRO_1_AZAZEL")},
			{"character": "tola",   "text": tr("DIALOG_TEBES_INTRO_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_INTRO_3_AZAZEL")},
		]
	}
	
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		push_error("⚠️ [IntroSequencer] HUD não encontrado!")
		return
	
	var dialog_scene = preload("res://Scenes/Inventory/dialog_system.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.dialog_data = dialog_data
	hud.add_child(dialog)
	
	await dialog.is_finished

func _finish_intro() -> void:
	if is_instance_valid(_npc) and _npc.has_method("play_gone"):
		await _npc.play_gone()
	
	if is_instance_valid(_npc):
		_npc.queue_free()
	
	serialization.game_data["intro_played"] = true
	serialization.save_data()
	
	_player._is_in_cinematic = false
	queue_free()
