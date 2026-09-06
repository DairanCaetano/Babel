extends Collectables
class_name CollectableAncientArmor

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Equipments/ancient_armor.png"
@export var ability_title: String = "Armadura Ancestral"
@export_multiline var ability_description: String = "Uma armadura forjada pelos antigos. Aumenta a defesa e protege contra ataques poderosos."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "ancient_armor_equipment"

	_body.collect_item({
		"name": tr("ITEM_ANCIENT_ARMOR_NAME"),
		"path": "res://sprites/Equipments/ancient_armor.png",
		"type": "armor",
		"description": tr("ITEM_ANCIENT_ARMOR_DESC"),
		"value": 20,
		"spawn_probability": 0.5,
		"amount_to_drop": 1,
		"attributes": { "defense": 5 }
	}, true)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_ANCIENT_ARMOR_NAME"),
		"description": tr("ITEM_ANCIENT_ARMOR_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	print("🛡️ Armadura Ancestral coletada e equipada!")
	_show_ability_display(ability_data)
