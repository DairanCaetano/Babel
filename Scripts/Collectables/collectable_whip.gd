extends Collectables
class_name CollectableWhip

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Weapons/Babel_sub_Armas_Whip_ICON_v01.png"
@export var skill_title: String = "Chicote Antigo"
@export_multiline var skill_description: String = "Um chicote antigo que parece ser uma relíquia de família. A arma perfeita para caçar monstros."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "whip_subweapon"
	
	serialization.game_data["has_whip"] = true
	
	_body.collect_item({
		"key": "ITEM_WHIP_NAME",
		"name": tr("ITEM_WHIP_NAME"),
		"path": "res://sprites/Weapons/Babel_sub_Armas_Whip_ICON_v01.png",
		"type": "weapon",
		"description": tr("ITEM_WHIP_DESC"),
		"value": 15,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_WHIP_NAME"),
		"description": tr("ITEM_WHIP_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("🪢 Chicote Antigo coletado e equipado!")
	
	_show_skill_display(skill_display_data)
