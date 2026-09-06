extends Control
class_name MainMenu

var _is_button_pressed: bool = false

# ========== NAVEGAÇÃO POR CONTROLE ==========
var _menu_buttons: Array = []
var _button_index: int = 0

@export_category("Objects")
@export var _animation: AnimationPlayer
@export var _game_start_audio: AudioStreamPlayer
@export var _select_audio: AudioStreamPlayer
@export var _buttons_container: VBoxContainer  # ✅ Referência ao VBoxContainer
@export var _continue_button: Button  # ✅ Referência ao botão Continue
@export var _options_button: Button

@export_category("Audio Settings")
@export var music_start_position: float = 30.0

@export_category("Wishlist Settings")
@export var wishlist_url: String = "https://store.steampowered.com/app/3880760"  # ✅ Coloque o ID do seu jogo aqui

func _ready() -> void:
	print("=== MAIN MENU READY ===")
	
	TransitionScreen.start_level.connect(_on_level_start)
	AudioManager.play_music_simple("start_game", music_start_position)
	_manage_continue_button()
	_setup_menu_buttons()
	
	for _button in get_tree().get_nodes_in_group("menu_button"):
		_button.pressed.connect(_on_button_pressed.bind(_button))
	
	if _menu_buttons.size() > 0:
		_skip_disabled_buttons()
		_update_button_highlight()
	
	# ✅ APLICAR IDIOMA SALVO
	serialization.load_settings()
	var saved_locale = serialization.settings_data.get("language", "pt_BR")
	TranslationServer.set_locale(saved_locale)
	
	# ✅ LOCALIZAÇÃO
	_update_texts()

func _manage_continue_button() -> void:
	"""Gerencia a visibilidade e posição do botão Continue baseado na existência de save"""
	if not _continue_button or not _buttons_container:
		print("⚠️ Continue button ou ButtonsContainer não configurado no Export!")
		return
	
	var has_save = FileAccess.file_exists("user://save.dat")
	
	if has_save:
		print("✅ Save encontrado - Continue será adicionado ao menu")
		
		# ✅ Adicionar o botão ao VBoxContainer se não estiver lá
		if _continue_button.get_parent() != _buttons_container:
			# Remove de onde estiver
			if _continue_button.get_parent():
				_continue_button.get_parent().remove_child(_continue_button)
			
			# Adiciona ao VBoxContainer na posição correta (depois de NewGame)
			var new_game_index = -1
			for i in range(_buttons_container.get_child_count()):
				var child = _buttons_container.get_child(i)
				if child.name == "NewGame":
					new_game_index = i
					break
			
			if new_game_index != -1:
				_buttons_container.add_child(_continue_button)
				_buttons_container.move_child(_continue_button, new_game_index + 1)
			else:
				_buttons_container.add_child(_continue_button)
		
		_continue_button.visible = true
		_continue_button.disabled = false
		
	else:
		print("📁 Nenhum save - Continue será removido do menu")
		
		# ✅ Remover do VBoxContainer
		if _continue_button.get_parent() == _buttons_container:
			_buttons_container.remove_child(_continue_button)
		
		_continue_button.visible = false
		_continue_button.disabled = true

func _setup_menu_buttons() -> void:
	"""Configura o array de botões do menu"""
	_menu_buttons.clear()
	
	if not _buttons_container:
		print("⚠️ ButtonsContainer não configurado!")
		return
	
	for child in _buttons_container.get_children():
		if child is Button and child.visible and not child.disabled:
			_menu_buttons.append(child)
	
	print("🎮 Botões ativos no menu: ", _menu_buttons.size())
	for btn in _menu_buttons:
		print("  - ", btn.name)

