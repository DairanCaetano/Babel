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
