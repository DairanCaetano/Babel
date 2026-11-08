extends Boss
class_name Ra

# =====================================================================
#  RÁ — chefe estilo "jogo de luta"
# ---------------------------------------------------------------------
#  Ciclo: surge num marker da RaArena → faz 2 ou 3 ataques → Teleport
#  → surge em outro marker → novo ciclo.
#
#  Ataques:
#   1  (só nas pontas)  Antecipação → Attack_1 em loop enquanto 4 pilares
#                       atravessam a sala (lado dele, lado oposto, depois
#                       os dois juntos que se encontram no meio).
#   2→3→4 (combo)       Só com o player dentro da ComboArea.
#                       Attack_2 (FX 2) → Attack_3 (FX 3) → sobe, carrega
#                       no ar e mergulha na posição do player.
#   5  (qualquer ponto) Shoryuken. Só com o player dentro da ComboArea.
#                       No ápice fica um tempo no ar (Attack_5_Air) e depois cai.
#   6  (só nas pontas)  Carrega 1s e desliza até a ponta oposta → Teleport.
#  Fase 2 (vida <= 50%): rugido → Pássaro de Fogo (lanças, Gone, explosão,
#                       Shine). Depois de 3 ataques, 60% de chance a cada
#                       ataque; depois de 4 sem virar, vira com certeza.
#                       O dano do deslize vem da própria HurtBox (contato).
#
#  FRAMES: todos os números de frame contam a partir de 0, igual ao
#  Godot (frame 0 = primeiro frame da animação).
#
#  COLISÕES / MARKERS: posicione tudo no editor com flip_h = false (do
#  jeito que os sprites foram desenhados — ver _sprite_faces_right). No
#  _ready o script guarda essas posições e espelha sozinho quando ele vira.
# =====================================================================

signal intro_finished
signal teleport_started
signal teleport_finished

# O AnimatedSprite2D fica centralizado no Rá (0, 0). Os pés ficam ~60px abaixo
# do centro (frames de 140x120). Os markers Left/Center/Right da arena marcam
# o CENTRO do Rá; esse offset é usado onde algo precisa nascer no chão.
# Golpes que o Rá deixa na fase (FX com dano, impacto, lanças, explosão):
# somem quando ele morre.
const SPAWNED_GROUP: String = "ra_spawned"

const FEET_OFFSET_Y: float = 60.0

enum Action {
	NONE,
	INTRO,
	ROAR,
	IDLE,
	TURN,
	TELEPORT_OUT,
	TELEPORT_HIDDEN,
	TELEPORT_IN,
	ATTACK_1,
	COMBO,
	ATTACK_5,
	ATTACK_6,
	BIRD,
	DEAD,
}

enum AttackType { NONE, ATTACK_1, COMBO, ATTACK_5, ATTACK_6, BIRD, ATTACK_4 }

# Poses de colisão por animação (posição com flip_h = false + escala).
# Animações que não estão aqui usam a posição/escala do editor.
const POSE_ATTACK_4 := {
	"body": [Vector2(-5, 7), Vector2(0.7, 0.7)],
	"hurt": [Vector2(-5, 8), Vector2(0.7, 0.7)],
}
const POSE_ATTACK_6 := {
	"body": [Vector2(-5, 26), Vector2(1.0, 0.7)],
	"hurt": [Vector2(-5, 25), Vector2(1.0, 0.7)],
}
# Ataque 5 (Shoryuken): frame (contando de 0) → posição da colisão de dano
# (flip_h = false). Liga no primeiro frame da tabela e desliga no primeiro
# frame depois do último.
const ATTACK_5_HIT_FRAMES := {
	1: Vector2(-22, 37),
	2: Vector2(-22, -23),
	3: Vector2(-22, -23),
}

# Forma de pássaro (fase 2): corpo/HurtBox no centro, mais largos e baixos
const POSE_BIRD := {
	"body": [Vector2(0, 0), Vector2(2.0, 0.6)],
	"hurt": [Vector2(0, 0), Vector2(2.0, 0.6)],
}

const COLLISION_POSES := {
	"Bird_Surge": POSE_BIRD,
	"Bird_Idle": POSE_BIRD,
	"Bird_Gone": POSE_BIRD,
	"Attack_4_Charge": POSE_ATTACK_4,
	"Attack_4": POSE_ATTACK_4,
	"Attack_6_Anticipation": POSE_ATTACK_6,
	"Attack_6": POSE_ATTACK_6,
}


@export_category("Objects")
@export var arena: RaArena
@export var _texture: AnimatedSprite2D
@export var _hurtbox: Area2D
@export var _body_collision: CollisionShape2D      # "Collision" (raiz)
@export var _hurtbox_collision: CollisionShape2D   # "HurtBox/Collision"
@export var _combo_area: Area2D
@export var _attack_4_area: RaAttackArea   # corpo em chamas durante o mergulho
@export var _attack_5_area: RaAttackArea   # shoryuken
@export var _attack_2_fx_marker: Marker2D  # onde nasce o FX 2 (espelha sozinho)
@export var _attack_3_fx_marker: Marker2D  # onde nasce o FX 3 (espelha sozinho)

@export_category("Projectile Scenes")
@export var _attack_1_pillar_scene: PackedScene
@export var _attack_2_fx_scene: PackedScene
@export var _attack_3_fx_scene: PackedScene
@export var _attack_4_impact_scene: PackedScene   # opcional — instanciado onde ele toca o chão
@export var _attack_5_charge_fx_scene: PackedScene   # Scenes/FX/attack_charge_fx.tscn — nasce no frame 0 (pausa antes de subir)
@export var _attack_5_fx_scene: PackedScene      # Scenes/FX/ra_attack_5_fx.tscn — fica parado onde nasceu
@export var _attack_4_impact_offset: Vector2 = Vector2.ZERO  # posição do impacto em relação ao centro do Rá (X = à frente de onde ele olha). (0,0) = ponto zero do Rá

@export_category("Health System")
@export var _enemy_health: int = 300
@export var _phase_2_threshold: float = 0.5   # fração da vida em que começa a fase 2 (rugido + pássaro)

@export_category("Start")
@export var _auto_start: bool = false   # true = começa sozinho (pra testar sem o Disco)
@export var _intro_animation: String = "Shine"   # primeira animação (se não existir/estiver vazia, usa a Transition de trás pra frente)
@export var _start_flip_h: bool = true           # entrada da direita pra esquerda: começa com flip_h ligado

@export_category("Rugido (igual ao Baal Berith)")
@export var _roar_fx_scene: PackedScene          # Scenes/FX/Roar.tscn
@export var _roar_duration: float = 2.0
@export var _roar_audio: AudioStreamPlayer
@export var _sprite_faces_right: bool = false  # direção em que os sprites foram desenhados (flip_h = false)

@export_category("Áudio")
## Cada som vazio usa o arquivo padrão da pasta EnemiesSound (ver _SFX_DEFAULTS).
@export var _sfx_roar: AudioStream            # rugido (início e fase 2)
@export var _sfx_idle: AudioStream            # chama da fênix no Idle (tom varia)
@export var _sfx_bird_dive: AudioStream       # grito no mergulho da forma de pássaro
@export var _sfx_attack_4: AudioStream        # explosão quando o mergulho do ataque 4 toca o chão
@export var _sfx_attack_5: AudioStream        # quando o shoryuken sobe
@export var _sfx_volume_db: float = 0.0
@export var _sfx_idle_volume_db: float = -6.0
@export var _sfx_idle_pitch: Vector2 = Vector2(0.85, 1.15)
@export var _sfx_idle_fade_out: float = 0.4   # o Idle acaba antes do som: some suave

