extends Node
class_name CharacterInventory

const _INVENTORY_SIZE: int = 24
var _inventory_data: Dictionary = {}

var _is_loading_save: bool = false

func _ready() -> void:
	global.inventory = self
	
	if serialization.should_apply_save:
		_is_loading_save = true
		print("🔒 CharacterInventory: Save bloqueado no _ready()")
	
	for _i in _INVENTORY_SIZE:
		_inventory_data[_i] = {}
	
	print("✅ CharacterInventory inicializado")

func _save_inventory_to_serialization() -> void:
	"""Serializa _inventory_data para o formato esperado e salva."""
	
	if _is_loading_save:
		print("	⚠️ Save bloqueado durante load")
		return
	
	var arr := []
	for i in _inventory_data.keys():
		if not _inventory_data[i].is_empty():
			arr.append({
				"index": i,
				"item": _inventory_data[i]
			})
	
	serialization.game_data["inventory"] = arr
	
	_update_subweapon_flags()
	
	serialization.save_data()
	print("	💾 Inventário serializado e salvo (itens: ", arr.size(), ")")

# ✅ IDENTIFICAÇÃO DE SUB-ARMAS PELA "key" (nunca pelo nome traduzido)
const SUBWEAPON_KEYS: Dictionary = {
	"ITEM_AXE_NAME": "axe",
	"ITEM_SPEAR_NAME": "spear",
	"ITEM_CHAKRAM_NAME": "chakram",
	"ITEM_FIRE_NAME": "fire"
}

# Nomes antigos (saves feitos antes dos itens terem "key")
const LEGACY_SUBWEAPON_NAMES: Dictionary = {
	"Machado Leve": "axe",
	"Lança de Arremesso": "spear",
	"Chakram": "chakram",
	"Chakram Arremessável": "chakram",
	"Fire Power": "fire",
	"Bálsamo Ígneo": "fire"
}

static func get_subweapon_type(item: Dictionary) -> String:
	"""Retorna 'axe', 'spear', 'chakram', 'fire' ou '' """
	if item.is_empty():
		return ""
	var key: String = item.get("key", "")
	if SUBWEAPON_KEYS.has(key):
		return SUBWEAPON_KEYS[key]
	return LEGACY_SUBWEAPON_NAMES.get(item.get("name", ""), "")

func _update_subweapon_flags() -> void:
	"""Atualiza as flags de sub-armas baseado no inventário + equipamentos"""
	var found: Dictionary = {"axe": false, "spear": false, "chakram": false, "fire": false}
	
	for slot in _inventory_data.values():
		var weapon_type: String = get_subweapon_type(slot)
		if weapon_type != "":
			found[weapon_type] = true
	
	if global.ui_equipments:
		var equipped = global.ui_equipments._equipments_inventory
		
		for slot_type in ["weapon", "armor", "offhand", "consumable"]:
			if equipped.has(slot_type):
				var weapon_type: String = get_subweapon_type(equipped[slot_type])
				if weapon_type != "":
					found[weapon_type] = true
	
	serialization.game_data["has_axe"] = found["axe"]
	serialization.game_data["has_spear"] = found["spear"]
	serialization.game_data["has_chakram"] = found["chakram"]
	serialization.game_data["has_fire"] = found["fire"]

func _sync_subweapon_state(_item: Dictionary) -> void:
	"""Sincroniza estado da sub-arma quando coletada/equipada"""
	if not global.character or not global.character.has_node("CharacterSubweapon"):
		print("⚠️ CharacterSubweapon não encontrado - sincronização ignorada")
		return
	
	var subweapon = global.character.get_node("CharacterSubweapon")
	
	match get_subweapon_type(_item):
		"axe":
			subweapon.update_axe_state(true)
			print("🪓 Axe sincronizado com CharacterSubweapon!")
		"spear":
			subweapon.update_spear_state(true)
			print("🗡️ Spear sincronizado com CharacterSubweapon!")
		"chakram":
			subweapon.update_chakram_state(true)
			print("🌀 Chakram sincronizado com CharacterSubweapon!")
		"fire":
			subweapon.update_fire_state(true)
			print("🔥 Fire Power sincronizado com CharacterSubweapon!")