func _process(_delta: float) -> void:
	if _menu_buttons.is_empty():
		return
	
	# ========== VOLTAR PARA START MENU ==========
	if Input.is_action_just_pressed("dash"):
		_return_to_start_menu()
		return
	
	# ========== NAVEGAÇÃO VERTICAL ==========
	if Input.is_action_just_pressed("move_up"):
		_button_index -= 1
		if _button_index < 0:
			_button_index = _menu_buttons.size() - 1
		
		_skip_disabled_buttons()
		_update_button_highlight()
		
		if _select_audio:
			_select_audio.play()
		
		print("⬆️ Botão selecionado: ", _menu_buttons[_button_index].name)
	
	if Input.is_action_just_pressed("move_down"):
		_button_index += 1
		if _button_index >= _menu_buttons.size():
			_button_index = 0
		
		_skip_disabled_buttons()
		_update_button_highlight()
		
		if _select_audio:
			_select_audio.play()
		
		print("⬇️ Botão selecionado: ", _menu_buttons[_button_index].name)
	
	# ========== CONFIRMAR SELEÇÃO ==========
	if Input.is_action_just_pressed("EquipWeapon"):
		var selected_button = _menu_buttons[_button_index]
		
		print("✅ Confirmando: ", selected_button.name)
		
		if not selected_button.disabled:
			_on_button_pressed(selected_button)
		else:
			print("⚠️ Botão desabilitado!")

func _return_to_start_menu() -> void:
	"""Volta para o Start Menu quando o jogador aperta Dash"""
	if _is_button_pressed:
		return
	
	_is_button_pressed = true
	
	print("⬅️ Voltando para Start Menu...")
	
	global.current_scene_path = "res://Scenes/Menu/start_menu.tscn"
	TransitionScreen.fade_in()

func _skip_disabled_buttons() -> void:
	"""Pula automaticamente botões desabilitados"""
	if _menu_buttons.is_empty():
		return
	
	var attempts = 0
	var max_attempts = _menu_buttons.size()
	
	while _menu_buttons[_button_index].disabled and attempts < max_attempts:
		_button_index += 1
		if _button_index >= _menu_buttons.size():
			_button_index = 0
		attempts += 1
		
		print("⏭️ Pulando botão desabilitado, novo índice: ", _button_index)
	
	if attempts >= max_attempts:
		_button_index = 0

func _update_button_highlight() -> void:
	"""Destaca visualmente o botão selecionado"""
	if _menu_buttons.is_empty():
		return
	
	for i in range(_menu_buttons.size()):
		var button = _menu_buttons[i]
		var selection_frame = button.get_node_or_null("SelectionFrame")
		
		if i == _button_index:
			# ✅ BOTÃO SELECIONADO
			if selection_frame:
				selection_frame.visible = true
			
			var hover_color = button.get_theme_color("font_hover_color")
			button.add_theme_color_override("font_color", hover_color)
			
			var icon_hover_color = button.get_theme_color("icon_hover_color")
			button.add_theme_color_override("icon_normal_color", icon_hover_color)
			
		else:
			# ❌ BOTÃO NÃO SELECIONADO
			if selection_frame:
				selection_frame.visible = false
			
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("icon_normal_color")

func _on_level_start() -> void:
	_animation.play("Start_menu")

func _on_button_pressed(_button_pressed: Button) -> void:
	if _is_button_pressed:
		return
	
	_is_button_pressed = true
	
	print("🎮 === BOTÃO PRESSIONADO: ", _button_pressed.name, " ===")
	
	# ✅ Aplicar cor pressed
	var pressed_color = _button_pressed.get_theme_color("font_pressed_color")
	_button_pressed.add_theme_color_override("font_color", pressed_color)
	
	var icon_pressed_color = _button_pressed.get_theme_color("icon_pressed_color")
	_button_pressed.add_theme_color_override("icon_normal_color", icon_pressed_color)
	
	await get_tree().create_timer(0.2).timeout
	
	# ✅ TOCAR SOM COM VALIDAÇÃO
	if _game_start_audio:
		print("  🔊 Tocando som de confirmação...")
		_game_start_audio.play()
		await get_tree().create_timer(0.3).timeout
	else:
		print("  ⚠️ _game_start_audio não encontrado!")
	
	print("  ➡️ Executando ação do botão...")
	
	match _button_pressed.name:
		"NewGame":
			_start_new_game()
		"Continue":
			_continue_game()
		"whishlist":
			_open_wishlist()
		"Options":
			_open_options()
		"Quit":
			print("  🚪 Saindo do jogo...")
			get_tree().quit()


