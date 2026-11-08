extends CanvasLayer
class_name HUD

const _DIALOG_SYSTEM: PackedScene = preload("res://Scenes/Inventory/dialog_system.tscn")

@onready var _objects: Array = [
	$SaveContainer/ButtonsBackground/ButtonsContainer/SaveButton, 
	$SaveContainer/ButtonsBackground/ButtonsContainer/TravelButton, 
	$SaveContainer/ButtonsBackground/ButtonsContainer/TalkButton, 
	$SaveContainer/ButtonsBackground/ButtonsContainer/QuitButton
]

const _DISABLED_BUTTONS: Array[String] = ["TravelButton"]

@onready var _save_animation: AnimatedSprite2D = $SaveContainer/Texture

var _just_opened_menu: bool = false
var _objects_index: int = 0
var _is_save_menu_open: bool = false

@export_category("Objects")
@export var _ui_inventory: UIInventory
@export var _bar_container: BarContainer
@export var _equipments: UIEquipments
@export var _interfacebar: TextureRect

@export_category("Inventory Audio")
@export var inventory_open_audio: AudioStreamPlayer
@export var inventory_close_audio: AudioStreamPlayer

@export_category("Save Menu Audio")
@export var save_menu_open_audio: AudioStreamPlayer
@export var save_menu_close_audio: AudioStreamPlayer
@export var save_menu_navigation_audio: AudioStreamPlayer
@export var save_menu_select_audio: AudioStreamPlayer
@export var save_audio: AudioStreamPlayer


@export_category("Variables")
@export var _is_in_cinematic: bool = false

# Referências dinâmicas
var player_character: BaseCharacter = null
var save_area: SaveArea = null

func _ready() -> void:
	add_to_group("hud")
	_hide_unimplemented_buttons()
	_find_references()
	_update_texts()

func _find_references() -> void:
	"""Encontra player e save_area dinamicamente"""
	
	if not player_character and global.character and is_instance_valid(global.character):
		player_character = global.character
		print("✅ HUD: Player encontrado via global")
	
	save_area = null
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main or not is_instance_valid(game_main):
		print("⚠️ HUD: game_main não encontrado ou inválido")
		return
	
	var level_container = game_main.get_node_or_null("LevelContainer")
	if not level_container or not is_instance_valid(level_container):
		print("⚠️ HUD: LevelContainer não encontrado ou inválido")
		return
	
	if level_container.get_child_count() == 0:
		print("⚠️ HUD: LevelContainer ainda não tem levels carregados")
		return
	
	var current_level = level_container.get_child(0)
	if not current_level or not is_instance_valid(current_level):
		print("⚠️ HUD: Level atual é inválido")
		return
	
	save_area = _find_save_area_recursive(current_level)
	
	if save_area:
		print("✅ HUD: SaveArea encontrado em ", save_area.get_path())
	else:
		print("⚠️ HUD: SaveArea não encontrado no level atual")

func _find_save_area_recursive(node: Node) -> SaveArea:
	"""Busca SaveArea recursivamente na árvore"""
	
	if node is SaveArea:
		return node
	
	for child in node.get_children():
		var result = _find_save_area_recursive(child)
		if result:
			return result
	
	return null

func _is_archive_display_open() -> bool:
	var archive_displays = get_tree().get_nodes_in_group("archive_display")
	for display in archive_displays:
		if is_instance_valid(display) and display.visible:
			return true
	return false