const _SFX_DEFAULTS: Dictionary = {
	"_sfx_roar": "res://Sound/SFX/EnemiesSound/Phoenix_Roar_phatphrogstudio-monster-phoenix-voice-angry-scream-cry-roar-519421.ogg",
	"_sfx_idle": "res://Sound/SFX/EnemiesSound/Phoenix_Flame_mightuser-mythical-sfx-phoenix-1hd-269469.ogg",
	"_sfx_bird_dive": "res://Sound/SFX/EnemiesSound/Phoenix_Cry_freesound_community-gryffin-cry-6995.ogg",
	"_sfx_attack_4": "res://Sound/SFX/EnemiesSound/Ra_Atk_4_FX_DSGNImpt_EXPLOSION-Eruption_HY_PC-001.ogg",
	"_sfx_attack_5": "res://Sound/SFX/EnemiesSound/Ra_Atk_5_DSGNImpt_EXPLOSION-Flare Nova_HY_PC-004.ogg",
}
var _idle_audio: AudioStreamPlayer2D = null

@export_category("Ciclo")
@export var _attacks_per_cycle_min: int = 2
@export var _attacks_per_cycle_max: int = 3
@export var _idle_time: float = 1.0          # descanso entre um ataque e outro
@export var _teleport_hidden_time: float = 0.4

@export_category("Ataque 1 - Pilares")
@export var _attack_1_first_pillar_time: float = 1.5 # o 1º pilar some depois disso andando; só então sai o 2º
@export var _attack_1_pair_delay: float = 2.0        # espera depois do 2º pilar até o par final (3º e 4º)
@export var _attack_1_pillar_speed: float = 150.0
@export var _attack_1_max_duration: float = 10.0   # segurança: encerra o ataque mesmo se algum pilar travar

@export_category("Combo - Ataques 2 e 3")
@export var _attack_2_fx_frame: int = 3   # frame do Attack_2 em que o FX 2 nasce (contando de 0)
@export var _attack_3_fx_frame: int = 3   # frame do Attack_3 em que o FX 3 nasce (contando de 0)
@export var _attack_2_to_3_delay: float = 0.75   # pausa entre o fim do Attack_2 e o início do Ataque 3

@export_category("Combo - Ataque 4")
@export var _attack_4_rise_start_frame: int = 7    # Attack_4_Anticipation: começa a subir (contando de 0)
@export var _attack_4_rise_end_frame: int = 9      # Attack_4_Anticipation: chega no ponto do ar (contando de 0)
@export var _attack_4_hover_height: float = 90.0
@export var _attack_4_charge_time: float = 0.5
@export var _attack_4_dive_speed: float = 630.0

@export_category("Ataque 5 - Shoryuken")
@export var _attack_5_windup_time: float = 0.4   # parado no frame 0 antes de subir (tempo pro player reagir)
@export var _attack_5_rise_frame: int = 2   # contando de 0
@export var _attack_5_apex_frame: int = 3   # contando de 0
@export var _attack_5_fall_frame: int = 4   # contando de 0
@export var _attack_5_air_time: float = 0.4   # tempo parado no ar (Attack_5_Air em loop) antes de cair; 0 = sem pausa
@export var _attack_5_height: float = 70.0
@export var _attack_5_forward: float = 20.0
@export var _attack_5_fx_sync: bool = true   # true = o FX troca de frame junto com o Rá (segura na pausa e no ar)

@export_category("Ataque 6 - Deslize")
@export var _attack_6_charge_time: float = 1.0
@export var _attack_6_speed: float = 260.0
@export var _attack_6_center_weight: float = 0.5   # chance do Ataque 6 fora das pontas (1 = igual aos outros, 0 = nunca)
@export var _attack_6_mini_fx_scene: PackedScene     # Scenes/FX/mini_explosion_fx.tscn — explosõezinhas durante a carga
@export var _attack_6_mini_fx_radius: float = 30.0  # raio (px) em volta do centro do Rá onde elas aparecem
@export var _attack_6_mini_fx_interval: Vector2 = Vector2(0.08, 0.2)   # intervalo aleatório entre uma e outra (mín, máx)

@export_category("Ghost Trail (Ataques 5 e 6)")
@export var _ghost_trail_scene: PackedScene          # vazio = usa Scenes/FX/ghost_trail.tscn
@export var _ghost_interval: float = 0.08           # segundos entre um rastro e outro (igual ao player)
@export var _ghost_color: Color = Color(0.3, 0.7, 1.0)   # cor do rastro (mesma da Estátua por padrão)
@export var _ghost_on_attack_5: bool = true         # shoryuken: o ataque inteiro
@export var _ghost_on_attack_6: bool = true         # deslize

@export_category("Fase 2 - Pássaro de Fogo")
@export var _spear_scene: PackedScene               # Scenes/Projectile/ra_spear.tscn
@export var _bird_explosion_scene: PackedScene      # Scenes/Projectile/ra_explosion.tscn
@export var _bird_material: ShaderMaterial          # material só da forma de pássaro (calor + blink)
@export var _bird_height: float = 100.0             # quanto acima do marker Center o pássaro surge
@export var _bird_hidden_time: float = 0.3          # tempo invisível entre a Transition e a Surge
@export var _spear_count: int = 8                   # lanças por fileira
@export var _spear_spacing: float = 70.0            # distância entre lanças da mesma fileira
@export var _spear_offset_y: float = 15.0           # centro da lança em relação ao centro do pássaro (a ponta passa só um pouco do pássaro)
@export var _spear_waves: int = 2                   # fileiras (a 2ª é deslocada meio espaço, cobrindo os vãos)
@export var _bird_attacks_between: int = 3          # depois da 1ª vez: a partir de N ataques ele pode virar pássaro
@export var _bird_chance: float = 0.6               # chance de virar pássaro em cada tentativa
@export var _bird_force_after: int = 4              # depois de N ataques sem virar, vira com certeza
@export var _spear_wave_gap: float = 0.5            # pausa entre uma fileira e outra
@export var _bird_idle_before_gone: float = 0.5     # depois que a última fileira some, espera isso e vai pra Gone
@export var _bird_gone_fall_frame: int = 3          # frame da Bird_Gone em que começa a cair (contando de 0)
@export var _bird_fall_speed: float = 500.0
@export var _bird_explosion_offset: Vector2 = Vector2(0, -70)   # posição da explosão em relação ao centro do Rá no chão
@export var _bird_land_vibration_strength: float = 1.0   # vibração forte do controle quando o pássaro bate no chão (0 = sem)
@export var _bird_land_vibration_duration: float = 0.6


var _action: Action = Action.NONE
var _action_id: int = 0
var _move_tween: Tween

var _facing: float = 1.0           # 1 = direita, -1 = esquerda
var _current_point: int = RaArena.NO_POINT
var _ground_y: float = 0.0

var _attacks_done: int = 0
var _attacks_this_cycle: int = 2
var _last_attack: AttackType = AttackType.NONE

