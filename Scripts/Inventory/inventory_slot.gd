extends Button
class_name UIInventorySlot

var _data: Dictionary = {}

var parent: UIInventory = null

@export_category("Objects")
@export var _slot_label: Label
@export var _slot_texture:  TextureRect

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
		parent.hover_slot(-1)
		return
		
	_data = _slot_data
	_slot_label.text = str(_slot_data["amount"])
	
	
func remove_item() -> void:
	_slot_texture.texture = null
	_slot_label.text = ""
	_data.clear()
	
	
func get_item_data() -> Dictionary:
	return _data
	
	
func get_item_description() -> String:
	if _data.is_empty():
		return ""
		
	return _data["description"]
	
	
func _on_pressed() -> void:
	if _data.is_empty():
		return
		
	if _data["type"] == "equipment":
		global.inventory.equip_item(get_index())
		
		
func _on_mouse_entered() -> void:
	parent.hover_slot(get_index())
