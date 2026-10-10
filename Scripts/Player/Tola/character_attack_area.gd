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
	var enemy = global.get_damage_target(_area)
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
	var _damage: int = _entity.scale_damage(_attack_damage)
	enemy.update_health(_damage, _entity)
	# Ponto exato onde o 1º impacto nasceu (mesmo cálculo do spawn_effect acima)
	var _first_impact: Vector2 = global_position + Vector2(-36 if _character_texture.flip_h else 36, 0)
	_try_echo_hit(enemy, _damage, _first_impact)
	ControllerVibration.vibrate_light()

# ========== ADAGA DA ÁGUIA: GOLPE-ECO ==========
# Com a adaga equipada, todo acerto do ataque corpo a corpo gera um segundo
# golpe no MESMO inimigo, pouco depois, com 1/3 do dano do primeiro.
# (Não depende de colisão: não erra por causa do knockback. Sub-armas não usam isto.)
@export_category("Echo Hit (Adaga da Águia)")
## Tempo entre o 1º golpe e o eco (s). Maior = mais distinto do primeiro impacto.
@export var echo_hit_delay: float = 0.2
@export var echo_hit_ratio: float = 1.0 / 3.0
## FX próprio do eco (Hit_impact_v02)
@export_file("*.tscn") var echo_hit_fx: String = "res://Scenes/FX/hit_echo_effect.tscn"
## Deslocamento do FX do eco em relação ao 1º impacto (y positivo = mais baixo;
## x espelha com a direção do Tola)
@export var echo_hit_fx_offset: Vector2 = Vector2(6, 10)

func _try_echo_hit(enemy: Node, first_damage: int, first_impact_pos: Vector2) -> void:
	if not _entity:
		return
	var _echo_attr: int = _entity._additional_attributes.get("echo_hit", 0)
	var _offhand_key: String = ""
	if global.ui_equipments:
		_offhand_key = global.ui_equipments._equipments_inventory.get("offhand", {}).get("key", "(vazio)")
	print("🦅 [ECO] acerto em ", enemy.name, " | dano 1º golpe: ", first_damage, " | echo_hit: ", _echo_attr, " | offhand: ", _offhand_key)
	if _echo_attr <= 0:
		print("🦅 [ECO] cancelado: Adaga da Águia não está equipada (echo_hit = 0)")
		return
	
	var echo_damage: int = max(1, roundi(first_damage * echo_hit_ratio))
	var flipped: bool = _character_texture.flip_h if _character_texture else false
	
	await get_tree().create_timer(echo_hit_delay, false).timeout
	
	if not is_instance_valid(enemy) or not enemy.has_method("update_health"):
		print("🦅 [ECO] cancelado: inimigo não existe mais")
		return
	if "_is_alive" in enemy and not enemy._is_alive:
		print("🦅 [ECO] cancelado: inimigo já morreu")
		return
	
	print("🦅 [ECO] 2º golpe: ", echo_damage, " de dano em ", enemy.name)
	var _fx_path: String = echo_hit_fx if ResourceLoader.exists(echo_hit_fx) else "res://Scenes/FX/hit_effect.tscn"
	global.spawn_effect(_fx_path, echo_hit_fx_offset, first_impact_pos, flipped)
	if _entity and _entity._audio:
		_entity._audio.play_attack_hit()
	enemy.update_health(echo_damage, _entity)

func get_damaged() -> int:
	return _attack_damage
