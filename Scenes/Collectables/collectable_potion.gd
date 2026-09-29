extends Collectables
class_name CollectablePotion

# ========== PENA DE AZAZEL ==========
# Fragmentos do poder de Azazel espalhados pela Torre.
# Cada pena coletada aumenta em 1 o número máximo de curas.
# As curas são recarregadas ao descansar com Azazel no save point.
#
# ✅ ÚNICO lugar onde os sprites da pena são definidos.
# UIEquipments e CharacterInventory leem estas constantes.
const ICON_FULL_PATH: String = "res://sprites/Items/Azazel_feather.png"
const ICON_EMPTY_PATH: String = "res://sprites/Items/Azazel_feather_Empty.png"

# ✅ Chaves do CSV (nunca usar tr() em campos de identificação)
const KEY_NAME: String = "ITEM_POTION_NAME"
const KEY_EMPTY: String = "ITEM_POTION_EMPTY"
const KEY_DESC: String = "ITEM_POTION_DESC"

const HEAL_VALUE: int = 70

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "max_health_potion"

	# ✅ Cada pena nova aumenta o máximo de curas em 1
	var new_max: int = int(serialization.game_data.get("max_potions", 0)) + 1
	serialization.game_data["max_potions"] = new_max

	_body.collect_item({
		"key": KEY_NAME,
		"name": tr(KEY_NAME),
		"path": ICON_FULL_PATH,
		"path_full": ICON_FULL_PATH,
		"path_empty": ICON_EMPTY_PATH,
		"type": "consumable",
		"description": KEY_DESC,
		"value": HEAL_VALUE,
		"spawn_probability": 1.0,
		"amount_to_drop": 1,
		"is_max_potion": true
	}, true)

	# ✅ Guardar CHAVES (não texto traduzido) — o display chama tr() na hora de mostrar
	var skill_display_data = {
		"id": collectible_id,
		"title": KEY_NAME,
		"description": KEY_DESC,
		"icon_path": ICON_FULL_PATH
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_POTION_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_POTION_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_POTION_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_POTION_3_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_POTION_4_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_POTION_5_AZAZEL")}
		]
	}

	print("🪶 Pena de Azazel coletada! Máximo de curas: ", new_max)
	_show_skill_display(skill_display_data)


# ========== HELPERS ESTÁTICOS (usados por outros scripts) ==========
static func is_feather(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if item.get("is_max_potion", false):
		return true
	var key: String = item.get("key", "")
	return key == KEY_NAME or key == KEY_EMPTY

static func is_empty_feather(item: Dictionary) -> bool:
	return is_feather(item) and item.get("key", "") == KEY_EMPTY

static func full_path(item: Dictionary) -> String:
	return item.get("path_full", ICON_FULL_PATH)

static func empty_path(item: Dictionary) -> String:
	return item.get("path_empty", ICON_EMPTY_PATH)

static func migrate(item: Dictionary) -> Dictionary:
	"""Atualiza itens de saves antigos (Águas de Cura) para os sprites/textos atuais"""
	var d: Dictionary = item.duplicate()
	d["is_max_potion"] = true
	d["path_full"] = ICON_FULL_PATH
	d["path_empty"] = ICON_EMPTY_PATH
	d["description"] = KEY_DESC
	if is_empty_feather(d):
		d["name"] = TranslationServer.translate(KEY_EMPTY)
		d["path"] = ICON_EMPTY_PATH
	else:
		d["key"] = KEY_NAME
		d["name"] = TranslationServer.translate(KEY_NAME)
		d["path"] = ICON_FULL_PATH
	return d
