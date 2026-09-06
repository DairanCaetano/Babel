extends Node
class_name Serialization

var save_path: String = "user://save.dat"
var settings_path: String = "user://settings.dat"
var should_apply_save: bool = false

var settings_data: Dictionary = {
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"crt_filter_enabled": true,
	"window_mode": true,
	"language": "pt_BR"
}

var game_data: Dictionary = {
	"intro_played": false,
	"has_axe": false,
	"has_spear": false,
	"has_chakram": false,
	"has_fire": false,
	"has_dagger": false,
	"has_whip": false,
	"has_dash": false,
	"has_hook": false,
	"has_wall_jump": false,
	"has_enemy_step": false,
	"has_speed_boost": false,
	"position": Vector2.ZERO,
	"current_scene": "",
	"save_area_id": "",
	"inventory": [],
	"collected_items": [],
	"equipments": {},
	"skills": {
		"dash": {},
		"hook": {},
		"wall_jump": {},
		"enemy_step": {}
	},
	"destroyed_objects": {},
	"defeated_bosses": [],
	"collected_archives": [],
	"destroyed_walls": [],
	"currencies": {"shards": 0},
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"egito_intro_played": false,
	"samyaza_egito_met": false,
	"has_map": false,
	"bonus_health_total": 0,       # ← NOVO: precisa estar aqui pra sobreviver ao load_data()
	"bonus_stamina_total": 0,  
	"collected_abilities": []      # ← NOVO: corrige o mesmo bug que já afetava fogo/sandálias/poção
}



func save_data() -> void:
	"""Salva os dados no arquivo"""
	
	game_data["destroyed_objects"] = global.destroyed_objects
	game_data["defeated_bosses"] = global.defeated_bosses
	
	var _file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if _file:
		_file.store_var(game_data)
		_file.close()
		print("💾 Dados salvos com sucesso!")
		print("	- Cena atual: ", game_data.get("current_scene", "desconhecida"))
		print("	- Save Area ID: ", game_data.get("save_area_id", "nenhuma"))
		print("	- has_axe: ", game_data["has_axe"])
		print("	- has_spear: ", game_data["has_spear"])
		print("	- has_chakram: ", game_data["has_chakram"])
		print("	- has_fire: ", game_data["has_fire"])
		print("	- has_dash: ", game_data["has_dash"])
		print("	- has_hook: ", game_data["has_hook"])
		print("	- has_wall_jump: ", game_data["has_wall_jump"])
		print("	- has_enemy_step: ", game_data["has_enemy_step"])
		print("	- position: ", game_data["position"])
		print("	- inventory items: ", game_data["inventory"].size())
		print("	- collected_items: ", game_data["collected_items"].size())
		print("	- equipments: ", game_data["equipments"].keys())
		print("	- skills: ", game_data["skills"].keys())
		print("	- destroyed_objects: ", game_data["destroyed_objects"].size(), " levels com objetos destruídos")
		print("	- defeated_bosses: ", game_data["defeated_bosses"].size(), " chefes derrotados")
		print("	- collected_archives: ", game_data["collected_archives"].size(), " arquivos coletados")
		print("	- destroyed_walls: ", game_data["destroyed_walls"].size(), " paredes destruídas")
		print("	- currencies: ", game_data["currencies"])
		print("	- has_dagger: ", game_data["has_dagger"])
		print("	- has_whip: ", game_data.get("has_whip", false))
		print("	- bonus_health_total: ", game_data.get("bonus_health_total", 0))
	else:
		push_error("Falha ao abrir arquivo para salvar: " + str(save_path))

