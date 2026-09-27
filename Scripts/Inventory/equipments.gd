extends Control
class_name UIEquipments

signal equipment_changed

var _has_consumable: bool = false

var _atributes_increased: Dictionary = {
	"armor": {}, "weapon": {}, "offhand": {}
}

var _equipments_inventory: Dictionary = {
	"armor": {}, "weapon": {}, 
	"offhand": {}, "consumable": {}
}

@export_category("Objects")
@export var _weapon_slot: Button
@export var _armor_slot: Button
@export var _offhand_slot: Button
@export var _consumable_slot: Button
@export var _fragments_slot: Button

func _ready() -> void:
	global.ui_equipments = self
	for _button in get_tree().get_nodes_in_group("equipments_slot"):
		_button.pressed.connect(_on_button_pressed.bind(_button))

func _on_button_pressed(_button_pressed: Button) -> void:
	_button_pressed.release_focus()
	var _item_slot: TextureRect = _button_pressed.get_node("SlotTexture/ItemTexture")
	if _item_slot.texture == null:
		return
	
	var _equipment_slot_type: String = ""
	
	match _button_pressed.name:
		"ConsumableSlot":
			_equipment_slot_type = "consumable"
		"WeaponSlot":
			_atributes_increased["weapon"] = {}
			_equipment_slot_type = "weapon"
		"ArmorSlot":
			_atributes_increased["armor"] = {}
			_equipment_slot_type = "armor"
		"OffhandSlot":
			_atributes_increased["offhand"] = {}
			_equipment_slot_type = "offhand"
	
	var _item_data: Dictionary = _equipments_inventory[_equipment_slot_type]
	global.inventory.add_item(_item_data)
	
	_equipments_inventory[_equipment_slot_type] = {}
	
	if _button_pressed == _consumable_slot:
		_get_amount_label(_consumable_slot).text = ""
	
	_item_slot.texture = null
	
	global.character._reset_bonus_attributes()
	global.character._increase_bonus_attributes(_atributes_increased)
	
	equipment_changed.emit()

func _get_amount_label(_slot: Button) -> Label:
	return _slot.get_node("Amount")

func _get_item_texture(_slot: Button) -> TextureRect:
	return _slot.get_node("SlotTexture/ItemTexture")

func use_consumable() -> void:
	if _equipments_inventory["consumable"].is_empty():
		return
	
	# ✅ VERIFICAR SE É PENA APAGADA (sem usos)
	if CollectablePotion.is_empty_feather(_equipments_inventory["consumable"]):
		print("⚠️ Pena de Azazel apagada - não pode usar!")
		return
	
	# ✅ VERIFICAR SE É PENA DE AZAZEL (cura recarregável)
	var is_max_potion = CollectablePotion.is_feather(_equipments_inventory["consumable"])
	
	# ✅ DECREMENTAR
	_equipments_inventory["consumable"]["amount"] -= 1
	serialization.game_data["current_potions"] = _equipments_inventory["consumable"]["amount"]
	
	# ✅ SE ZEROU
	if _equipments_inventory["consumable"]["amount"] <= 0:
		if is_max_potion:
			# ✅ TRANSFORMAR EM PENA APAGADA (não remove)
			var _feather: Dictionary = _equipments_inventory["consumable"]
			var _empty_path: String = CollectablePotion.empty_path(_feather)
			_feather["path_full"] = CollectablePotion.full_path(_feather)
			_feather["name"] = tr(CollectablePotion.KEY_EMPTY)
			_feather["key"] = CollectablePotion.KEY_EMPTY
			_feather["path"] = _empty_path
			_feather["amount"] = 0
			
			# ✅ ATUALIZAR SPRITE
			_get_item_texture(_consumable_slot).texture = load(_empty_path)
			_get_amount_label(_consumable_slot).text = ""
			
			print("🪶 Pena de Azazel sem usos - sprite alterado para apagada")
		else:
			# ✅ CONSUMÍVEL NORMAL - REMOVE COMPLETAMENTE
			_equipments_inventory["consumable"] = {}
			_get_item_texture(_consumable_slot).texture = null
			_get_amount_label(_consumable_slot).text = ""
			_has_consumable = false
			print("🗑️ Consumível normal removido")
	else:
		# ✅ AINDA TEM QUANTIDADE - ATUALIZAR LABEL
		_get_amount_label(_consumable_slot).text = str(_equipments_inventory["consumable"]["amount"])
	
	_save_equipments_to_serialization()
	equipment_changed.emit()

