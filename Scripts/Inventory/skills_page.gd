extends Control
class_name UISkills

var _skills_inventory: Dictionary = {
	"dash": {},
	"hook": {},
	"wall_jump": {},
	"enemy_step": {},
	"speed_boost": {}
}

# ✅ Prefixo das chaves do CSV de cada slot (_NAME / _DESC)
const SKILL_KEYS: Dictionary = {
	"dash": "ITEM_DASH",
	"hook": "ITEM_HOOK",
	"wall_jump": "ITEM_WALL_JUMP",
	"enemy_step": "ITEM_ENEMY_STEP",
	"speed_boost": "ITEM_SPEED_BOOST"
}

# Nomes antigos (saves feitos antes das skills terem "key")
const LEGACY_SKILL_NAMES: Dictionary = {
	"Dash": "dash",
	"Hook": "hook",
	"Wall Jump": "wall_jump",
	"Enemy Step": "enemy_step",
	"Aceleração": "speed_boost"
}

var _current_index: int = 0
var _previous_index: int = -1
var _skill_slots: Array[Button] = []

@export_category("Objects")
@export var _dash_slot: Button
@export var _hook_slot: Button
@export var _wall_jump_slot: Button
@export var _enemy_step_slot: Button
@export var _speed_boost_slot: Button

@export_category("UI Elements")
@export var _skill_title_label: Label
@export var _skill_description_label: Label

func initialize() -> void:
	global.ui_skills = self
	print("🎮 UISkills inicializada como página do inventário")
	
	# ✅ Criar array de slots na ordem de navegação
	_skill_slots = [_dash_slot, _wall_jump_slot, _hook_slot, _enemy_step_slot, _speed_boost_slot]
	
	# ✅ Carregar habilidades salvas
	restore_skills_from_save()

func focus_current_slot() -> void:
	_update_selection(_current_index)

func _update_selection(new_index: int) -> void:
	# ✅ Desmarcar todos os slots
	for slot in _skill_slots:
		var slot_selected = slot.get_node_or_null("SlotSelected")
		if slot_selected:
			slot_selected.visible = false
	
	# ✅ Marcar o slot atual
	var current_slot = _skill_slots[new_index]
	var slot_selected = current_slot.get_node_or_null("SlotSelected")
	if slot_selected:
		slot_selected.visible = true
	
	# ✅ Atualizar texto da habilidade
	var skill_data = _get_skill_data_from_slot(current_slot)
	
	if skill_data.is_empty():
		_skill_title_label.text = ""  # ← VAZIO ao invés de "---"
		_skill_description_label.text = ""  # ← VAZIO ao invés de mensagem
	else:
		# ✅ Texto sempre vem do CSV pelo tipo do slot (funciona em qualquer idioma e em saves antigos)
		var slot_type: String = _get_slot_type(current_slot)
		if SKILL_KEYS.has(slot_type):
			_skill_title_label.text = tr(SKILL_KEYS[slot_type] + "_NAME")
			_skill_description_label.text = tr(SKILL_KEYS[slot_type] + "_DESC")
		else:
			_skill_title_label.text = tr(skill_data.get("name", "???"))
			_skill_description_label.text = tr(skill_data.get("description", ""))
	
	_current_index = new_index

func _get_slot_type(slot: Button) -> String:
	match slot:
		_dash_slot:
			return "dash"
		_hook_slot:
			return "hook"
		_wall_jump_slot:
			return "wall_jump"
		_enemy_step_slot:
			return "enemy_step"
		_speed_boost_slot:
			return "speed_boost"
	return ""

func _get_slot_type_for_skill(skill_data: Dictionary) -> String:
	"""Descobre o slot da skill pela "key"; se não tiver, tenta nomes antigos/traduzidos"""
	var key: String = skill_data.get("key", "")
	var skill_name: String = skill_data.get("name", "")
	for slot_type in SKILL_KEYS:
		if key == SKILL_KEYS[slot_type] + "_NAME":
			return slot_type
	if LEGACY_SKILL_NAMES.has(skill_name):
		return LEGACY_SKILL_NAMES[skill_name]
	for slot_type in SKILL_KEYS:
		if skill_name == tr(SKILL_KEYS[slot_type] + "_NAME"):
			return slot_type
	return ""

func _get_skill_data_from_slot(slot: Button) -> Dictionary:
	"""Retorna os dados da skill do slot"""
	match slot:
		_dash_slot:
			return _skills_inventory["dash"]
		_hook_slot:
			return _skills_inventory["hook"]
		_wall_jump_slot:
			return _skills_inventory["wall_jump"]
		_enemy_step_slot:
			return _skills_inventory["enemy_step"]
		_speed_boost_slot:
			return _skills_inventory["speed_boost"]
	return {}

