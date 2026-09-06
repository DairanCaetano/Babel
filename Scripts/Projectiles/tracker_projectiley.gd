extends Area2D
class_name TrackerProjectile

# 📄 ARQUIVO: tracker_projectiley.gd
# 📍 ONDE: res://Scenes/Projectile/
# 🎬 CENA: tracker_projectiley.tscn

# ---------------------------------------------------------------------------
# COMPORTAMENTO
# ---------------------------------------------------------------------------
# 1) Nasce tocando "Charge" (parado).
# 2) Quando "Charge" termina, captura a posição do alvo e traça um arco curvo
#    (Bézier quadrática) do ponto de nascimento até a posição do alvo naquele
#    instante — passando por um ponto de controle deslocado pra cima ou pra
#    baixo no meio do caminho (dependendo se o projétil nasceu acima ou
#    abaixo do alvo), criando uma trajetória em curva suave em vez de reta.
# 3) Nesse momento troca pra "Idle" e ativa a partícula.
# 4) Ao terminar a curva (chegar na posição que era do alvo), continua reto
#    na mesma direção final, até acertar algo ou o tempo de vida acabar.
# 5) Se acertar o player, for destruído pelo CharacterAttackArea, ou o tempo
#    de vida máximo expirar, ele se autodestrói.

@export_category("Variables")
@export var attack_damage: int = 1
@export var move_speed: float = 220.0        # velocidade aproximada ao longo da curva (px/s)
@export var arc_bulge_factor: float = 0.4    # o quanto a curva se desvia da linha reta (fração da distância)
@export var max_lifetime: float = 5.0        # segurança: autodestrói depois disso, aconteça o que acontecer
@export var _health: int = 1
@export var is_interactable: bool = true     # pode ser destruído pelo CharacterAttackArea
@export var interactable_pieces: Array

@export_category("Objects")
@export var _sprite: AnimatedSprite2D
@export var _body_collision: CollisionShape2D
@export var _particle: GPUParticles2D
@export var _charge_audio: AudioStreamPlayer   # toca ao nascer, junto com "Charge"
@export var _idle_audio: AudioStreamPlayer     # toca em loop enquanto se move ("Idle") — marque "Loop" no áudio
@export var _hit_audio: AudioStreamPlayer      # toca ao colidir/acertar algo

var _target: Node2D = null
var is_destroyed: bool = false

# --- Estado da curva (Bézier quadrática) ---
var _start_pos: Vector2
var _control_pos: Vector2   # ponto de controle (define a curvatura)
var _end_pos: Vector2       # posição do alvo capturada no início do movimento
var _elapsed: float = 0.0
var _travel_time: float = 0.0
var _is_moving: bool = false
var _is_past_curve: bool = false   # true depois que a curva termina (segue reto)
var _straight_dir: Vector2 = Vector2.ZERO   # direção do trecho reto após a curva


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_interactable_area_entered)

	if _particle:
		_particle.visible = false
		_particle.emitting = false

	if _sprite:
		_sprite.animation_finished.connect(_on_animation_finished)
		_sprite.play("Charge")

	if _charge_audio:
		_charge_audio.play()

	var lifetime_timer := Timer.new()
	add_child(lifetime_timer)
	lifetime_timer.wait_time = max_lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()


# Chamado por quem instancia o projétil (ex: SacerdoteEgito._perform_attack)
func set_target(target: Node2D) -> void:
	_target = target


# ---------------------------------------------------------------------------
# ANIMAÇÃO
# ---------------------------------------------------------------------------

func _on_animation_finished() -> void:
	if is_destroyed:
		return
	if _sprite.animation == "Charge":
		_start_moving()


