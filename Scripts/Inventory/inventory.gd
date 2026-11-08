extends Control
class_name UIInventory

const _INVENTORY_SIZE: int = 40      # total de espaços (5 linhas de 8)
const _COLUMNS: int = 8
const _VISIBLE_ROWS: int = 3          # linhas visíveis na tela
const _VISIBLE_SLOTS: int = 24        # quadrados na tela (_COLUMNS × _VISIBLE_ROWS)
const _INVENTORY_SLOT: PackedScene = preload("res://Scenes/Inventory/inventory_slot.tscn")

enum Page { INVENTORY, SKILLS, ARCHIVES, OPTIONS }
var current_page: Page = Page.INVENTORY
var index: int = 0
var previous_index: int = -1

@export_category("Objects")
@export var _slots_container: GridContainer

@export_category("Rolagem")
## Quanto a barra lateral desce no máximo (px), quando chega na última linha.
@export var scroll_bar_travel: float = 22.0
## Duração do deslizar da barra (s). 0 = instantâneo.
@export var scroll_bar_tween_time: float = 0.08

@export_category("Títulos")
@export var _inventory_title: TextureRect
@export var _skills_title: TextureRect
@export var _archives_title: TextureRect
@export var _options_title: TextureRect

@export_category("Audio")
@export var navigation_audio: AudioStreamPlayer
@export var select_audio: AudioStreamPlayer
@export var change_page_audio: AudioStreamPlayer

@onready var inventory_page: Control = $InventoryPage
@onready var skills_page: Control = $SkillsPage
@onready var archives_page: Control = $ArchivesPage
@onready var options_page: Control = $OptionsPage

var _top_row: int = 0                 # primeira linha visível da lista
var _scroll_bar: TextureRect = null
var _bar_tween: Tween

func _ready() -> void:
	global.ui_inventory = self
	
	for _i in _VISIBLE_SLOTS:
		var _inventory_slot: UIInventorySlot = _INVENTORY_SLOT.instantiate()
		_inventory_slot.parent = self
		_slots_container.add_child(_inventory_slot)
	
	if skills_page and skills_page.has_method("initialize"):
		skills_page.initialize()
	
	if archives_page and archives_page.has_method("initialize"):
		archives_page.initialize()
	
	_scroll_bar = get_node_or_null("InventoryPage/ScrollBar") as TextureRect
	_update_scroll_bar(false)
	
	_update_page_visibility()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_connect_equipment_signal")
	_update_texts()
	if options_page and options_page.has_signal("language_changed"):
		options_page.language_changed.connect(_update_texts)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if global.ui_equipments and global.ui_equipments.is_choosing():
		return
	
	# ✅ Rodinha do mouse rola a grade
	if current_page == Page.INVENTORY and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(1)
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("Inventory_Change_Right"):
		_change_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Inventory_Change_Left"):
		_change_page(-1)
		get_viewport().set_input_as_handled()

func _change_page(direction: int) -> void:
	# ✅ TOCAR SOM DE TROCAR PÁGINA
	play_change_page_audio()
	
	if direction > 0:
		match current_page:
			Page.INVENTORY:
				current_page = Page.SKILLS
			Page.SKILLS:
				current_page = Page.ARCHIVES
			Page.ARCHIVES:
				current_page = Page.OPTIONS
			Page.OPTIONS:
				current_page = Page.INVENTORY
	else:
		match current_page:
			Page.INVENTORY:
				current_page = Page.OPTIONS
			Page.SKILLS:
				current_page = Page.INVENTORY
			Page.ARCHIVES:
				current_page = Page.SKILLS
			Page.OPTIONS:
				current_page = Page.ARCHIVES
	
	_update_page_visibility()

# ========== FUNÇÕES DE ÁUDIO PÚBLICAS ==========
func play_navigation_audio() -> void:
	if navigation_audio and not navigation_audio.playing:
		navigation_audio.play()

func play_select_audio() -> void:
	if select_audio and not select_audio.playing:
		select_audio.play()

func play_change_page_audio() -> void:
	if change_page_audio:
		# ✅ PARAR O SOM ANTERIOR SE ESTIVER TOCANDO
		if change_page_audio.playing:
			change_page_audio.stop()
		
		# ✅ TOCAR O SOM NOVAMENTE DO INÍCIO
		change_page_audio.play()

# ========== RESTO DO CÓDIGO INALTERADO ==========
func _update_page_visibility() -> void:
	inventory_page.visible = (current_page == Page.INVENTORY)
	skills_page.visible = (current_page == Page.SKILLS)
	archives_page.visible = (current_page == Page.ARCHIVES)
	options_page.visible = (current_page == Page.OPTIONS)
	
	_update_title_colors()
	
	if current_page == Page.INVENTORY:
		hover_slot(index)
	elif current_page == Page.SKILLS and skills_page.has_method("focus_current_slot"):
		skills_page.focus_current_slot()
	elif current_page == Page.ARCHIVES and archives_page.has_method("focus_current_slot"):
		archives_page.focus_current_slot()

