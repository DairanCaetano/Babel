extends Button
class_name UIInventorySlot

var _data: Dictionary = {}

var parent: UIInventory = null

@export_category("Objects")
@export var _slot_label: Label
@export var _slot_texture:  TextureRect
## Moldura de "equipado" (só na grade da página de inventário)
@export var _equipped_frame: TextureRect

func display(_slot_data: Dictionary) -> void:
	"""Mostra qualquer item da lista (ou vazio). Usado pela grade com rolagem."""
	_data = _slot_data
	if _slot_data.is_empty():
		_slot_texture.texture = null
		_slot_label.text = ""
		set_equipped(false)
		return
	_slot_texture.texture = load(_slot_data["path"])
	if _slot_data.get("type", "") != "equipment":
		_slot_label.text = str(_slot_data.get("amount", 1))
	else:
		_slot_label.text = ""

func set_equipped(_state: bool) -> void:
	if _equipped_frame:
		_equipped_frame.visible = _state

func hover(_state: bool) -> void:
	$SlotSelected.visible = _state
	
	
func initialize(_slot_data: Dictionary) -> void:
	_data = _slot_data
	_slot_texture.texture = load(_slot_data["path"])
	if _slot_data["type"] != "equipment":
		_slot_label.text = str(_slot_data["amount"])
		
		
func update(_slot_data: Dictionary) -> void:
	if _slot_data.is_empty():
		_slot_texture.texture = null
		_slot_label.text = ""
		set_equipped(false)
		parent.hover_slot(-1)
		return
		
	_data = _slot_data
	_slot_label.text = str(_slot_data["amount"])
	
	
func remove_item() -> void:
	set_equipped(false)
	_slot_texture.texture = null
	_slot_label.text = ""
	_data.clear()
	
	
func get_item_data() -> Dictionary:
	return _data
	
	
func get_item_description() -> String:
	if _data.is_empty():
		return ""
	
	# ✅ Pena de Azazel: sempre usar o texto atual do CSV
	if CollectablePotion.is_feather(_data):
		return tr(CollectablePotion.KEY_DESC)
	
	# ✅ tr() traduz se for chave; se já for texto pronto, retorna igual
	return tr(_data.get("description", ""))
	
	
func _on_pressed() -> void:
	if _data.is_empty():
		return
		
	if _data["type"] == "equipment":
		global.inventory.equip_item(parent.view_to_data(get_index()))
		
		
func _on_mouse_entered() -> void:
	parent.hover_slot(parent.view_to_data(get_index()))
