extends Collectables
class_name CollectableSandals

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Equipments/sandals.png"
@export var ability_title: String = "Sandálias Aladas"
@export_multiline var ability_description: String = "Sandálias leves e encantadas. Aumentam significativamente a velocidade de movimento."

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

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_SANDALS_NAME"),
		"description": tr("ITEM_SANDALS_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	print("👟 Sandálias Aladas coletadas e equipadas!")
	_show_ability_display(ability_data)