func _start_moving() -> void:
	_sprite.play("Idle")

	if _idle_audio:
		_idle_audio.play()

	if _particle:
		_particle.visible = true
		_particle.emitting = true

	_start_pos = global_position

	if is_instance_valid(_target):
		_end_pos = _target.global_position
	else:
		# Sem alvo válido: não tem pra onde ir, só espera o lifetime acabar.
		_is_moving = false
		return

	var chord: Vector2 = _end_pos - _start_pos
	var chord_length: float = chord.length()

	if chord_length < 1.0:
		_is_moving = false
		return

	var chord_hat: Vector2 = chord.normalized()

	# Duas perpendiculares possíveis. A escolha depende de onde o projétil
	# nasceu em relação ao alvo:
	# - Se nasceu ACIMA do alvo (start.y < end.y): curva em "U" — desce
	#   primeiro, passa por baixo, sobe depois — controle pra BAIXO (Y maior).
	# - Se nasceu ABAIXO do alvo: o inverso — controle pra CIMA (Y menor).
	var perp_a := Vector2(chord_hat.y, -chord_hat.x)
	var perp_b := Vector2(-chord_hat.y, chord_hat.x)
	var spawned_above_target: bool = _start_pos.y < _end_pos.y

	var perp_hat: Vector2
	if spawned_above_target:
		perp_hat = perp_a if perp_a.y > perp_b.y else perp_b   # curva pra baixo (U)
	else:
		perp_hat = perp_a if perp_a.y < perp_b.y else perp_b   # curva pra cima (∩)

	var mid: Vector2 = (_start_pos + _end_pos) / 2.0
	_control_pos = mid + perp_hat * (chord_length * arc_bulge_factor)

	# Duração aproximada: a curva é um pouco mais longa que a linha reta.
	_travel_time = (chord_length * (1.0 + arc_bulge_factor)) / max(move_speed, 1.0)
	_elapsed = 0.0
	_is_moving = true
	_is_past_curve = false


# ---------------------------------------------------------------------------
# MOVIMENTO (curva Bézier + trecho reto depois)
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_moving or is_destroyed:
		return

	if _is_past_curve:
		# Já terminou a curva: segue reto na direção final.
		global_position += _straight_dir * move_speed * delta
		return

	_elapsed += delta
	var t: float = clamp(_elapsed / _travel_time, 0.0, 1.0)

	# Bézier quadrática: B(t) = (1-t)² * start + 2(1-t)t * control + t² * end
	var one_minus_t: float = 1.0 - t
	global_position = (one_minus_t * one_minus_t) * _start_pos \
		+ (2.0 * one_minus_t * t) * _control_pos \
		+ (t * t) * _end_pos

	if t >= 1.0:
		# Direção final = derivada da Bézier em t=1: 2 * (end - control)
		var tangent: Vector2 = _end_pos - _control_pos
		_straight_dir = tangent.normalized() if tangent.length() > 0.01 else (_end_pos - _start_pos).normalized()
		_is_past_curve = true


# ---------------------------------------------------------------------------
# DANO / DESTRUIÇÃO
# ---------------------------------------------------------------------------

func _on_body_entered(_body: Node2D) -> void:
	if is_destroyed:
		return

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(0, 0),
		global_position,
		false
	)

	if _body is BaseCharacter:
		_body.update_health(attack_damage, self)

	_destroy_projectile()


func _on_interactable_area_entered(_area: Area2D) -> void:
	if not is_interactable or is_destroyed:
		return
	if _area is CharacterAttackArea:
		_interact(_area)


func _interact(_area) -> void:
	var _damage: int = _area.get_damaged()
	_health -= _damage
	if _health <= 0:
		_destroy_projectile(true, true)  # destruído pelo player: toca animação "Destroyed"


func _on_lifetime_timeout() -> void:
	if not is_destroyed:
		_destroy_projectile(false)  # expirou sozinho, não é colisão — sem hit_audio


func _destroy_projectile(play_hit_sound: bool = true, play_destroyed_anim: bool = false) -> void:
	if is_destroyed:
		return

	is_destroyed = true
	_is_moving = false

	if _idle_audio and _idle_audio.playing:
		_idle_audio.stop()

	if play_hit_sound and _hit_audio:
		_hit_audio.play()

	if _particle:
		_particle.emitting = false

	if _body_collision:
		_body_collision.set_deferred("disabled", true)

	if play_destroyed_anim and _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Destroyed"):
		_sprite.play("Destroyed")
		# Mesmo padrão do Sacerdote: usa duração calculada por frames/FPS ao
		# invés de animation_finished (que não dispara se a animação tiver loop).
		var duration: float = _get_animation_duration("Destroyed")
		if duration <= 0.0:
			duration = 0.5
		await get_tree().create_timer(duration).timeout

	queue_free()


func _get_animation_duration(anim_name: String) -> float:
	if not _sprite or not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(anim_name):
		return 0.0

	var frame_count: int = _sprite.sprite_frames.get_frame_count(anim_name)
	var speed: float = _sprite.sprite_frames.get_animation_speed(anim_name)

	if speed <= 0.0 or frame_count <= 0:
		return 0.0

	return float(frame_count) / speed
