extends Control
class_name UIInventory

const _INVENTORY_SIZE: int = 24
const _INVENTORY_SLOT: PackedScene = preload("res://Scenes/Inventory/inventory_slot.tscn")

enum Page { INVENTORY, ABILITIES, ARCHIVES, OPTIONS }
var current_page: Page = Page.INVENTORY
var index: int = 0
var previous_index: int = -1

@export_category("Objects")
@export var _slots_container: GridContainer

@export_category("Títulos")
@export var _inventory_title: TextureRect
@export var _abilities_title: TextureRect
@export var _archives_title: TextureRect
@export var _options_title: TextureRect

@export_category("Audio")
@export var navigation_audio: AudioStreamPlayer
@export var select_audio: AudioStreamPlayer
@export var change_page_audio: AudioStreamPlayer

@onready var inventory_page: Control = $InventoryPage
@onready var abilities_page: Control = $AbilitiesPage
@onready var archives_page: Control = $ArchivesPage
@onready var options_page: Control = $OptionsPage

func _ready() -> void:
	global.ui_inventory = self
	
	for _i in _INVENTORY_SIZE:
		var _inventory_slot: UIInventorySlot = _INVENTORY_SLOT.instantiate()
		_inventory_slot.parent = self
		_slots_container.add_child(_inventory_slot)
	
	if abilities_page and abilities_page.has_method("initialize"):
		abilities_page.initialize()
	
	if archives_page and archives_page.has_method("initialize"):
		archives_page.initialize()
	
	_update_page_visibility()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_update_texts()
	if options_page and options_page.has_signal("language_changed"):
		options_page.language_changed.connect(_update_texts)

func _input(event: InputEvent) -> void:
	if not visible:
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
				current_page = Page.ABILITIES
			Page.ABILITIES:
				current_page = Page.ARCHIVES
			Page.ARCHIVES:
				current_page = Page.OPTIONS
			Page.OPTIONS:
				current_page = Page.INVENTORY
	else:
		match current_page:
			Page.INVENTORY:
				current_page = Page.OPTIONS
			Page.ABILITIES:
				current_page = Page.INVENTORY
			Page.ARCHIVES:
				current_page = Page.ABILITIES
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
	abilities_page.visible = (current_page == Page.ABILITIES)
	archives_page.visible = (current_page == Page.ARCHIVES)
	options_page.visible = (current_page == Page.OPTIONS)
	
	_update_title_colors()
	
	if current_page == Page.INVENTORY:
		hover_slot(index)
	elif current_page == Page.ABILITIES and abilities_page.has_method("focus_current_slot"):
		abilities_page.focus_current_slot()
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
	
	if _abilities_title:
		var label = _abilities_title.get_node_or_null("Title")
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
		
		Page.ABILITIES:
			if _abilities_title:
				var label = _abilities_title.get_node_or_null("Title")
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

func initialize_slot(_index: int, _item_data: Dictionary) -> void:
	$InventoryPage/InventoryGrid/SlotsContainer.get_child(_index).initialize(_item_data)

func hover_slot(_index: int) -> void:
	if _index == -1:
		$InventoryPage/InventoryText/ItemDescription.hide()
		index = 0
		return
		
	for _children in $InventoryPage/InventoryGrid/SlotsContainer.get_children():
		_children.hover(false)
		
	$InventoryPage/InventoryGrid/SlotsContainer.get_child(_index).hover(true)
	$InventoryPage/InventoryText/ItemDescription.text = $InventoryPage/InventoryGrid/SlotsContainer.get_child(_index).get_item_description()
	$InventoryPage/InventoryText/ItemDescription.show()
	index = _index

func update_slot(_index: int, _slot_data: Dictionary) -> void:
	_slots_container.get_child(_index).update(_slot_data)

func _process(_delta: float) -> void:
	if not visible or current_page != Page.INVENTORY:
		return
	
	if Input.is_action_just_pressed("EquipWeapon"):
		var _slot: UIInventorySlot = $InventoryPage/InventoryGrid/SlotsContainer.get_child(index)
		var _item_data: Dictionary = _slot.get_item_data()
		
		if _item_data.is_empty():
			return
		
		var item_type = _item_data.get("type", "")
		if item_type in ["weapon", "offhand", "consumable"]:
			# ✅ TOCAR SOM DE EQUIPAR
			play_select_audio()
			global.inventory.equip_item(index)
	
	var moved: bool = false
	
	if Input.is_action_just_pressed("move_left"):
		index -= 1
		if index < 0:
			index = _INVENTORY_SIZE - 1
		moved = true
		
	if Input.is_action_just_pressed("move_right"):
		index += 1
		moved = true
		
	if Input.is_action_just_pressed("move_up"):
		index -= 8
		if index < 0:
			index = _INVENTORY_SIZE + index
		moved = true
		
	if Input.is_action_just_pressed("move_down"):
		index += 8
		moved = true
		
	if index > _INVENTORY_SIZE - 1:
		index = index - _INVENTORY_SIZE
	
	# ✅ TOCAR SOM DE NAVEGAÇÃO QUANDO MOVER
	if moved and previous_index != index:
		play_navigation_audio()
		previous_index = index
		hover_slot(index)

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
	if abilities_page and abilities_page.has_method("equip_skill"):
		abilities_page.equip_skill(skill_data)

func _update_texts() -> void:
	var titles = {
		"InventoryTexture": "INV_PAGE_INVENTORY",
		"AbilitiesTexture": "INV_PAGE_ABILITIES",
		"ArchivesTexture": "INV_PAGE_ARCHIVES",
		"OptionsTexture": "INV_PAGE_OPTIONS"
	}
	
	for texture_name in titles:
		var label = get_node_or_null(texture_name + "/Title")
		if label:
			label.text = tr(titles[texture_name])