func load_data() -> void:
	"""Carrega os dados do arquivo"""
	if FileAccess.file_exists(save_path):
		var _file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		var loaded_data = _file.get_var()
		_file.close()
		
		if loaded_data == null or not loaded_data is Dictionary:
			print("⚠️ Save corrompido - usando valores padrão")
			return
		
		for key in game_data.keys():
			if loaded_data.has(key):
				game_data[key] = loaded_data[key]
		
		# Validar inventário
		if game_data["inventory"] == null or not game_data["inventory"] is Array:
			game_data["inventory"] = []
		
		var valid_inventory = []
		for item in game_data["inventory"]:
			if item is Dictionary and item.has("index") and item.has("item"):
				valid_inventory.append(item)
		game_data["inventory"] = valid_inventory
		
		# Validar collected_items
		if game_data["collected_items"] == null or not game_data["collected_items"] is Array:
			game_data["collected_items"] = []
		
		# Validar equipments
		if game_data["equipments"] == null or not game_data["equipments"] is Dictionary:
			game_data["equipments"] = {}
		
		# Validar skills
		if game_data["skills"] == null or not game_data["skills"] is Dictionary:
			game_data["skills"] = {
				"dash": {},
				"hook": {},
				"wall_jump": {},
				"enemy_step": {}
			}
		
		# Validar destroyed_objects (sistema antigo)
		if game_data["destroyed_objects"] == null or not game_data["destroyed_objects"] is Dictionary:
			game_data["destroyed_objects"] = {}
		
		# Validar defeated_bosses
		if game_data["defeated_bosses"] == null or not game_data["defeated_bosses"] is Array:
			game_data["defeated_bosses"] = []
		
		# Validar collected_archives
		if game_data["collected_archives"] == null or not game_data["collected_archives"] is Array:
			game_data["collected_archives"] = []
		
		# Validar destroyed_walls
		if game_data["destroyed_walls"] == null or not game_data["destroyed_walls"] is Array:
			game_data["destroyed_walls"] = []
		
		# Validar save_area_id
		if not game_data.has("save_area_id") or game_data["save_area_id"] == null:
			game_data["save_area_id"] = ""
		
		if game_data["currencies"] == null or not game_data["currencies"] is Dictionary:
			game_data["currencies"] = {"shards": 0}
		
		# ← NOVO: Validar bonus_health_total
		if not game_data.has("bonus_health_total") or game_data["bonus_health_total"] == null or not game_data["bonus_health_total"] is int:
			game_data["bonus_health_total"] = 0
		
		
		# ← NOVO: Validar bonus_stamina_total
		if not game_data.has("bonus_stamina_total") or game_data["bonus_stamina_total"] == null or not game_data["bonus_stamina_total"] is int:
			game_data["bonus_stamina_total"] = 0
		
		
		# ← NOVO: Validar collected_abilities
		if not game_data.has("collected_abilities") or game_data["collected_abilities"] == null or not game_data["collected_abilities"] is Array:
			game_data["collected_abilities"] = []
		
		print("✅ Dados carregados")
		print("	- Cena salva: ", game_data.get("current_scene", "nenhuma"))
		print("	- Save Area ID: ", game_data.get("save_area_id", "nenhuma"))
		print("	- has_axe: ", game_data["has_axe"])
		print("	- has_spear: ", game_data["has_spear"])
		print("	- has_chakram: ", game_data["has_chakram"])
		print("	- has_fire: ", game_data["has_fire"])
		print("	- has_dash: ", game_data["has_dash"])
		print("	- has_hook: ", game_data["has_hook"])
		print("	- has_wall_jump: ", game_data["has_wall_jump"])
		print("	- has_enemy_step: ", game_data["has_enemy_step"])
		print("	- inventory items: ", game_data["inventory"].size())
		print("	- collected_items: ", game_data["collected_items"].size())
		print("	- destroyed_objects: ", game_data["destroyed_objects"].size(), " levels")
		print("	- defeated_bosses: ", game_data["defeated_bosses"].size(), " chefes")
		print("	- collected_archives: ", game_data["collected_archives"].size(), " arquivos")
		print("	- destroyed_walls: ", game_data["destroyed_walls"].size(), " paredes")
		print("	- currencies: ", game_data["currencies"])
		print("	- has_dagger: ", game_data["has_dagger"])
		print("	- has_whip: ", game_data.get("has_whip", false))
		print("	- bonus_health_total: ", game_data["bonus_health_total"])
	else:
		print("📁 Nenhum save encontrado")

