extends Collectables
class_name CollectableSandals

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Equipments/sandals.png"
@export var skill_title: String = "Sandálias Aladas"
@export_multiline var skill_description: String = "Sandálias leves e encantadas. Aumentam significativamente a velocidade de movimento."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "sandals_equipment"

	_body.collect_item({
		"name": tr("ITEM_SANDALS_NAME"),
		"path": "res://sprites/Equipments/sandals.png",
		"type": "offhand",
		"description": tr("ITEM_SANDALS_DESC"),
		"value": 20,
		"spawn_probability": 0.5,
		"amount_to_drop": 1,
		"attributes": { "move_speed": 16 }
	}, true)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_SANDALS_NAME"),
		"description": tr("ITEM_SANDALS_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	print("👟 Sandálias Aladas coletadas e equipadas!")
	_show_skill_display(skill_display_data)
