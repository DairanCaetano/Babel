extends Area2D
class_name CharacterAttackArea

@export_category("Variables")
@export var _attack_damage: int = 5

@export_category("Objects")
@export var _entity: BaseCharacter
@export var _character_texture: CharacterTexture



# ✅ SISTEMA DE PROTEÇÃO CONTRA HITS DUPLICADOS
var _hit_entities: Array = []
var _current_attack_id: int = 0

func _ready() -> void:
	add_to_group("player_attack")

# ✅ CHAMAR ISSO NO INÍCIO DE CADA ATAQUE
func start_new_attack() -> void:
	print("🗡️ start_new_attack | id: ", _current_attack_id, " | hit_entities tinha: ", _hit_entities.size())
	_hit_entities.clear()
	_current_attack_id += 1

func _on_body_entered(_body) -> void:
	if _body in _hit_entities:
		return
	if _body == _entity:
		return
	_hit_entities.append(_body)
	if _entity and _entity._audio:
		_entity._audio.play_attack_hit_object()

func _on_area_entered(_area: Area2D) -> void:
	print("⚔️ area_entered: ", _area.name, " | já na lista: ", _area in _hit_entities, " | lista size: ", _hit_entities.size())
	if _area in _hit_entities:
		return
	# ✅ OBJETOS DESTRUTÍVEIS
	if _area.is_in_group("destructible_objects"):
		_hit_entities.append(_area)
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn", 
			Vector2(36, 0), global_position, _character_texture.flip_h
		)
		if _entity and _entity._audio:
			_entity._audio.play_attack_hit_object()
		ControllerVibration.vibrate_light()
		return
	# ✅ HURTBOX DO INIMIGO
	var enemy = _area.get_parent()
	if not enemy.has_method("update_health"):
		_hit_entities.append(_area)
		if _entity and _entity._audio:
			_entity._audio.play_attack_hit_object()
		return
	if enemy in _hit_entities:  # ✅ LINHA NOVA
		return
	_hit_entities.append(_area)
	_hit_entities.append(enemy)  # ✅ LINHA NOVA
	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn", 
		Vector2(36, 0), global_position, _character_texture.flip_h
	)
	if _entity and _entity._audio:
		_entity._audio.play_attack_hit()
	enemy.update_health(
		_attack_damage + _entity.get_additional_attack(), 
		_entity
	)
	ControllerVibration.vibrate_light()

func get_damaged() -> int:
	return _attack_damage