func _save_equipments_to_serialization() -> void:
	serialization.game_data["equipments"] = {
		"weapon": _equipments_inventory["weapon"],
		"armor": _equipments_inventory["armor"],
		"offhand": _equipments_inventory["offhand"],
		"consumable": _equipments_inventory["consumable"]
	}
	serialization.save_data()

func equip_item(_item: Dictionary) -> void:
	if global.inventory and global.inventory._is_loading_save:
		return
	
	var _item_copy: Dictionary = _item.duplicate()
	var _target_slot: Button = null
	
	match _item_copy["type"]:
		"armor":
			_target_slot = _armor_slot
		"weapon":
			_target_slot = _weapon_slot
		"offhand":
			_target_slot = _offhand_slot
		"consumable":
			_target_slot = _consumable_slot
			_has_consumable = false
	
	if _target_slot == null:
		return
	
	var _item_amount: int = 0
	var _current_equipped: Dictionary = _equipments_inventory[_item_copy["type"]]
	if not _current_equipped.is_empty():
		# ✅ Penas de Azazel se juntam mesmo se a equipada estiver apagada
		var _same_item: bool = _current_equipped["name"] == _item_copy["name"]
		if CollectablePotion.is_feather(_current_equipped) and CollectablePotion.is_feather(_item_copy):
			_same_item = true
		
		if _same_item:
			_item_amount = _current_equipped["amount"]
		else:
			global.inventory.add_item(_current_equipped)
	
	_item_copy["amount"] += _item_amount
	_equipments_inventory[_item_copy["type"]] = _item_copy
	
	# ✅ Guardar atributos do item equipado
	if _item_copy.has("attributes"):
		_atributes_increased[_item_copy["type"]] = _item_copy["attributes"].duplicate()
	else:
		_atributes_increased[_item_copy["type"]] = {}
	
	# ✅ PENA DE AZAZEL: o máximo é incrementado na coleta (CollectablePotion)
	if CollectablePotion.is_feather(_item_copy):
		if _item_copy["amount"] > 0:
			_item_copy["key"] = CollectablePotion.KEY_NAME
			_item_copy["name"] = tr(CollectablePotion.KEY_NAME)
			_item_copy["path"] = CollectablePotion.full_path(_item_copy)
		serialization.game_data["current_potions"] = _item_copy["amount"]
		if _item_copy["amount"] > int(serialization.game_data.get("max_potions", 0)):
			serialization.game_data["max_potions"] = _item_copy["amount"]
	
	if global.character and global.character.has_node("CharacterSubweapon"):
		var subweapon = global.character.get_node("CharacterSubweapon")
		
		match _item_copy.get("key", ""):
					"ITEM_AXE_NAME":
						subweapon._has_axe = true
						serialization.game_data["has_axe"] = true
					"ITEM_SPEAR_NAME":
						subweapon._has_spear = true
						serialization.game_data["has_spear"] = true
					"ITEM_CHAKRAM_NAME":
						subweapon._has_chakram = true
						serialization.game_data["has_chakram"] = true
					"ITEM_FIRE_NAME":
						serialization.game_data["has_fire"] = true
					"ITEM_DAGGER_NAME":
						subweapon._has_dagger = true
						serialization.game_data["has_dagger"] = true
					"ITEM_WHIP_NAME":
						serialization.game_data["has_whip"] = true
		
		serialization.save_data()
	
	if _target_slot == _consumable_slot:
		_get_amount_label(_target_slot).text = str(_item_copy["amount"])
		if CollectablePotion.is_empty_feather(_equipments_inventory["consumable"]):
			_get_amount_label(_target_slot).text = ""
	
	_get_item_texture(_target_slot).texture = load(_item_copy["path"])
	
	_save_equipments_to_serialization()
	
	# ✅ Aplicar atributos de TODOS os slots equipados
	if global.character and is_instance_valid(global.character):
		global.character._reset_bonus_attributes()
		global.character._increase_bonus_attributes(_atributes_increased)
	
	await get_tree().physics_frame
	_has_consumable = true
	
	equipment_changed.emit()
