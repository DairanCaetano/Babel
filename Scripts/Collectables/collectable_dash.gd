extends Collectables
class_name CollectableDash

@export var _animation_player: AnimationPlayer

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Items/Skills_Dash.png"
@export var skill_title: String = "Esquiva"
@export_multiline var skill_description: String = "Seu corpo recobrou a velocidade de outros tempos. Permite avançar rapidamente enquanto corre."

func _ready() -> void:
	if collectible_id != "" and _is_already_collected():
		queue_free()
		return

	add_to_group("collectible")

	if _animation_player:
		_animation_player.play("float")

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "dash_skill"

	serialization.game_data["has_dash"] = true
	_body._skills.update_dash_state(true)

	var skill_data = {
		"key": "ITEM_DASH_NAME",
		"name": tr("ITEM_DASH_NAME"),
		"path": "res://sprites/Items/Skills_Dash.png",
		"type": "skill",
		"description": tr("ITEM_DASH_DESC")
	}
	if global.ui_inventory:
		global.ui_inventory.equip_skill(skill_data)

	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_DASH_NAME"),
		"description": tr("ITEM_DASH_DESC"),
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	post_dialog_data = {
		"dialog_type": "skill_followup",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_DASH_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_DASH_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_DASH_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_DASH_3_AZAZEL")}
		]
	}

	print("✅ Dash desbloqueado!")
	_show_skill_display(skill_display_data)
