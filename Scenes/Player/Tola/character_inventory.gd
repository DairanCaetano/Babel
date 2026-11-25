extends Node
class_name CharacterInventory

const _INVENTORY_SIZE: int = 40   # 5 linhas de 8 (a tela mostra 3 por vez)
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
			# O fogo não tem flag própria: can_use_fire() só confere a arma equipada
			print("🔥 Bálsamo Ígneo coletado (liberado pela arma equipada)")

func add_item(_item: Dictionary, _equip_directly: bool = false) -> void:
	var _item_copy: Dictionary = _item.duplicate()
	
	if _is_loading_save:
		print("❌ add_item() BLOQUEADO DURANTE LOAD!")
		print("   Item tentado: ", _item_copy["name"])
		return
	
	print("📦 Adicionando item: ", _item_copy["name"], " | Equipar direto: ", _equip_directly)
	
	# 🪶 Pena de Azazel: soma os usos na pena equipada e mantém o espelho na grade
	if CollectablePotion.is_feather(_item_copy) and global.ui_equipments:
		_add_feather(_item_copy)
		return
	
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
				equip_item(_slot, false)
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
				global.ui_inventory.initialize_slot(_slot, _inventory_data[_slot])
				equip_item(_slot, false)
				_save_inventory_to_serialization()
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
	# Troca por um vazio em vez de .clear(): a Pena de Azazel da grade é o MESMO
	# dicionário do slot equipado, e .clear() apagaria a equipada também.
	_inventory_data[_slot_index] = {}
	global.ui_inventory.update_slot(_slot_index, {})
	_save_inventory_to_serialization()

func equip_item(_slot: int, _toggle: bool = true) -> void:
	"""Pena de Azazel: fica na grade com a moldura (mesmo dicionário do slot).
	Outros consumíveis: saem da grade e vão para o slot.
	Arma/armadura/offhand: fica na grade com a moldura de equipado;
	se já estiver equipado e _toggle = true, desequipa."""
	if _inventory_data[_slot].is_empty():
		print("	⚠️ Slot ", _slot, " está vazio - não pode equipar")
		return
	
	var item_to_equip = _inventory_data[_slot]
	
	if item_to_equip.get("type", "") == "consumable":
		# 🪶 Pena de Azazel: fica na grade (moldura de equipado), igual às armas
		if CollectablePotion.is_feather(item_to_equip):
			if global.ui_equipments.is_equipped(item_to_equip):
				if _toggle:
					print("	⚙️ Desequipando: ", item_to_equip["name"])
					global.ui_equipments.unequip("consumable")
				return
			print("	⚙️ Equipando: ", item_to_equip["name"])
			global.ui_equipments.equip_item(item_to_equip)
			sync_feather_mirror()
			_save_inventory_to_serialization()
			return
		# Outros consumíveis (futuros): saem da grade e vão para o slot
		print("	⚙️ Equipando: ", item_to_equip["name"])
		_sync_subweapon_state(item_to_equip)
		global.ui_equipments.equip_item(item_to_equip)
		remove_item(_slot)
		return
	
	if global.ui_equipments.is_equipped(item_to_equip):
		if _toggle:
			print("	⚙️ Desequipando: ", item_to_equip["name"])
			global.ui_equipments.unequip(global.ui_equipments.find_equipped_slot(item_to_equip))
		return
	
	print("	⚙️ Equipando: ", item_to_equip["name"])
	_sync_subweapon_state(item_to_equip)
	if UIEquipments.is_sacred(item_to_equip):
		# ✨ Sagrado: slot livre ou janela de substituição
		global.ui_equipments.equip_sacred(item_to_equip)
	else:
		global.ui_equipments.equip_item(item_to_equip)

const _BRONZE_SHIELD_KEY: String = "ITEM_BRONZE_SHIELD_NAME"

func migrate_bronze_shield() -> void:
	"""Saves antigos: o Escudo de Bronze era offhand, agora é armadura."""
	for _slot in _inventory_data:
		var _it: Dictionary = _inventory_data[_slot]
		if _it.get("key", "") == _BRONZE_SHIELD_KEY and _it.get("type", "") != "armor":
			_it["type"] = "armor"
			print("	🛡️ Escudo de Bronze migrado para armadura (grade, slot ", _slot, ")")
	
	if not global.ui_equipments:
		return
	var _eq_ui = global.ui_equipments
	var _off: Dictionary = _eq_ui._equipments_inventory.get("offhand", {})
	if _off.get("key", "") != _BRONZE_SHIELD_KEY:
		return
	
	# Sai do offhand
	_off["type"] = "armor"
	_eq_ui._equipments_inventory["offhand"] = {}
	_eq_ui._atributes_increased["offhand"] = {}
	_eq_ui._get_item_texture(_eq_ui._offhand_slot).texture = null
	
	if _eq_ui._equipments_inventory["armor"].is_empty():
		# Armadura livre: equipa lá
		_eq_ui._equipments_inventory["armor"] = _off
		_eq_ui._atributes_increased["armor"] = _off.get("attributes", {}).duplicate()
		_eq_ui._get_item_texture(_eq_ui._armor_slot).texture = load(_off["path"])
		print("	🛡️ Escudo de Bronze equipado: offhand → armadura")
	else:
		# Armadura ocupada: só desequipa (continua/volta para a grade)
		var _in_grid: bool = false
		for _slot in _inventory_data:
			if _inventory_data[_slot].get("key", "") == _BRONZE_SHIELD_KEY:
				_in_grid = true
				break
		if not _in_grid:
			for _slot in _INVENTORY_SIZE:
				if _inventory_data[_slot].is_empty():
					_inventory_data[_slot] = _off.duplicate()
					if not _inventory_data[_slot].has("amount"):
						_inventory_data[_slot]["amount"] = 1
					global.ui_inventory.initialize_slot(_slot, _inventory_data[_slot])
					break
		print("	🛡️ Escudo de Bronze desequipado (armadura já ocupada)")
	
	if global.character and is_instance_valid(global.character):
		global.character._reset_bonus_attributes()
		global.character._increase_bonus_attributes(_eq_ui._atributes_increased)

