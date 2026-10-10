extends Collectables
class_name CollectableEagleDagger

# ========== ADAGA DA ÁGUIA (equipamento — slot offhand) ==========
# Enquanto equipada, todo acerto do ataque corpo a corpo do Tola gera um
# segundo golpe com 1/3 do dano (ver CharacterAttackArea._try_echo_hit).
# Sub-armas NÃO são afetadas.

@export_group("Skill Display")
@export_file("*.png") var skill_icon_path: String = "res://sprites/Equipments/Adaga_da_Águia_Item.png"

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableEagleDagger sem collectible_id definido: ", name)
	
	_body.collect_item({
		"key": "ITEM_EAGLE_DAGGER_NAME",
		"name": tr("ITEM_EAGLE_DAGGER_NAME"),
		"path": skill_icon_path,
		"type": "offhand",
		"description": tr("ITEM_EAGLE_DAGGER_DESC"),
		"value": 30,
		"spawn_probability": 1.0,
		"amount_to_drop": 1,
		"attributes": { "echo_hit": 1 }
	}, true)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_EAGLE_DAGGER_NAME"),
		"description": tr("ITEM_EAGLE_DAGGER_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("🦅 Adaga da Águia coletada e equipada!")
	_show_skill_display(skill_display_data)
