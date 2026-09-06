extends Node

# Signals específicos para eventos importantes
signal boss_defeated(boss_id: String)
signal final_boss_defeated()

# Configuração de bosses especiais
const FINAL_BOSS_ID = "baal_berith"

func _ready():
	print("✅ BossEventManager inicializado")

func register_boss_defeat(boss_id: String) -> void:
	"""Registra a derrota de um boss"""
	boss_defeated.emit(boss_id)
	
	# Se for o boss final, emitir signal especial
	if boss_id == FINAL_BOSS_ID:
		final_boss_defeated.emit()
	
	print("🎯 Boss derrotado: ", boss_id)

func is_boss_defeated(boss_id: String) -> bool:
	"""Verifica se um boss específico foi derrotado"""
	if not serialization.game_data.has("defeated_bosses"):
		return false
	
	return boss_id in serialization.game_data["defeated_bosses"]

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
