extends ProjectileComponent
class_name ProjectileFirePillar

# Posições padrão dos raycasts (estado sem flip / shooter_flip_h = false)
const GROUND_RAY_DEFAULT_POS: Vector2 = Vector2(-20, 0)
const WALL_RAY_DEFAULT_POS: Vector2 = Vector2(0, -70)
const WALL_RAY_DEFAULT_TARGET: Vector2 = Vector2(-20, 0)  # TODO: ajustar se necessário

var is_destroyed: bool = false

# true assim que "Rise" termina — antes disso o pilar não se move nem checa
# wall_ray/ground_ray.
var _is_moving: bool = false

# Flip_h de quem disparou (ex: EstatuaGuardiaoRa), usado pra espelhar sprite/raycasts.
var shooter_flip_h: bool = false

@export_category("Variables")
@export var attack_damage: int = 10
@export var _lifetime_after_rise: float = 2.0  # tempo vivo (movendo/parado) após "Rise" terminar, antes do "Fade"

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var ground_ray: RayCast2D
@export var wall_ray: RayCast2D
@export var attack_audio: AudioStreamPlayer

var _fade_timer: Timer
var _was_blocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if texture and not texture.animation_finished.is_connected(_on_texture_animation_finished):
		texture.animation_finished.connect(_on_texture_animation_finished)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_fade_timer = Timer.new()
	_fade_timer.one_shot = true
	_fade_timer.timeout.connect(_on_fade_timer_timeout)
	add_child(_fade_timer)

	is_destroyed = false
	_is_moving = false
	_was_blocked = false
	_start_rise()

	if attack_audio:
		attack_audio.play()


# shooter_flip: passe o flip_h de quem disparou (ex: _texture.flip_h do inimigo)
func setup(new_direction: Vector2, speed: float = 300.0, shooter_flip: bool = false) -> void:
	direction = new_direction.normalized()
	_move_speed = speed
	shooter_flip_h = shooter_flip
	is_destroyed = false
	_is_moving = false

	if texture:
		texture.flip_h = shooter_flip_h

	_update_raycasts_position()

	print("🔥 ProjectileFirePillar configurado - Direção: ", direction, " Velocidade: ", _move_speed, " Flip: ", shooter_flip_h)


func _update_raycasts_position() -> void:
	var mirror: float = -1.0 if shooter_flip_h else 1.0

	if ground_ray:
		ground_ray.position = Vector2(GROUND_RAY_DEFAULT_POS.x * mirror, GROUND_RAY_DEFAULT_POS.y)

	if wall_ray:
		wall_ray.position = Vector2(WALL_RAY_DEFAULT_POS.x * mirror, WALL_RAY_DEFAULT_POS.y)
		wall_ray.target_position = Vector2(WALL_RAY_DEFAULT_TARGET.x * mirror, WALL_RAY_DEFAULT_TARGET.y)


# --- RISE → IDLE (movendo) → FADE ---
func _start_rise() -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation("Rise"):
		texture.play("Rise")
	else:
		# Ainda não existe animação de Rise — pula direto pro comportamento
		# de "já subiu e pode se mover", sem travar o teste.
		_begin_moving()


func _begin_moving() -> void:
	_is_moving = true
	_play_animation("Idle")
	print("🏃 ProjectileFirePillar começou a se mover | pos: ", global_position, " direção: ", direction)

	# Força os raycasts a atualizarem AGORA, em vez de esperar o próximo
	# frame de física — sem isso, a primeira checagem em _physics_process
	# lia um estado "vazio" (ainda não processado) e travava o movimento
	# desde o primeiro frame.
	if ground_ray:
		ground_ray.force_raycast_update()
	if wall_ray:
		wall_ray.force_raycast_update()

	_fade_timer.start(_lifetime_after_rise)


func _on_fade_timer_timeout() -> void:
	_start_fade()


func _start_fade() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	_is_moving = false
	print("🌫️ ProjectileFirePillar iniciando Fade | pos final: ", global_position)

	if texture and texture.sprite_frames and texture.sprite_frames.has_animation("Fade"):
		texture.play("Fade")
	else:
		queue_free()


func _play_animation(animation_name: String) -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)
	# Se a animação não existir ainda, não faz nada — mantém o que já está tocando.


func _on_texture_animation_finished() -> void:
	if not texture:
		return

	match texture.animation:
		"Rise":
			_begin_moving()
		"Fade":
			print("🗑️ Fade finalizado → queue_free()")
			queue_free()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	if not _is_moving:
		return  # ainda no "Rise" — não se move, não checa raycasts

	# wall_ray/ground_ray só TRAVAM o movimento — não destroem mais o pilar.
	# Se o obstáculo sumir depois (chão reaparece, parede se move), ele volta
	# a andar normalmente no frame seguinte.
	var blocked: bool = (wall_ray and wall_ray.is_colliding()) or (ground_ray and not ground_ray.is_colliding())

	if blocked != _was_blocked:
		_was_blocked = blocked
		print("🚧 ProjectileFirePillar blocked = ", blocked, " | pos: ", global_position, " | wall: ", (wall_ray and wall_ray.is_colliding()), " | ground_ok: ", (not ground_ray or ground_ray.is_colliding()))

	if not blocked:
		super._physics_process(delta)


# O pilar é um obstáculo, não uma arma reativa ao player: acertar o player
# não interrompe nem afeta o movimento — segue o comportamento normal.
func _on_body_entered(_body) -> void:
	if _body is BaseCharacter and not is_destroyed:
		_body.update_health(attack_damage, get_parent())
		print("⚔️ Dano aplicado: ", attack_damage)