var _player_close: bool = false
var _is_vulnerable: bool = false

var _pending_turn_callback: Callable
var _pending_turn_facing: float = 1.0

var _attack_1_alive_pillars: int = 0
var _attack_1_all_spawned: bool = false

var _roar_fx_instance: Node = null
var _roar_next: Callable = Callable()

var _max_health: int = 1
var _phase: int = 1
var _attacks_since_bird: int = 0
var _spear_wave: int = 0
var _spears_alive: int = 0

var _fired_events: Dictionary = {}
var _mirror_defaults: Dictionary = {}   # Node2D -> Vector2 (posição do editor, flip_h = false)
var _scale_defaults: Dictionary = {}    # CollisionShape2D -> Vector2 (escala do editor)
var _default_material: Material = null  # material normal do Texture (blink)
var _ghost_timer: float = 0.0
var _attack_5_fx: AnimatedSprite2D = null


# =====================================================================
#  SETUP
# =====================================================================

func _ready() -> void:
	boss_id = "ra"
	if boss_name_key == "":
		boss_name_key = "BOSS_RA_NAME"
	if boss_subtitle_key == "":
		boss_subtitle_key = "BOSS_RA_TITLE"
	# Nome curto: 2x maior que o padrão (fonte 56 / subtítulo 28)
	if title_name_scale == 0:
		title_name_scale = 4
	if title_subtitle_scale == 0:
		title_subtitle_scale = 2
	super._ready()

	if is_already_defeated():
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_PAUSABLE
	_max_health = max(_enemy_health, 1)

	_register_mirror_nodes()

	if _texture:
		_default_material = _texture.material
		_texture.animation_finished.connect(_on_animation_finished)
		_texture.frame_changed.connect(_on_frame_changed)

	if _combo_area:
		_combo_area.body_entered.connect(_on_combo_area_body_entered)
		_combo_area.body_exited.connect(_on_combo_area_body_exited)

	# Dano por contato (mesmo script do HurtBox do Baal Berith)
	if _hurtbox and _hurtbox.has_method("_on_body_entered"):
		if not _hurtbox.body_entered.is_connected(_hurtbox._on_body_entered):
			_hurtbox.body_entered.connect(_hurtbox._on_body_entered)

	_load_sfx_defaults()

	if not _ghost_trail_scene and ResourceLoader.exists("res://Scenes/FX/ghost_trail.tscn"):
		_ghost_trail_scene = load("res://Scenes/FX/ghost_trail.tscn")

	_set_vulnerable(false)

	if _auto_start:
		call_deferred("start_intro")


# =====================================================================
#  GHOST TRAIL — rastro no shoryuken (Ataque 5) e no deslize (Ataque 6)
# =====================================================================

func _process(delta: float) -> void:
	if not _ghost_trail_active():
		_ghost_timer = _ghost_interval   # o primeiro rastro sai assim que o movimento começa
		return
	_ghost_timer += delta
	if _ghost_timer >= _ghost_interval:
		_ghost_timer = 0.0
		_spawn_ghost_trail()


func _ghost_trail_active() -> bool:
	if not _is_alive or not _texture or not _ghost_trail_scene:
		return false
	var anim: StringName = _texture.animation
	if _action == Action.ATTACK_5 and _ghost_on_attack_5:
		return anim == &"Attack_5" or anim == &"Attack_5_Air"   # o ataque inteiro, qualquer frame
	if _action == Action.ATTACK_6 and _ghost_on_attack_6:
		return anim == &"Attack_6"
	return false


func _spawn_ghost_trail() -> void:
	var ghost = _ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = _texture.global_position
	ghost.global_rotation = global_rotation
	if ghost.has_method("setup"):
		ghost.setup(_texture)
	if "mat" in ghost and ghost.mat:
		ghost.mat.set_shader_parameter("colorize_color", _ghost_color)


# Guarda a posição de editor de toda CollisionShape2D e Marker2D do Rá,
# para espelhar quando ele virar (mesma ideia do _mirrored_pos da Estátua).
func _register_mirror_nodes() -> void:
	for node in find_children("*", "CollisionShape2D", true, false):
		_mirror_defaults[node] = node.position
		_scale_defaults[node] = node.scale
	for node in find_children("*", "Marker2D", true, false):
		_mirror_defaults[node] = node.position


func _find_arena() -> void:
	if not arena:
		arena = get_tree().get_first_node_in_group("ra_arena") as RaArena
	if not arena:
		push_error("Rá sem RaArena! Coloque uma RaArena na fase e ligue no inspector (ou no Disco).")


# =====================================================================
#  INTRO: Shine → Rugido → combate
# =====================================================================

func start_intro() -> void:
	_find_arena()
	if not arena:
		return

	_current_point = _nearest_point()
	global_position = arena.get_point_position(_current_point)
	_ground_y = global_position.y

	if _start_flip_h:
		_set_facing(-_drawn_dir())   # flip_h = true
	else:
		_set_facing(_dir_to_player())

	_new_action(Action.INTRO)

	if _has_frames(_intro_animation):
		_play(_intro_animation)
		# Se a animação de entrada estiver em loop, animation_finished não dispara
		if _texture.sprite_frames.get_animation_loop(_intro_animation):
			_after(_animation_length(_intro_animation), _start_roar)
	else:
		_play("Transition", true)


# Rugido: mesmo esquema do rugido inicial do Baal Berith
# (FX de rugido + tremor de câmera + vibração do controle durante _roar_duration)
# next: o que fazer quando o rugido acabar (padrão: começar o combate)
func _start_roar(next: Callable = Callable()) -> void:
	_new_action(Action.ROAR)
	_roar_next = next
	
	# 👑 Nome do chefe: só no rugido de entrada (fase 1), não no da fase 2
	if _phase == 1:
		show_title_card(_roar_duration)

	if _roar_fx_scene:
		_roar_fx_instance = _roar_fx_scene.instantiate()
		add_child(_roar_fx_instance)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(5, _roar_duration)

	ControllerVibration.vibrate_custom(0.8, 0.8, _roar_duration)

	if _roar_audio:
		_roar_audio.play()
	else:
		_play_sfx(_sfx_roar)

	_after(_roar_duration, _on_roar_done)


func _on_roar_done() -> void:
	if _roar_fx_instance and is_instance_valid(_roar_fx_instance):
		_roar_fx_instance.queue_free()
	_roar_fx_instance = null
	var next: Callable = _roar_next
	_roar_next = Callable()
	if next.is_valid():
		next.call()
	else:
		_on_intro_done()


func _on_intro_done() -> void:
	_set_vulnerable(true)
	intro_finished.emit()
	_start_cycle()
	_go_idle()


# =====================================================================
#  CICLO / ESCOLHA DE ATAQUE
# =====================================================================

func _start_cycle() -> void:
	_attacks_done = 0
	_attacks_this_cycle = randi_range(_attacks_per_cycle_min, _attacks_per_cycle_max)


func _go_idle() -> void:
	_new_action(Action.IDLE)
	_play("Idle")
	_stop_idle_sfx(0.0)
	_idle_audio = _play_sfx(_sfx_idle, _sfx_idle_pitch.x, _sfx_idle_pitch.y, _sfx_idle_volume_db)
	_after(_idle_time, _choose_next)


