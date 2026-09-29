extends Collectables
class_name CollectableWallJump

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/UI/MENU_1/SKILLS ICONS/Babel_GUI_Wall_Jump_Icons_v01.png"
@export var skill_title: String = "Pulo na parede"
@export_multiline var skill_description: String = "Ao pular na parede você agora pode dar um impulso para realizar mais um pulo."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "wall_jump_skill"
	
	serialization.game_data["has_wall_jump"] = true
	_body._skills.update_wall_jump_state(true)
	
	var skill_data = {
		"key": "ITEM_WALL_JUMP_NAME",
		"name": tr("ITEM_WALL_JUMP_NAME"),
		"path": "res://sprites/Items/Skills_Wall_Jump.png",
		"type": "skill",
		"description": tr("ITEM_WALL_JUMP_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_WALL_JUMP_NAME"),
		"description": tr("ITEM_WALL_JUMP_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("✅ Wall Jump desbloqueado!")
	
	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_WALL_JUMP_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_WALL_JUMP_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_3_AZAZEL")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_4_AZAZEL")}
		]
	}
	
	_show_skill_display(skill_display_data)
