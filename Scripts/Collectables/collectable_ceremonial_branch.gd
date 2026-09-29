extends Collectables
class_name CollectableCeremonialBranch

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Equipments/ramo_ritualistico.png"
@export var skill_title: String = "Broto Cerimonial"
@export_multiline var skill_description: String = "Uma erva rara capaz de acalmar a fúria de um deus."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "ceremonial_branch"

	serialization.game_data["has_ceremonial_branch"] = true

	_body.collect_item({
		"key": "ITEM_CEREMONIAL_BRANCH_NAME",
		"name": tr("ITEM_CEREMONIAL_BRANCH_NAME"),
		"path": "res://sprites/Equipments/ramo_ritualistico.png",
		"type": "key_item",
		"description": tr("ITEM_CEREMONIAL_BRANCH_DESC"),
		"value": 0,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, false)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_CEREMONIAL_BRANCH_NAME"),
		"description": tr("ITEM_CEREMONIAL_BRANCH_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_BRANCH_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_BRANCH_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_BRANCH_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_BRANCH_3_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_BRANCH_4_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_BRANCH_5_AZAZEL")}
		]
	}

	print("🌿 Ceremonial Branch coletado!")
	_show_skill_display(skill_display_data)
