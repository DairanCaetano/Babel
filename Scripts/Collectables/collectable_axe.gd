extends Collectables
class_name CollectableAxe

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Weapons/Babel_Armas_Machado_Pixel Art_v02.png"
@export var ability_title: String = "Machado Leve"
@export_multiline var ability_description: String = "Um machado leve, forjado para arremessos."

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "axe_subweapon"
	
	serialization.game_data["has_axe"] = true
	
	_body.collect_item({
		"key": "ITEM_AXE_NAME",
		"name": tr("ITEM_AXE_NAME"),
		"path": "res://sprites/Weapons/Babel_Armas_Machado_Pixel Art_v02.png",
		"type": "weapon",
		"description": tr("ITEM_AXE_DESC"),
		"value": 15,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, true)
	
	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_AXE_NAME"),
		"description": tr("ITEM_AXE_DESC"),
		"icon_path": ability_icon_path
	}
	
	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []
	
	serialization.game_data["collected_abilities"].append(ability_data)
	serialization.save_data()
	
	print("🪓 Machado coletado e equipado!")
	
	_show_ability_display(ability_data)
