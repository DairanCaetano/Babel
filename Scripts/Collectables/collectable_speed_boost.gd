extends Collectables
class_name CollectableSpeedBoost

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/UI/MENU_1/SKILLS ICONS/GUI_Skills_Run_fast_Icon.png"
@export var skill_title: String = "Aceleração"
@export_multiline var skill_description: String = "Seu corpo está mais leve e mais ágil permitindo que se mova a altas velocidades."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "speed_boost_skill"

	serialization.game_data["has_speed_boost"] = true
	_body._skills.update_speed_boost_state(true)

	var skill_data = {
		"key": "ITEM_SPEED_BOOST_NAME",
		"name": tr("ITEM_SPEED_BOOST_NAME"),
		"path": "res://sprites/Items/Skills_Speed_Boost.png",
		"type": "skill",
		"description": tr("ITEM_SPEED_BOOST_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_SPEED_BOOST_NAME"),
		"description": tr("ITEM_SPEED_BOOST_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_SPEED_BOOST_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_SPEED_BOOST_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_SPEED_BOOST_2_TOLA")}
		]
	}

	print("✅ Speed Boost desbloqueado!")
	_show_skill_display(skill_display_data)
