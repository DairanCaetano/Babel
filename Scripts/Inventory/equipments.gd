extends Control
class_name UIEquipments

signal equipment_changed

var _has_consumable: bool = false

var _atributes_increased: Dictionary = {
	"armor": {}, "weapon": {}, "offhand": {}, "sacred": {}
}

var _equipments_inventory: Dictionary = {
	"armor": {}, "weapon": {}, 
	"offhand": {}, "consumable": {},
	"sacred": {}   # slot de Gavri'el (só aceita sagrados)
}

# ========== ITENS SAGRADOS ==========
# Itens dos arcanjos podem ir em qualquer slot (offhand/armadura e, na parte 4,
# o slot sagrado de Gavri'el). Reconhecidos pelo campo "sacred" ou pela chave
# (saves antigos não têm o campo).
const SACRED_KEYS: Array[String] = [
	"ITEM_RAPHAEL_BLESSING_NAME",
	"ITEM_VENGEANCE_MARK_NAME",
]
const _SACRED_CHOICE_SCENE: String = "res://Scenes/Inventory/sacred_slot_choice.tscn"
const _NORMAL_SLOTS: Array[String] = ["armor", "offhand"]

var sacred_slot_unlocked: bool = false   # parte 4 (Gavri'el)
var _choice: Node = null
var _choice_item: Dictionary = {}
var _choice_paused_by_me: bool = false
var _choice_closed_frame: int = -1   # o aperto que fechou a janela não vaza para a grade

@export_category("Objects")
@export var _weapon_slot: Button
@export var _armor_slot: Button
@export var _offhand_slot: Button
@export var _consumable_slot: Button
@export var _fragments_slot: Button
## Slot sagrado (Bênção de Gavri'el). Escondido até ser liberado.
@export var _sacred_slot: Button

func _ready() -> void:
	global.ui_equipments = self
	set_sacred_slot_unlocked(bool(serialization.game_data.get("sacred_slot_unlocked", false)))
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
			_equipment_slot_type = "weapon"
		"ArmorSlot":
			_equipment_slot_type = "armor"
		"OffhandSlot", "offhandSlot":
			_equipment_slot_type = "offhand"
		"SacredSlot":
			_equipment_slot_type = "sacred"
	
	if _equipment_slot_type != "":
		unequip(_equipment_slot_type)

func _get_slot_button(_type: String) -> Button:
	match _type:
		"weapon":
			return _weapon_slot
		"armor":
			return _armor_slot
		"offhand":
			return _offhand_slot
		"consumable":
			return _consumable_slot
		"sacred":
			return _sacred_slot
	return null

func unequip(_type: String) -> void:
	"""Esvazia o slot de equipamento. Consumível volta para a grade;
	arma/armadura/offhand já estão na grade (só perdem a moldura)."""
	if not _equipments_inventory.has(_type):
		return
	var _item_data: Dictionary = _equipments_inventory[_type]
	if _item_data.is_empty():
		return
	
	if _type == "consumable":
		global.inventory.add_item(_item_data)
	else:
		_atributes_increased[_type] = {}
	
	_equipments_inventory[_type] = {}
	
	var _button: Button = _get_slot_button(_type)
	if _button:
		_get_item_texture(_button).texture = null
		if _button == _consumable_slot:
			_get_amount_label(_consumable_slot).text = ""
	
	if global.character and is_instance_valid(global.character):
		global.character._reset_bonus_attributes()
		global.character._increase_bonus_attributes(_atributes_increased)
	
	_save_equipments_to_serialization()
	equipment_changed.emit()

func is_equipped(_item: Dictionary) -> bool:
	"""True se este item da grade está equipado em algum slot."""
	if _item.is_empty() or _item.get("type", "") == "consumable":
		return false
	return find_equipped_slot(_item) != ""

func find_equipped_slot(_item: Dictionary) -> String:
	"""Slot onde o item está equipado ("" se não está). Sagrados podem estar em qualquer um."""
	if _item.is_empty():
		return ""
	for _slot in _equipments_inventory:
		if _slot == "consumable":
			continue
		if _same_item(_item, _equipments_inventory[_slot]):
			return _slot
	return ""

func _same_item(_a: Dictionary, _b: Dictionary) -> bool:
	if _a.is_empty() or _b.is_empty():
		return false
	var _key_a: String = _a.get("key", "")
	var _key_b: String = _b.get("key", "")
	if _key_a != "" and _key_b != "":
		return _key_a == _key_b
	return _a.get("name", "") == _b.get("name", "")

static func is_sacred(_item: Dictionary) -> bool:
	if _item.is_empty():
		return false
	return bool(_item.get("sacred", false)) or SACRED_KEYS.has(_item.get("key", ""))

# ========== EQUIPAR SAGRADO ==========

func _sacred_slot_available() -> bool:
	return sacred_slot_unlocked and _equipments_inventory.has("sacred")

func set_sacred_slot_unlocked(_unlocked: bool) -> void:
	"""Bênção de Gavri'el: mostra/esconde o 5º slot."""
	sacred_slot_unlocked = _unlocked
	if _sacred_slot:
		_sacred_slot.visible = _unlocked
	equipment_changed.emit()

