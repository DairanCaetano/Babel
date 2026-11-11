extends Area2D
class_name RaSpear

# Lança do Rá-Pássaro.
#
#   Surge  (1x)   aparece no lugar onde foi instanciada
#   Idle   (loop) desce devagar (_hover_drift_speed) por _hover_time segundos,
#                 depois cai com gravidade
#                 (o dano fica ligado durante a queda)
#   Stick  (1x)   crava no chão + tremida de câmera; quando termina → Gone
#                 (se não existir, espera _ground_time no Idle e vai pra Gone)
#   Gone   (1x)   some (Surge de trás pra frente) → queue_free
#
# O Texture fica centralizado no nó (0, 0). O GroundRay sai da ponta da lança
# para baixo e detecta o chão (layer 2, igual aos outros projéteis).

enum Stage { SURGE, HOVER, FALL, GROUND, GONE }

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var ground_ray: RayCast2D
@export var fall_audio: AudioStreamPlayer
@export var impact_audio: AudioStreamPlayer

@export_category("Áudio")
## Som ao surgir e ao cravar no chão. Vazio = arquivos padrão (EnemiesSound).
## Várias lanças surgem/cravam juntas: só uma toca por vez (evita som estourado).
@export var surge_sound: AudioStream
@export var land_sound: AudioStream
@export var fall_sound: AudioStream   # quando começa a queda rápida (uma vez por fileira)
@export var sound_volume_db: float = 0.0
@export var sound_pitch: Vector2 = Vector2(0.95, 1.05)
const _SURGE_DEFAULT: String = "res://Sound/SFX/EnemiesSound/Ra_Spear_1_DSGNImpt_EXPLOSION-Flare Ignite_HY_PC-005.ogg"
const _LAND_DEFAULT: String = "res://Sound/SFX/EnemiesSound/Ra_Spear_2_DSGNImpt_EXPLOSION-Flare Nova_HY_PC-004.ogg"
const _FALL_DEFAULT: String = "res://Sound/SFX/EnemiesSound/Flame_Spear_Fall_dragon-studio-elemental-spell-impact-flame-448566.ogg"
const _LAND_FX_DEFAULT: String = "res://Scenes/FX/fire_ground_fx.tscn"
static var _last_fall_ms: int = -100000

## Efeito que nasce onde a lança crava (vazio = fire_ground_fx.tscn, o fogo do chão).
## Só a primeira explosão de cada fileira toca som (8 juntas estourariam).
@export var land_fx_scene: PackedScene
@export var land_fx_enabled: bool = true
## Distância (px) da base do desenho da explosão até o centro do frame dela
@export var land_fx_offset_y: float = 0.0   # 0 = base do efeito no chão (a cena já tem a origem na base)
## O fogo do sprite da mini explosão fica ~9 px à esquerda do centro do frame: corrige
@export var land_fx_art_offset_x: float = 0.0
## Duas explosões por lança: uma de cada lado, alturas um pouco diferentes,
## a segunda um pouco depois (parecido com as do Ataque 6)
@export var land_fx_count: int = 1
@export var land_fx_spread_x: float = 6.0     # quanto cada uma vai para o lado
@export var land_fx_spread_y: float = 5.0     # variação aleatória de altura (±)
@export var land_fx_delay: float = 0.2        # atraso entre uma explosão e a próxima
const _SOUND_GAP_MS: int = 120
static var _last_surge_ms: int = -100000
static var _last_land_ms: int = -100000

@export_category("Variables")
@export var attack_damage: int = 10
@export var _hover_time: float = 1.0          # tempo descendo devagar antes da queda rápida
@export var _hover_drift_speed: float = 20.0  # px/s que ela desce durante o Idle (0 = parada)
@export var _ground_time: float = 1.0         # só usado se a Stick não existir (ou estiver em loop)
@export var _gravity: float = 980.0
@export var _max_fall_speed: float = 600.0
@export var _damage_on_ground: bool = false   # true = continua machucando cravada no chão
@export var _max_lifetime: float = 6.0        # segurança: some mesmo se nunca achar o chão
@export var _land_shake_strength: float = 2.0 # tremida da câmera ao cravar (0 = sem tremida)
@export var _land_shake_duration: float = 0.15
@export var _land_vibration_strength: float = 0.4   # vibração do controle ao cravar (0 = sem vibração)
@export var _land_vibration_duration: float = 0.15

var _stage: Stage = Stage.SURGE
var _velocity_y: float = 0.0
var _has_hit: bool = false
var _ray_base_target_y: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if not texture:
		texture = get_node_or_null("Texture")
	if not collision:
		collision = get_node_or_null("Collision")
	if not ground_ray:
		ground_ray = get_node_or_null("GroundRay")

	if collision:
		collision.disabled = true
	if ground_ray:
		_ray_base_target_y = ground_ray.target_position.y

	body_entered.connect(_on_body_entered)
	if texture:
		texture.animation_finished.connect(_on_animation_finished)

	get_tree().create_timer(_max_lifetime, false).timeout.connect(_start_gone)

	_stage = Stage.SURGE
	_play("Surge")
	
	if not surge_sound and ResourceLoader.exists(_SURGE_DEFAULT):
		surge_sound = load(_SURGE_DEFAULT)
	if not land_sound and ResourceLoader.exists(_LAND_DEFAULT):
		land_sound = load(_LAND_DEFAULT)
	if not fall_sound and ResourceLoader.exists(_FALL_DEFAULT):
		fall_sound = load(_FALL_DEFAULT)
	if not land_fx_scene and ResourceLoader.exists(_LAND_FX_DEFAULT):
		land_fx_scene = load(_LAND_FX_DEFAULT)
	var _now: int = Time.get_ticks_msec()
	if _now - _last_surge_ms > _SOUND_GAP_MS:
		_last_surge_ms = _now
		_play_sound(surge_sound)