func _open_options() -> void:
	"""Abre o menu de opções"""
	print("⚙️ Abrindo menu de opções...")
	
	global.current_scene_path = "res://Scenes/Inventory/options_menu.tscn"  
	TransitionScreen.fade_in()


func _open_wishlist() -> void:
	"""Abre a página da wishlist do jogo na Steam"""
	print("💝 Abrindo wishlist da Steam...")
	
	if wishlist_url.is_empty():
		print("⚠️ URL da wishlist não configurada!")
		return
	
	var error = OS.shell_open(wishlist_url)
	
	if error == OK:
		print("✅ Navegador aberto com sucesso!")
	else:
		print("❌ Erro ao abrir navegador: ", error)

func _continue_game() -> void:
	print("▶️ ========== CONTINUE PRESSIONADO ==========")
	
	var save_system = get_node("/root/serialization")
	save_system.load_data()
	
	print("  ✓ Save carregado do arquivo")
	print("  📍 Posição: ", save_system.game_data["position"])
	print("  📦 Inventário: ", save_system.game_data["inventory"].size(), " itens")
	
	# ✅ ATIVAR FLAGS
	global.should_load_save = true
	save_system.should_apply_save = true
	
	# ✅ SEMPRE IR PARA GAME.TSCN
	global.current_scene_path = "res://Scenes/Base/game.tscn"
	
	print("  📂 Indo para: ", global.current_scene_path)
	print("  ✅ Flag should_load_save: ", global.should_load_save)
	print("=============================================")
	
	TransitionScreen.fade_in()

func _start_new_game() -> void:
	print("🆕 ========== NOVO JOGO ==========")
	
	serialization.reset_to_new_game()
	
	# ✅ ZERAR MOEDAS
	global.currencies = {"shards": 0}
	global.currency_changed.emit("shards", 0)
	print("💰 Moedas zeradas para novo jogo")
	
	serialization.save_data()
	
	global.should_load_save = false
	
	print("  ✓ Save resetado")
	print("  📂 Indo para cinemática...")
	print("  🎯 Path: res://Scenes/Cinematic/cinematic_intro.tscn")
	
	# ✅ VERIFICAR SE A CENA EXISTE
	var cinematic_path = "res://Scenes/Cinematic/cinematic_intro.tscn"
	
	if not ResourceLoader.exists(cinematic_path):
		print("❌ ERRO CRÍTICO: Cena da cinemática NÃO EXISTE!")
		print("  Tentando carregar: ", cinematic_path)
		
		# FALLBACK: Ir direto para o jogo
		print("  ⚠️ FALLBACK: Indo direto para game.tscn")
		global.current_scene_path = "res://Scenes/Base/game.tscn"
		TransitionScreen.fade_in()
		return
	
	print("  ✅ Cena encontrada, iniciando transição...")
	
	# ✅ TESTAR CARREGAMENTO DA CENA
	var loaded_scene = load(cinematic_path)
	if loaded_scene == null:
		print("❌ ERRO: Falha ao carregar a cena!")
		print("  ⚠️ FALLBACK: Indo direto para game.tscn")
		global.current_scene_path = "res://Scenes/Base/game.tscn"
		TransitionScreen.fade_in()
		return
	
	print("  ✅ Cena carregada com sucesso: ", loaded_scene.get_class())
	
	# ✅ IR PARA CINEMÁTICA
	global.current_scene_path = cinematic_path
	TransitionScreen.fade_in()
	
	print("====================================")

func _update_texts() -> void:
	var new_game = _buttons_container.get_node_or_null("NewGame")
	var continue_btn = _continue_button
	var wishlist = _buttons_container.get_node_or_null("whishlist")
	var quit = _buttons_container.get_node_or_null("Quit")
	
	if new_game:
		new_game.text = tr("MENU_NEW_GAME")
	if continue_btn:
		continue_btn.text = tr("MENU_CONTINUE")
	if wishlist:
		wishlist.text = tr("MENU_WISHLIST")
	if _options_button:
		_options_button.text = tr("MENU_OPTIONS")
	if quit:
		quit.text = tr("MENU_QUIT")
