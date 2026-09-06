extends Collectables
class_name CollectableLife

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Items/hpmax_icon.png"
@export var ability_title: String = "Cálice da Vitalidade"
@export_multiline var ability_description: String = "Um cálice ancestral que expande permanentemente sua capacidade vital."

@export_group("Health Bonus")
@export var bonus_amount: int = 20

@export_group("Custom Effect")
@export var custom_effect_path: String = ""  # ← NOVO: preencha depois com sua partícula/shader própria

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableHPMax sem collectible_id definido: ", name)
	
	serialization.game_data["bonus_health_total"] = serialization.game_data.get("bonus_health_total", 0) + bonus_amount
	
	if _body.has_node("Stats"):
		var stats = _body.get_node("Stats")
		stats.increase_max_health(bonus_amount)
	
	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_HPMAX_NAME"),
		"description": tr("ITEM_HPMAX_DESC"),
		"icon_path": ability_icon_path
	}
	
	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []
	serialization.game_data["collected_abilities"].append(ability_data)
	
	serialization.save_data()
	
	print("💗 Vida máxima aumentada em +", bonus_amount, "! (ID: ", collectible_id, ")")
	
	_spawn_custom_collect_effect(custom_effect_path)
	_show_stat_boost_popup(tr("STAT_BOOST_HEALTH"))