func _choose_next() -> void:
	if _attacks_done >= _attacks_this_cycle:
		_start_teleport()
		return

	# Fase 2: depois de _bird_attacks_between ataques, _bird_chance de virar
	# pássaro a cada escolha; depois de _bird_force_after ataques, vira com certeza
	if _phase == 2 and _attacks_since_bird >= _bird_attacks_between:
		if _attacks_since_bird >= _bird_force_after or randf() < _bird_chance:
			_attacks_since_bird = 0
			_last_attack = AttackType.BIRD
			_bird_start()
			return

	# Player perto (ComboArea): combo 2→3→4 ou Shoryuken (5)
	# Player longe, Rá numa ponta: Ataque 1 (pilares) ou 6 (deslize)
	# Player longe, Rá fora das pontas (centro ou onde o Ataque 4 caiu):
	#   Ataque 1, Ataque 4 sozinho, Shoryuken (5) ou Ataque 6 (com menos chance que nas pontas)
	var pool: Array = []
	var weights: Array = []
	if _player_close:
		pool = [AttackType.COMBO, AttackType.ATTACK_5]
		weights = [1.0, 1.0]
	elif arena.is_edge(_current_point):
		pool = [AttackType.ATTACK_1, AttackType.ATTACK_6]
		weights = [1.0, 1.0]
	else:
		pool = [AttackType.ATTACK_1, AttackType.ATTACK_4, AttackType.ATTACK_5, AttackType.ATTACK_6]
		weights = [1.0, 1.0, 1.0, _attack_6_center_weight]

	# Evita repetir o último ataque
	var last_index: int = pool.find(_last_attack)
	if last_index >= 0 and pool.size() > 1:
		pool.remove_at(last_index)
		weights.remove_at(last_index)

	var choice: AttackType = _weighted_pick(pool, weights)
	_last_attack = choice

	match choice:
		AttackType.ATTACK_1:
			_face_then(_edge_inward_dir(), _attack_1_start)
		AttackType.COMBO:
			_face_then(_dir_to_player(), _combo_start)
		AttackType.ATTACK_4:
			_face_then(_dir_to_player(), _attack_4_start)
		AttackType.ATTACK_5:
			_face_then(_dir_to_player(), _attack_5_start)
		AttackType.ATTACK_6:
			_face_then(_edge_inward_dir(), _attack_6_start)


func _weighted_pick(pool: Array, weights: Array) -> AttackType:
	var total: float = 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return pool.pick_random()
	var roll: float = randf() * total
	for i in pool.size():
		roll -= maxf(weights[i], 0.0)
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _end_attack() -> void:
	_attacks_done += 1
	if _last_attack != AttackType.BIRD:
		_attacks_since_bird += 1
	_go_idle()


# =====================================================================
#  ATAQUE 1 — PILARES
# =====================================================================

func _attack_1_start() -> void:
	_new_action(Action.ATTACK_1)
	_attack_1_alive_pillars = 0
	_attack_1_all_spawned = false
	_play("Attack_1_Anticipation")


# Os pilares saem só da METADE da sala onde o player está (RaArena.get_pillar_lane):
#   player entre PillarLeft e PillarCenter  → pilares nascem nessas duas pontas
#   player entre PillarCenter e PillarRight → pilares nascem nessas duas pontas
# A metade é escolhida de novo a cada pilar, então se o player trocar de lado
# durante o ataque, os próximos pilares já saem do lado novo.
func _attack_1_begin_pillars() -> void:
	_play("Attack_1")

	# 1º: da ponta da metade mais perto do Rá — some depois de _attack_1_first_pillar_time
	var first := _spawn_pillar_from_lane(true, -1, _attack_1_first_pillar_time)

	# 2º: da outra ponta, só quando o 1º sumir (pra não se esbarrarem)
	var id: int = _action_id
	if first:
		first.tree_exited.connect(func():
			if id == _action_id and _is_alive:
				call_deferred("_attack_1_second_pillar")
		)
	else:
		_attack_1_second_pillar()

	# Segurança
	_after(_attack_1_max_duration, _attack_1_finish)


func _attack_1_second_pillar() -> void:
	if _action != Action.ATTACK_1:
		return
	_spawn_pillar_from_lane(false, -1)

	# 3º e 4º: juntos, das duas pontas da metade — se encontram no meio e somem
	_after(_attack_1_pair_delay, func():
		var pair: int = randi()
		var lane: Array[Vector2] = arena.get_pillar_lane(_player_x())
		_spawn_pillar(lane[0], Vector2.RIGHT, pair)
		_spawn_pillar(lane[1], Vector2.LEFT, pair)
		_attack_1_all_spawned = true
		if _attack_1_alive_pillars <= 0:
			_attack_1_finish()
	)


# near_ra = true  → nasce na ponta da metade mais perto do Rá
# near_ra = false → nasce na ponta mais longe do Rá
# O pilar sempre anda em direção à outra ponta da metade.
func _spawn_pillar_from_lane(near_ra: bool, pair: int, lifetime: float = -1.0) -> Node2D:
	var lane: Array[Vector2] = arena.get_pillar_lane(_player_x())
	var left_is_near: bool = absf(lane[0].x - global_position.x) <= absf(lane[1].x - global_position.x)
	var use_left: bool = left_is_near == near_ra
	if use_left:
		return _spawn_pillar(lane[0], Vector2.RIGHT, pair, lifetime)
	return _spawn_pillar(lane[1], Vector2.LEFT, pair, lifetime)


func _player_x() -> float:
	var player := _get_player()
	if player:
		return player.global_position.x
	return arena.get_pillar_center().x


# lifetime > 0 sobrescreve o tempo andando do pilar (_lifetime_after_rise)
func _spawn_pillar(pos: Vector2, dir: Vector2, pair: int, lifetime: float = -1.0) -> Node2D:
	if not _attack_1_pillar_scene:
		push_warning("Rá: _attack_1_pillar_scene não definido")
		return null

	var pillar: Node2D = _attack_1_pillar_scene.instantiate()

	if pillar is ProjectileFirePillar:
		pillar.pair_id = pair
		if lifetime > 0.0:
			pillar._lifetime_after_rise = lifetime

	get_parent().add_child(pillar)
	pillar.global_position = pos

	if pillar.has_method("setup"):
		pillar.setup(dir, _attack_1_pillar_speed, dir.x > 0.0)

	_attack_1_alive_pillars += 1
	pillar.tree_exited.connect(_on_pillar_freed.bind(_action_id))
	return pillar


func _on_pillar_freed(owner_action_id: int) -> void:
	if owner_action_id != _action_id:
		return
	_attack_1_alive_pillars -= 1
	if _attack_1_all_spawned and _attack_1_alive_pillars <= 0:
		_attack_1_finish()


func _attack_1_finish() -> void:
	if _action != Action.ATTACK_1 or not _is_alive:
		return
	_end_attack()


# =====================================================================
#  COMBO — ATAQUES 2 → 3 → 4
# =====================================================================

func _combo_start() -> void:
	_new_action(Action.COMBO)
	_play("Attack_2_Anticipation")


# Ataque 4 sozinho (sem o 2 e o 3 antes): sobe, carrega e mergulha no player.
# Usa a mesma ação do combo, então todo o resto (subida, carga, mergulho,
# explosão) é o mesmo código.
func _attack_4_start() -> void:
	_new_action(Action.COMBO)
	_play("Attack_4_Anticipation")


