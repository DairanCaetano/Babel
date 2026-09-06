extends Control
class_name StartMenu

var _is_button_pressed: bool = false
var _can_press: bool = false

@export_category("Objects")
@export var _anim: AnimationPlayer
@export var _start_audio: AudioStreamPlayer

@export_category("Audio Settings")
@export var music_start_position: float = 30.0  # ✅ Onde começar a música (ex: 30s)

func _ready() -> void:
	get_tree().paused = false
	print("=== START MENU READY ===")
	
	TransitionScreen.start_level.connect(_on_level_start)
	_anim.play("Start")
	_anim.animation_finished.connect(_on_animation_finished)
	
	for _button in get_tree().get_nodes_in_group("menu_button"):
		_button.pressed.connect(_on_button_pressed)
	
	AudioManager.play_music_simple("start_game", music_start_position)
	
	# ✅ LOCALIZAÇÃO
	_update_texts()

func _process(_delta: float) -> void:
	if _can_press and not _is_button_pressed:
		if Input.is_action_just_pressed("Inventory"):
			_on_button_pressed()

func _on_animation_finished(_anim_name: String) -> void:
	if _anim_name == "Start":
		print("✅ Animação terminada - pode apertar o botão agora!")
		_can_press = true
		_start_blink_animation()

func _on_button_pressed() -> void:
	if _is_button_pressed:
		return
	
	_is_button_pressed = true
	
	print("🎮 === BOTÃO PRESS START PRESSIONADO ===")
	
	var press_start_button = get_node_or_null("ButtonsContainer/PressStart")
	
	if press_start_button:
		var pressed_color = press_start_button.get_theme_color("font_pressed_color")
		press_start_button.add_theme_color_override("font_color", pressed_color)
		
		var icon_pressed_color = press_start_button.get_theme_color("icon_pressed_color")
		press_start_button.add_theme_color_override("icon_normal_color", icon_pressed_color)
	
	await get_tree().create_timer(0.2).timeout
	
	# ✅ TOCAR SOM COM VALIDAÇÃO
	if _start_audio:
		print("  🔊 Tocando som de start...")
		_start_audio.play()
		await get_tree().create_timer(0.3).timeout  # Tempo fixo curto
	else:
		print("  ⚠️ _start_audio não encontrado!")
	
	# ✅ Transição
	print("  📂 Mudando para Main Menu...")
	get_tree().change_scene_to_file("res://Scenes/Menu/main_menu.tscn")


func _on_level_start() -> void:
	print("✅ Transição para Main Menu completa!")

func _start_blink_animation() -> void:
	var press_start_button = get_node_or_null("ButtonsContainer/PressStart")
	
	if press_start_button:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(press_start_button, "modulate:a", 0.3, 0.8)
		tween.tween_property(press_start_button, "modulate:a", 1.0, 0.8)

func _update_texts() -> void:
	var press_start_button = get_node_or_null("ButtonsContainer/PressStart")
	print("Locale atual: ", TranslationServer.get_locale())
	print("Traduções carregadas: ", TranslationServer.get_loaded_locales())
	print("Tradução: ", tr("MENU_PRESS_START"))
	if press_start_button:
		press_start_button.text = tr("MENU_PRESS_START")