func _update_title_colors() -> void:
	const COLOR_ACTIVE: Color = Color("#beb600")
	const COLOR_INACTIVE: Color = Color.WHITE
	const OFFSET_ACTIVE: int = -2
	const OFFSET_INACTIVE: int = 0
	
	if _inventory_title:
		var label = _inventory_title.get_node_or_null("Title")
		if label:
			label.modulate = COLOR_INACTIVE
			label.position.y = OFFSET_INACTIVE
	
	if _skills_title:
		var label = _skills_title.get_node_or_null("Title")
		if label:
			label.modulate = COLOR_INACTIVE
			label.position.y = OFFSET_INACTIVE
	
	if _archives_title:
		var label = _archives_title.get_node_or_null("Title")
		if label:
			label.modulate = COLOR_INACTIVE
			label.position.y = OFFSET_INACTIVE
	
	if _options_title:
		var label = _options_title.get_node_or_null("Title")
		if label:
			label.modulate = COLOR_INACTIVE
			label.position.y = OFFSET_INACTIVE
	
	match current_page:
		Page.INVENTORY:
			if _inventory_title:
				var label = _inventory_title.get_node_or_null("Title")
				if label:
					label.modulate = COLOR_ACTIVE
					label.position.y = OFFSET_ACTIVE
		
		Page.SKILLS:
			if _skills_title:
				var label = _skills_title.get_node_or_null("Title")
				if label:
					label.modulate = COLOR_ACTIVE
					label.position.y = OFFSET_ACTIVE
		
		Page.ARCHIVES:
			if _archives_title:
				var label = _archives_title.get_node_or_null("Title")
				if label:
					label.modulate = COLOR_ACTIVE
					label.position.y = OFFSET_ACTIVE
		
		Page.OPTIONS:
			if _options_title:
				var label = _options_title.get_node_or_null("Title")
				if label:
					label.modulate = COLOR_ACTIVE
					label.position.y = OFFSET_ACTIVE

# ========== GRADE COM ROLAGEM ==========
# A lista tem _INVENTORY_SIZE espaços (5 linhas de 8). A tela mostra uma
# janela de _VISIBLE_ROWS linhas (24 quadrados fixos). Ao rolar, os mesmos
# quadrados passam a mostrar outra parte da lista.
# "index" e as funções públicas usam sempre o índice da LISTA (0..39).

func _max_top_row() -> int:
	var _total_rows: int = int(ceil(_INVENTORY_SIZE / float(_COLUMNS)))
	return maxi(0, _total_rows - _VISIBLE_ROWS)

func view_to_data(_view_index: int) -> int:
	return _top_row * _COLUMNS + _view_index

func _data_to_view(_data_index: int) -> int:
	var _v: int = _data_index - _top_row * _COLUMNS
	if _v >= 0 and _v < _VISIBLE_SLOTS:
		return _v
	return -1

func _get_item(_data_index: int) -> Dictionary:
	if global.inventory and global.inventory._inventory_data.has(_data_index):
		return global.inventory._inventory_data[_data_index]
	return {}

func _render_view_slot(_view_index: int, _item_data: Dictionary) -> void:
	var _slot = _slots_container.get_child(_view_index)
	_slot.display(_item_data)
	_refresh_slot_mark(view_to_data(_view_index))

func _render_window() -> void:
	for _v in _slots_container.get_child_count():
		_render_view_slot(_v, _get_item(view_to_data(_v)))

func _set_top_row(_row: int) -> bool:
	var _new_top: int = clampi(_row, 0, _max_top_row())
	if _new_top == _top_row:
		return false
	_top_row = _new_top
	_render_window()
	_update_scroll_bar(true)
	return true

func _scroll_to_row(_row: int) -> void:
	"""Rola só o necessário para a linha ficar visível."""
	if _row < _top_row:
		_set_top_row(_row)
	elif _row > _top_row + _VISIBLE_ROWS - 1:
		_set_top_row(_row - (_VISIBLE_ROWS - 1))

func _scroll_by(_rows: int) -> void:
	"""Rodinha do mouse: anda a janela e mantém o cursor dentro dela."""
	if not _set_top_row(_top_row + _rows):
		return
	play_navigation_audio()
	var _row: int = clampi(int(float(index) / _COLUMNS), _top_row, _top_row + _VISIBLE_ROWS - 1)
	hover_slot(_row * _COLUMNS + index % _COLUMNS)

func _update_scroll_bar(_animate: bool) -> void:
	if not _scroll_bar:
		return
	var _max_top: int = _max_top_row()
	var _target: float = 0.0
	if _max_top > 0:
		_target = roundf(scroll_bar_travel * _top_row / float(_max_top))
	if _bar_tween:
		_bar_tween.kill()
	if _animate and scroll_bar_tween_time > 0.0:
		_bar_tween = create_tween()
		_bar_tween.tween_method(_set_bar_y, _scroll_bar.position.y, _target, scroll_bar_tween_time)
	else:
		_set_bar_y(_target)

func _set_bar_y(_y: float) -> void:
	if _scroll_bar:
		_scroll_bar.position.y = roundf(_y)   # pixel inteiro

