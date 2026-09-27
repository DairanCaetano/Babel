extends Control

@export var _weapon_slot: Button
@export var _armor_slot: Button
@export var _offhand_slot: Button
@export var _consumable_slot: Button

var _signal_connected: bool = false

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		if not _signal_connected and global.ui_equipments:
			global.ui_equipments.equipment_changed.connect(_sync_equipments)
			_signal_connected = true
		
		_sync_equipments()

func _sync_equipments() -> void:
	if not global.ui_equipments:
		return
	
	var eq = global.ui_equipments._equipments_inventory
	
	_update_slot(_weapon_slot, eq.get("weapon", {}))
	_update_slot(_armor_slot, eq.get("armor", {}))
	_update_slot(_offhand_slot, eq.get("offhand", {}))
	_update_slot(_consumable_slot, eq.get("consumable", {}))

func _update_slot(slot: Button, item: Dictionary) -> void:
	if not slot:
		return
	
	var tex = slot.get_node_or_null("SlotTexture/ItemTexture")
	if not tex:
		return
	
	if item.is_empty():
		tex.texture = null
	else:
		tex.texture = load(item["path"])
	
	if slot == _consumable_slot:
		var amount_label = slot.get_node_or_null("Amount")
		if amount_label:
			if item.is_empty() or CollectablePotion.is_empty_feather(item):
				amount_label.text = ""
			else:
				amount_label.text = str(item.get("amount", 0))
