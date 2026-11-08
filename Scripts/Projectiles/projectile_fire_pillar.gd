extends ProjectileComponent
class_name ProjectileFirePillar

# Pilar de luz/fogo — usado pela Estátua Guardiã de Rá (ataque especial)
# e pelo Rá (Ataque 1).
#
# Estágios (animações do Texture):
#   Anticipation  (loop)  parado, sem dano, por pelo menos _anticipation_time
#   Flame         (1x)    o fogo sobe, ainda sem dano
#   Attack        (loop)  a colisão de dano LIGA aqui; anda até bater na parede /
#                         acabar o chão, encontrar o par, ou estourar _lifetime_after_rise
#   Flame_End     (1x)    encerramento, sem dano → some
#
# Par (só o Rá usa): dois pilares com o mesmo pair_id, vindo de lados opostos,
# encerram juntos quando se encontram. pair_id = -1 (padrão) = sem par.
#
# A origem do pilar fica na BASE (o Texture sobe metade da altura), então o
# marker de onde ele nasce marca o chão — igual ao que a Estátua já usava.

const GROUP_NAME: String = "fire_pillar"

enum Stage { ANTICIPATION, FLAME, ATTACK, FINISH }

@export_category("Variables")
@export var attack_damage: int = 10
@export var _anticipation_time: float = 0.5   # tempo mínimo parado na Anticipation
@export var _lifetime_after_rise: float = 4.0 # tempo máximo andando na Attack (segurança)
@export var _meet_distance: float = 8.0       # distância (px) em que o par é considerado "encontrado"

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var ground_ray: RayCast2D
@export var wall_ray: RayCast2D
@export_group("Áudio")
## Toca quando o pilar SURGE (início da Anticipation)
@export var spawn_audio: AudioStreamPlayer
## Toca durante a Attack, em loop, até o encerramento
@export var attack_audio: AudioStreamPlayer
## Tempo que o som da Attack leva pra sumir no encerramento (0 = corta seco)
@export var attack_audio_fade: float = 0.25
## Toca no encerramento (Flame_End)
@export var fade_audio: AudioStreamPlayer

var pair_id: int = -1
var is_destroyed: bool = false

var _stage: Stage = Stage.ANTICIPATION
var _is_moving: bool = false

# Posições dos raycasts no editor (apontando para a ESQUERDA, como a Estátua usa)
var _ground_ray_default_pos: Vector2 = Vector2.ZERO
var _wall_ray_default_pos: Vector2 = Vector2.ZERO
var _wall_ray_default_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(GROUP_NAME)

	if not texture:
		texture = get_node_or_null("Texture")
	if not collision:
		collision = get_node_or_null("Collision")

	if ground_ray:
		_ground_ray_default_pos = ground_ray.position
	if wall_ray:
		_wall_ray_default_pos = wall_ray.position
		_wall_ray_default_target = wall_ray.target_position

	if collision:
		collision.disabled = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if texture and not texture.animation_finished.is_connected(_on_texture_animation_finished):
		texture.animation_finished.connect(_on_texture_animation_finished)
	
	# ✅ Áudio de ataque em loop enquanto o pilar estiver na Attack
	if attack_audio and not attack_audio.finished.is_connected(_on_attack_audio_finished):
		attack_audio.finished.connect(_on_attack_audio_finished)

	_start_anticipation()


# Chamado por quem dispara (Estátua ou Rá) logo depois de instanciar.
# shooter_flip mantido por compatibilidade; o lado é calculado pela direção.
func setup(new_direction: Vector2, speed: float = 300.0, _shooter_flip: bool = false) -> void:
	direction = new_direction.normalized()
	_move_speed = speed

	var going_right: bool = direction.x > 0.0
	var mirror: float = -1.0 if going_right else 1.0

	if texture:
		texture.flip_h = going_right
	if ground_ray:
		ground_ray.position = Vector2(_ground_ray_default_pos.x * mirror, _ground_ray_default_pos.y)
	if wall_ray:
		wall_ray.position = Vector2(_wall_ray_default_pos.x * mirror, _wall_ray_default_pos.y)
		wall_ray.target_position = Vector2(_wall_ray_default_target.x * mirror, _wall_ray_default_target.y)


# ---------------------------------------------------------------- estágios

