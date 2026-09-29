extends Collectables
class_name CollectableAxe

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Weapons/Babel_Armas_Machado_Pixel Art_v02.png"
@export var skill_title: String = "Machado Leve"
@export_multiline var skill_description: String = "Um machado leve, forjado para arremessos."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "axe_subweapon"
	
	serialization.game_data["has_axe"] = true
	
	_body.collect_item({
		"key": "ITEM_AXE_NAME",
		"name": tr("ITEM_AXE_NAME"),
		"path": "res://sprites/Weapons/Babel_Armas_Machado_Pixel Art_v02.png",
		"type": "weapon",
		"description": tr("ITEM_AXE_DESC"),
		"value": 15,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_AXE_NAME"),
		"description": tr("ITEM_AXE_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("🪓 Machado coletado e equipado!")
	
	_show_skill_display(skill_display_data)
