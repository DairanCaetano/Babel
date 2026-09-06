extends Button
class_name ArchiveSlot

@export_category("Objects")
@export var _texture_rect: TextureRect
@export var _slot_selected: TextureRect

var _archive_data: Dictionary = {}
var _slot_index: int = 0
var _is_empty: bool = true

func initialize(archive_data: Dictionary) -> void:
	_archive_data = archive_data
	_is_empty = false
	
	# ✅ Carregar textura igual o inventário (usando "path")
	var icon_path: String = archive_data.get("path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_texture_rect.texture = load(icon_path)
		print("✅ Textura carregada: ", icon_path)
	else:
		print("⚠️ Textura não encontrada: ", icon_path)
	
	disabled = false

func set_selected(is_selected: bool) -> void:
	_slot_selected.visible = is_selected

func get_archive_data() -> Dictionary:
	return _archive_data

func _on_pressed() -> void:
	if _is_empty:
		return
	
	# Quando clicado com mouse, atualizar seleção
	var archives_page = get_parent().get_parent()
	if archives_page is UIArchives:
		archives_page._update_selection(_slot_index)

func _on_mouse_entered() -> void:
	if _is_empty:
		return
	
	var archives_page = get_parent().get_parent()
	if archives_page is UIArchives:
		archives_page._update_selection(_slot_index)