func apply_loaded_data() -> void:
	"""Aplica os dados carregados aos sistemas do jogo"""
	
	if global.inventory:
		global.inventory._is_loading_save = true
		print("🔒 Sistema de save bloqueado durante load")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("🔄 ========== APLICANDO SAVE ==========")
	print("  📍 Posição salva: ", game_data["position"])
	print("  🏷️ Save Area ID: ", game_data.get("save_area_id", "nenhuma"))
	print("  🪓 Machado: ", game_data["has_axe"])
	print("  🔱 Lança: ", game_data["has_spear"])
	print("  ⭕ Chakram: ", game_data["has_chakram"])
	print("  🔥 Fire Power: ", game_data["has_fire"])
	print("  🏃 Dash: ", game_data["has_dash"])
	print("  🪝 Hook: ", game_data["has_hook"])
	print("  🧗 Wall Jump: ", game_data["has_wall_jump"])
	print("  👟 Enemy Step: ", game_data["has_enemy_step"])
	print("  ⚡ Speed Boost: ", game_data.get("has_speed_boost", false))
	print("  🗺️ Mapa: ", game_data.get("has_map", false))
	print("  📦 Inventário: ", game_data["inventory"].size(), " itens")
	print("  🗑️ Coletáveis pegos: ", game_data["collected_items"].size())
	print("  🔨 Objetos destruídos: ", game_data["destroyed_objects"].size(), " levels")
	print("  👑 Chefes derrotados: ", game_data["defeated_bosses"].size())
	print("  🧱 Paredes destruídas: ", game_data["destroyed_walls"].size())
	print("	- has_dagger: ", game_data["has_dagger"])
	print("	- has_whip: ", game_data.get("has_whip", false))
	print("  💗 Bônus de vida total: ", game_data.get("bonus_health_total", 0))
	
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("  ❌ Cena atual não encontrada")
		if global.inventory:
			global.inventory._is_loading_save = false
		return
	
	@warning_ignore("shadowed_global_identifier")
	var player = current_scene.get_node_or_null("Player/Character")
	if not player:
		print("  ❌ Player não encontrado")
		if global.inventory:
			global.inventory._is_loading_save = false
		return

	print("  ✓ Restaurando posição: ", game_data["position"])
	player.global_position = game_data["position"]

	await get_tree().process_frame

	if global.inventory != null and global.ui_inventory != null:
		print("  ✓ Restaurando inventário...")
		
		for slot_idx in range(24):
			global.inventory._inventory_data[slot_idx] = {}
			global.ui_inventory.update_slot(slot_idx, {})
		
		print("    - Inventário limpo")
		print("    - Restaurando ", game_data["inventory"].size(), " itens...")
		
		for item_entry in game_data["inventory"]:
			if not item_entry is Dictionary:
				continue
			if not item_entry.has("index") or not item_entry.has("item"):
				continue
			
			var slot_index = item_entry["index"]
			var item_data = item_entry["item"]
			
			if item_data.is_empty() or not item_data.has("name"):
				continue
			
			print("      → Slot ", slot_index, ": ", item_data["name"])
			global.inventory._inventory_data[slot_index] = item_data.duplicate()
			global.ui_inventory.initialize_slot(slot_index, item_data)
		
		print("  ✓ Inventário restaurado!")
	else:
		print("  ❌ global.inventory ou global.ui_inventory é NULL!")
	
	await get_tree().process_frame

	if global.ui_equipments != null:
		print("  ✓ Restaurando equipamentos na UI...")
		var eq_data: Dictionary = game_data.get("equipments", {})
		
		for slot in ["weapon", "armor", "offhand", "consumable"]:
			global.ui_equipments._equipments_inventory[slot] = {}
			
			if eq_data.has(slot) and not eq_data[slot].is_empty():
				var item = eq_data[slot]
				print("    - Restaurando ", slot, ": ", item.get("name", "sem nome"))
				
				global.ui_equipments._equipments_inventory[slot] = item.duplicate()
				
				if item.has("attributes"):
					global.ui_equipments._atributes_increased[slot] = item["attributes"].duplicate()
				
				var path = item.get("path", "")
				if path != "":
					var target_button = null
					match slot:
						"weapon":
							target_button = global.ui_equipments._weapon_slot
						"armor":
							target_button = global.ui_equipments._armor_slot
						"offhand":
							target_button = global.ui_equipments._offhand_slot
						"consumable":
							target_button = global.ui_equipments._consumable_slot
					
					if target_button:
						var tex = load(path)
						target_button.get_node("SlotTexture/ItemTexture").texture = tex
						
						if slot == "consumable" and item.has("amount"):
							var amount_label = target_button.get_node_or_null("Amount")
							if amount_label:
								if item["name"] == "Empty Health Potions":
									amount_label.text = ""
								else:
									amount_label.text = str(item["amount"])
									global.ui_equipments._has_consumable = true
						
						print("      ✓ Textura carregada")
		
		if global.character and is_instance_valid(global.character):
			global.character._reset_bonus_attributes()
			global.character._increase_bonus_attributes(global.ui_equipments._atributes_increased)
			print("  ✓ Atributos de equipamentos aplicados ao character")
			
			# ← NOVO: recalcula o bônus de vida de equipamento após restaurar do save
			# (esse fluxo não passa por equip_item()/emit do sinal equipment_changed)
			if player.has_node("Stats"):
				player.get_node("Stats").recalculate_equipment_health_bonus()
				print("  ✓ Bônus de vida de equipamento recalculado após load")
		
		print("  ✓ Equipamentos restaurados")
	else:
		print("  ❌ global.ui_equipments é NULL!")
	
	var subweapon = player.get_node_or_null("CharacterSubweapon")
	if subweapon:
		print("  ✓ Restaurando flags das sub-armas no CharacterSubweapon...")
		
		if game_data["has_axe"]:
			subweapon._has_axe = true
			if player.has_method("update_axe_state"):
				player.update_axe_state(true)
			print("      ✓ Machado ativado")
		else:
			subweapon._has_axe = false
		
		if game_data["has_spear"]:
			subweapon._has_spear = true
			if player.has_method("update_spear_state"):
				player.update_spear_state(true)
			print("      ✓ Lança ativada")
		else:
			subweapon._has_spear = false
		
		if game_data["has_chakram"]:
			subweapon._has_chakram = true
			if player.has_method("update_chakram_state"):
				player.update_chakram_state(true)
			print("      ✓ Chakram ativado")
		else:
			subweapon._has_chakram = false
		
		if game_data["has_dagger"]:
			subweapon._has_dagger = true
			if player.has_method("update_dagger_state"):
				player.update_dagger_state(true)
			print("      ✓ Adaga ativada")
		else:
			subweapon._has_dagger = false
		
		if game_data.get("has_whip", false):
			print("      ✓ Chicote ativado")
		
		print("  ✓ Flags das sub-armas restauradas!")

	if game_data.get("has_map", false):
		if player.has_method("update_map_state"):
			player.update_map_state(true)
		print("      ✓ Mapa ativado")
	
	var char_skills = player.get_node_or_null("CharacterSkills")
	if char_skills:
		print("  ✓ Restaurando flags das skills no CharacterSkills...")
		
		if game_data["has_dash"]:
			char_skills._has_dash_skill = true
			print("      ✓ Dash ativado")
		else:
			char_skills._has_dash_skill = false
		
		if game_data["has_hook"]:
			char_skills._has_hook_skill = true
			print("      ✓ Hook ativado")
		else:
			char_skills._has_hook_skill = false
		
		if game_data["has_wall_jump"]:
			char_skills._has_wall_jump_skill = true
			print("      ✓ Wall Jump ativado")
		else:
			char_skills._has_wall_jump_skill = false
		
		if game_data["has_enemy_step"]:
			char_skills._has_enemy_step_skill = true
			print("      ✓ Enemy Step ativado")
		else:
			char_skills._has_enemy_step_skill = false
		
		if game_data.get("has_speed_boost", false):
			char_skills._has_speed_boost_skill = true
			print("      ✓ Speed Boost ativado")
		else:
			char_skills._has_speed_boost_skill = false
		
		print("  ✓ Flags das skills restauradas!")
	else:
		print("  ❌ CharacterSkills não encontrado!")
	
	await get_tree().process_frame
	
	if global.ui_skills != null:
		print("  ✓ Restaurando skills na UI...")
		global.ui_skills.restore_skills_from_save()
	else:
		print("  ❌ global.ui_skills é NULL!")
	
	if game_data.has("collected_items"):
		var collected = game_data["collected_items"]
		print("  ✓ Sistema de coletáveis: ", collected.size(), " itens já foram coletados")
		print("    (Remoção automática pelo _ready() dos coletáveis)")
	
	await get_tree().process_frame
	
	if game_data.has("destroyed_objects"):
		global.destroyed_objects = game_data["destroyed_objects"]
		print("  ✓ Objetos destruídos restaurados: ", global.destroyed_objects.size(), " levels")
	
	if game_data.has("defeated_bosses"):
		global.defeated_bosses = game_data["defeated_bosses"]
		print("  ✓ Chefes derrotados restaurados: ", global.defeated_bosses.size())
	
	if game_data.has("destroyed_walls"):
		print("  ✓ Sistema de paredes: ", game_data["destroyed_walls"].size(), " paredes já foram destruídas")
		print("    (Remoção automática pelo _ready() das paredes)")
	
	await get_tree().process_frame

	if game_data.has("currencies"):
		global.currencies = game_data["currencies"].duplicate()
		print("  ✓ Moedas restauradas:")
		for currency_type in global.currencies.keys():
			var amount = global.currencies[currency_type]
			print("    - ", currency_type, ": ", amount)
			global.currency_changed.emit(currency_type, amount)
	
	if global.inventory:
		global.inventory._is_loading_save = false
		print("  🔓 Sistema de save desbloqueado")
	
	# ✅ Restaurar vida do player (já reflete max_health atualizado, pois PlayerStats._ready()
	# já leu bonus_health_total antes desse ponto do fluxo)
	restore_player_health()
	
	await get_tree().process_frame
	TransitionScreen.fade_out_after_load()
	
	print("✅ ========== SAVE APLICADO COM SUCESSO ==========")