func _process(_delta: float) -> void:
	# 🗺️ Com o mapa aberto, o HUD não abre inventário/menus
	if MapManager.esta_aberto():
		return
	
	if _is_in_cinematic:
		return
	
	if _is_archive_display_open():
		return
	
	if _just_opened_menu:
		_just_opened_menu = false
		return
	
	if Input.is_action_just_pressed("EquipWeapon") and $SaveContainer.visible:
		# ✅ NÃO TOCAR SOM GENÉRICO PARA O SAVE BUTTON (ele tem som próprio)
		if _objects[_objects_index].name != "SaveButton":
			_play_save_menu_select_audio()
		
		match _objects[_objects_index].name:
			"SaveButton":
				_on_save_button_pressed()
			"TravelButton":
				_on_travel_button_pressed()
			"TalkButton":
				_on_talk_button_pressed()
			"QuitButton":
				_on_quit_button_pressed()
				
	if Input.is_action_just_pressed("move_up") and $SaveContainer.visible:
		# ✅ TOCAR SOM DE NAVEGAÇÃO
		_play_save_menu_navigation_audio()
		
		_objects_index -= 1
		if _objects_index < 0:
			_objects_index =  _objects.size() - 1
		toggle_save()
		
	if Input.is_action_just_pressed("move_down") and $SaveContainer.visible:
		# ✅ TOCAR SOM DE NAVEGAÇÃO
		_play_save_menu_navigation_audio()
		
		_objects_index += 1
		if _objects_index >= _objects.size():
			_objects_index = 0
		toggle_save()
		
	if Input.is_action_just_pressed("close_menu") and $SaveContainer.visible:
		_on_quit_button_pressed()
		return
		
	# ✅ ○/B (ou clique direito) também fecha o menu de pausa
	if Input.is_action_just_pressed("close_menu") and _ui_inventory.visible:
		if not _is_archive_display_open() and not (global.ui_equipments and global.ui_equipments.is_choosing()):
			_set_inventory_open(false)
			return
	
	if Input.is_action_just_pressed("Inventory"):
		if _is_archive_display_open():
			return
		# ✨ Não fecha o inventário com a escolha de slot sagrado aberta
		if global.ui_equipments and global.ui_equipments.is_choosing():
			return
		
		_set_inventory_open(not _ui_inventory.visible)

func _set_inventory_open(is_opening: bool) -> void:
	if is_opening:
		_play_inventory_open_audio()
	else:
		_play_inventory_close_audio()
	
	_ui_inventory.visible = is_opening
	
	if _bar_container:
		_bar_container.visible = not is_opening
	
	if _equipments:
		_equipments.visible = not is_opening
	
	if _interfacebar:
		_interfacebar.visible = not is_opening
	
	if is_opening:
		_ui_inventory.hover_slot(0)
		_pause(true)
	else:
		_pause(false)

# ========== FUNÇÕES DE ÁUDIO - INVENTÁRIO ==========
func _play_inventory_open_audio() -> void:
	if inventory_open_audio:
		if inventory_open_audio.playing:
			inventory_open_audio.stop()
		inventory_open_audio.play()

func _play_inventory_close_audio() -> void:
	if inventory_close_audio:
		if inventory_close_audio.playing:
			inventory_close_audio.stop()
		inventory_close_audio.play()

# ========== FUNÇÕES DE ÁUDIO - SAVE MENU ==========
func _play_save_menu_open_audio() -> void:
	if save_menu_open_audio:
		if save_menu_open_audio.playing:
			save_menu_open_audio.stop()
		save_menu_open_audio.play()

func _play_save_menu_close_audio() -> void:
	if save_menu_close_audio:
		if save_menu_close_audio.playing:
			save_menu_close_audio.stop()
		save_menu_close_audio.play()

func _play_save_menu_navigation_audio() -> void:
	if save_menu_navigation_audio and not save_menu_navigation_audio.playing:
		save_menu_navigation_audio.play()

func _play_save_menu_select_audio() -> void:
	if save_menu_select_audio and not save_menu_select_audio.playing:
		save_menu_select_audio.play()

func toggle_save() -> void:
	for _children in _objects:
		_children.texture_normal = load("res://sprites/UI/SAVE/Babel_GUI_SAVE_TEXTE_SPACEPixel Art_v01.png")
		
	_objects[_objects_index].texture_normal = load("res://sprites/UI/SAVE/Babel_GUI_SAVE_SELECT_Pixel Art_v01.png")

