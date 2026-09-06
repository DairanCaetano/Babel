extends Node2D
class_name BaseCinematic

@export_category("References")
@export var animation_player: AnimationPlayer

@export_category("Dialog")
@export var dialog_data: Dictionary = {}

var _is_playing: bool = false
var _can_skip: bool = false

func _ready() -> void:
	print("🎬 Cinemática iniciada")
	
	# ✅ MÚSICA SEM AWAIT - VERSÃO SIMPLIFICADA
	AudioManager.play_music_simple("cinematic", 0.0)
	
	call_deferred("_start")

func _start() -> void:
	_is_playing = true
	
	await get_tree().process_frame
	
	# Fade in visual
	TransitionScreen.fade_in_level()
	await TransitionScreen.transition_finished
	
	_can_skip = true
	
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	else:
		push_error("AnimationPlayer não encontrado!")
		_finish()

func _on_animation_finished(anim_name: String) -> void:
	print("🎬 Animação terminada: ", anim_name)
	_can_skip = false
	
	if not dialog_data.is_empty():
		_show_dialog()
	else:
		_finish()

func _show_dialog() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	
	if hud:
		dialog_data["dialog_type"] = "cinematic"
		hud.dialog_finished.connect(_on_dialog_finished)
		hud.spawn_dialog(dialog_data)
	else:
		_finish()

func _on_dialog_finished(dialog_type: String) -> void:
	if dialog_type == "cinematic":
		_finish()

func _finish() -> void:
	if not _is_playing:
		return
	
	_is_playing = false
	_can_skip = false
	
	print("🎬 Finalizando cinemática")
	
	if AudioManager.is_playing() and AudioManager.get_current_track() == "cinematic":
		print("🔉 Aplicando fade out na música (1s)...")
		await AudioManager.stop_music(1.0)
		print("  ✅ Música parada")
	
	# ✅ USA fade_out() DO MODO LEVEL, NÃO O MODO 3
	# Isso evita que o TransitionScreen tente fazer change_scene_to_file
	TransitionScreen.fade_out()
	await TransitionScreen.transition_finished
	
	print("🎮 Indo para game.tscn...")
	# ✅ TROCA DE CENA DIRETA, SEM PASSAR PELO MODO 3 DO TRANSITIONSCREEN
	get_tree().change_scene_to_file("res://Scenes/Base/game.tscn")

func _input(event: InputEvent) -> void:
	if not _is_playing or not _can_skip:
		return
	
	if event.is_action_pressed("ui_cancel") or \
	   event.is_action_pressed("Inventory") or \
	   event.is_action_pressed("EquipWeapon"):
		_skip_cinematic()

func _skip_cinematic() -> void:
	print("⏭️ Cinemática pulada pelo jogador")
	
	if animation_player and animation_player.is_playing():
		animation_player.pause()
	
	if animation_player and animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	
	_can_skip = false
	_finish()
