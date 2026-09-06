extends Control
class_name UIOptions

# ========== NAVEGAÇÃO ==========
var _option_containers: Array = []
var _current_index: int = 0
var _is_transitioning: bool = false

# ========== ESTADOS DAS OPÇÕES ==========
var current_filter_index: int = 0
var current_language_index: int = 0
var current_vibration_index: int = 0
var current_window_index: int = 0

# ========== CORES ==========
const COLOR_NORMAL: Color = Color.WHITE
const COLOR_SELECTED: Color = Color("#beb600")
const COLOR_CONFIRM: Color = Color("#db3f00")

# ========== IDIOMAS ==========
signal language_changed
const LANGUAGE_LOCALES: Array = ["pt_BR", "en", "ja"]
const LANGUAGE_NAMES: Array = ["Português", "English", "日本語"]

# ========== EXPORTS DAS LABELS ==========
@export_category("Title Labels")
@export var filter_title_label: Label
@export var language_title_label: Label
@export var window_title_label: Label
@export var vibration_title_label: Label
@export var quit_title_label: Label

@export_category("Value Labels")
@export var filter_value_label: Label
@export var language_value_label: Label
@export var window_value_label: Label
@export var vibration_value_label: Label

# ========== REFERÊNCIAS ==========
@onready var options_container = $OptionsContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	for child in options_container.get_children():
		if child is HBoxContainer:
			_option_containers.append(child)

	# ✅ CARREGAR FILTRO
	if serialization.game_data.has("crt_filter_enabled"):
		var is_enabled = serialization.game_data["crt_filter_enabled"]
		current_filter_index = 0 if is_enabled else 1
		CRTScreen.visible = is_enabled

	# ✅ CARREGAR JANELA
	if serialization.game_data.has("window_mode"):
		var is_fullscreen = serialization.game_data["window_mode"]
		current_window_index = 0 if is_fullscreen else 1
	else:
		current_window_index = 0 if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else 1

	# ✅ CARREGAR IDIOMA SALVO
	var saved_locale = serialization.settings_data.get("language", "pt_BR")
	var locale_index = LANGUAGE_LOCALES.find(saved_locale)
	if locale_index >= 0:
		current_language_index = locale_index

	# ✅ ATUALIZAR TODOS OS TEXTOS
	_update_texts()

	if _option_containers.size() > 0:
		_update_visual_selection()


func _update_texts() -> void:
	# Títulos
	if filter_title_label:
		filter_title_label.text = tr("OPT_FILTER")
	if language_title_label:
		language_title_label.text = tr("OPT_LANGUAGE")
	if window_title_label:
		window_title_label.text = tr("OPT_WINDOW")
	if vibration_title_label:
		vibration_title_label.text = tr("OPT_VIBRATION")
	if quit_title_label:
		quit_title_label.text = tr("OPT_QUIT")

	# Valores
	if filter_value_label:
		filter_value_label.text = tr("OPT_ON") if current_filter_index == 0 else tr("OPT_OFF")
	if language_value_label:
		language_value_label.text = LANGUAGE_NAMES[current_language_index]
	if window_value_label:
		window_value_label.text = "Fullscreen" if current_window_index == 0 else "Window"
	if vibration_value_label:
		vibration_value_label.text = tr("OPT_ON") if current_vibration_index == 0 else tr("OPT_OFF")


func _process(_delta: float) -> void:
	if not visible or _is_transitioning:
		return

	var moved: bool = false

	if Input.is_action_just_pressed("move_up"):
		_current_index -= 1
		if _current_index < 0:
			_current_index = _option_containers.size() - 1
		moved = true

	if Input.is_action_just_pressed("move_down"):
		_current_index += 1
		if _current_index >= _option_containers.size():
			_current_index = 0
		moved = true

	if moved:
		if global.ui_inventory:
			global.ui_inventory.play_navigation_audio()
		_update_visual_selection()

	if Input.is_action_just_pressed("move_left"):
		if global.ui_inventory:
			global.ui_inventory.play_navigation_audio()
		_change_option_value(-1)

	if Input.is_action_just_pressed("move_right"):
		if global.ui_inventory:
			global.ui_inventory.play_navigation_audio()
		_change_option_value(1)

	if Input.is_action_just_pressed("EquipWeapon"):
		_confirm_selection()


