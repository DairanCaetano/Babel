extends Node2D
class_name RaDisco

# Disco de Rá — equivalente à BerithTree.
# Fica na fase, rodando em loop. Quando o player entra na DetectionArea:
#   congela o player
#   → se o player tem a Joia do Sol (Coração do Sol): oferece aliança
#       Sim → aliança salva, portas somem, disco fica no idle, sequência de vitória
#       Não → luta normal
#   → luta: o disco sobe, instancia o Rá num marker da RaArena, toca a música,
#     o Rá roda a intro e o player é liberado. Durante a luta o disco segue o Rá.
#   → Rá derrotado: o disco volta para a posição inicial e fica em "Defeated",
#     depois roda a sequência de vitória da fase.
# Ao carregar a fase com a sala já resolvida, o disco já aparece no estado final
# (Defeated se o Rá morreu, Default se houve aliança) e não detecta mais o player.

const BOSS_ID: String = "ra"
const ITEM_KEY: String = "ITEM_JOIA_DO_SOL_NAME"
const ITEM_FLAG: String = "has_joia_do_sol"

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _detection_area: Area2D
@export var _detection_collision: CollisionShape2D
@export var arena: RaArena
@export var ra_scene: PackedScene

@export_category("Animações")
@export var _idle_animation: String = "Default"         # normal e depois da aliança
@export var _defeated_animation: String = "Defeated"    # depois que o Rá morre (se não existir, usa o idle)

@export_category("Spawn")
@export var _spawn_point: RaArena.Point = RaArena.Point.CENTER
@export var _rise_to_y: float = -28.0        # position.y (local) para onde o disco sobe antes de chamar o Rá
@export var _rise_duration: float = 1.0

@export_category("Seguir o Rá")
@export var _follow_offset: Vector2 = Vector2(0, -40)    # posição do disco em relação ao centro do Rá
@export var _follow_speed: float = 10.0                 # quanto maior, mais "grudado"
@export var _hide_on_teleport: bool = true
@export var _attack_6_extra_offset: Vector2 = Vector2(0, 20)   # o disco desce durante o Ataque 6 (agachado)

@export_category("Fim da luta")
@export var _return_duration: float = 1.5      # tempo voltando para a posição inicial
@export var _victory_delay: float = 1.0        # espera depois de voltar, antes da sequência de vitória
@export var _victory_sequence: bool = true     # desligue quando não for mais a demo

@export_category("Boss Music")
@export var boss_music_track: String = "boss"
@export var music_fade_duration: float = 2.0

var _ra: Ra = null
var _spawned: bool = false
var _player_entered: BaseCharacter = null
var _home_position: Vector2 = Vector2.ZERO
var _move_tween: Tween = null
var _fade_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_home_position = position

	if not _texture:
		_texture = get_node_or_null("Texture")
	if not _detection_area:
		_detection_area = get_node_or_null("DetectionArea")
	if not _detection_collision and _detection_area:
		_detection_collision = _detection_area.get_node_or_null("Collision")

	# Sala já resolvida → estado final, sem detecção
	if BossEventManager.is_boss_defeated(BOSS_ID):
		_disable_detection()
		_play(_defeated_animation)
		return
	if BossEventManager.has_alliance(BOSS_ID):
		_disable_detection()
		_play(_idle_animation)
		return

	_play(_idle_animation)

	if _detection_area:
		_detection_area.body_entered.connect(_on_detection_area_body_entered)

	# Player já dentro da área ao carregar a sala
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _detection_area and not _spawned and is_inside_tree():
		for body in _detection_area.get_overlapping_bodies():
			if body is BaseCharacter:
				_on_detection_area_body_entered(body)
				break


