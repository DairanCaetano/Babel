extends Collectables
class_name CollectableChakram

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Weapons/Babel_Armas_Chakram_Icon_Pixel Art_v01.png"
@export var skill_title: String = "Chakram"
@export_multiline var skill_description: String = "Arma de arremesso comum no sul da Ásia. Pode interagir com paredes e ser reposicionada."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "chakram_subweapon"

	serialization.game_data["has_chakram"] = true

	_body.collect_item({
		"key": "ITEM_CHAKRAM_NAME",
		"name": tr("ITEM_CHAKRAM_NAME"),
		"path": "res://sprites/Weapons/Babel_Armas_Chakram_Icon_Pixel Art_v01.png",
		"type": "weapon",
		"description": tr("ITEM_CHAKRAM_DESC"),
		"value": 15,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_CHAKRAM_NAME"),
		"description": tr("ITEM_CHAKRAM_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	print("⭕ Chakram coletado e equipado!")
	_show_skill_display(skill_display_data)