func choose_free_sacred_slot(_item: Dictionary) -> String:
	"""Slot livre para o sagrado ("" = todos ocupados).
	Ordem: slot sagrado → slot preferido do item → o outro slot comum."""
	var _order: Array[String] = []
	if _sacred_slot_available():
		_order.append("sacred")
	var _home: String = _item.get("type", "armor")
	if _NORMAL_SLOTS.has(_home):
		_order.append(_home)
	for _slot in _NORMAL_SLOTS:
		if not _order.has(_slot):
			_order.append(_slot)
	for _slot in _order:
		if _equipments_inventory.has(_slot) and _equipments_inventory[_slot].is_empty():
			return _slot
	return ""

func equip_sacred(_item: Dictionary) -> void:
	"""Vai para um slot livre; se não houver, abre a janela de substituição."""
	var _slot: String = choose_free_sacred_slot(_item)
	if _slot != "":
		equip_item(_item, _slot)
		return
	_open_sacred_choice(_item)

func is_choosing() -> bool:
	if Engine.get_process_frames() == _choice_closed_frame:
		return true
	return _choice != null and is_instance_valid(_choice) and _choice.is_open

func _ensure_choice_scene() -> void:
	if _choice and is_instance_valid(_choice):
		return
	var _scene: PackedScene = load(_SACRED_CHOICE_SCENE)
	if not _scene:
		push_error("❌ Cena da escolha de slot sagrado não encontrada")
		return
	var _layer := CanvasLayer.new()
	_layer.name = "SacredChoiceLayer"
	_layer.layer = 90
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var _host: Node = null
	var _game_main = get_tree().get_first_node_in_group("game_main")
	if _game_main:
		_host = _game_main.get_node_or_null("HUD")
	if not _host:
		_host = get_tree().root
	_host.add_child(_layer)
	_choice = _scene.instantiate()
	_layer.add_child(_choice)
	_choice.slot_chosen.connect(_on_sacred_slot_chosen)
	_choice.cancelled.connect(_on_sacred_choice_cancelled)

func _open_sacred_choice(_item: Dictionary) -> void:
	_choice_item = _item.duplicate()
	
	# Na coleta: espera o aviso de item novo fechar antes de abrir
	await get_tree().process_frame
	for _display in get_tree().get_nodes_in_group("skill_display"):
		if is_instance_valid(_display) and _display.has_signal("display_finished"):
			await _display.display_finished
			break
	
	_ensure_choice_scene()
	if not _choice:
		return
	_choice_paused_by_me = not get_tree().paused
	if _choice_paused_by_me:
		get_tree().paused = true
	_choice.open(_choice_item, _sacred_slot_available())

func _end_sacred_choice() -> void:
	_choice_closed_frame = Engine.get_process_frames()
	if _choice_paused_by_me:
		get_tree().paused = false
	_choice_paused_by_me = false

func _on_sacred_slot_chosen(_slot: String) -> void:
	_end_sacred_choice()
	if _choice_item.is_empty():
		return
	equip_item(_choice_item, _slot)
	_choice_item = {}

func _on_sacred_choice_cancelled() -> void:
	# O item continua na grade, sem equipar
	_end_sacred_choice()
	_choice_item = {}

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
		"consumable": _equipments_inventory["consumable"],
		"sacred": _equipments_inventory["sacred"]
	}
	serialization.save_data()

func equip_item(_item: Dictionary, _slot: String = "") -> void:
	"""_slot vazio = slot do tipo do item. Sagrados recebem o slot escolhido."""
	if global.inventory and global.inventory._is_loading_save:
		return
	
	var _item_copy: Dictionary = _item.duplicate()
	var _slot_type: String = _slot if _slot != "" else _item_copy["type"]
	var _target_slot: Button = _get_slot_button(_slot_type)
	if _slot_type == "consumable":
		_has_consumable = false
	
	if _target_slot == null or not _equipments_inventory.has(_slot_type):
		return
	
	# Sagrado mudando de slot: libera o slot antigo
	if _slot_type != "consumable":
		var _previous_slot: String = find_equipped_slot(_item_copy)
		if _previous_slot != "" and _previous_slot != _slot_type:
			_equipments_inventory[_previous_slot] = {}
			_atributes_increased[_previous_slot] = {}
			var _old_button: Button = _get_slot_button(_previous_slot)
			if _old_button:
				_get_item_texture(_old_button).texture = null
	
	var _item_amount: int = 0
	var _current_equipped: Dictionary = _equipments_inventory[_slot_type]
	# Arma/armadura/offhand: o item anterior nunca saiu da grade, só perde a moldura.
	# Só o consumível ainda sai da grade e volta para ela ao ser trocado.
	if not _current_equipped.is_empty() and _slot_type == "consumable":
		# ✅ Penas de Azazel se juntam mesmo se a equipada estiver apagada
		var _same_item: bool = _current_equipped["name"] == _item_copy["name"]
		if CollectablePotion.is_feather(_current_equipped) and CollectablePotion.is_feather(_item_copy):
			_same_item = true
		
		if _same_item:
			_item_amount = _current_equipped["amount"]
		else:
			global.inventory.add_item(_current_equipped)
	
	_item_copy["amount"] = int(_item_copy.get("amount", 1)) + _item_amount
	_equipments_inventory[_slot_type] = _item_copy
	
	# ✅ Guardar atributos do item equipado (por SLOT, não por tipo)
	if _item_copy.has("attributes"):
		_atributes_increased[_slot_type] = _item_copy["attributes"].duplicate()
	else:
		_atributes_increased[_slot_type] = {}
	
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
