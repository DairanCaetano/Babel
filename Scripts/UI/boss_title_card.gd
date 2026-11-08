extends CanvasLayer
class_name BossTitleCard

# ==========================================================================
# CARTÃO DE APRESENTAÇÃO DO CHEFE
# --------------------------------------------------------------------------
# Mostra o nome do chefe durante o primeiro rugido (só no primeiro encontro).
# Chamado por Boss.show_title_card() (Scripts/Bosses/boss_base.gd).
#
# Estilos (Boss.TitleCardStyle):
#   TEXT  → só o nome, sobre a luta (branco com sombra preta)
#   BLACK → fundo preto com névoa (normal) + nome branco
#   RED   → fundo vermelho com névoa (multiply) + nome branco
#   WHITE → fundo branco com névoa (multiply) + nome preto
#
# Nome grande + subtítulo menor na linha de baixo (opcional), na fonte do jogo.
# Tamanhos em múltiplos inteiros do tamanho base (pixel art sempre nítida):
# name_scale 2 ≈ "Baal Berite" com 1/3 da largura da tela.
# Não mexe na música nem nos sons do chefe.
# ==========================================================================

enum Style { OFF, TEXT, BLACK, RED, WHITE }

@export_category("Texto")
@export var font: FontFile = preload("res://Fonts/old_style/njo_14.ttf")
## Tamanho base da fonte (pixel font: múltiplos disso ficam nítidos)
@export var base_font_size: int = 14
## Tamanho do nome: múltiplo do tamanho base (2 = fonte 28)
@export var name_scale: int = 2
## Tamanho do subtítulo: múltiplo do tamanho base (1 = fonte 14)
@export var subtitle_scale: int = 1
## Espaço entre o nome e o subtítulo (px do jogo)
@export var line_gap: int = 2
## Margem de cada lado: se o nome não couber, a escala diminui sozinha
@export var side_margin: float = 24.0

@export_category("Cores")
@export var black_bg: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var red_bg: Color = Color(0.55, 0.04, 0.04, 1.0)
@export var white_bg: Color = Color(0.92, 0.92, 0.92, 1.0)

@export_category("Tempo")
@export var fade_in_time: float = 0.2
@export var fade_out_time: float = 0.3

const _MENU_BG_SCENE: String = "res://Scenes/UI/menu_bg.tscn"
const _GAME_SIZE: Vector2 = Vector2(480, 270)

var _root: Control


func setup(style: int, title: String, sound: AudioStream, duration: float, subtitle: String = "", name_scale_override: int = 0, subtitle_scale_override: int = 0) -> void:
	# Escalas do próprio chefe (0 = usa as desta cena)
	if name_scale_override > 0:
		name_scale = name_scale_override
	if subtitle_scale_override > 0:
		subtitle_scale = subtitle_scale_override
	layer = 80
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	
	var _text_color: Color = Color.WHITE
	if style != Style.TEXT:
		_add_background(style)
		if style == Style.WHITE:
			_text_color = Color.BLACK
	
	_add_titles(title, subtitle, _text_color)
	_play_sound(sound)
	
	# fade in → segura → fade out (total = duration)
	var _hold: float = maxf(duration - fade_in_time - fade_out_time, 0.0)
	var _tween := create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(_hold)
	_tween.tween_property(_root, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(queue_free)
	print("👑 Cartão do chefe: ", title, " (estilo ", Style.keys()[style], ")")


func _add_background(style: int) -> void:
	var _bg: ColorRect = null
	if ResourceLoader.exists(_MENU_BG_SCENE):
		_bg = load(_MENU_BG_SCENE).instantiate()
	if not _bg:
		_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)
	
	var _mat := _bg.material as ShaderMaterial
	if _mat:
		_mat = _mat.duplicate()   # não altera o material dos menus
		_bg.material = _mat
		match style:
			Style.BLACK:
				_mat.set_shader_parameter("base_color", black_bg)
				_mat.set_shader_parameter("blend_mode", 0)
			Style.RED:
				_mat.set_shader_parameter("base_color", red_bg)
				_mat.set_shader_parameter("blend_mode", 1)
			Style.WHITE:
				_mat.set_shader_parameter("base_color", white_bg)
				_mat.set_shader_parameter("blend_mode", 1)
	else:
		match style:
			Style.BLACK:
				_bg.color = black_bg
			Style.RED:
				_bg.color = red_bg
			Style.WHITE:
				_bg.color = white_bg


func _add_titles(title: String, subtitle: String, color: Color) -> void:
	# Centro da tela: nome em cima, subtítulo embaixo
	var _center := CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)
	var _box := VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", line_gap)
	_center.add_child(_box)
	
	_box.add_child(_make_label(title, _fit_scale(title, name_scale), color))
	if subtitle != "":
		_box.add_child(_make_label(subtitle, _fit_scale(subtitle, subtitle_scale), color))


func _make_label(text: String, scale_mult: int, color: Color) -> Label:
	var _settings := LabelSettings.new()
	_settings.font = font
	_settings.font_size = base_font_size * scale_mult
	_settings.font_color = color
	_settings.line_spacing = 0.0
	# Sombra preta (igual aos textos do jogo), proporcional ao tamanho
	_settings.shadow_size = 0
	_settings.shadow_color = Color(0, 0, 0, 1) if color != Color.BLACK else Color(0, 0, 0, 0)
	_settings.shadow_offset = Vector2(0, scale_mult)
	
	var _label := Label.new()
	_label.text = text
	_label.label_settings = _settings
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _label


func _fit_scale(text: String, wanted: int) -> int:
	"""Usa a escala pedida; só diminui se o texto não couber na tela"""
	var _scale: int = maxi(wanted, 1)
	if not font:
		return _scale
	var _available: float = _GAME_SIZE.x - side_margin * 2.0
	while _scale > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, base_font_size * _scale).x > _available:
		_scale -= 1
	return _scale


func _play_sound(sound: AudioStream) -> void:
	if not sound:
		return
	var _player := AudioStreamPlayer.new()
	_player.stream = sound
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_player)
	_player.play()
