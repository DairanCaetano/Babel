extends Collectables
class_name CollectableGreatAxe

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Weapons/Babel_sub_Armas_Great_Axe_ICON_v01.png"
@export var ability_title: String = "Machado de Guerra"
@export_multiline var ability_description: String = "Um machado pesado de duas mãos. Lento, mas devastador."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "great_axe_subweapon"

	serialization.game_data["has_great_axe"] = true

	_body.collect_item({
		"key": "ITEM_GREAT_AXE_NAME",
		"name": tr("ITEM_GREAT_AXE_NAME"),
		"path": ability_icon_path,
		"type": "weapon",
		"description": tr("ITEM_GREAT_AXE_DESC"),
		"value": 25,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)

	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_GREAT_AXE_NAME"),
		"description": tr("ITEM_GREAT_AXE_DESC"),
		"icon_path": ability_icon_path
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []

	# ✅ Evita duplicar a habilidade se o item for coletado de novo
	var already_has: bool = false
	for ability in serialization.game_data["collected_abilities"]:
		if ability.get("id", "") == collectible_id:
			already_has = true
			break

	if not already_has:
		serialization.game_data["collected_abilities"].append(ability_data)

	serialization.save_data()

	print("🪓 Machado de Guerra coletado e equipado!")
	_show_ability_display(ability_data)


func _on_area_exited(area: Area2D) -> void:
	pass # Replace with function body.
