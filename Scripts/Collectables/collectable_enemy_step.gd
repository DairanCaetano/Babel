extends Collectables
class_name CollectableEnemyStep

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/UI/MENU_1/ABILITIES ICONS/Babel_GUI_Enemy_Step_Icons_v01.png"
@export var ability_title: String = "Impulso no inimigo"
@export_multiline var ability_description: String = "Pule em cima do inimigo para realizar um impulso e alcançar áreas mais altas."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "enemy_step_ability"

	serialization.game_data["has_enemy_step"] = true
	_body._skills.update_enemy_step_state(true)

	var skill_data = {
		"name": "Enemy Step",
		"path": "res://sprites/Items/Skills_Enemy_Step.png",
		"type": "skill",
		"description": tr("ITEM_ENEMY_STEP_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_ENEMY_STEP_NAME"),
		"description": tr("ITEM_ENEMY_STEP_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_ENEMY_STEP_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_ENEMY_STEP_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_ENEMY_STEP_2_TOLA")}
		]
	}

	print("✅ Enemy Step desbloqueado!")
	_show_ability_display(ability_data)