func _spawn_fx(scene: PackedScene, marker: Marker2D) -> void:
	if not scene:
		return
	var fx: Node2D = scene.instantiate()
	get_parent().add_child(fx)
	fx.add_to_group(SPAWNED_GROUP)
	# Sem marker ligado, nasce no ponto zero do Rá
	fx.global_position = marker.global_position if marker else global_position
	if fx.has_method("setup"):
		fx.setup(_mirror())   # FX desenhado no mesmo canvas do Rá: espelha igual a ele


func _attack_4_rise() -> void:
	var duration: float = _frames_duration("Attack_4_Anticipation", _attack_4_rise_start_frame, _attack_4_rise_end_frame)
	_tween_to(Vector2(global_position.x, _ground_y - _attack_4_hover_height), duration)


func _attack_4_charge() -> void:
	# garante que está no ponto do ar mesmo se o tween não terminou
	if _move_tween:
		_move_tween.kill()
	global_position.y = _ground_y - _attack_4_hover_height

	_set_facing(_dir_to_player())   # no ar vira na hora, sem Turn
	_play("Attack_4_Charge")
	_after(_attack_4_charge_time, _attack_4_dive)


func _attack_4_dive() -> void:
	var target_x: float = global_position.x
	var player := _get_player()
	if player:
		target_x = clampf(player.global_position.x, arena.get_min_x(), arena.get_max_x())

	var target := Vector2(target_x, _ground_y)
	_set_facing(signf(target_x - global_position.x) if target_x != global_position.x else _facing)

	_play("Attack_4")
	if _attack_4_area:
		_attack_4_area.activate()

	var duration: float = global_position.distance_to(target) / maxf(_attack_4_dive_speed, 1.0)
	_tween_to(target, maxf(duration, 0.05), _attack_4_land)


func _attack_4_land() -> void:
	if _attack_4_area:
		_attack_4_area.deactivate()

	_play_sfx(_sfx_attack_4)

	if _attack_4_impact_scene:
		var impact: Node2D = _attack_4_impact_scene.instantiate()
		get_parent().add_child(impact)
		impact.add_to_group(SPAWNED_GROUP)
		impact.global_position = global_position + Vector2(_attack_4_impact_offset.x * _facing, _attack_4_impact_offset.y)
		if impact.has_method("setup"):
			impact.setup(_mirror())

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 0.3)

	# Caiu na posição do player, não num marker: ataques 1 e 6 ficam
	# indisponíveis até o próximo teleport.
	_current_point = _point_at(global_position)
	_end_attack()


# =====================================================================
#  ATAQUE 5 — SHORYUKEN
# =====================================================================

func _attack_5_start() -> void:
	_new_action(Action.ATTACK_5)
	_play("Attack_5")
	_spawn_attack_5_fx()
	_spawn_simple_fx(_attack_5_charge_fx_scene)
	if _attack_5_windup_time > 0.0:
		_texture.pause()   # segura no frame 0
		_after(_attack_5_windup_time, func(): _texture.play())


func _attack_5_rise() -> void:
	var duration: float = _frames_duration("Attack_5", _attack_5_rise_frame, _attack_5_apex_frame)
	var target_x: float = clampf(global_position.x + _attack_5_forward * _facing, arena.get_min_x(), arena.get_max_x())
	_tween_to(Vector2(target_x, _ground_y - _attack_5_height), duration)


# No ápice: troca para Attack_5_Air (loop) e segura no ar por _attack_5_air_time.
# Depois volta para o Attack_5 já no frame da queda.
func _attack_5_hang() -> void:
	if _attack_5_air_time <= 0.0 or not _has_frames("Attack_5_Air"):
		return

	_texture.play("Attack_5_Air")
	_after(_attack_5_air_time, func():
		_texture.play("Attack_5")
		_texture.frame = _attack_5_fall_frame
		_on_frame_changed()
	)


func _attack_5_fall() -> void:
	var frame_count: int = _texture.sprite_frames.get_frame_count("Attack_5")
	var duration: float = _frames_duration("Attack_5", _attack_5_fall_frame, frame_count)
	_tween_to(Vector2(global_position.x, _ground_y), duration)


# FX do Ataque 5: nasce no centro do Rá (mesmo tamanho de frame do sprite dele)
# e fica parado ali enquanto ele sobe. Com _attack_5_fx_sync o frame do FX
# acompanha o frame do Rá; sem ele, o FX só toca uma vez e some sozinho.
func _spawn_attack_5_fx() -> void:
	_free_attack_5_fx()
	if not _attack_5_fx_scene:
		return
	var fx = _attack_5_fx_scene.instantiate()
	get_parent().add_child(fx)
	fx.global_position = _texture.global_position
	if fx is AnimatedSprite2D:
		fx.flip_h = _texture.flip_h
		if _attack_5_fx_sync:
			fx.pause()
			fx.frame = _texture.frame
			_attack_5_fx = fx


# FX simples (igual à poeira): nasce no ponto zero do Rá, vira junto com ele,
# fica parado onde nasceu, toca uma vez e some sozinho.
func _spawn_simple_fx(scene: PackedScene) -> void:
	if not scene:
		return
	var fx = scene.instantiate()
	get_parent().add_child(fx)
	fx.global_position = _texture.global_position
	if fx is AnimatedSprite2D:
		fx.flip_h = _texture.flip_h


func _free_attack_5_fx() -> void:
	if _attack_5_fx and is_instance_valid(_attack_5_fx):
		_attack_5_fx.queue_free()
	_attack_5_fx = null


func _attack_5_finish() -> void:
	_free_attack_5_fx()
	if _attack_5_area:
		_attack_5_area.deactivate()
	if _move_tween:
		_move_tween.kill()
	global_position.y = _ground_y
	_end_attack()


# =====================================================================
#  ATAQUE 6 — DESLIZE
# =====================================================================

func _attack_6_start() -> void:
	_new_action(Action.ATTACK_6)
	_play("Attack_6_Anticipation")
	_attack_6_mini_fx_tick()
	_after(_attack_6_charge_time, _attack_6_slide)


# Durante a carga do Ataque 6: explosõezinhas em pontos aleatórios dentro de um
# círculo de raio _attack_6_mini_fx_radius em volta do centro do Rá, uma atrás
# da outra em intervalos aleatórios, até ele começar a deslizar.
func _attack_6_mini_fx_tick() -> void:
	if _action != Action.ATTACK_6 or _texture.animation != &"Attack_6_Anticipation":
		return
	if _attack_6_mini_fx_scene:
		var fx = _attack_6_mini_fx_scene.instantiate()
		get_parent().add_child(fx)
		var angle: float = randf() * TAU
		var dist: float = sqrt(randf()) * _attack_6_mini_fx_radius   # sqrt = espalha por igual no círculo
		fx.global_position = _texture.global_position + Vector2.from_angle(angle) * dist
		if fx is AnimatedSprite2D:
			fx.flip_h = randf() < 0.5
	var wait: float = randf_range(_attack_6_mini_fx_interval.x, maxf(_attack_6_mini_fx_interval.x, _attack_6_mini_fx_interval.y))
	_after(wait, _attack_6_mini_fx_tick)