func initialize_slot(_index: int, _item_data: Dictionary) -> void:
	var _v: int = _data_to_view(_index)
	if _v >= 0:
		_render_view_slot(_v, _item_data)
		if _index == index:
			_update_description()

func update_slot(_index: int, _slot_data: Dictionary) -> void:
	initialize_slot(_index, _slot_data)

# ========== MOLDURA DE EQUIPADO ==========
# O item equipado (arma, armadura, offhand) continua na grade e ganha a moldura.
# A moldura é calculada comparando a grade com os slots de equipamento,
# então nunca fica dessincronizada do save.

func _connect_equipment_signal() -> void:
	if global.ui_equipments and not global.ui_equipments.equipment_changed.is_connected(refresh_equipped_marks):
		global.ui_equipments.equipment_changed.connect(refresh_equipped_marks)
	refresh_equipped_marks()

func _on_visibility_changed() -> void:
	if visible:
		_render_window()

func refresh_equipped_marks() -> void:
	if not _slots_container:
		return
	for _v in _slots_container.get_child_count():
		_refresh_slot_mark(view_to_data(_v))

func _refresh_slot_mark(_data_index: int) -> void:
	var _v: int = _data_to_view(_data_index)
	if not _slots_container or _v < 0 or _v >= _slots_container.get_child_count():
		return
	var _slot = _slots_container.get_child(_v)
	if not _slot.has_method("set_equipped"):
		return
	var _equipped: bool = false
	if global.ui_equipments:
		_equipped = global.ui_equipments.is_equipped(_get_item(_data_index))
	_slot.set_equipped(_equipped)

func hover_slot(_index: int) -> void:
	if _index == -1:
		$InventoryPage/InventoryText/ItemDescription.hide()
		return
	
	_index = clampi(_index, 0, _INVENTORY_SIZE - 1)
	_scroll_to_row(int(float(_index) / _COLUMNS))
	index = _index
	
	for _children in _slots_container.get_children():
		_children.hover(false)
	
	var _v: int = _data_to_view(_index)
	if _v >= 0:
		_slots_container.get_child(_v).hover(true)
	_update_description()

func _update_description() -> void:
	var _v: int = _data_to_view(index)
	if _v < 0:
		return
	$InventoryPage/InventoryText/ItemDescription.text = _slots_container.get_child(_v).get_item_description()
	$InventoryPage/InventoryText/ItemDescription.show()

func _process(_delta: float) -> void:
	if not visible or current_page != Page.INVENTORY:
		return
	# ✨ Janela de escolha de slot sagrado aberta: a grade não responde
	if global.ui_equipments and global.ui_equipments.is_choosing():
		return
	
	if Input.is_action_just_pressed("EquipWeapon"):
		var _item_data: Dictionary = _get_item(index)
		
		if _item_data.is_empty():
			return
		
		var item_type = _item_data.get("type", "")
		if item_type in ["weapon", "armor", "offhand", "consumable"]:
			# ✅ TOCAR SOM DE EQUIPAR
			play_select_audio()
			global.inventory.equip_item(index)
	
	# ✅ NAVEGAÇÃO: lados dão a volta na mesma linha; cima/baixo param nas bordas
	var _new_index: int = index
	
	if Input.is_action_just_pressed("move_left"):
		if _new_index % _COLUMNS == 0:
			_new_index += _COLUMNS - 1
		else:
			_new_index -= 1
	
	if Input.is_action_just_pressed("move_right"):
		if _new_index % _COLUMNS == _COLUMNS - 1:
			_new_index -= _COLUMNS - 1
		else:
			_new_index += 1
	
	if Input.is_action_just_pressed("move_up"):
		if _new_index - _COLUMNS >= 0:
			_new_index -= _COLUMNS
	
	if Input.is_action_just_pressed("move_down"):
		if _new_index + _COLUMNS < _INVENTORY_SIZE:
			_new_index += _COLUMNS
	
	# ✅ TOCAR SOM DE NAVEGAÇÃO QUANDO MOVER
	if _new_index != index:
		play_navigation_audio()
		previous_index = _new_index
		hover_slot(_new_index)

func toggle_visibility() -> void:
	visible = !visible
	
	if visible:
		get_tree().paused = true
		current_page = Page.INVENTORY
		_update_page_visibility()
	else:
		get_tree().paused = false

func add_archive(archive_data: Dictionary) -> void:
	if archives_page and archives_page.has_method("add_archive"):
		archives_page.add_archive(archive_data)

func refresh_archives() -> void:
	if archives_page and archives_page.has_method("refresh_archives"):
		archives_page.refresh_archives()

func equip_skill(skill_data: Dictionary) -> void:
	if skills_page and skills_page.has_method("equip_skill"):
		skills_page.equip_skill(skill_data)

func _update_texts() -> void:
	var titles = {
		"InventoryTexture": "INV_PAGE_INVENTORY",
		"SkillsTexture": "INV_PAGE_SKILLS",
		"ArchivesTexture": "INV_PAGE_ARCHIVES",
		"OptionsTexture": "INV_PAGE_OPTIONS"
	}
	
	for texture_name in titles:
		var label = get_node_or_null(texture_name + "/Title")
		if label:
			label.text = tr(titles[texture_name])
