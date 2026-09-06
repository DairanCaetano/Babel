extends Collectables
class_name CollectableFire

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Weapons/Babel_sub_Armas_Fogo_ICON_v01.png"
@export var ability_title: String = "Bálsamo Ígneo"
@export_multiline var ability_description: String = "Poder de fogo ancestral."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "fire_subweapon"

	serialization.game_data["has_fire"] = true

	_body.collect_item({
		"key": "ITEM_FIRE_NAME",
		"name": tr("ITEM_FIRE_NAME"),
		"path": "res://sprites/Weapons/Babel_sub_Armas_Fogo_ICON_v01.png",
		"type": "weapon",
		"description": tr("ITEM_FIRE_DESC"),
		"value": 50,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_FIRE_NAME"),
		"description": tr("ITEM_FIRE_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	print("🔥 Bálsamo Ígneo coletado!")
	_show_ability_display(ability_data)