func _on_animation_finished() -> void:
	match texture.animation:
		"Surge":
			_start_hover()
		"Stick":
			_start_gone()
		"Gone":
			queue_free()


func _start_hover() -> void:
	if _stage != Stage.SURGE:
		return
	_stage = Stage.HOVER
	_play("Idle")
	get_tree().create_timer(_hover_time, false).timeout.connect(_start_fall)


func _start_fall() -> void:
	if _stage != Stage.HOVER:
		return
	_stage = Stage.FALL
	_velocity_y = _hover_drift_speed   # continua da velocidade da descida lenta (sem tranco)
	if collision:
		collision.set_deferred("disabled", false)   # dano liga na queda
	if fall_audio:
		fall_audio.play()
	var _now: int = Time.get_ticks_msec()
	if _now - _last_fall_ms > _SOUND_GAP_MS:
		_last_fall_ms = _now
		_play_sound(fall_sound)


func _physics_process(delta: float) -> void:
	if _stage == Stage.HOVER:
		global_position.y += _hover_drift_speed * delta
		return
	if _stage != Stage.FALL:
		return

	_velocity_y = minf(_velocity_y + _gravity * delta, _max_fall_speed)
	var step: float = _velocity_y * delta

	# Ajusta o raio para enxergar todo o trecho deste frame (evita atravessar o chão)
	if ground_ray:
		ground_ray.target_position.y = _ray_base_target_y + step
		ground_ray.force_raycast_update()
		if ground_ray.is_colliding():
			var tip_offset: float = ground_ray.position.y
			global_position.y = ground_ray.get_collision_point().y - tip_offset
			_land()
			return

	global_position.y += step


func _land() -> void:
	_stage = Stage.GROUND
	if not _damage_on_ground and collision:
		collision.set_deferred("disabled", true)
	if impact_audio:
		impact_audio.play()
	var _now: int = Time.get_ticks_msec()
	var _first_of_wave: bool = _now - _last_land_ms > _SOUND_GAP_MS
	_spawn_land_fx(_first_of_wave)
	if _first_of_wave:
		_last_land_ms = _now
		_play_sound(land_sound)
		# Uma vibração por fileira (as lanças cravam juntas)
		if _land_vibration_strength > 0.0 and _land_vibration_duration > 0.0:
			ControllerVibration.vibrate_custom(_land_vibration_strength, _land_vibration_strength, _land_vibration_duration)

	if _land_shake_strength > 0.0:
		var camera = get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("shake_camera"):
			camera.shake_camera(_land_shake_strength, _land_shake_duration)

	# Stick (fincar no chão): quando terminar, vai pra Gone (ver _on_animation_finished)
	var frames: SpriteFrames = texture.sprite_frames if texture else null
	if frames and frames.has_animation("Stick") and frames.get_frame_count("Stick") > 0:
		_play("Stick")
		if not frames.get_animation_loop("Stick"):
			return
	get_tree().create_timer(_ground_time, false).timeout.connect(_start_gone)


func _start_gone() -> void:
	if _stage == Stage.GONE:
		return
	_stage = Stage.GONE
	if collision:
		collision.set_deferred("disabled", true)
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation("Gone"):
		_play("Gone")
	else:
		queue_free()


# Som solto na cena (continua tocando mesmo se a lança sumir antes)
# Mini explosão no ponto em que a ponta da lança tocou o chão
func _spawn_land_fx(with_sound: bool) -> void:
	if not land_fx_enabled or not land_fx_scene or not get_parent():
		return
	var host: Node = get_parent()
	var tip_y: float = global_position.y + (ground_ray.position.y if ground_ray else 0.0)
	var base := Vector2(global_position.x + land_fx_art_offset_x, tip_y - land_fx_offset_y)
	var count: int = maxi(land_fx_count, 1)
	var first_side: float = -1.0 if randf() < 0.5 else 1.0
	for i in count:
		# alterna os lados: esquerda/direita (ou direita/esquerda)
		var side: float = first_side * (1.0 if i % 2 == 0 else -1.0)
		var offset := Vector2(side * land_fx_spread_x, randf_range(-land_fx_spread_y, land_fx_spread_y))
		if count == 1:
			offset = Vector2.ZERO
		var play_sound: bool = with_sound and i == 0   # só a primeira da fileira faz som
		var delay: float = land_fx_delay * i
		if delay <= 0.0:
			_spawn_one_land_fx(host, base + offset, play_sound)
		else:
			get_tree().create_timer(delay, false).timeout.connect(_spawn_one_land_fx.bind(host, base + offset, play_sound))


# Não depende da lança: a segunda explosão nasce mesmo se a lança já sumiu
func _spawn_one_land_fx(host: Node, pos: Vector2, play_sound: bool) -> void:
	if not is_instance_valid(host) or not land_fx_scene:
		return
	var fx = land_fx_scene.instantiate()
	if not play_sound and "sound" in fx:
		fx.sound = null
	host.add_child(fx)
	fx.global_position = pos


func _play_sound(stream: AudioStream) -> void:
	if not stream or not get_parent():
		return
	var _player := AudioStreamPlayer2D.new()
	_player.stream = stream
	_player.volume_db = sound_volume_db
	_player.pitch_scale = randf_range(minf(sound_pitch.x, sound_pitch.y), maxf(sound_pitch.x, sound_pitch.y))
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	get_parent().add_child(_player)
	_player.global_position = global_position
	_player.play()
	_player.finished.connect(_player.queue_free)


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	if body is BaseCharacter:
		_has_hit = true
		body.update_health(attack_damage, self)


func _play(animation_name: String) -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.stop()
		texture.play(animation_name)
