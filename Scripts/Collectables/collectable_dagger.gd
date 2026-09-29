extends Collectables
class_name CollectableDagger

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Weapons/Babel_Armas_Adaga_Pixel Art_v02.png"
@export var skill_title: String = "Adaga de Bronze"
@export_multiline var skill_description: String = "Uma adaga leve, perfeita para arremessos. Dizem que nas mãos dos mestres malabaristas ela nunca tocava o chão."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "dagger_subweapon"
	
	serialization.game_data["has_dagger"] = true
	
	_body.collect_item({
		"key": "ITEM_DAGGER_NAME",
		"name": tr("ITEM_DAGGER_NAME"),
		"path": "res://sprites/Weapons/Babel_Armas_Adaga_Pixel Art_v01.png",
		"type": "weapon",
		"description": tr("ITEM_DAGGER_DESC"),
		"value": 15,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)
	
	_body.update_dagger_state(true)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_DAGGER_NAME"),
		"description": tr("ITEM_DAGGER_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("🗡️ Adaga de Bronze coletada e equipada!")
	
	_show_skill_display(skill_display_data)
