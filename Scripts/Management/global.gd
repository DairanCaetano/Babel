extends Node
class_name Global

var character = null
var inventory: CharacterInventory = null
var ui_inventory: UIInventory = null
var ui_equipments: UIEquipments = null
var ui_bars: BarContainer = null
var current_scene_path: String
var active_platform: Node2D = null

# ✅ MANTER para compatibilidade (não será mais usada diretamente)
var ui_skills: UISkills = null

# ✅ Sistema de save/load
var should_load_save: bool = false

# ✅ NOVO: Sistema de persistência de objetos destruídos
var destroyed_objects: Dictionary = {}
var defeated_bosses: Array = []

# ===== ADICIONAR NO Global.gd =====

# ✅ NOVO: Sistema de Moedas
var currencies: Dictionary = {
	"shards": 0  # Total de fragmentos (small + medium convertidos)
}

# Signal para atualizar UI
signal currency_changed(currency_type: String, new_amount: int)

# ===== FUNÇÕES DE MOEDA =====

func add_currency(currency_type: String, amount: int) -> void:
	"""Adiciona moeda e notifica a UI"""
	if currency_type in currencies:
		currencies[currency_type] += amount
		currency_changed.emit(currency_type, currencies[currency_type])
		print("💰 +", amount, " ", currency_type, " | Total: ", currencies[currency_type])

func remove_currency(currency_type: String, amount: int) -> bool:
	"""Remove moeda se houver saldo suficiente"""
	if currency_type in currencies and currencies[currency_type] >= amount:
		currencies[currency_type] -= amount
		currency_changed.emit(currency_type, currencies[currency_type])
		print("💸 -", amount, " ", currency_type, " | Total: ", currencies[currency_type])
		return true
	else:
		print("❌ Moeda insuficiente! Tem: ", currencies.get(currency_type, 0), " | Precisa: ", amount)
		return false

func get_currency(currency_type: String) -> int:
	"""Retorna quantidade de moeda"""
	return currencies.get(currency_type, 0)

func reset_currencies() -> void:
	"""Reseta todas as moedas (New Game)"""
	for key in currencies.keys():
		currencies[key] = 0
		currency_changed.emit(key, 0)
	print("🔄 Moedas resetadas")

# ===== FUNÇÕES EXISTENTES =====
func register_new_platform(new_platform: Node2D) -> void:
	if is_instance_valid(active_platform):
		active_platform.queue_free()
	
	active_platform = new_platform

func spawn_effect(
	_path: String, _offset: Vector2,
	_initial_position: Vector2, _is_flipped: bool
) -> void:
	
	var _effect: BaseEffect = load(_path).instantiate()
	
	var ajusted_offset = _offset
	if _is_flipped:
		ajusted_offset.x = -_offset.x
	
	_effect.global_position = _initial_position + ajusted_offset
	_effect.flip_h = _is_flipped
	
	get_tree().root.call_deferred("add_child", _effect)

# ===== SISTEMA DE TRANSIÇÃO =====
signal level_transition_requested(target_level: String, spawn_point: String)

func request_level_transition(target_level: String, spawn_point: String) -> void:
	"""Solicita uma transição de level (chamado por LevelTransition)"""
	level_transition_requested.emit(target_level, spawn_point)

# ===== ✅ NOVO: SISTEMA DE PERSISTÊNCIA DE OBJETOS DESTRUÍDOS =====
func register_destroyed_object(object_id: String) -> void:
	var level_id = _get_current_level_id()
	
	if not destroyed_objects.has(level_id):
		destroyed_objects[level_id] = []
	
	if not destroyed_objects[level_id].has(object_id):
		destroyed_objects[level_id].append(object_id)
		print("🔨 Objeto destruído registrado: ", object_id, " no level: ", level_id)

func is_object_destroyed(object_id: String) -> bool:
	var level_id = _get_current_level_id()
	
	if not destroyed_objects.has(level_id):
		return false
	
	return destroyed_objects[level_id].has(object_id)

func clear_destroyed_objects_in_level(level_id: String) -> void:
	if destroyed_objects.has(level_id):
		destroyed_objects.erase(level_id)
		print("🔄 Objetos destruídos do level ", level_id, " foram resetados")

func _get_current_level_id() -> String:
	if current_scene_path != "":
		return current_scene_path.get_file().get_basename()
	return "unknown"

# ===== ✅ NOVO: SISTEMA DE CHEFES DERROTADOS =====
func register_boss_defeated(boss_id: String) -> void:
	if not defeated_bosses.has(boss_id):
		defeated_bosses.append(boss_id)
		print("👑 Chefe derrotado: ", boss_id)

func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.has(boss_id)

func reset_all_bosses() -> void:
	defeated_bosses.clear()
	print("🔄 Lista de chefes derrotados foi resetada")

# ===== ✅ NOVO: FUNÇÕES DE RESET GERAL =====
func reset_all_persistence() -> void:
	destroyed_objects.clear()
	defeated_bosses.clear()
	print("🔄 Toda persistência foi resetada (New Game)")
