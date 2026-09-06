extends Collectables
class_name CollectableStaminaMax

@export_group("Ability Display")
@export var ability_icon_path: String = "res://sprites/Items/staminamax_icon.png"
@export var ability_title: String = "Fôlego Ancestral"
@export_multiline var ability_description: String = "Uma essência que expande permanentemente sua reserva de energia."

@export_group("Stamina Bonus")
@export var bonus_amount: int = 3

@export_group("Custom Effect")
@export var custom_effect_path: String = ""  # ← NOVO

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableStaminaMax sem collectible_id definido: ", name)
	
	serialization.game_data["bonus_stamina_total"] = serialization.game_data.get("bonus_stamina_total", 0) + bonus_amount
	
	if _body.has_node("Stats"):
		var stats = _body.get_node("Stats")
		stats.increase_max_stamina(bonus_amount)
	
	var ability_data = {
		"id": collectible_id,
		"title": tr("ITEM_STAMINAMAX_NAME"),
		"description": tr("ITEM_STAMINAMAX_DESC"),
		"icon_path": ability_icon_path
	}
	
	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []
	serialization.game_data["collected_abilities"].append(ability_data)
	
	serialization.save_data()
	
	print("⚡ Stamina máxima aumentada em +", bonus_amount, "! (ID: ", collectible_id, ")")
	
	_spawn_custom_collect_effect(custom_effect_path)
	_show_stat_boost_popup(tr("STAT_BOOST_STAMINA"))
