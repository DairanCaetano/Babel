extends Collectables
class_name CollectableSpear

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Weapons/Babel_sub_Armas_Lança_ICON_v02.png"
@export var skill_title: String = "Lança de Arremesso"
@export_multiline var skill_description: String = "Uma lança longa de arremesso. É capaz de sustentar o peso de um homem."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "spear_subweapon"

	serialization.game_data["has_spear"] = true

	_body.collect_item({
		"key": "ITEM_SPEAR_NAME",
		"name": tr("ITEM_SPEAR_NAME"),
		"path": "res://sprites/Weapons/Babel_sub_Armas_Lança_ICON_v02.png",
		"type": "weapon",
		"description": tr("ITEM_SPEAR_DESC"),
		"value": 20,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_SPEAR_NAME"),
		"description": tr("ITEM_SPEAR_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	print("🔱 Lança coletada e equipada!")
	_show_skill_display(skill_display_data)
