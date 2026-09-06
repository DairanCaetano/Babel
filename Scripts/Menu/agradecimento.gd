extends Control
class_name CreditsScreen

var _input_processed: bool = false

@export var _select_audio: AudioStreamPlayer

func _ready() -> void:
	# FADE IN AUTOMÁTICO AO CARREGAR OS CRÉDITOS
	TransitionScreen.fade_in_level()
	
	# ✅ CORRIGIDO - Usar play_music_simple
	AudioManager.play_music_simple("start_game", 30.0)
	
	print("✅ Credits Screen pronta - Pressione Inventário ou Equipar Arma para voltar")

func _process(_delta: float) -> void:
	if _input_processed:
		return
	
	if Input.is_action_just_pressed("Inventory") or Input.is_action_just_pressed("EquipWeapon"):
		_return_to_start_menu()

func _return_to_start_menu() -> void:
	if _input_processed:
		return
	
	_input_processed = true
	
	# 🔊 Toca som de seleção com validação
	if _select_audio and is_instance_valid(_select_audio):
		_select_audio.play()
		await get_tree().create_timer(0.3).timeout  # ✅ Timeout fixo
	
	print("⬅️ Voltando para Start Menu dos créditos...")
	
	global.current_scene_path = "res://Scenes/Menu/start_menu.tscn"
	TransitionScreen.fade_in()