func _process(_delta: float) -> void:
	if not visible:
		return
	
	var moved: bool = false
	
	if Input.is_action_just_pressed("move_left"):
		_current_index -= 1
		if _current_index < 0:
			_current_index = _skill_slots.size() - 1
		moved = true
		
	elif Input.is_action_just_pressed("move_right"):
		_current_index += 1
		if _current_index >= _skill_slots.size():
			_current_index = 0
		moved = true
		
	elif Input.is_action_just_pressed("move_up"):
		_current_index -= 2
		if _current_index < 0:
			_current_index = _skill_slots.size() + _current_index
		moved = true
		
	elif Input.is_action_just_pressed("move_down"):
		_current_index += 2
		if _current_index >= _skill_slots.size():
			_current_index = _current_index - _skill_slots.size()
		moved = true
	
	# ✅ TOCAR SOM DE NAVEGAÇÃO
	if moved and _previous_index != _current_index:
		if global.ui_inventory:
			global.ui_inventory.play_navigation_audio()
		_previous_index = _current_index
		_update_selection(_current_index)

# ✅ HELPER FUNCTION: Pega a TextureRect de item de qualquer slot
func _get_item_texture(_slot: Button) -> TextureRect:
	return _slot.get_node("SlotTexture/ItemTexture")

func equip_skill(_skill_data: Dictionary) -> void:
	"""Equipa uma skill no slot correspondente"""
	
	# ✅ BLOQUEAR DURANTE LOAD
	if global.inventory and global.inventory._is_loading_save:
		print("  ⏸️ UISkills: Bloqueado durante load")
		return
	
	var _skill_copy: Dictionary = _skill_data.duplicate()
	var _skill_name: String = _skill_copy["name"]
	var _target_slot: Button = null
	var _slot_type: String = ""
	
	# ✅ DETERMINAR O SLOT CORRETO PELA "key" DA SKILL
	_slot_type = _get_slot_type_for_skill(_skill_copy)
	match _slot_type:
		"dash":
			_target_slot = _dash_slot
		"hook":
			_target_slot = _hook_slot
		"wall_jump":
			_target_slot = _wall_jump_slot
		"enemy_step":
			_target_slot = _enemy_step_slot
		"speed_boost":
			_target_slot = _speed_boost_slot



	if _target_slot == null:
		print("❌ Skill não reconhecida: ", _skill_name)
		return
	
	# ✅ ADICIONAR SKILL AO INVENTÁRIO
	_skills_inventory[_slot_type] = _skill_copy
	
	# ✅ ATUALIZAR VISUAL DO SLOT
	_get_item_texture(_target_slot).texture = load(_skill_copy["path"])
	print("  ✅ Sprite carregado para ", _skill_name, ": ", _skill_copy["path"])
	
	# ✅ SALVAR NO SISTEMA DE SERIALIZAÇÃO
	_save_skills_to_serialization()
	
	print("✅ Skill equipada: ", _skill_name, " no slot ", _slot_type)

func _save_skills_to_serialization() -> void:
	"""Serializa _skills_inventory no formato esperado pelo save"""
	serialization.game_data["skills"] = {
			"dash": _skills_inventory["dash"],
			"hook": _skills_inventory["hook"],
			"wall_jump": _skills_inventory["wall_jump"],
			"enemy_step": _skills_inventory["enemy_step"],
			"speed_boost": _skills_inventory["speed_boost"]
		}
	serialization.save_data()
	print("  💾 Skills salvas no sistema")

func restore_skills_from_save() -> void:
	"""Restaura as skills do save"""
	
	if not serialization.game_data.has("skills"):
		print("  ⚠️ Nenhuma skill salva encontrada")
		return
	
	var saved_skills = serialization.game_data["skills"]
	
	print("  ✓ Restaurando skills na SkillsPage...")
	
	# ✅ Restaurar Dash
	if not saved_skills["dash"].is_empty():
		var dash_data = saved_skills["dash"]
		_skills_inventory["dash"] = dash_data
		_get_item_texture(_dash_slot).texture = load(dash_data["path"])
		print("    - Restaurando dash: ", dash_data["name"])
	
	# ✅ Restaurar Hook
	if not saved_skills["hook"].is_empty():
		var hook_data = saved_skills["hook"]
		_skills_inventory["hook"] = hook_data
		_get_item_texture(_hook_slot).texture = load(hook_data["path"])
		print("    - Restaurando hook: ", hook_data["name"])
	
	# ✅ Restaurar Wall Jump
	if not saved_skills["wall_jump"].is_empty():
		var wall_jump_data = saved_skills["wall_jump"]
		_skills_inventory["wall_jump"] = wall_jump_data
		_get_item_texture(_wall_jump_slot).texture = load(wall_jump_data["path"])
		print("    - Restaurando wall_jump: ", wall_jump_data["name"])
	
	# ✅ Restaurar Enemy Step
	if not saved_skills["enemy_step"].is_empty():
		var enemy_step_data = saved_skills["enemy_step"]
		_skills_inventory["enemy_step"] = enemy_step_data
		_get_item_texture(_enemy_step_slot).texture = load(enemy_step_data["path"])
		print("    - Restaurando enemy_step: ", enemy_step_data["name"])
	
	if not saved_skills.get("speed_boost", {}).is_empty():
		var speed_boost_data = saved_skills["speed_boost"]
		_skills_inventory["speed_boost"] = speed_boost_data
		_get_item_texture(_speed_boost_slot).texture = load(speed_boost_data["path"])
		print("    - Restaurando speed_boost: ", speed_boost_data["name"])
	
	print("  ✓ Skills restauradas na SkillsPage!")
