extends Collectables
class_name CollectableEnemyStep

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/UI/MENU_1/SKILLS ICONS/Babel_GUI_Enemy_Step_Icons_v01.png"
@export var skill_title: String = "Impulso no inimigo"
@export_multiline var skill_description: String = "Pule em cima do inimigo para realizar um impulso e alcançar áreas mais altas."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "enemy_step_skill"

	serialization.game_data["has_enemy_step"] = true
	_body._skills.update_enemy_step_state(true)

	var skill_data = {
		"key": "ITEM_ENEMY_STEP_NAME",
		"name": tr("ITEM_ENEMY_STEP_NAME"),
		"path": "res://sprites/Items/Skills_Enemy_Step.png",
		"type": "skill",
		"description": tr("ITEM_ENEMY_STEP_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_ENEMY_STEP_NAME"),
		"description": tr("ITEM_ENEMY_STEP_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_ENEMY_STEP_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_ENEMY_STEP_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_ENEMY_STEP_2_TOLA")}
		]
	}

	print("✅ Enemy Step desbloqueado!")
	_show_skill_display(skill_display_data)