func ensure_equipped_in_inventory() -> void:
	"""Saves antigos: o item equipado tinha saído da grade.
	Coloca de volta no primeiro espaço livre (a moldura aparece sozinha)."""
	if not global.ui_equipments:
		return
	var _equipped: Dictionary = global.ui_equipments._equipments_inventory
	for _type in ["weapon", "armor", "offhand"]:
		var _item: Dictionary = _equipped.get(_type, {})
		if _item.is_empty():
			continue
		var _found: bool = false
		for _slot in _inventory_data:
			if global.ui_equipments.find_equipped_slot(_inventory_data[_slot]) == _type:
				_found = true
				break
		if _found:
			continue
		var _placed: bool = false
		for _slot in _INVENTORY_SIZE:
			if _inventory_data[_slot].is_empty():
				_inventory_data[_slot] = _item.duplicate()
				if not _inventory_data[_slot].has("amount"):
					_inventory_data[_slot]["amount"] = 1
				global.ui_inventory.initialize_slot(_slot, _inventory_data[_slot])
				print("	↩️ Item equipado devolvido à grade (save antigo): ", _item.get("name", ""), " → slot ", _slot)
				_placed = true
				break
		if not _placed:
			print("	⚠️ Grade cheia: item equipado ", _item.get("name", ""), " não coube no inventário")
	sync_feather_mirror()
	if global.ui_inventory and global.ui_inventory.has_method("refresh_equipped_marks"):
		global.ui_inventory.refresh_equipped_marks()

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
			_inventory_data[_slot] = {}
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
	
	sync_feather_mirror()
	_save_inventory_to_serialization()
	print("✅ Recarga das Penas de Azazel concluída!")

# ========== PENA DE AZAZEL NA GRADE (espelho do slot) ==========
# Com a pena equipada, a grade guarda O MESMO dicionário do slot de consumível
# (não uma cópia). Usar, apagar ou recarregar a pena muda os dois lugares juntos.

func _find_feather_slot() -> int:
	for _s in _inventory_data:
		if CollectablePotion.is_feather(_inventory_data[_s]):
			return _s
	return -1

func _add_feather(item: Dictionary) -> void:
	var _equipped: Dictionary = global.ui_equipments._equipments_inventory.get("consumable", {})
	if CollectablePotion.is_feather(_equipped):
		# Já equipada: soma os usos (equip_item junta as penas)
		global.ui_equipments.equip_item(item)
	else:
		var _s: int = _find_feather_slot()
		if _s != -1:
			# Pena desequipada na grade: junta os usos e equipa
			var _merged: Dictionary = _inventory_data[_s].duplicate()
			_merged["amount"] = int(_merged.get("amount", 0)) + int(item.get("amount", 1))
			global.ui_equipments.equip_item(_merged)
		else:
			global.ui_equipments.equip_item(item)
	sync_feather_mirror()
	_save_inventory_to_serialization()

func sync_feather_mirror() -> void:
	"""Garante 1 pena na grade apontando para a pena equipada (mesmo dicionário)."""
	if not global.ui_equipments or not global.ui_inventory:
		return
	var _equipped: Dictionary = global.ui_equipments._equipments_inventory.get("consumable", {})
	if not CollectablePotion.is_feather(_equipped):
		return
	var _target: int = -1
	for _s in _INVENTORY_SIZE:
		if not CollectablePotion.is_feather(_inventory_data[_s]):
			continue
		if _target == -1:
			_target = _s
		else:
			# Pena repetida na grade (save antigo): fica só uma
			_inventory_data[_s] = {}
			global.ui_inventory.update_slot(_s, {})
	if _target == -1:
		for _s in _INVENTORY_SIZE:
			if _inventory_data[_s].is_empty():
				_target = _s
				break
	if _target == -1:
		print("	⚠️ Grade cheia: Pena de Azazel não coube na grade")
		return
	_inventory_data[_target] = _equipped
	global.ui_inventory.update_slot(_target, _equipped)
	if global.ui_inventory.has_method("refresh_equipped_marks"):
		global.ui_inventory.refresh_equipped_marks()

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