func _attack_6_slide() -> void:
	# Numa ponta: desliza até a ponta oposta. Fora das pontas: até a ponta
	# para onde ele está olhando (ele virou pro player antes de carregar).
	var target_point: int = arena.opposite_edge(_current_point)
	if target_point == RaArena.NO_POINT:
		target_point = RaArena.Point.RIGHT if _facing > 0.0 else RaArena.Point.LEFT
	var target: Vector2 = arena.get_point_position(target_point)

	_play("Attack_6")   # dano do deslize = contato da própria HurtBox

	var duration: float = global_position.distance_to(target) / maxf(_attack_6_speed, 1.0)
	_tween_to(target, maxf(duration, 0.05), func():
		_attack_6_finish(target_point)
	)


func _attack_6_finish(target_point: int) -> void:
	_current_point = target_point
	_attacks_done += 1
	_start_teleport()   # o Ataque 6 sempre termina com teleport


# =====================================================================
#  FASE 2 — PÁSSARO DE FOGO
# ---------------------------------------------------------------------
#  Transition (some) → sobe pro Center + _bird_height → Bird_Surge →
#  Bird_Idle + fileira de lanças (x _spear_waves) → Idle 2s → Bird_Gone →
#  cai reto no frame _bird_gone_fall_frame → explosão → Shine → combate
# =====================================================================

func _enter_phase_2() -> void:
	_phase = 2
	_attacks_since_bird = 0
	_last_attack = AttackType.BIRD   # o próprio rugido já leva ao ataque do pássaro

	for area in [_attack_4_area, _attack_5_area]:
		if area:
			area.deactivate()

	# Interrompe o que estiver fazendo e volta pro chão, visível
	# (continua podendo levar dano durante esse rugido)
	_new_action(Action.ROAR)
	_texture.modulate.a = 1.0
	global_position.y = _ground_y
	_set_vulnerable(true)
	_play("Idle")
	_start_roar(_bird_start)


func _bird_start() -> void:
	_new_action(Action.BIRD)
	_set_vulnerable(false)
	_play("Transition")   # vira disco e some


func _bird_hide() -> void:
	_texture.modulate.a = 0.0
	var center: Vector2 = arena.get_point_position(RaArena.Point.CENTER)
	_current_point = RaArena.Point.CENTER
	_ground_y = center.y
	global_position = center + Vector2(0, -_bird_height)
	_after(_bird_hidden_time, _bird_appear)


func _bird_appear() -> void:
	_set_facing(_dir_to_player())
	_texture.modulate.a = 1.0
	_play("Bird_Surge")


func _bird_after_surge() -> void:
	_set_vulnerable(true)
	_play("Bird_Idle")
	_spear_wave = 0
	_after(0.3, _bird_spear_wave)


func _bird_spear_wave() -> void:
	_spear_wave += 1
	_spears_alive = 0

	# Fileira reta abaixo do pássaro. Fileiras pares saem deslocadas meio
	# espaço, caindo nos vãos da anterior ("pares" e "ímpares").
	var line: Vector2 = global_position + Vector2(0, _spear_offset_y)
	var count: int = max(_spear_count, 1)
	var shift: float = _spear_spacing * 0.5 if _spear_wave % 2 == 0 else 0.0
	for i in count:
		var offset_x: float = (i - (count - 1) / 2.0) * _spear_spacing + shift - (_spear_spacing * 0.25 if _spear_waves > 1 else 0.0)
		_spawn_spear(line + Vector2(offset_x, 0))

	if _spears_alive <= 0:
		_on_spear_wave_done()


func _spawn_spear(pos: Vector2) -> void:
	if not _spear_scene:
		return
	var spear: Node2D = _spear_scene.instantiate()
	get_parent().add_child(spear)
	spear.add_to_group(SPAWNED_GROUP)
	spear.global_position = pos
	_spears_alive += 1
	spear.tree_exited.connect(_on_spear_freed.bind(_action_id))


func _on_spear_freed(owner_action_id: int) -> void:
	if owner_action_id != _action_id or not _is_alive:
		return
	_spears_alive -= 1
	if _spears_alive <= 0:
		_on_spear_wave_done()


func _on_spear_wave_done() -> void:
	if _spear_wave < _spear_waves:
		_after(_spear_wave_gap, _bird_spear_wave)
	else:
		_after(_bird_idle_before_gone, _bird_gone)


func _bird_gone() -> void:
	if _has_frames("Bird_Gone"):
		_play("Bird_Gone")
	else:
		_bird_fall()


func _bird_fall() -> void:
	_play_sfx(_sfx_bird_dive)
	var target := Vector2(global_position.x, _ground_y)
	var duration: float = absf(target.y - global_position.y) / maxf(_bird_fall_speed, 1.0)
	_tween_to(target, maxf(duration, 0.05), _bird_land)


func _bird_land() -> void:
	_texture.modulate.a = 0.0   # o pássaro "vira" a explosão
	_set_vulnerable(false)

	if _bird_land_vibration_strength > 0.0 and _bird_land_vibration_duration > 0.0:
		ControllerVibration.vibrate_custom(_bird_land_vibration_strength, _bird_land_vibration_strength, _bird_land_vibration_duration)

	if _bird_explosion_scene:
		var explosion: Node2D = _bird_explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.add_to_group(SPAWNED_GROUP)
		explosion.global_position = global_position + _bird_explosion_offset
		if explosion.has_signal("finished"):
			explosion.finished.connect(_bird_explosion_done.bind(_action_id))
			return

	_bird_explosion_done(_action_id)


func _bird_explosion_done(owner_action_id: int) -> void:
	if owner_action_id != _action_id or not _is_alive:
		return
	_texture.modulate.a = 1.0
	_set_facing(_dir_to_player())
	if _has_frames(_intro_animation):
		_play(_intro_animation)   # Shine: volta à forma humana
	else:
		_bird_finish()


func _bird_finish() -> void:
	_set_vulnerable(true)
	_end_attack()


# =====================================================================
#  TELEPORT
# =====================================================================

func _start_teleport() -> void:
	_new_action(Action.TELEPORT_OUT)
	teleport_started.emit()
	_play("Teleport")


func _on_teleport_out_done() -> void:
	_new_action(Action.TELEPORT_HIDDEN)
	_texture.modulate.a = 0.0
	_set_vulnerable(false)

	var target: int = arena.get_random_point_except(_current_point)
	_after(_teleport_hidden_time, func():
		_teleport_appear(target)
	)


func _teleport_appear(target: int) -> void:
	_current_point = target
	global_position = arena.get_point_position(target)
	_ground_y = global_position.y
	_set_facing(_dir_to_player())

	_texture.modulate.a = 1.0
	_new_action(Action.TELEPORT_IN)
	_play("Teleport", true)   # reaparece com o Teleport de trás pra frente


func _on_teleport_in_done() -> void:
	_set_vulnerable(true)
	teleport_finished.emit()
	_start_cycle()
	# Lugar novo, sorteio novo: sem isso, numa ponta ele sempre fazia 1 → 6
	# (o 6 do ciclo anterior ficava bloqueado como "último ataque").
	if _last_attack != AttackType.BIRD:
		_last_attack = AttackType.NONE
	_go_idle()


# =====================================================================
#  VIRAR (Turn)
# =====================================================================