func _update_visual_selection() -> void:
	for i in range(_option_containers.size()):
		var container = _option_containers[i]
		var texture = container.get_node_or_null("Texture")

		var title_label = container.get_node_or_null("Label") as Label
		if not title_label:
			title_label = container.get_node_or_null("Teme") as Label

		var options_label = container.get_node_or_null("options") as Label
		if not options_label:
			options_label = container.get_node_or_null("Options") as Label

		if texture:
			texture.visible = (i == _current_index)

		var target_color = COLOR_SELECTED if i == _current_index else COLOR_NORMAL

		if title_label:
			title_label.modulate = target_color
		if options_label:
			options_label.modulate = target_color


func _change_option_value(direction: int) -> void:
	var container_name = _option_containers[_current_index].name

	match container_name:
		"FilterContainer":
			_change_filter(direction)
		"LanguageContainer":
			_change_language(direction)
		"vibrationContainer":
			_change_vibration(direction)
		"WindowContainer":
			_change_window_mode(direction)
		"QuitContainer":
			pass


func _change_filter(direction: int) -> void:
	current_filter_index = wrapi(current_filter_index + direction, 0, 2)
	if filter_value_label:
		filter_value_label.text = tr("OPT_ON") if current_filter_index == 0 else tr("OPT_OFF")


func _change_language(direction: int) -> void:
	current_language_index = wrapi(current_language_index + direction, 0, LANGUAGE_LOCALES.size())
	if language_value_label:
		language_value_label.text = LANGUAGE_NAMES[current_language_index]


func _change_vibration(direction: int) -> void:
	current_vibration_index = wrapi(current_vibration_index + direction, 0, 2)
	if vibration_value_label:
		vibration_value_label.text = tr("OPT_ON") if current_vibration_index == 0 else tr("OPT_OFF")


func _change_window_mode(direction: int) -> void:
	current_window_index = wrapi(current_window_index + direction, 0, 2)
	if window_value_label:
		window_value_label.text = "Fullscreen" if current_window_index == 0 else "Window"


func _confirm_selection() -> void:
	var container_name = _option_containers[_current_index].name

	if global.ui_inventory:
		global.ui_inventory.play_select_audio()

	await _flash_confirm_color()

	match container_name:
		"FilterContainer":
			_apply_filter()
		"LanguageContainer":
			_apply_language()
		"vibrationContainer":
			_apply_vibration()
		"WindowContainer":
			_apply_window_mode()
		"QuitContainer":
			_quit_to_main_menu()


func _flash_confirm_color() -> void:
	var current_container = _option_containers[_current_index]

	var title_label = current_container.get_node_or_null("Label") as Label
	if not title_label:
		title_label = current_container.get_node_or_null("Teme") as Label

	var options_label = current_container.get_node_or_null("options") as Label
	if not options_label:
		options_label = current_container.get_node_or_null("Options") as Label

	if title_label:
		title_label.modulate = COLOR_CONFIRM
	if options_label:
		options_label.modulate = COLOR_CONFIRM

	await get_tree().process_frame

	if title_label:
		title_label.modulate = COLOR_SELECTED
	if options_label:
		options_label.modulate = COLOR_SELECTED


func _apply_filter() -> void:
	var is_enabled = (current_filter_index == 0)
	CRTScreen.visible = is_enabled
	serialization.game_data["crt_filter_enabled"] = is_enabled
	serialization.save_data()


func _apply_language() -> void:
	var locale = LANGUAGE_LOCALES[current_language_index]
	TranslationServer.set_locale(locale)
	serialization.settings_data["language"] = locale
	serialization.save_settings()
	language_changed.emit()
	_update_texts()


func _apply_vibration() -> void:
	if current_vibration_index == 1:
		Input.stop_joy_vibration(0)


func _apply_window_mode() -> void:
	var is_fullscreen = (current_window_index == 0)
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	serialization.game_data["window_mode"] = is_fullscreen
	serialization.save_data()


func _quit_to_main_menu() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	set_process(false)

	if global.character:
		global.character._is_in_cinematic = true

	get_tree().paused = false
	await get_tree().process_frame

	global.current_scene_path = "res://Scenes/Menu/main_menu.tscn"
	TransitionScreen.fade_in()
