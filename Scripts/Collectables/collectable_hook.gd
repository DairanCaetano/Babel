extends Collectables
class_name CollectableHook

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Items/Skills_Hook.png"
@export var ability_title: String = "Garra Mística"
@export_multiline var ability_description: String = "Uma luva mística que dispara uma garra para alcançar lugares distantes."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "hook_ability"

	serialization.game_data["has_hook"] = true
	_body._skills.update_hook_state(true)

	var skill_data = {
		"name": tr("ITEM_HOOK_NAME"),
		"path": "res://sprites/Items/Skills_Hook.png",
		"type": "skill",
		"description": tr("ITEM_HOOK_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_HOOK_NAME"),
		"description": tr("ITEM_HOOK_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_HOOK_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_HOOK_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_HOOK_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_HOOK_3_AZAZEL")}
		]
	}

	print("✅ Hook desbloqueado!")
	_show_ability_display(ability_data)
