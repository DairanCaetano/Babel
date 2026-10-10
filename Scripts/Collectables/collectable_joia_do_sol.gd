extends Collectables
class_name CollectableJoiaDoSol

# Coração do Sol — item de aliança com o Rá (igual ao Broto Cerimonial do Baal).
# Com ele no inventário, o Disco do Rá oferece aliança em vez da luta.
#
# Nome e descrição exibidos: se os campos abaixo ficarem vazios, usa os textos
# traduzidos ITEM_JOIA_DO_SOL_NAME / ITEM_JOIA_DO_SOL_DESC (localization/texts.csv).
# Preenchendo os campos, eles substituem a tradução.

const ITEM_KEY: String = "ITEM_JOIA_DO_SOL_NAME"
const ITEM_DESC_KEY: String = "ITEM_JOIA_DO_SOL_DESC"
const ITEM_FLAG: String = "has_joia_do_sol"

@export_group("Skill Display")
@export var skill_icon_path: String = "res://sprites/Equipments/Coração_do_sol.png"
@export var skill_title: String = ""
@export_multiline var skill_description: String = ""


func _consume(_body: BaseCharacter) -> void:
	if collectible_id == "":
		collectible_id = "joia_do_sol"

	var title: String = skill_title if skill_title != "" else tr(ITEM_KEY)
	var description: String = skill_description if skill_description != "" else tr(ITEM_DESC_KEY)

	serialization.game_data[ITEM_FLAG] = true

	_body.collect_item({
		"key": ITEM_KEY,
		"name": title,
		"path": skill_icon_path,
		"type": "key_item",
		"description": description,
		"value": 0,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, false)

	var skill_display_data = {
		"id": collectible_id,
		"title": title,
		"description": description,
		"icon_path": skill_icon_path
	}

	if not serialization.game_data.has("collected_skills"):
		serialization.game_data["collected_skills"] = []

	serialization.game_data["collected_skills"].append(skill_display_data)
	serialization.save_data()

	print("☀️ Coração do Sol coletado!")
	_show_skill_display(skill_display_data)