func add_item(_item: Dictionary, _equip_directly: bool = false) -> void:
	var _item_copy: Dictionary = _item.duplicate()
	
	if _is_loading_save:
		print("❌ add_item() BLOQUEADO DURANTE LOAD!")
		print("   Item tentado: ", _item_copy["name"])
		return
	
	print("📦 Adicionando item: ", _item_copy["name"], " | Equipar direto: ", _equip_directly)
	
	match _item_copy["type"]:
		"consumable":
			var _equiped_item_data = global.ui_equipments._equipments_inventory["consumable"]
			if not _equiped_item_data.is_empty():
				if CollectablePotion.is_feather(_item_copy):
					if CollectablePotion.is_feather(_equiped_item_data):
						_equip_directly = true
	
	for _slot in _inventory_data:
		if _inventory_data[_slot].is_empty():
			continue
			
		if _inventory_data[_slot]["name"] == _item_copy["name"]:
			var _amount: int = 1
			if _item_copy.has("amount"):
				_amount = _item_copy["amount"]
			
			print("	✓ Item já existe no slot ", _slot, " - aumentando quantidade")
			
			if _equip_directly:
				_sync_subweapon_state(_item_copy)
				equip_item(_slot)
				return
			
			update_item(_amount, _slot, "Increase")
			return
	
	for _slot in _inventory_data:
		if _inventory_data[_slot].is_empty():
			_inventory_data[_slot] = _item_copy
			
			var _amount: int = 1
			if _item_copy.has("amount"):
				_amount = _item_copy["amount"]
			
			_inventory_data[_slot]["amount"] = _amount
			
			print("	✓ Item adicionado no slot ", _slot)
			
			if _equip_directly:
				print("	⚙️ Equipando item diretamente...")
				_sync_subweapon_state(_item_copy)
				equip_item(_slot)
				return
			
			global.ui_inventory.initialize_slot(_slot, _inventory_data[_slot])
			_sync_subweapon_state(_item_copy)
			_save_inventory_to_serialization()
			return
	
	print("	❌ ERRO: Inventário cheio!")

func update_item(_amount: int, _slot: int, _type: String) -> void:
	match _type:
		"Increase":
			_inventory_data[_slot]["amount"] += _amount
			global.ui_inventory.update_slot(_slot, _inventory_data[_slot])
			_save_inventory_to_serialization()
			
		"Decrease":
			_inventory_data[_slot]["amount"] -= _amount
			if _inventory_data[_slot]["amount"] <= 0:
				remove_item(_slot)
			else:
				global.ui_inventory.update_slot(_slot, _inventory_data[_slot])
				_save_inventory_to_serialization()

func remove_item(_slot_index: int) -> void:
	_inventory_data[_slot_index].clear()
	global.ui_inventory.update_slot(_slot_index, {})
	_save_inventory_to_serialization()

func equip_item(_slot: int) -> void:
	if _inventory_data[_slot].is_empty():
		print("	⚠️ Slot ", _slot, " está vazio - não pode equipar")
		return
	
	var item_to_equip = _inventory_data[_slot]
	print("	⚙️ Equipando: ", item_to_equip["name"])
	
	_sync_subweapon_state(item_to_equip)
	
	global.ui_equipments.equip_item(item_to_equip)
	remove_item(_slot)

func restore_item_at_slot(_slot: int, _item: Dictionary) -> void:
	"""Restaura um item do save diretamente no slot especificado"""
	if _slot < 0 or _slot >= _INVENTORY_SIZE:
		print("ERRO: Slot inválido: ", _slot)
		return
	
	_inventory_data[_slot] = _item.duplicate()
	global.ui_inventory.initialize_slot(_slot, _inventory_data[_slot])
	print("	✓ Item restaurado: ", _item["name"], " no slot ", _slot)