func toggle_save_container() -> void:
	_find_references()
	
	if not player_character:
		push_error("HUD: Player não encontrado!")
		return
	
	# ✅ DETERMINAR SE ESTÁ ABRINDO OU FECHANDO
	var is_opening = not $SaveContainer.visible
	
	# ✅ TOCAR ÁUDIO APROPRIADO
	if is_opening:
		_play_save_menu_open_audio()
	else:
		_play_save_menu_close_audio()
	
	$SaveContainer.visible = is_opening
	
	if is_opening:
		# ========== ABRIR MENU ==========
		_just_opened_menu = true
		_is_save_menu_open = true
		_objects_index = 0
		toggle_save()
		
		# ✅ REGENERAR VIDA E STAMINA
		if player_character.has_node("Stats"):
			var stats = player_character.get_node("Stats")
			
			var stamina_to_restore = stats.max_stamina - stats.current_stamina
			if stamina_to_restore > 0:
				stats.update_stamina("increase", stamina_to_restore)
			
			var health_to_restore = stats.max_health - stats.current_health
			if health_to_restore > 0:
				stats.update_health("increase", health_to_restore)
		
		# ✅ DESCANSO: recarrega o Escudo de Bronze e limpa bônus temporários
		if player_character.has_method("on_save_rest"):
			player_character.on_save_rest()
		
		# ✅ RESTAURAR POÇÕES (CÓDIGO NOVO - SIMPLIFICADO)
		if global.inventory and global.inventory.has_method("refill_max_potions"):
			global.inventory.refill_max_potions()
			print("🪶 Penas de Azazel recarregadas via CharacterInventory")
		
		player_character._is_in_cinematic = true
		_pause(true)
		
		var char_texture = null
		if player_character.has_node("Texture"):
			char_texture = player_character.get_node("Texture")
		
		var azazel_animating = false
		
		if save_area and is_instance_valid(save_area) and save_area._azazel_texture:
			save_area._azazel_texture.play("Arrive")
			azazel_animating = true
		
		if char_texture:
			char_texture.action_animation("Rest")
			print("🎬 Tocando animação Rest")
		
		if azazel_animating and char_texture:
			if is_instance_valid(save_area) and save_area._azazel_texture:
				await save_area._azazel_texture.animation_finished
				print("✅ Azazel Arrive finalizado")
				
				if _is_save_menu_open and is_instance_valid(save_area):
					save_area._azazel_texture.play("Idle")
					print("🎬 Azazel agora em Idle")
			
			await char_texture.animation_finished
			print("✅ Player Rest finalizado")
			
			if _is_save_menu_open:
				char_texture.play("Resting")
				print("🎬 Player agora em Resting")
		
		elif char_texture:
			await char_texture.animation_finished
			print("✅ Player Rest finalizado (sem Azazel)")
			
			if _is_save_menu_open:
				char_texture.play("Resting")
				print("🎬 Player agora em Resting")
		
		# ✅ DIÁLOGO AUTOMÁTICO NO PRIMEIRO SAVE (só fases que pedem, ex.: Tebes 1-1)
		# Usa o mesmo caminho do botão Conversar: ao fim do diálogo o menu reabre.
		if _is_save_menu_open:
			var level = _get_current_base_level()
			if level and level.has_method("should_auto_start_save_dialog") and level.should_auto_start_save_dialog():
				level.mark_auto_save_dialog_done()
				print("💬 Primeiro save desta fase: iniciando diálogo automaticamente")
				_on_talk_button_pressed()
	
	else:
		# ========== FECHAR MENU ==========
		_is_save_menu_open = false
		
		var char_texture = null
		if player_character and player_character.has_node("Texture"):
			char_texture = player_character.get_node("Texture")
		
		if char_texture and char_texture._is_in_rest_state:
			char_texture.action_animation("Rise")
			print("🎬 Tocando animação Rise")
			
			await char_texture.animation_finished
			print("✅ Rise finalizado")
			
			if is_instance_valid(player_character):
				player_character._is_in_cinematic = false
				print("✅ Player liberado")
		else:
			if is_instance_valid(player_character):
				player_character._is_in_cinematic = false
				print("✅ Player liberado (não estava em rest)")
		
		_pause(false)

