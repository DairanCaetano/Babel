extends Collectables
class_name CollectableWallJump

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/UI/MENU_1/ABILITIES ICONS/Babel_GUI_Wall_Jump_Icons_v01.png"
@export var ability_title: String = "Pulo na parede"
@export_multiline var ability_description: String = "Ao pular na parede você agora pode dar um impulso para realizar mais um pulo."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "wall_jump_ability"
	
	serialization.game_data["has_wall_jump"] = true
	_body._skills.update_wall_jump_state(true)
	
	var skill_data = {
		"name": "Wall Jump",
		"path": "res://sprites/Items/Skills_Wall_Jump.png",
		"type": "skill",
		"description": tr("ITEM_WALL_JUMP_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)
	
	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_WALL_JUMP_NAME"),
		"description": tr("ITEM_WALL_JUMP_DESC"),
		"icon_path": ability_icon_path
	}
	
	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []
	
	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()
	
	print("✅ Wall Jump desbloqueado!")
	
	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_WALL_JUMP_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_WALL_JUMP_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_3_AZAZEL")},
			{"character": "azazel", "text": tr("DIALOG_WALL_JUMP_4_AZAZEL")}
		]
	}
	
	_show_ability_display(ability_data)
