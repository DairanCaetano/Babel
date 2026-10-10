extends Collectables
class_name CollectableEquipment

# ========== EQUIPAMENTO GENÉRICO ==========
# Um único script para equipamentos que só precisam de: nome/descrição no CSV,
# slot, ícone e atributos. Cada item é uma cena (.tscn) com estes campos
# preenchidos no Inspector.
#
# item_key: prefixo das chaves do texts.csv. Ex.: "ITEM_BRONZE_SHIELD"
#   → usa ITEM_BRONZE_SHIELD_NAME e ITEM_BRONZE_SHIELD_DESC
#
# ⚠️ Cada instância colocada no mapa precisa de um collectible_id ÚNICO.

@export_group("Equipamento")
@export var item_key: String = ""
@export_enum("offhand", "armor") var equip_slot: String = "offhand"
@export var attributes: Dictionary = {}
@export var item_value: int = 30

@export_group("Skill Display")
@export_file("*.png") var skill_icon_path: String = ""

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableEquipment sem collectible_id definido: ", name)
	if item_key == "":
		push_error("❌ CollectableEquipment sem item_key: ", name)
		return

	var name_key: String = item_key + "_NAME"
	var desc_key: String = item_key + "_DESC"

	_body.collect_item({
		"key": name_key,
		"name": tr(name_key),
		"path": skill_icon_path,
		"type": equip_slot,
		"description": tr(desc_key),
		"value": item_value,
		"spawn_probability": 1.0,
		"amount_to_drop": 1,
		"attributes": attributes.duplicate()
	}, true)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr(name_key),
		"description": tr(desc_key),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	print("🎒 Equipamento coletado: ", tr(name_key), " (", equip_slot, ") ", attributes)
	_show_skill_display(skill_display_data)