func spawn_dialog(_dialog_info: Dictionary) -> void:
	var _ds: DialogSystem = _DIALOG_SYSTEM.instantiate()
	_ds.dialog_data = _dialog_info
	add_child(_ds)
	
	_disable_player_control()
	_ds.is_finished.connect(_on_dialog_finished)

func _disable_player_control() -> void:
	if not player_character:
		_find_references()
	
	if player_character:
		player_character._is_in_cinematic = true

func _enable_player_control() -> void:
	if not player_character:
		_find_references()
	
	if player_character:
		player_character._is_in_cinematic = false

func _on_dialog_finished(_dialog_info: String) -> void:
	match _dialog_info:
		"save_point_dialog", "save_point":
			_reopen_save_menu()
		
		"cinematic_2":
			var game_main = get_tree().get_first_node_in_group("game_main")
			if game_main and game_main.has_method("load_level"):
				game_main.load_level("res://Scenes/Fases/tebes_t1.tscn", "default")
			
		_:
			if "save_point" in _dialog_info or "save" in _dialog_info:
				_reopen_save_menu()
			else:
				if save_area and is_instance_valid(save_area) and save_area._azazel_texture:
					save_area._azazel_texture.play("Gone")
					await save_area._azazel_texture.animation_finished
					save_area._azazel_texture.play("Await")
				
				_enable_player_control()

func _reopen_save_menu() -> void:
	# ✅ TOCAR SOM DE REABRIR MENU
	_play_save_menu_open_audio()
	
	$SaveContainer.visible = true
	_is_save_menu_open = true
	toggle_save()
	
	if player_character:
		player_character._is_in_cinematic = true
	
	if save_area and is_instance_valid(save_area) and save_area._azazel_texture:
		if save_area._azazel_texture.animation != "Idle":
			save_area._azazel_texture.play("Idle")
	
	if player_character and player_character.has_node("Texture"):
		var char_texture = player_character.get_node("Texture")
		if char_texture.animation != "Resting":
			char_texture.play("Resting")
		char_texture._is_in_rest_state = true

func _pause(should_be_paused: bool):
	get_tree().paused = should_be_paused

func _on_quit_button_pressed() -> void:
	# ✅ TOCAR SOM DE FECHAR MENU
	_play_save_menu_close_audio()
	
	_is_save_menu_open = false
	
	_find_references()
	
	if save_area and is_instance_valid(save_area) and save_area._azazel_texture:
		save_area._azazel_texture.play("Gone")
		await save_area._azazel_texture.animation_finished
		
		if is_instance_valid(save_area):
			save_area._azazel_texture.play("Await")
			save_area.is_save_visible = false
	
	$SaveContainer.visible = false
	
	if player_character and player_character.has_node("Texture"):
		var char_texture = player_character.get_node("Texture")
		if char_texture._is_in_rest_state:
			char_texture.action_animation("Rise")
			await char_texture.animation_finished
			
			if is_instance_valid(player_character):
				player_character._is_in_cinematic = false
		else:
			if is_instance_valid(player_character):
				player_character._is_in_cinematic = false
	
	_pause(false)