func _face_then(new_facing: float, callback: Callable) -> void:
	if new_facing == 0.0 or signf(new_facing) == _facing:
		callback.call()
		return

	_new_action(Action.TURN)
	_pending_turn_facing = signf(new_facing)
	_pending_turn_callback = callback
	_play("Turn")


func _finish_turn() -> void:
	_set_facing(_pending_turn_facing)
	var callback: Callable = _pending_turn_callback
	_pending_turn_callback = Callable()
	if callback.is_valid():
		callback.call()


func _set_facing(new_facing: float) -> void:
	if new_facing == 0.0:
		return
	_facing = signf(new_facing)

	# drawn = direção em que os sprites foram desenhados (flip_h = false)
	var drawn: float = 1.0 if _sprite_faces_right else -1.0
	var mirror: float = _facing * drawn   # 1 = igual ao editor, -1 = espelhado

	if _texture:
		_texture.flip_h = mirror < 0.0

	for node in _mirror_defaults:
		if node == _body_collision or node == _hurtbox_collision:
			continue   # esses dois seguem a pose da animação (ver _apply_collision_pose)
		if is_instance_valid(node):
			var base: Vector2 = _mirror_defaults[node]
			node.position = Vector2(base.x * mirror, base.y)

	if _texture:
		_apply_collision_pose(_texture.animation)


# Corpo e HurtBox mudam de posição/escala em algumas animações (bola de fogo
# do Ataque 4, agachado do Ataque 6). Fora delas, voltam ao que está no editor.
func _apply_collision_pose(animation_name: String) -> void:
	var pose: Dictionary = COLLISION_POSES.get(animation_name, {})
	var mirror: float = _mirror()
	_set_shape_pose(_body_collision, pose.get("body", []), mirror)
	_set_shape_pose(_hurtbox_collision, pose.get("hurt", []), mirror)


# Animações "Bird_*" usam o material do pássaro; as outras, o material normal
func _apply_form_material(animation_name: String) -> void:
	if not _texture:
		return
	var wanted: Material = _default_material
	if _bird_material and animation_name.begins_with("Bird_"):
		wanted = _bird_material
	if _texture.material != wanted:
		_texture.material = wanted


func _set_shape_pose(shape: CollisionShape2D, pose: Array, mirror: float) -> void:
	if not shape or not _mirror_defaults.has(shape):
		return
	var pos: Vector2 = pose[0] if pose.size() > 0 else _mirror_defaults[shape]
	var scl: Vector2 = pose[1] if pose.size() > 1 else _scale_defaults[shape]
	shape.position = Vector2(pos.x * mirror, pos.y)
	shape.scale = scl


# =====================================================================
#  ANIMAÇÃO
# =====================================================================

func _play(animation_name: String, backwards: bool = false) -> void:
	if not _texture or not _texture.sprite_frames:
		return
	if not _texture.sprite_frames.has_animation(animation_name):
		push_warning("Rá: animação não encontrada: " + animation_name)
		return

	_fired_events.clear()
	_apply_collision_pose(animation_name)
	_apply_form_material(animation_name)
	if backwards:
		_texture.play_backwards(animation_name)
	else:
		_texture.play(animation_name)
		_on_frame_changed()   # garante eventos marcados no frame 0


func _on_animation_finished() -> void:
	if not _is_alive and _action != Action.DEAD:
		return

	# Fim da animação de entrada (Shine, ou Transition como reserva) → rugido
	if _action == Action.INTRO and (_texture.animation == _intro_animation or _texture.animation == "Transition"):
		_start_roar()
		return

	# Pássaro: Shine depois da explosão → volta ao combate
	if _action == Action.BIRD and _texture.animation == _intro_animation:
		_bird_finish()
		return

	match _texture.animation:
		"Transition":
			if _action == Action.DEAD:
				queue_free()
			elif _action == Action.BIRD:
				_bird_hide()

		"Bird_Surge":
			if _action == Action.BIRD:
				_bird_after_surge()

		"Turn":
			if _action == Action.TURN:
				_finish_turn()

		"Teleport":
			if _action == Action.TELEPORT_OUT:
				_on_teleport_out_done()
			elif _action == Action.TELEPORT_IN:
				_on_teleport_in_done()

		"Attack_1_Anticipation":
			if _action == Action.ATTACK_1:
				_attack_1_begin_pillars()

		"Attack_2_Anticipation":
			if _action == Action.COMBO:
				_play("Attack_2")

		"Attack_2":
			if _action == Action.COMBO:
				# fica no último frame do Attack_2 durante a pausa
				_after(_attack_2_to_3_delay, func(): _play("Attack_3_Anticipation"))

		"Attack_3_Anticipation":
			if _action == Action.COMBO:
				_play("Attack_3")

		"Attack_3":
			if _action == Action.COMBO:
				_play("Attack_4_Anticipation")

		"Attack_4_Anticipation":
			if _action == Action.COMBO:
				_attack_4_charge()

		"Attack_5":
			if _action == Action.ATTACK_5:
				_attack_5_finish()


# Eventos por frame (contando a partir de 0, igual ao Godot)
func _on_frame_changed() -> void:
	if not _is_alive or not _texture:
		return

	var f: int = _texture.frame

	match _texture.animation:
		"Attack_2":
			if _action == Action.COMBO and f == _attack_2_fx_frame:
				_fire_once("fx2", func(): _spawn_fx(_attack_2_fx_scene, _attack_2_fx_marker))   # o som está na cena do FX

		"Attack_3":
			if _action == Action.COMBO and f == _attack_3_fx_frame:
				_fire_once("fx3", func(): _spawn_fx(_attack_3_fx_scene, _attack_3_fx_marker))   # o som está na cena do FX

		"Attack_4_Anticipation":
			if _action == Action.COMBO and f == _attack_4_rise_start_frame:
				_fire_once("rise4", _attack_4_rise)

		"Bird_Gone":
			if _action == Action.BIRD and f == _bird_gone_fall_frame:
				_fire_once("bird_fall", _bird_fall)

		"Attack_5":
			if _action != Action.ATTACK_5:
				return
			if _attack_5_fx and is_instance_valid(_attack_5_fx):
				_attack_5_fx.frame = f
			if f == _attack_5_rise_frame:
				_fire_once("rise5", func():
					_attack_5_rise()
					_play_sfx(_sfx_attack_5)
				)
			if f == _attack_5_apex_frame:
				_fire_once("air5", _attack_5_hang)
			if f == _attack_5_fall_frame:
				_fire_once("fall5", _attack_5_fall)
			_update_attack_5_hitbox(f)


# Liga/move/desliga a colisão de dano do Shoryuken conforme ATTACK_5_HIT_FRAMES
func _update_attack_5_hitbox(f: int) -> void:
	if not _attack_5_area:
		return

	if ATTACK_5_HIT_FRAMES.has(f):
		var shape: CollisionShape2D = _attack_5_area._collision
		if shape:
			var pos: Vector2 = ATTACK_5_HIT_FRAMES[f]
			shape.position = Vector2(pos.x * _mirror(), pos.y)
		_fire_once("hit5_on", _attack_5_area.activate)
	elif f > ATTACK_5_HIT_FRAMES.keys().max():
		_fire_once("hit5_off", _attack_5_area.deactivate)


