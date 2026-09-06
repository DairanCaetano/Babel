extends Collectables
class_name CollectablePotion

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Items/health_potion.png"
@export var ability_title: String = "Águas de Cura"
@export_multiline var ability_description: String = "Águas sagradas que recuperam o corpo e o espírito. Aumenta a capacidade máxima de vida."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "max_health_potion"

	_body.collect_item({
		"key": "ITEM_POTION_NAME",
		"name": tr("ITEM_POTION_NAME"),
		"path": "res://sprites/Items/health_potion.png",
		"path_empty": "res://sprites/Items/empty_health_potion.png",
		"type": "consumable",
		"description": tr("ITEM_POTION_DESC"),
		"value": 70,
		"spawn_probability": 1.0,
		"amount_to_drop": 1,
		"is_max_potion": true
	}, true)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_POTION_NAME"),
		"description": tr("ITEM_POTION_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_POTION_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_POTION_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_POTION_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_POTION_3_AZAZEL")}
		]
	}

	print("✅ Águas de Cura coletadas e equipadas!")
	_show_ability_display(ability_data)
