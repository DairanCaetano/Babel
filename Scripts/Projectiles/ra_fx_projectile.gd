extends Area2D
class_name RaFxProjectile

# Projétil de FX do Rá (usado pelas cenas ra_attack_2_fx.tscn e ra_attack_3_fx.tscn).
# Nasce no ponto zero do Rá, fica parado (speed = 0) e liga a área de dano
# só nos frames definidos abaixo. Quando a animação termina, some.
#
# Os frames são contados a partir de 0, igual ao Godot (frame 0 = primeiro).

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _collision: CollisionShape2D
@export var _hit_audio: AudioStreamPlayer

@export_category("Variables")
@export var _attack_damage: int = 10
@export var _animation_name: String = "Default"
@export var _active_frame_start: int = 1   # primeiro frame com dano (contando de 0)
@export var _active_frame_end: int = 2     # último frame com dano (contando de 0)
@export var _speed: float = 0.0            # 0 = parado no lugar onde nasceu

@export_category("Áudio")
@export var _sound: AudioStream            # som do golpe (vazio = sem som)
@export var _sound_frame: int = -1         # frame em que o som toca (contando de 0); -1 = não toca
@export var _sound_volume_db: float = 0.0

var _direction: float = 1.0
var _has_hit: bool = false
var _sound_played: bool = false

# Posição da colisão no estado padrão (flip_h = false, como foi desenhado).
# É lida do editor no _ready, então é só posicionar a Collision na cena.
var _collision_default_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if not _texture:
		_texture = get_node_or_null("Texture")
	if not _collision:
		_collision = get_node_or_null("Collision")

	if _collision:
		_collision_default_pos = _collision.position
		_collision.disabled = true

	body_entered.connect(_on_body_entered)

	if _texture:
		_texture.frame_changed.connect(_on_frame_changed)
		_texture.animation_finished.connect(_on_animation_finished)
		_texture.stop()   # volta pro frame 0 (a cena pode ter sido salva parada em outro frame)
		_texture.play(_animation_name)
		_on_frame_changed()   # aplica a regra de dano já no frame 0

	_apply_facing()


# Chamado pelo Rá logo depois de instanciar.
# mirror: 1.0 = igual ao desenho (flip_h = false), -1.0 = espelhado
func setup(mirror: float) -> void:
	_direction = 1.0 if mirror >= 0.0 else -1.0
	_apply_facing()


func _apply_facing() -> void:
	if _texture:
		_texture.flip_h = _direction < 0.0
	if _collision:
		_collision.position = Vector2(_collision_default_pos.x * _direction, _collision_default_pos.y)


func _physics_process(delta: float) -> void:
	if _speed != 0.0:
		global_position.x += _direction * _speed * delta


func _on_frame_changed() -> void:
	var frame_number: int = _texture.frame

	if not _sound_played and _sound and _sound_frame >= 0 and frame_number >= _sound_frame:
		_sound_played = true
		_play_sound()

	if not _collision:
		return

	var active: bool = frame_number >= _active_frame_start and frame_number <= _active_frame_end
	_collision.set_deferred("disabled", not active)


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return

	if body is BaseCharacter:
		_has_hit = true
		if _hit_audio:
			_hit_audio.play()
		body.update_health(_attack_damage, self)


func _on_animation_finished() -> void:
	queue_free()


# O player de áudio fica FORA do FX (no pai dele): o FX some ao fim da animação,
# e o som cortaria no meio. Ele se apaga sozinho quando o som termina.
func _play_sound() -> void:
	var host: Node = get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _sound
	player.volume_db = _sound_volume_db
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	host.add_child(player)
	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)