func reset_to_new_game() -> void:
	"""Reseta todos os dados para um novo jogo"""
	game_data = {
		"intro_played": false,
		"has_axe": false,
		"has_spear": false,
		"has_chakram": false,
		"has_fire": false,
		"has_dagger": false,
		"has_whip": false,
		"has_dash": false,
		"has_hook": false,
		"has_wall_jump": false,
		"has_enemy_step": false,
		"has_speed_boost": false,
		"position": Vector2.ZERO,
		"current_scene": "",
		"save_area_id": "",
		"spawn_point": "default",
		"egito_intro_played": false,
		"samyaza_egito_met": false,
		"has_map": false,
		"inventory": [],
		"collected_items": [],
		"collected_archives": [],
		"destroyed_walls": [],
		"destroyed_objects": {},
		"defeated_bosses": [],
		"currencies": {"shards": 0},
		"bonus_health_total": 0,       # ← NOVO
		"bonus_stamina_total": 0,  
		"collected_abilities": [],     # ← NOVO
		"equipments": {
			"weapon": {},
			"armor": {},
			"offhand": {},
			"consumable": {}
		},
		"skills": {
			"dash": {},
			"hook": {},
			"wall_jump": {},
			"enemy_step": {},
			"speed_boost": {}
		}
	}
	
	global.currencies = {"shards": 0}
	global.currency_changed.emit("shards", 0)
	
	print("🔄 Game data resetado para novo jogo")

func _save_currencies() -> void:
	"""Salva moedas no save (chamada pela SaveArea)"""
	game_data["currencies"] = global.currencies.duplicate()
	print("💰 Moedas salvas: ", game_data["currencies"])

func restore_player_health() -> void:
	"""Restaura a vida do player para o máximo ao carregar o save"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	var player = current_scene.get_node_or_null("Player/Character")
	if not player:
		return
	
	var stats = player.get_node_or_null("Stats")
	if not stats:
		return
	
	stats.current_health = stats.max_health
	
	if global.ui_bars:
		global.ui_bars.update_bar("HealthBar", stats.max_health)
	
	print("  ✓ Vida restaurada para o máximo: ", stats.max_health)

func save_settings() -> void:
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_var(settings_data)
		file.close()

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			for key in data.keys():
				settings_data[key] = data[key]
