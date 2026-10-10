extends Node

# Central de eventos dos chefes.
#
# Uma sala de chefe fica "resolvida" quando o chefe é DERROTADO ou quando o
# player faz ALIANÇA com ele. Portas, spawners (BerithTree, Disco do Rá) etc.
# só precisam perguntar is_boss_resolved(boss_id) e ouvir o sinal boss_resolved.
#
#   Derrota:  register_boss_defeat(boss_id)   → salva em defeated_bosses
#   Aliança:  register_boss_alliance(boss_id) → salva "<boss_id>_alliance" = true
#
# As duas funções salvam o jogo na hora e podem ser chamadas mais de uma vez.

signal boss_defeated(boss_id: String)
signal boss_alliance(boss_id: String)
signal boss_resolved(boss_id: String)   # derrota OU aliança
signal final_boss_defeated()

# Configuração de bosses especiais
const FINAL_BOSS_ID = "baal_berith"

func _ready():
	print("✅ BossEventManager inicializado")


# ========== DERROTA ==========

func register_boss_defeat(boss_id: String) -> void:
	"""Registra a derrota de um boss (global + save) e avisa portas/spawners"""
	if boss_id == "":
		return
	var already_registered: bool = is_boss_defeated(boss_id)

	# Mantém as duas listas iguais. Antes só o game_data era atualizado e o
	# save_data() sobrescrevia com global.defeated_bosses (vazio num jogo novo).
	global.register_boss_defeated(boss_id)
	if not serialization.game_data.has("defeated_bosses") or not serialization.game_data["defeated_bosses"] is Array:
		serialization.game_data["defeated_bosses"] = []
	if not boss_id in serialization.game_data["defeated_bosses"]:
		serialization.game_data["defeated_bosses"].append(boss_id)
	serialization.save_data()

	if already_registered:
		return   # chamado de novo (ex.: boss + spawner): não repete os sinais

	boss_defeated.emit(boss_id)
	boss_resolved.emit(boss_id)

	# Se for o boss final, emitir signal especial
	if boss_id == FINAL_BOSS_ID:
		final_boss_defeated.emit()

	print("🎯 Boss derrotado: ", boss_id)


func is_boss_defeated(boss_id: String) -> bool:
	"""Verifica se um boss específico foi derrotado"""
	if global.defeated_bosses.has(boss_id):
		return true
	if not serialization.game_data.has("defeated_bosses"):
		return false
	return boss_id in serialization.game_data["defeated_bosses"]


# ========== ALIANÇA ==========

func register_boss_alliance(boss_id: String) -> void:
	"""Registra a aliança com um boss (save) e avisa portas/spawners"""
	if boss_id == "":
		return
	var already_registered: bool = has_alliance(boss_id)
	serialization.game_data[alliance_key(boss_id)] = true
	serialization.save_data()
	if already_registered:
		return

	boss_alliance.emit(boss_id)
	boss_resolved.emit(boss_id)
	print("🤝 Aliança com: ", boss_id)


func has_alliance(boss_id: String) -> bool:
	return serialization.game_data.get(alliance_key(boss_id), false)


# Ex.: "baal_berith" → "baal_berith_alliance", "ra" → "ra_alliance"
func alliance_key(boss_id: String) -> String:
	return boss_id + "_alliance"


# ========== SALA RESOLVIDA ==========

func is_boss_resolved(boss_id: String) -> bool:
	"""true se o chefe foi derrotado OU se houve aliança"""
	return is_boss_defeated(boss_id) or has_alliance(boss_id)


# ========== CONSULTAS ==========

func get_defeated_bosses_count() -> int:
	"""Retorna quantos bosses foram derrotados"""
	if not serialization.game_data.has("defeated_bosses"):
		return 0

	return serialization.game_data["defeated_bosses"].size()

func get_defeated_bosses() -> Array:
	"""Retorna lista de bosses derrotados"""
	if not serialization.game_data.has("defeated_bosses"):
		return []

	return serialization.game_data["defeated_bosses"]
