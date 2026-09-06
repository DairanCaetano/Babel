extends Control
class_name UISkills

var _skills_inventory: Dictionary = {
	"dash": {},
	"hook": {},
	"wall_jump": {},
	"enemy_step": {}
}

@export_category("Objects")
@export var _dash_slot: Button
@export var _hook_slot: Button
@export var _wall_jump_slot: Button
@export var _enemy_step_slot: Button

func _ready() -> void:
	global.ui_skills = self
	print("🎮 UISkills inicializado")

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
	
	# ✅ DETERMINAR O SLOT CORRETO BASEADO NO NOME
	match _skill_name:
		"Dash":
			_target_slot = _dash_slot
			_slot_type = "dash"
		"Hook":
			_target_slot = _hook_slot
			_slot_type = "hook"
		"Wall Jump":
			_target_slot = _wall_jump_slot
			_slot_type = "wall_jump"
		"Enemy Step":
			_target_slot = _enemy_step_slot
			_slot_type = "enemy_step"
	
	if _target_slot == null:
		print("❌ Skill não reconhecida: ", _skill_name)
		return
	
	# ✅ ADICIONAR SKILL AO INVENTÁRIO
	_skills_inventory[_slot_type] = _skill_copy
	
	# ✅ ATUALIZAR VISUAL DO SLOT (usando helper function)
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
		"enemy_step": _skills_inventory["enemy_step"]
	}
	serialization.save_data()
	print("  💾 Skills salvas no sistema")

func restore_skills_from_save() -> void:
	"""Restaura as skills do save (chamado pelo serialization.apply_loaded_data())"""
	
	if not serialization.game_data.has("skills"):
		print("  ⚠️ Nenhuma skill salva encontrada")
		return
	
	var saved_skills = serialization.game_data["skills"]
	
	print("  ✓ Restaurando skills...")
	
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
	
	print("  ✓ Skills restauradas!")
