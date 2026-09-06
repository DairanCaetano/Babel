extends Control
class_name DialogSystem

signal is_finished

var _dialog_index: int = 0
var _is_finished: bool = false

# ✅ Novo formato: recebe dados via dicionário
var dialog_data: Dictionary = {}

@export_category("Objects")
@export var _faceset: TextureRect
@export var _title: Label
@export var _dialog_Text: Label
@export var _skip_indicator: TextureRect

@export_category("Audio")
@export var _dialog_audio: AudioStreamPlayer

# ✅ Mapeamento de personagens para imagens
const CHARACTER_PORTRAITS = {
	"tola": "res://sprites/UI/DIALOGUE/Babel_GUI_FaceDialogue_Pixel Art_v01.png",
	"azazel": "res://sprites/UI/DIALOGUE/Babel_GUI_FaceDialogue_Pixel Art_v02.png",
	"samyaza": "res://sprites/UI/DIALOGUE/Babel_GUI_FaceDialogue_Pixel Art_v03.png"
}

func _ready() -> void:
	# ✅ Converter formato antigo para novo (compatibilidade)
	if dialog_data.has("lines"):
		# Já está no formato novo
		pass
	else:
		# Formato antigo → converter
		_convert_legacy_format()
	
	_load_dialog()

func _convert_legacy_format() -> void:
	"""Converte formato antigo (0, 1, 2...) para novo formato (lines)"""
	var lines = []
	var index = 0
	
	while dialog_data.has(index):
		var old_entry = dialog_data[index]
		lines.append({
			"character": _detect_character(old_entry.get("faceset", "")),
			"text": old_entry.get("dialog", ""),
			"portrait": old_entry.get("faceset", "")
		})
		index += 1
	
	dialog_data["lines"] = lines
	dialog_data["dialog_name"] = "legacy_dialog"

func _detect_character(portrait_path: String) -> String:
	"""Detecta personagem baseado no caminho da imagem"""
	if "v01" in portrait_path:
		return "tola"
	elif "v02" in portrait_path:
		return "azazel"
	return "tola"

func _process(_delta: float) -> void:
	_skip_indicator.visible = _is_finished
	
	if Input.is_action_just_pressed("SkipDialogue") and _is_finished:
		_dialog_index += 1
		
		# ✅ Verificar se tem mais linhas
		if dialog_data.has("lines") and _dialog_index < dialog_data["lines"].size():
			_load_dialog()
			return
		
		# ✅ Diálogo terminou
		var signal_name = _determine_dialog_type()
		is_finished.emit(signal_name)
		queue_free()

func _load_dialog() -> void:
	"""Carrega uma linha de diálogo"""
	_is_finished = false
	
	# ✅ Sortear pitch para este bloco (80% a 110%)
	if _dialog_audio:
		_dialog_audio.pitch_scale = randf_range(0.8, 1.1)
	
	# ✅ Formato novo (com "lines")
	if dialog_data.has("lines"):
		var lines = dialog_data["lines"]
		
		if _dialog_index >= lines.size():
			push_error("DialogSystem: Índice fora do range!")
			return
		
		var current_line = lines[_dialog_index]
		
		# ✅ Configurar portrait
		var character = current_line.get("character", "tola").to_lower()
		var portrait_path = CHARACTER_PORTRAITS.get(character, CHARACTER_PORTRAITS["tola"])
		
		# ✅ Se tiver portrait customizado, usar ele
		if current_line.has("portrait") and current_line["portrait"] != "":
			portrait_path = current_line["portrait"]
		
		_faceset.texture = load(portrait_path)
		
		# ✅ Configurar título
		_title.text = character.capitalize()
		
		# ✅ Configurar texto
		_dialog_Text.text = current_line.get("text", "")
	
	# ✅ Formato antigo (compatibilidade)
	else:
		if not dialog_data.has(_dialog_index):
			push_error("DialogSystem: Formato inválido!")
			return
		
		var current_data = dialog_data[_dialog_index]
		_faceset.texture = load(current_data["faceset"])
		_title.text = current_data["title"]
		_dialog_Text.text = current_data["dialog"]
	
	# ✅ Animação de digitação
	_dialog_Text.visible_characters = 0
	while _dialog_Text.visible_characters < _dialog_Text.get_total_character_count():
		_dialog_Text.visible_characters += 1
		if _dialog_audio and _dialog_Text.visible_characters % 2 == 0:
			_dialog_audio.play()
		await get_tree().physics_frame
	
	# ✅ Para o áudio quando o texto termina
	if _dialog_audio:
		_dialog_audio.stop()
	
	_is_finished = true

func _determine_dialog_type() -> String:
	"""Determina o tipo de diálogo para saber como reagir após terminar"""
	
	# ✅ 1. Verificar campo "dialog_type" (prioridade)
	if dialog_data.has("dialog_type"):
		return dialog_data["dialog_type"]
	
	# ✅ 2. Verificar campo "dialog_name"
	if dialog_data.has("dialog_name"):
		var name = dialog_data["dialog_name"]
		
		if "save" in name or "rest" in name:
			return "save_point"
		
		if "cinematic" in name:
			return "cinematic_2"
	
	# ✅ 3. Tentar detectar pelo conteúdo (fallback)
	if dialog_data.has("lines") and dialog_data["lines"].size() > 0:
		var first_text = dialog_data["lines"][0].get("text", "").to_lower()
		
		if "descansar" in first_text or "salvar" in first_text or "seguro" in first_text:
			return "save_point"
	
	# ✅ 4. Padrão
	return "cinematic_2"