func _on_save_button_pressed() -> void:
	# ✅ TOCAR SOM DE SAVE (ESTAVA FALTANDO!)
	if save_audio:
		if save_audio.playing:
			save_audio.stop()
		save_audio.play()
	
	if _save_animation:
		_save_animation.play_save_sequence()
	
	if save_area and is_instance_valid(save_area) and save_area._save_fx:
		save_area._save_fx.emitting = true
	
	if not player_character:
		_find_references()
	
	if not player_character:
		push_error("HUD: Player não encontrado ao salvar!")
		return
	
	
	if global.inventory and is_instance_valid(global.inventory):
		global.inventory.serialize_inventory()
		print("  💾 Inventário serializado via CharacterInventory")
	else:
		push_error("HUD: global.inventory é nulo ou inválido!")
	
	if global.ui_equipments:
		serialization.game_data["equipments"] = {
			"weapon": global.ui_equipments._equipments_inventory.get("weapon", {}),
			"armor": global.ui_equipments._equipments_inventory.get("armor", {}),
			"offhand": global.ui_equipments._equipments_inventory.get("offhand", {}),
			"consumable": global.ui_equipments._equipments_inventory.get("consumable", {}),
			"sacred": global.ui_equipments._equipments_inventory.get("sacred", {})
		}
		
		var consumable = serialization.game_data["equipments"].get("consumable", {})
		if not consumable.is_empty():
			if CollectablePotion.is_feather(consumable):
				var current_amount = consumable.get("amount", 0)
				if current_amount > serialization.game_data.get("max_potions", 0):
					serialization.game_data["max_potions"] = current_amount
	
	# ✅ Flags de sub-armas calculadas pela "key" do item (ver CharacterInventory)
	if global.inventory and is_instance_valid(global.inventory):
		global.inventory._update_subweapon_flags()
	
	serialization.save_data()
	
	# ✅ Recarrega o level para respawnar inimigos (exceto bosses — não estão aqui)
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.has_method("reload_current_level"):
		await game_main.reload_current_level()
		# ✅ O reload recria a fase inteira (inclusive o SaveArea e o Azazel),
		# e o Azazel novo nasce em "Await". Se o menu ainda está aberto, volta pra Idle.
		_restore_save_point_after_reload()
	
	print("✅ Save concluído com sucesso!")

func _restore_save_point_after_reload() -> void:
	"""Reconecta o HUD ao SaveArea novo e mantém o Azazel presente enquanto o menu está aberto"""
	_find_references()
	
	if not _is_save_menu_open:
		return
	
	if save_area and is_instance_valid(save_area):
		if save_area._azazel_texture:
			save_area._azazel_texture.play("Idle")
		if save_area._interaction_icon:
			save_area._interaction_icon.visible = false
		save_area.is_save_visible = true
		print("🎬 Azazel mantido em Idle após o reload do save")


func _on_travel_button_pressed() -> void:
	pass

func _get_current_base_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		return null
	var level_container = game_main.get_node_or_null("LevelContainer")
	if level_container and level_container.get_child_count() > 0:
		return level_container.get_child(0)
	return null

func _on_talk_button_pressed() -> void:
	$SaveContainer.visible = false
	
	if player_character:
		if player_character.has_node("Texture"):
			var char_texture = player_character.get_node("Texture")
			char_texture._is_in_rest_state = true
			char_texture.play("Resting")
		
		player_character._is_in_cinematic = true
		
		if "is_consuming" in player_character:
			player_character.is_consuming = true
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main:
		var level_container = game_main.get_node_or_null("LevelContainer")
		if level_container and level_container.get_child_count() > 0:
			var base_level = level_container.get_child(0)
			
			if base_level and base_level.has_method("load_save_point_dialog"):
				base_level.load_save_point_dialog()
			else:
				_reopen_save_menu()
		else:
			_reopen_save_menu()
	else:
		_reopen_save_menu()

func _hide_unimplemented_buttons() -> void:
	"""Remove botões não implementados do menu de save"""
	var buttons_to_remove: Array = []
	
	for button in _objects:
		if button.name in _DISABLED_BUTTONS:
			button.visible = false
			buttons_to_remove.append(button)
	
	for button in buttons_to_remove:
		_objects.erase(button)
	
	print("🔒 Botões ocultos (não implementados): ", _DISABLED_BUTTONS)

func _update_texts() -> void:
	var buttons = {
		"SaveButton": "HUD_SAVE",
		"TravelButton": "HUD_TRAVEL",
		"TalkButton": "HUD_TALK",
		"QuitButton": "HUD_QUIT"
	}
	
	for button_name in buttons:
		var label = get_node_or_null("SaveContainer/ButtonsBackground/ButtonsContainer/" + button_name + "/Label")
		if label:
			label.text = tr(buttons[button_name])
