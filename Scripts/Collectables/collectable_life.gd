extends Collectables
class_name CollectableLife

const ITEM_GLOW := preload("res://Scenes/FX/item_glow.tscn")

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Items/Life_Max_2_Item.png"
@export var skill_title: String = "Cálice da Vitalidade"
@export_multiline var skill_description: String = "Um cálice ancestral que expande permanentemente sua capacidade vital."
@export_group("Health Bonus")
@export var bonus_amount: int = 20
@export_group("Custom Effect")
@export var custom_effect_path: String = ""  # ← NOVO: preencha depois com sua partícula/shader própria

func _ready() -> void:
	super._ready()
	
	if collectible_id != "" and collectible_id in serialization.game_data["collected_items"]:
		return
	
	var glow: Node2D = ITEM_GLOW.instantiate()
	add_child(glow)
	glow.setup(load(skill_icon_path))

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableHPMax sem collectible_id definido: ", name)
	
	serialization.game_data["bonus_health_total"] = serialization.game_data.get("bonus_health_total", 0) + bonus_amount
	
	if _body.has_node("Stats"):
		var stats = _body.get_node("Stats")
		stats.increase_max_health(bonus_amount)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_HPMAX_NAME"),
		"description": tr("ITEM_HPMAX_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	serialization.game_data["collected_skills"].append(skill_display_data)
	
	serialization.save_data()
	
	print("💗 Vida máxima aumentada em +", bonus_amount, "! (ID: ", collectible_id, ")")
	
	_spawn_rainbow_pulse_on_player()
	_spawn_custom_collect_effect(custom_effect_path)
	_show_stat_boost_popup(tr("STAT_BOOST_HEALTH"))

func _spawn_rainbow_pulse_on_player() -> void:
	@warning_ignore("shadowed_global_identifier")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	
	if player == null:
		push_warning("⚠️ Nenhum player encontrado no grupo 'player'")
		return
	
	RainbowPulse.spawn(player.global_position, get_tree().current_scene, player)
	
	if player.has_method("trigger_rainbow_shine"):
		player.trigger_rainbow_shine(1.0)
