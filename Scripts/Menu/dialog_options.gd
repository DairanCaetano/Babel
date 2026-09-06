extends Control
class_name DialogOptions

# ✅ SINAIS para comunicar a escolha
signal option_selected(option_index: int)
signal option_1_selected()
signal option_2_selected()

@export_category("Objects")
@export var _texture: TextureRect
@export var _vbox_container: VBoxContainer
@export var _options_text: Label
@export var _dialog_option_1: Control
@export var _option_1_text: Label
@export var _select_1: TextureRect
@export var _dialog_option_2: Control
@export var _option_2_text: Label
@export var _select_2: TextureRect

@export_category("Settings")
@export_multiline var question_text: String = "Você tem certeza?"
@export var option_1_text: String = "SIM"
@export var option_2_text: String = "NÃO"

@export_category("Colors")
@export var color_normal: Color = Color.WHITE  # Cor padrão (não selecionado)
@export var color_selected: Color = Color("#beb600")  # Amarelo quando selecionado
@export var color_confirmed: Color = Color("#db3f00")  # Vermelho quando confirmado

var _current_selection: int = 1  # 1 ou 2
var _is_active: bool = false
var _player: BaseCharacter = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialog_options")
	
	# ✅ Garantir que os selects começam invisíveis
	if _select_1:
		_select_1.visible = false
	if _select_2:
		_select_2.visible = false
	
	# ✅ Definir cores iniciais
	if _option_1_text:
		_option_1_text.modulate = color_normal
	if _option_2_text:
		_option_2_text.modulate = color_normal

func show_dialog(question: String = "", opt1: String = "", opt2: String = "") -> void:
	"""Mostra o diálogo com textos personalizados"""
	
	# ✅ Usar textos passados ou usar os padrões
	if question != "":
		_options_text.text = question
	else:
		_options_text.text = question_text
	
	if opt1 != "":
		_option_1_text.text = opt1
	else:
		_option_1_text.text = option_1_text
	
	if opt2 != "":
		_option_2_text.text = opt2
	else:
		_option_2_text.text = option_2_text
	
	# ✅ Resetar cores
	_option_1_text.modulate = color_normal
	_option_2_text.modulate = color_normal
	
	# ✅ Resetar seleção para opção 1
	_current_selection = 1
	_update_selection_visual()
	
	# ❌ REMOVER TODO ESSE BLOCO:
	# _player = get_tree().get_first_node_in_group("player")
	# if _player:
	#     _player._is_in_cinematic = true
	#     ...
	
	# ✅ SÓ ISSO:
	visible = true
	_is_active = true
	
	print("💬 Diálogo ativado - Seleção inicial: Opção ", _current_selection)

func _input(event: InputEvent) -> void:
	if not visible or not _is_active:
		return
	
	# ✅ NAVEGAÇÃO: Esquerda/Direita
	if event.is_action_pressed("move_left"):
		_navigate_left()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("move_right"):
		_navigate_right()
		get_viewport().set_input_as_handled()
		return
	
	# ✅ CONFIRMAÇÃO: EquipWeapon
	if event.is_action_pressed("EquipWeapon"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return
	
	# ✅ BLOQUEAR TODOS OS OUTROS INPUTS
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _navigate_left() -> void:
	"""Navega para a esquerda (Opção 1)"""
	if _current_selection != 1:
		_current_selection = 1
		_update_selection_visual()
		_play_navigation_sound()
		print("◀️ Selecionado: Opção 1")

func _navigate_right() -> void:
	"""Navega para a direita (Opção 2)"""
	if _current_selection != 2:
		_current_selection = 2
		_update_selection_visual()
		_play_navigation_sound()
		print("▶️ Selecionado: Opção 2")

func _update_selection_visual() -> void:
	"""Atualiza a visibilidade dos indicadores de seleção E as cores"""
	if _current_selection == 1:
		# Opção 1 selecionada
		_select_1.visible = true
		_select_2.visible = false
		_option_1_text.modulate = color_selected  # ✅ Amarelo
		_option_2_text.modulate = color_normal     # ✅ Branco
	else:
		# Opção 2 selecionada
		_select_1.visible = false
		_select_2.visible = true
		_option_1_text.modulate = color_normal     # ✅ Branco
		_option_2_text.modulate = color_selected  # ✅ Amarelo

func _confirm_selection() -> void:
	"""Confirma a opção selecionada"""
	_is_active = false
	
	print("✅ Opção confirmada: ", _current_selection)
	
	# ✅ APLICAR COR DE CONFIRMAÇÃO (VERMELHO)
	if _current_selection == 1:
		_option_1_text.modulate = color_confirmed
	else:
		_option_2_text.modulate = color_confirmed
	
	# ✅ Pequeno delay para feedback visual (0.2s)
	await get_tree().create_timer(0.2).timeout
	
	# ✅ Emitir sinais
	option_selected.emit(_current_selection)
	
	if _current_selection == 1:
		option_1_selected.emit()
	else:
		option_2_selected.emit()
	
	# ✅ Tocar som de confirmação (opcional)
	_play_confirm_sound()
	
	# ✅ Fechar diálogo
	_close_dialog()

func _close_dialog() -> void:
	"""Fecha o diálogo e restaura o controle do player"""
	
	# ❌ REMOVER TODO ESSE BLOCO:
	# if _player:
	#     _player._is_in_cinematic = false
	#     ...
	
	# ✅ SÓ ISSO:
	visible = false
	
	print("🔽 Diálogo fechado")

func get_selected_option() -> int:
	"""Retorna a opção selecionada (1 ou 2)"""
	return _current_selection

func _play_navigation_sound() -> void:
	"""Som de navegação entre opções"""
	# ✅ Implementar quando tiver sistema de áudio
	# AudioManager.play_ui_navigation()
	pass

func _play_confirm_sound() -> void:
	"""Som de confirmação"""
	# ✅ Implementar quando tiver sistema de áudio
	# AudioManager.play_ui_confirm()
	pass