func clear_inventory() -> void:
	"""Limpa todo o inventário antes de carregar um save"""
	for _slot in _INVENTORY_SIZE:
		if not _inventory_data[_slot].is_empty():
			_inventory_data[_slot].clear()
			global.ui_inventory.update_slot(_slot, {})
	
	print("	🧹 Inventário limpo completamente")

# ✅ ADICIONAR ESTA FUNÇÃO NO FINAL
func serialize_inventory() -> void:
	"""Alias público para _save_inventory_to_serialization()"""
	_save_inventory_to_serialization()

# ✅ RECARGA DAS PENAS DE AZAZEL (save point)
func refill_max_potions() -> void:
	"""Recarrega todas as Penas de Azazel ao descansar com Azazel no save point"""
	print("🔄 Recarregando Penas de Azazel...")
	
	var max_potions: int = int(serialization.game_data.get("max_potions", 0))
	
	# ✅ 1. RECARREGAR NO INVENTÁRIO
	for _slot in _inventory_data:
		var item = _inventory_data[_slot]
		if not CollectablePotion.is_feather(item):
			continue
		
		# ✅ Detectar max_potions se ainda não foi salvo
		if max_potions == 0:
			max_potions = item.get("amount_to_drop", 1)
			serialization.game_data["max_potions"] = max_potions
		
		_restore_feather(item, max_potions)
		global.ui_inventory.update_slot(_slot, item)
		print("	✓ Pena de Azazel recarregada no inventário (slot ", _slot, ")")
	
	# ✅ 2. RECARREGAR SE ESTIVER EQUIPADA
	if global.ui_equipments:
		var equipped = global.ui_equipments._equipments_inventory.get("consumable", {})
		
		if CollectablePotion.is_feather(equipped):
			# ✅ Detectar max_potions se ainda não foi salvo
			if max_potions == 0:
				max_potions = equipped.get("amount_to_drop", 1)
				serialization.game_data["max_potions"] = max_potions
			
			_restore_feather(equipped, max_potions)
			
			# ✅ Atualizar UI
			var consumable_slot = global.ui_equipments._consumable_slot
			if consumable_slot:
				global.ui_equipments._get_item_texture(consumable_slot).texture = load(equipped["path"])
				global.ui_equipments._get_amount_label(consumable_slot).text = str(max_potions)
			
			# ✅ Atualizar serialização
			serialization.game_data["current_potions"] = max_potions
			
			print("	✓ Pena de Azazel equipada recarregada")
	
	_save_inventory_to_serialization()
	print("✅ Recarga das Penas de Azazel concluída!")

func _restore_feather(item: Dictionary, amount: int) -> void:
	"""Volta a pena para o estado cheio (key, nome, sprite e quantidade)"""
	item["amount"] = amount
	item["key"] = CollectablePotion.KEY_NAME
	item["name"] = tr(CollectablePotion.KEY_NAME)
	item["is_max_potion"] = true
	item["path_full"] = CollectablePotion.ICON_FULL_PATH
	item["path_empty"] = CollectablePotion.ICON_EMPTY_PATH
	item["path"] = CollectablePotion.ICON_FULL_PATH

func collect_item(_item: Dictionary) -> void:
	# ✅ VERIFICAR SE É UM RECURSO (MOEDA)
	if _item.has("type") and _item["type"] == "resource":
		_collect_currency(_item)
		return

# ✅ NOVA FUNÇÃO: Coletar moeda
func _collect_currency(_item: Dictionary) -> void:
	"""Coleta fragmentos e converte diretamente em moeda"""
	var value = _item.get("value", 1)
	var amount = _item.get("amount", 1)
	var total_value = value * amount
	
	global.add_currency("shards", total_value)
	
	# ✅ Feedback visual/audio aqui se quiser
	print("💰 Coletou ", amount, "x ", _item["name"], " = ", total_value, " shards")