func _process(delta: float) -> void:
	if not _ra or not is_instance_valid(_ra):
		return
	var target: Vector2 = _ra.global_position + _follow_offset
	if _ra._texture and _ra._texture.animation in [&"Attack_6_Anticipation", &"Attack_6"]:
		target += _attack_6_extra_offset
	global_position = global_position.lerp(target, clampf(_follow_speed * delta, 0.0, 1.0))


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _spawned or not body is BaseCharacter:
		return

	_spawned = true
	_player_entered = body
	_freeze_player()
	_disable_detection()

	# Aliança: só se o player tiver a Joia do Sol
	if serialization.game_data.get(ITEM_FLAG, false):
		var accepted: bool = await BossAlliance.ask(self, "BOSS_RA_CALMED",
				"BOSS_RA_ALLIANCE_QUESTION", "BOSS_RA_YES", "BOSS_RA_NO")
		if accepted:
			_accept_alliance()
			return

	_start_fight()


# ========== ALIANÇA ==========

func _accept_alliance() -> void:
	BossAlliance.remove_item(ITEM_KEY, ITEM_FLAG)
	BossEventManager.register_boss_alliance(BOSS_ID)   # salva + some com as portas
	_play(_idle_animation)
	_unfreeze_player()
	if _victory_sequence:
		BossAlliance.trigger_victory_sequence(self)


# ========== LUTA ==========

func _start_fight() -> void:
	# Disco sobe e só então chama o Rá
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", _rise_to_y, _rise_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tween.tween_callback(_spawn_ra)


func _spawn_ra() -> void:
	if not ra_scene:
		push_error("RaDisco: ra_scene não definido!")
		_unfreeze_player()
		return

	if not arena:
		arena = get_tree().get_first_node_in_group("ra_arena") as RaArena
	if not arena:
		push_error("RaDisco: RaArena não encontrada!")
		_unfreeze_player()
		return

	_ra = ra_scene.instantiate() as Ra
	_ra.arena = arena
	get_parent().add_child(_ra)
	_ra.global_position = arena.get_point_position(_spawn_point)

	_ra.intro_finished.connect(_on_ra_intro_finished)
	_ra.boss_defeated.connect(_on_boss_defeated)
	_ra.teleport_started.connect(_on_ra_teleport_started)
	_ra.teleport_finished.connect(_on_ra_teleport_finished)

	_ra.start_intro()

	if AudioManager:
		AudioManager.play_music(boss_music_track, music_fade_duration)


func _on_ra_intro_finished() -> void:
	_unfreeze_player()


func _on_ra_teleport_started() -> void:
	if _hide_on_teleport:
		_fade_to(0.0, 0.2)


func _on_ra_teleport_finished() -> void:
	if _hide_on_teleport and _ra and is_instance_valid(_ra):
		global_position = _ra.global_position + _follow_offset
		_fade_to(1.0, 0.2)


func _on_boss_defeated(_boss_id: String) -> void:
	# O Rá já salvou a derrota (Boss._save_boss_death → BossEventManager)
	_ra = null
	_fade_to(1.0, 0.3)
	_play(_defeated_animation)

	# Volta para onde estava antes de subir
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _home_position, _return_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _victory_sequence:
		_move_tween.tween_interval(_victory_delay)
		_move_tween.tween_callback(BossAlliance.trigger_victory_sequence.bind(self))


# ========== UTIL ==========

func _fade_to(alpha: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, duration)


func _play(animation_name: String) -> void:
	if not _texture or not _texture.sprite_frames:
		return
	if _texture.sprite_frames.has_animation(animation_name):
		_texture.play(animation_name)
	elif _texture.sprite_frames.has_animation(_idle_animation):
		_texture.play(_idle_animation)


func _disable_detection() -> void:
	if _detection_collision:
		_detection_collision.set_deferred("disabled", true)
	if _detection_area:
		_detection_area.set_deferred("monitoring", false)


# --- Congelar / descongelar (mesmo esquema da BerithTree) ---

func _freeze_player() -> void:
	if _player_entered and is_instance_valid(_player_entered):
		_player_entered._is_in_cinematic = true
		_player_entered.velocity = Vector2.ZERO
		_player_entered._was_moving_last_frame = false
		if _player_entered._character_texture:
			_player_entered._character_texture._was_moving = false
			_player_entered._character_texture._is_on_action = false


func _unfreeze_player() -> void:
	if _player_entered and is_instance_valid(_player_entered):
		_player_entered._is_in_cinematic = false
