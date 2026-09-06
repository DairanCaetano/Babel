extends Control
class_name UIArchives

const _ARCHIVE_SLOT: PackedScene = preload("res://Scenes/Inventory/archives_slot.tscn")
const _ARCHIVES_GRID_SIZE: int = 40
const _GRID_COLUMNS: int = 8

var _current_index: int = 0
var _previous_index: int = -1
var _total_archives: int = 0

@export_category("Objects")
@export var _archives_container: GridContainer
@export var _archive_title_label: Label
@export var _archive_content_label: Label

func initialize() -> void:
	print("🔧 Inicializando página de arquivos...")
	
	# ✅ Criar todos os 40 slots vazios
	for i in _ARCHIVES_GRID_SIZE:
		var archive_slot: ArchiveSlot = _ARCHIVE_SLOT.instantiate()
		archive_slot._slot_index = i
		_archives_container.add_child(archive_slot)
		print("📦 Slot ", i, " criado")
	
	print("✅ ", _ARCHIVES_GRID_SIZE, " slots criados!")
	
	# ✅ Carregar arquivos salvos do serialization
	_load_collected_archives()

func _load_collected_archives() -> void:
	print("📂 Carregando arquivos coletados...")
	
	if not serialization.game_data.has("collected_archives"):
		print("⚠️ Nenhum arquivo coletado ainda")
		return
	
	var collected_archives: Array = serialization.game_data["collected_archives"]
	_total_archives = collected_archives.size()
	
	print("📜 Encontrados ", _total_archives, " arquivos salvos")
	
	for i in collected_archives.size():
		if i >= _ARCHIVES_GRID_SIZE:
			break
		
		var archive_data: Dictionary = collected_archives[i]
		var slot: ArchiveSlot = _archives_container.get_child(i)
		slot.initialize(archive_data)
		print("✅ Arquivo ", i, " carregado: ", archive_data.get("title", "???"))

func add_archive(archive_data: Dictionary) -> void:
	print("➕ Adicionando novo arquivo ao inventário...")
	
	if _total_archives >= _ARCHIVES_GRID_SIZE:
		print("⚠️ Archive grid is full!")
		return
	
	# ✅ Adicionar ao próximo slot vazio
	var slot: ArchiveSlot = _archives_container.get_child(_total_archives)
	slot.initialize(archive_data)
	_total_archives += 1
	
	print("✅ Arquivo adicionado ao slot ", _total_archives - 1, ": ", archive_data.get("title", "???"))

func refresh_archives() -> void:
	print("🔄 Refrescando página de arquivos...")
	
	# ✅ Limpar slots atuais
	for child in _archives_container.get_children():
		child.queue_free()
	
	_total_archives = 0
	
	# ✅ Aguardar remoção
	await get_tree().process_frame
	
	# ✅ Reinicializar
	initialize()

func focus_current_slot() -> void:
	_update_selection(_current_index)

func _update_selection(new_index: int) -> void:
	# ✅ Desmarcar todos
	for child in _archives_container.get_children():
		if child is ArchiveSlot:
			child.set_selected(false)
	
	# ✅ Marcar o atual
	var current_slot: ArchiveSlot = _archives_container.get_child(new_index)
	current_slot.set_selected(true)
	
	# ✅ Atualizar texto
	if current_slot._is_empty:
		_archive_title_label.text = ""
		_archive_content_label.text = ""
	else:
		_archive_title_label.text = current_slot._archive_data.get("title", "Untitled")
		_archive_content_label.text = current_slot._archive_data.get("content", "")
	
	_current_index = new_index

func _process(_delta: float) -> void:
	if not visible:
		return
	
	var moved: bool = false
	
	if Input.is_action_just_pressed("move_left"):
		_current_index -= 1
		if _current_index < 0:
			_current_index = _ARCHIVES_GRID_SIZE - 1
		moved = true
		
	elif Input.is_action_just_pressed("move_right"):
		_current_index += 1
		if _current_index >= _ARCHIVES_GRID_SIZE:
			_current_index = 0
		moved = true
		
	elif Input.is_action_just_pressed("move_up"):
		_current_index -= _GRID_COLUMNS
		if _current_index < 0:
			_current_index = _ARCHIVES_GRID_SIZE + _current_index
		moved = true
		
	elif Input.is_action_just_pressed("move_down"):
		_current_index += _GRID_COLUMNS
		if _current_index >= _ARCHIVES_GRID_SIZE:
			_current_index = _current_index - _ARCHIVES_GRID_SIZE
		moved = true
	
	# ✅ TOCAR SOM DE NAVEGAÇÃO
	if moved and _previous_index != _current_index:
		if global.ui_inventory:
			global.ui_inventory.play_navigation_audio()
		_previous_index = _current_index
		_update_selection(_current_index)