func _fire_once(key: String, callback: Callable) -> void:
	if _fired_events.has(key):
		return
	_fired_events[key] = true
	callback.call()


# Duração (em segundos) do frame `from_frame` até `to_frame` (contando de 0)
func _frames_duration(animation_name: String, from_frame: int, to_frame: int) -> float:
	var frames: SpriteFrames = _texture.sprite_frames
	var fps: float = frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.1

	var total: float = 0.0
	for i in range(from_frame, to_frame):
		if i >= 0 and i < frames.get_frame_count(animation_name):
			total += frames.get_frame_duration(animation_name, i)

	var speed: float = maxf(absf(_texture.speed_scale), 0.01)
	return maxf(total / fps / speed, 0.05)


# =====================================================================
#  DANO / MORTE
# =====================================================================

func update_health(damage: int, _entity) -> void:
	if not _is_alive or not _is_vulnerable:
		return

	_enemy_health -= damage

	var tween := create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)

	if _enemy_health <= 0:
		HitStopManager.hit_stop_short()
		_die()
		return

	if _phase == 1 and _enemy_health <= int(_max_health * _phase_2_threshold):
		_enter_phase_2()


func _set_shader_blink_intensity(value: float) -> void:
	if not _texture:
		return
	var mat := _texture.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("blink_active", value > 0.0)
	mat.set_shader_parameter("blink_intensity", value)


func _die() -> void:
	if not _is_alive:
		return

	_new_action(Action.DEAD)
	_is_alive = false
	_set_vulnerable(false)

	for area in [_attack_4_area, _attack_5_area]:
		if area:
			area.deactivate()

	# some com lanças, FX de golpe e explosões que ainda estão na sala
	for node in get_tree().get_nodes_in_group(SPAWNED_GROUP):
		if not is_instance_valid(node):
			continue
		if node.has_method("_start_gone"):
			node._start_gone()   # lança: animação Gone e some
		else:
			node.queue_free()

	# some com os pilares que ainda estão na sala
	for pillar in get_tree().get_nodes_in_group(ProjectileFirePillar.GROUP_NAME):
		if is_instance_valid(pillar) and pillar.has_method("_start_fade"):
			pillar._start_fade()

	_texture.modulate.a = 1.0
	global_position.y = _ground_y

	_save_boss_death()
	boss_defeated.emit(boss_id)

	if AudioManager:
		AudioManager.stop_music_realtime(5.0)

	# Provisório: sem animação de morte, ele vira disco e some (Transition normal)
	_play("Transition")


# =====================================================================
#  HELPERS
# =====================================================================

# =====================================================================
#  ÁUDIO
# =====================================================================

func _load_sfx_defaults() -> void:
	for _prop in _SFX_DEFAULTS:
		if get(_prop) == null and ResourceLoader.exists(_SFX_DEFAULTS[_prop]):
			set(_prop, load(_SFX_DEFAULTS[_prop]))


# Toca um som uma vez, preso ao Rá (acompanha ele), e se apaga ao terminar.
func _play_sfx(stream: AudioStream, pitch_min: float = 1.0, pitch_max: float = 1.0, volume_db: float = INF) -> AudioStreamPlayer2D:
	if not stream:
		return null
	var _player := AudioStreamPlayer2D.new()
	_player.stream = stream
	_player.volume_db = _sfx_volume_db if volume_db == INF else volume_db
	_player.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_player)
	_player.play()
	_player.finished.connect(_player.queue_free)
	return _player


func _stop_idle_sfx(fade: float) -> void:
	if not _idle_audio or not is_instance_valid(_idle_audio):
		_idle_audio = null
		return
	var _player: AudioStreamPlayer2D = _idle_audio
	_idle_audio = null
	if fade <= 0.0:
		_player.queue_free()
		return
	var _tw := _player.create_tween()
	_tw.tween_property(_player, "volume_db", -40.0, fade)
	_tw.tween_callback(_player.queue_free)


func _new_action(action: Action) -> void:
	if action != Action.ATTACK_5:
		_free_attack_5_fx()   # ataque interrompido (ex.: fase 2)
	if action != Action.IDLE:
		_stop_idle_sfx(_sfx_idle_fade_out)
	_action = action
	_action_id += 1
	if _move_tween:
		_move_tween.kill()
		_move_tween = null


# Espera `seconds` e chama `callback` — mas só se nenhuma outra ação
# começou nesse meio tempo (evita callbacks "velhos").
func _after(seconds: float, callback: Callable) -> void:
	# Timer como filho: se o Rá for removido, o timer some junto (sem callback órfão)
	var id: int = _action_id
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.01)
	add_child(timer)
	timer.timeout.connect(func():
		timer.queue_free()
		if id == _action_id and _is_alive:
			callback.call()
	)
	timer.start()


func _tween_to(target: Vector2, duration: float, on_finish: Callable = Callable()) -> void:
	if _move_tween:
		_move_tween.kill()
	var id: int = _action_id
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", target, duration)
	if on_finish.is_valid():
		_move_tween.tween_callback(func():
			if id == _action_id and _is_alive:
				on_finish.call()
		)


# Direção em que os sprites foram desenhados (1 = direita, -1 = esquerda)
func _drawn_dir() -> float:
	return 1.0 if _sprite_faces_right else -1.0


# 1 = Rá do jeito que foi desenhado (flip_h = false), -1 = espelhado
func _mirror() -> float:
	return _facing * _drawn_dir()


func _has_frames(animation_name: String) -> bool:
	return _texture and _texture.sprite_frames \
		and _texture.sprite_frames.has_animation(animation_name) \
		and _texture.sprite_frames.get_frame_count(animation_name) > 0


func _animation_length(animation_name: String) -> float:
	var count: int = _texture.sprite_frames.get_frame_count(animation_name)
	return _frames_duration(animation_name, 0, count)


func _set_vulnerable(value: bool) -> void:
	_is_vulnerable = value
	if _hurtbox:
		_hurtbox.set_deferred("monitorable", value)
		_hurtbox.set_deferred("monitoring", value)


func _get_player() -> BaseCharacter:
	if global.character and is_instance_valid(global.character):
		return global.character
	return null


func _dir_to_player() -> float:
	var player := _get_player()
	if not player:
		return _facing
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) < 1.0:
		return _facing
	return signf(dx)


# Direção "para dentro da sala" a partir da ponta onde ele está
func _edge_inward_dir() -> float:
	if _current_point == RaArena.Point.LEFT:
		return 1.0
	if _current_point == RaArena.Point.RIGHT:
		return -1.0
	return _dir_to_player()


func _nearest_point() -> int:
	var best: int = RaArena.Point.CENTER
	var best_dist: float = INF
	for p in [RaArena.Point.LEFT, RaArena.Point.CENTER, RaArena.Point.RIGHT]:
		var d: float = global_position.distance_to(arena.get_point_position(p))
		if d < best_dist:
			best_dist = d
			best = p
	return best


# Marker exatamente na posição (tolerância 8px), ou NO_POINT
func _point_at(pos: Vector2) -> int:
	for p in [RaArena.Point.LEFT, RaArena.Point.CENTER, RaArena.Point.RIGHT]:
		if pos.distance_to(arena.get_point_position(p)) <= 8.0:
			return p
	return RaArena.NO_POINT


func _on_combo_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_close = true


func _on_combo_area_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_close = false
