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
	"""Salva a morte do boss (global + save) e avisa portas/spawners"""
	# Tudo centralizado no BossEventManager. Antes o nome ia só pro game_data e o
	# save_data() sobrescrevia a lista com global.defeated_bosses → num jogo novo
	# a morte do chefe se perdia.
	BossEventManager.register_boss_defeat(boss_id)
	print("✅ Boss derrotado salvo: ", boss_id)

func is_already_defeated() -> bool:
	"""Verifica se o boss já foi derrotado anteriormente"""
	return BossEventManager.is_boss_defeated(boss_id)
