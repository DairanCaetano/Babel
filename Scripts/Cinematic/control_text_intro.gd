extends Control
@export var scroll_speed: float = 22.0
@export var reveal_speed: float = 0.08
@export var font: Font  # Arraste sua fonte aqui no inspector
@export var font_size: int = 16
var is_scrolling: bool = false
var text_label: Label
var scroll_offset: float = 0.0
var current_visible_ratio: float = 0.0

func _ready() -> void:
	# Cria a Label como filha
	text_label = Label.new()
	add_child(text_label)
	
	# Configura a label
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # ✅ CENTRALIZA O TEXTO
	
	# ✅ Define a largura da label igual ao Control pai
	text_label.size.x = size.x
	text_label.custom_minimum_size.x = size.x
	
	# Configura a fonte SE foi definida
	if font:
		text_label.add_theme_font_override("font", font)
		text_label.add_theme_font_size_override("font_size", font_size)
	
	# ✅ COMBINAÇÃO SUAVE
	# Outline bem fino
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	text_label.add_theme_constant_override("outline_size", 1)
	
	# Sombra bem próxima e suave
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	text_label.add_theme_constant_override("shadow_offset_x", 1)
	text_label.add_theme_constant_override("shadow_offset_y", 1)
	text_label.add_theme_constant_override("shadow_outline_size", 1)
	
	# Define o texto
	text_label.text = tr("CINEMATIC_INTRO").replace("\n", "\n\n")
	
	# Configura o Control pai para fazer o clipping
	clip_contents = true
	
	# Posiciona a label no fundo inicialmente
	text_label.position.y = size.y
	text_label.visible_ratio = 0

func _process(delta: float) -> void:
	if not is_scrolling:
		return
	
	# REVELA O TEXTO letra por letra
	if current_visible_ratio < 1.0:
		current_visible_ratio += reveal_speed
		current_visible_ratio = min(current_visible_ratio, 1.0)
		text_label.visible_ratio = current_visible_ratio
	
	# Calcula altura do texto revelado até agora
	var total_text_height = text_label.get_minimum_size().y
	var revealed_height = total_text_height * current_visible_ratio
	
	# Se o texto revelado ultrapassar a altura do container, ROLA PRA CIMA
	if revealed_height > size.y:
		scroll_offset += scroll_speed * delta
		text_label.position.y = size.y - scroll_offset

func start_scroll() -> void:
	print("📜 Iniciando scroll de texto!")
	is_scrolling = true
	scroll_offset = 0
	current_visible_ratio = 0.0
	text_label.position.y = size.y
	text_label.visible_ratio = 0

func stop_scroll() -> void:
	is_scrolling = false
