extends Collectables
class_name CollectableGabrielBlessing

# ========== BÊNÇÃO DE GAVRI'EL ==========
# Libera o 5º slot (sagrado) para sempre. Mostra o aviso de item novo como
# os outros equipamentos, mas NÃO vai para o inventário.
#
# ⚠️ Cada instância colocada no mapa precisa de um collectible_id ÚNICO.

@export_group("Bênção")
@export var item_key: String = "ITEM_GABRIEL_BLESSING"

@export_group("Skill Display")
@export_file("*.png") var skill_icon_path: String = ""

func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		push_warning("⚠️ Bênção de Gavri'el sem collectible_id definido: ", name)
	
	serialization.game_data["sacred_slot_unlocked"] = true
	if global.ui_equipments:
		global.ui_equipments.set_sacred_slot_unlocked(true)
	
	var name_key: String = item_key + "_NAME"
	var desc_key: String = item_key + "_DESC"
	var skill_display_data = {
		"id": collectible_id,
		"title": tr(name_key),
		"description": tr(desc_key),
		"icon_path": skill_icon_path
	}
	
	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []
	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()
	
	print("✨ Bênção de Gavri'el: slot sagrado liberado")
	_show_skill_display(skill_display_data)
