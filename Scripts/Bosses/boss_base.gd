extends CharacterBody2D
class_name Boss

# Signal padrão para TODOS os bosses
signal boss_defeated(boss_id: String)

@export var boss_id: String = ""  # ID único do boss

var _is_alive: bool = true

func _ready():
	if boss_id == "":
		push_error("Boss sem ID definido! Configure o boss_id no inspector.")

func _save_boss_death() -> void:
	"""Salva a morte do boss na serialização"""
	if not serialization.game_data.has("defeated_bosses"):
		serialization.game_data["defeated_bosses"] = []
	
	if boss_id not in serialization.game_data["defeated_bosses"]:
		serialization.game_data["defeated_bosses"].append(boss_id)
		serialization.save_data()  # ← CORRIGIDO: save_data() em vez de save_game()
		print("✅ Boss derrotado salvo: ", boss_id)

func is_already_defeated() -> bool:
	"""Verifica se o boss já foi derrotado anteriormente"""
	if not serialization.game_data.has("defeated_bosses"):
		return false
	
	return boss_id in serialization.game_data["defeated_bosses"]
