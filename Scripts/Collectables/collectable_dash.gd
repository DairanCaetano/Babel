extends Collectables
class_name CollectableDash

@export var _animation_player: AnimationPlayer

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Items/Skills_Dash.png"
@export var ability_title: String = "Dash"
@export_multiline var ability_description: String = "Botas ancestrais que permitem avançar rapidamente enquanto corre."

func _ready() -> void:
	if collectible_id != "" and _is_already_collected():
		queue_free()
		return

	add_to_group("collectible")

	if _animation_player:
		_animation_player.play("float")

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "dash_ability"

	serialization.game_data["has_dash"] = true
	_body._skills.update_dash_state(true)

	var skill_data = {
		"name": tr("ITEM_DASH_NAME"),
		"path": "res://sprites/Items/Skills_Dash.png",
		"type": "skill",
		"description": tr("ITEM_DASH_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_DASH_NAME"),
		"description": tr("ITEM_DASH_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "ability_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_DASH_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_DASH_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_DASH_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_DASH_3_AZAZEL")}
		]
	}

	print("✅ Dash desbloqueado!")
	_show_ability_display(ability_data)
