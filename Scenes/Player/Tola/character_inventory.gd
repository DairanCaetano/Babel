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

func _update_subweapon_flags() -> void:
	"""Atualiza as flags de sub-armas baseado no inventário + equipamentos"""
	var has_axe = false
	var has_spear = false
	var has_chakram = false
	var has_fire = false
	
	for slot in _inventory_data.values():
		if slot.is_empty():
			continue
		
		match slot.get("name", ""):
			"Machado Leve":  # ← JÁ ATUALIZADO
				has_axe = true
			"Lança de Arremesso":  # ← JÁ ATUALIZADO
				has_spear = true
			"Chakram":  # ← MUDOU
				has_chakram = true
			"Fire Power":
				has_fire = true
	
	if global.ui_equipments:
		var equipped = global.ui_equipments._equipments_inventory
		
		for slot_type in ["weapon", "armor", "offhand", "consumable"]:
			if equipped.has(slot_type) and not equipped[slot_type].is_empty():
				match equipped[slot_type].get("name", ""):
					"Machado Leve":  # ← JÁ ATUALIZADO
						has_axe = true
					"Lança de Arremesso":  # ← JÁ ATUALIZADO
						has_spear = true
					"Chakram":  # ← MUDOU
						has_chakram = true
					"Fire Power":
						has_fire = true
	
	serialization.game_data["has_axe"] = has_axe
	serialization.game_data["has_spear"] = has_spear
	serialization.game_data["has_chakram"] = has_chakram
	serialization.game_data["has_fire"] = has_fire

func _sync_subweapon_state(_item: Dictionary) -> void:
	"""Sincroniza estado da sub-arma quando coletada/equipada"""
	if not global.character or not global.character.has_node("CharacterSubweapon"):
		print("⚠️ CharacterSubweapon não encontrado - sincronização ignorada")
		return
	
	var subweapon = global.character.get_node("CharacterSubweapon")
	
	match _item["name"]:
		"Machado Leve":  # ← JÁ ATUALIZADO
			subweapon.update_axe_state(true)
			print("🪓 Axe sincronizado com CharacterSubweapon!")
			
		"Lança de Arremesso":  # ← JÁ ATUALIZADO
			subweapon.update_spear_state(true)
			print("🗡️ Spear sincronizado com CharacterSubweapon!")
			
		"Chakram":  # ← MUDOU
			subweapon.update_chakram_state(true)
			print("🌀 Chakram sincronizado com CharacterSubweapon!")
			
		"Fire Power":
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
				if _item_copy["name"].contains("Health"):
					if _equiped_item_data["name"].contains("Health"):
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

# ✅ ADICIONAR NO FINAL DO ARQUIVO
func refill_max_potions() -> void:
	"""Recarrega todas as poções máximas ao interagir com save point"""
	print("🔄 Recarregando Águas de Cura...")
	
	var max_potions = serialization.game_data.get("max_potions", 0)
	
	# ✅ 1. RECARREGAR NO INVENTÁRIO
	for _slot in _inventory_data:
		var item = _inventory_data[_slot]
		if item.is_empty():
			continue
		
		if item.get("is_max_potion", false):
			# ✅ Detectar max_potions se ainda não foi salvo
			if max_potions == 0:
				max_potions = item.get("amount_to_drop", 1)
				serialization.game_data["max_potions"] = max_potions
			
			item["amount"] = max_potions
			
			# ✅ Se estava vazia, restaurar nome e sprite
			if item["name"] == "Águas de Cura (Vazia)":
				item["name"] = "Águas de Cura"
				item["path"] = "res://sprites/Items/health_potion.png"
			
			global.ui_inventory.update_slot(_slot, item)
			print("	✓ Águas de Cura recarregadas no inventário (slot ", _slot, ")")
	
	# ✅ 2. RECARREGAR SE ESTIVER EQUIPADA
	if global.ui_equipments:
		var equipped = global.ui_equipments._equipments_inventory.get("consumable", {})
		
		if not equipped.is_empty():
			var is_max_potion = equipped.get("is_max_potion", false)
			
			# ✅ Também aceitar nome "Águas de Cura (Vazia)" como indicador
			var potion_name = equipped.get("name", "")
			if potion_name == "Águas de Cura" or potion_name == "Águas de Cura (Vazia)":
				is_max_potion = true
			
			if is_max_potion:
				# ✅ Detectar max_potions se ainda não foi salvo
				if max_potions == 0:
					max_potions = equipped.get("amount_to_drop", 1)
					serialization.game_data["max_potions"] = max_potions
				
				# ✅ Restaurar dados
				equipped["amount"] = max_potions
				equipped["name"] = "Águas de Cura"
				equipped["path"] = "res://sprites/Items/health_potion.png"
				
				# ✅ Atualizar UI
				var consumable_slot = global.ui_equipments._consumable_slot
				if consumable_slot:
					global.ui_equipments._get_item_texture(consumable_slot).texture = load(
						"res://sprites/Items/health_potion.png"
					)
					global.ui_equipments._get_amount_label(consumable_slot).text = str(max_potions)
				
				# ✅ Atualizar serialização
				serialization.game_data["current_potions"] = max_potions
				
				print("	✓ Águas de Cura equipadas recarregadas")
	
	_save_inventory_to_serialization()
	print("✅ Recarga de Águas de Cura concluída!")

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
