extends Control
class_name SacredSlotChoice

# ==========================================================================
# TELA DE ESCOLHA DE SLOT (itens sagrados)
# --------------------------------------------------------------------------
# Abre quando um item sagrado vai ser equipado e todos os slots possíveis
# estão ocupados. Mostra o item equipado em cada slot (o que será trocado).
#   move_left / move_right → troca de slot (dá a volta)
#   EquipWeapon            → confirma (emite slot_chosen)
#   close_menu             → cancela (emite cancelled)
#
# TESTE: abra esta cena e rode com F6 — ela abre sozinha com os 3 slots.
# ==========================================================================

signal slot_chosen(slot_type: String)
signal cancelled

const _ORDER: Array[String] = ["offhand", "armor", "sacred"]

@onready var _slots: Dictionary = {
	"offhand": $Center/VBox/Slots/OffhandSlot,
	"armor": $Center/VBox/Slots/ArmorSlot,
	"sacred": $Center/VBox/Slots/SacredSlot,
}

var is_open: bool = false
var _item: Dictionary = {}
var _available: Array[String] = []
var _cursor: int = 0
var _input_ready: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().current_scene == self:
		# Rodando sozinha (F6): abre para teste com o slot sagrado visível
		call_deferred("open", {}, true)
	else:
		hide()

# ========== API ==========

func open(item: Dictionary, sacred_unlocked: bool = false) -> void:
	_item = item
	_available = ["offhand", "armor"]
	if sacred_unlocked:
		_available.append("sacred")
	_slots["sacred"].visible = sacred_unlocked
	
	for _type in _ORDER:
		_set_slot_icon(_type)
	
	_cursor = 0
	_update_cursor()
	is_open = true
	show()
	
	# Ignora o mesmo aperto que abriu a tela
	_input_ready = false
	await get_tree().process_frame
	_input_ready = true

func close() -> void:
	is_open = false
	_input_ready = false
	hide()

func get_item() -> Dictionary:
	return _item

# ========== INTERNO ==========

func _input(event: InputEvent) -> void:
	if not is_open or not _input_ready:
		return
	
	if event.is_action_pressed("move_left"):
		_move(-1)
	elif event.is_action_pressed("move_right"):
		_move(1)
	elif event.is_action_pressed("EquipWeapon"):
		_confirm()
	elif event.is_action_pressed("close_menu"):
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func _move(direction: int) -> void:
	if _available.size() <= 1:
		return
	_cursor = wrapi(_cursor + direction, 0, _available.size())
	_update_cursor()
	if global.ui_inventory and global.ui_inventory.has_method("play_navigation_audio"):
		global.ui_inventory.play_navigation_audio()

func _confirm() -> void:
	var _type: String = _available[_cursor]
	if global.ui_inventory and global.ui_inventory.has_method("play_select_audio"):
		global.ui_inventory.play_select_audio()
	close()
	print("✨ Slot escolhido: ", _type)
	slot_chosen.emit(_type)

func _cancel() -> void:
	close()
	print("✨ Escolha de slot cancelada")
	cancelled.emit()

func _update_cursor() -> void:
	var _selected: String = _available[_cursor] if _available.size() > 0 else ""
	for _type in _ORDER:
		var _cursor_rect: TextureRect = _slots[_type].get_node("Selected")
		_cursor_rect.visible = (_type == _selected)

func _set_slot_icon(_type: String) -> void:
	var _icon: TextureRect = _slots[_type].get_node("ItemTexture")
	_icon.texture = null
	if not global.ui_equipments:
		return
	var _equipped: Dictionary = global.ui_equipments._equipments_inventory.get(_type, {})
	if not _equipped.is_empty() and _equipped.get("path", "") != "":
		_icon.texture = load(_equipped["path"])