func _start_anticipation() -> void:
	_stage = Stage.ANTICIPATION
	_play_audio(spawn_audio)
	_play_animation("Anticipation")
	get_tree().create_timer(_anticipation_time, false).timeout.connect(_start_flame)


func _start_flame() -> void:
	if is_destroyed or _stage != Stage.ANTICIPATION:
		return
	_stage = Stage.FLAME
	_play_animation("Flame")


func _start_attack() -> void:
	if is_destroyed:
		return
	_stage = Stage.ATTACK
	_is_moving = true
	if collision:
		collision.set_deferred("disabled", false)   # dano só durante a Attack
	# Par de pilares: só um deles toca o som de movimento (dois iguais juntos
	# só dobrariam o volume)
	if not _pair_audio_already_playing():
		_play_audio(attack_audio)
	_play_animation("Attack")

	if ground_ray:
		ground_ray.force_raycast_update()
	if wall_ray:
		wall_ray.force_raycast_update()

	get_tree().create_timer(_lifetime_after_rise, false).timeout.connect(_start_fade)


# Encerramento (nome mantido: o Rá chama _start_fade() nos pilares quando morre)
func _start_fade() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	_is_moving = false
	_stage = Stage.FINISH
	if collision:
		collision.set_deferred("disabled", true)
	_fade_attack_audio()
	_play_audio(fade_audio)
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation("Flame_End"):
		_play_animation("Flame_End")
	elif texture and texture.sprite_frames and texture.sprite_frames.has_animation("Finish"):
		_play_animation("Finish")   # cenas antigas
	else:
		queue_free()


func _on_texture_animation_finished() -> void:
	if not texture:
		return
	match texture.animation:
		"Flame":
			_start_attack()
		"Flame_End", "Finish":
			_free_after_audio()


# ---------------------------------------------------------------- movimento

func _physics_process(delta: float) -> void:
	if not _is_moving or is_destroyed:
		return

	# Parede na frente ou fim do chão → encerra
	var blocked: bool = (wall_ray and wall_ray.is_colliding()) or (ground_ray and not ground_ray.is_colliding())
	if blocked:
		_start_fade()
		return

	super._physics_process(delta)   # anda: direction * _move_speed

	if pair_id < 0:
		return

	for other in get_tree().get_nodes_in_group(GROUP_NAME):
		if other == self or not is_instance_valid(other) or not other is ProjectileFirePillar:
			continue
		if other.pair_id != pair_id or other.is_destroyed:
			continue

		# Distância que ainda falta até o outro, na direção em que ESTE pilar anda
		var gap: float = (other.global_position.x - global_position.x) * signf(direction.x)
		if gap <= _meet_distance:
			_start_fade()
			other._start_fade()
			return


# ---------------------------------------------------------------- dano

func _on_body_entered(_body) -> void:
	if is_destroyed:
		return
	if _body is BaseCharacter:
		_body.update_health(attack_damage, self)


# ---------------------------------------------------------------- áudio

func _play_audio(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()

# true se o outro pilar do mesmo par já está tocando o som de movimento
func _pair_audio_already_playing() -> bool:
	if pair_id < 0:
		return false
	for other in get_tree().get_nodes_in_group(GROUP_NAME):
		if other == self or not is_instance_valid(other) or not other is ProjectileFirePillar:
			continue
		if other.pair_id == pair_id and other.attack_audio and other.attack_audio.playing:
			return true
	return false


# Some com o som de movimento suavemente em vez de cortar seco
func _fade_attack_audio() -> void:
	if not attack_audio or not attack_audio.playing:
		return
	if attack_audio_fade <= 0.0:
		attack_audio.stop()
		return
	var tween := create_tween()
	tween.tween_property(attack_audio, "volume_db", -40.0, attack_audio_fade)
	tween.tween_callback(attack_audio.stop)

func _on_attack_audio_finished() -> void:
	# Loop manual (funciona mesmo se o arquivo de áudio não estiver marcado como loop)
	if _stage == Stage.ATTACK and not is_destroyed and attack_audio:
		attack_audio.play()

func _free_after_audio() -> void:
	# Não corta o som do encerramento: some da tela e espera o áudio acabar
	if fade_audio and fade_audio.playing:
		visible = false
		await fade_audio.finished
	queue_free()


func _play_animation(animation_name: String) -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)
