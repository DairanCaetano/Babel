extends Collectables
class_name CollectableStrength

# ========== FRAGMENTO DE FORÇA ==========
# Fragmentos da força do próprio Tola, perdidos pela torre (3 no total).
# Cada um aumenta PERMANENTEMENTE a força do Tola. Todas as armas
# escalam com essa força (ver BaseCharacter.scale_damage()).
# ⚠️ Cada fragmento colocado numa fase precisa de um Collectible Id ÚNICO
#    (ex.: strength_fragment_1, _2, _3), senão ele reaparece ao recarregar.

const ITEM_GLOW := preload("res://Scenes/FX/item_glow.tscn")

@export_group("Skill Display")
@export_file("*.png") var skill_icon_path: String = "" # sprite do fragmento: clique na pastinha no Inspector pra escolher
@export_group("Attack Bonus")
@export var bonus_amount: int = 5
@export_group("Custom Effect")
@export var custom_effect_path: String = ""

func _ready() -> void:
	super._ready()
	
	if collectible_id != "" and collectible_id in serialization.game_data["collected_items"]:
		return
	
	if skill_icon_path == "":
		push_warning("⚠️ CollectableStrength sem skill_icon_path: o fragmento fica invisível (" + name + ")")
		return
	
	var glow: Node2D = ITEM_GLOW.instantiate()
	add_child(glow)
	glow.setup(load(skill_icon_path))

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ CollectableStrength sem collectible_id definido: ", name)
	
	serialization.game_data["bonus_attack_total"] = serialization.game_data.get("bonus_attack_total", 0) + bonus_amount
	
	if _body.has_node("Stats"):
		var stats = _body.get_node("Stats")
		stats.increase_attack(bonus_amount)
	
	var skill_display_data = {
		"id": collectible_id,
		"title": tr("ITEM_STRENGTH_NAME"),
		"description": tr("ITEM_STRENGTH_DESC"),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	serialization.game_data["collected_skills"].append(skill_display_data)
	
	serialization.save_data()
	
	print("⚔️ Fragmento de Força coletado: +", bonus_amount, " de ataque! (ID: ", collectible_id, ")")
	
	_spawn_rainbow_pulse_on_player()
	_spawn_custom_collect_effect(custom_effect_path)
	_show_stat_boost_popup(tr("STAT_BOOST_ATTACK"))

func _spawn_rainbow_pulse_on_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	
	if player == null:
		push_warning("⚠️ Nenhum player encontrado no grupo 'player'")
		return
	
	RainbowPulse.spawn(player.global_position, get_tree().current_scene, player)
	
	if player.has_method("trigger_rainbow_shine"):
		player.trigger_rainbow_shine(1.0)
