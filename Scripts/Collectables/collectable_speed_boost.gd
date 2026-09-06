extends Collectables
class_name CollectableSpeedBoost

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/UI/MENU_1/ABILITIES ICONS/GUI_Abilities_Run_fast_Icon.png"
@export var ability_title: String = "Aceleração"
@export_multiline var ability_description: String = "Seu corpo está mais leve e mais ágil permitindo que se mova a altas velocidades."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "speed_boost_ability"

	serialization.game_data["has_speed_boost"] = true
	_body._skills.update_speed_boost_state(true)

	var skill_data = {
		"name": "Aceleração",
		"path": "res://sprites/Items/Skills_Speed_Boost.png",
		"type": "skill",
		"description": tr("ITEM_SPEED_BOOST_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_SPEED_BOOST_NAME"),
		"description": tr("ITEM_SPEED_BOOST_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_SPEED_BOOST_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_SPEED_BOOST_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_SPEED_BOOST_2_TOLA")}
		]
	}

	print("✅ Speed Boost desbloqueado!")
	_show_ability_display(ability_data)
