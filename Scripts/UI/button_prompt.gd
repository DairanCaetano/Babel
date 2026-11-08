extends HBoxContainer
class_name ButtonPrompt

# ==========================================================================
# INSTRUÇÃO DE BOTÕES ("Aperte [✕] para confirmar. Aperte [○] para sair")
# --------------------------------------------------------------------------
# O texto vem do texts.csv (text_key) com marcadores {confirm} e {back}, que
# viram os ícones do dispositivo em uso. Cada língua pode ter sua ordem.
# Troca os ícones na hora quando o jogador muda de teclado para controle.
# ==========================================================================

@export var text_key: String = "PROMPT_CONFIRM_BACK"
@export var label_settings: LabelSettings
## Tamanho do ícone na tela (px do jogo). Os ícones são 16x16.
@export var icon_size: int = 16
## Espaço entre textos e ícones (px)
@export var spacing: int = 2

var _shown_device: int = -2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # ouve o controle mesmo com o jogo pausado
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", spacing)
	ButtonIcons.ensure_input_map()
	_rebuild()


func _input(event: InputEvent) -> void:
	ButtonIcons.detect_from_event(event)


func _process(_delta: float) -> void:
	if ButtonIcons.get_device() != _shown_device:
		_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild()


func _rebuild() -> void:
	_shown_device = ButtonIcons.get_device()
	for _c in get_children():
		_c.queue_free()
	
	var _text: String = tr(text_key)
	var _regex := RegEx.new()
	_regex.compile("\\{(confirm|back)\\}")
	var _pos: int = 0
	for _m in _regex.search_all(_text):
		_add_text(_text.substr(_pos, _m.get_start() - _pos))
		_add_icon(_m.get_string(1))
		_pos = _m.get_end()
	_add_text(_text.substr(_pos))


func _add_text(part: String) -> void:
	part = part.strip_edges()
	if part == "":
		return
	var _label := Label.new()
	_label.text = part
	_label.label_settings = label_settings
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _add_icon(kind: String) -> void:
	var _icon := TextureRect.new()
	_icon.texture = ButtonIcons.get_icon(kind)
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
