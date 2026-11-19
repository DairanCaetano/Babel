extends ProjectileComponent
class_name ProjectileBerith4

## Projétil do Ataque 4 do Baal Berith.
## Anda em linha reta na direção recebida em setup() e gira o sprite
## para ficar alinhado com essa direção.
## Atravessa o cenário, acerta só o player e pode ser destruído pelo ataque do Tola
## (grupo "destructible_objects" + máscara na camada do ataque do player).

@export_category("Objects")
@export var texture: AnimatedSprite2D

@export_category("Variables")
@export var attack_damage: int = 10
## Tempo máximo de vida (s) caso não bata em nada
@export var lifetime: float = 4.0
## A arte do projétil aponta para a esquerda (rastro à direita)
@export var art_faces_left: bool = true
## FX quando o projétil acerta o Tola (explode no ponto do impacto)
@export var hit_fx_scene: PackedScene
## FX opcional quando o ataque do Tola destrói o projétil
@export var destroy_fx_scene: PackedScene

@export_category("Sound")
## Som tocado quando o projétil é instanciado
@export var spawn_sound: AudioStream
@export var spawn_sound_volume_db: float = 0.0
@export var spawn_pitch_min: float = 0.95
@export var spawn_pitch_max: float = 1.05
## Ajuste (dB) no som de impacto do próprio Tola ao acertar este projétil.
## Negativo = mais baixo, para o som de destruição do projétil ficar em destaque.
@export var player_hit_sound_offset_db: float = -10.0
## Som tocado quando o ataque do Tola destrói o projétil
@export var destroy_sound: AudioStream
@export var destroy_sound_volume_db: float = 0.0
@export var destroy_pitch_min: float = 0.9
@export var destroy_pitch_max: float = 1.1

var _hit: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if texture:
		texture.play("Active")
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)
	add_to_group("destructible_objects")
	area_entered.connect(_on_area_entered)
	_play_sound_here(spawn_sound, spawn_sound_volume_db, spawn_pitch_min, spawn_pitch_max)

func setup(new_direction: Vector2, speed: float) -> void:
	direction = new_direction.normalized()
	if speed > 0.0:
		_move_speed = speed
	rotation = direction.angle() - (PI if art_faces_left else 0.0)

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	if body is BaseCharacter:
		_spawn_hit_fx(body)
		body.update_health(attack_damage, self)
	queue_free()

func _spawn_hit_fx(target: Node2D) -> void:
	if not hit_fx_scene:
		return
	var host: Node = get_parent() if get_parent() else target
	var fx := hit_fx_scene.instantiate()
	host.add_child(fx)
	if fx is Node2D:
		fx.global_position = global_position

# Ataque do Tola destrói o projétil
func _on_area_entered(area: Area2D) -> void:
	if _hit or not area.is_in_group("player_attack"):
		return
	_hit = true
	_play_sound_here(destroy_sound, destroy_sound_volume_db, destroy_pitch_min, destroy_pitch_max)
	if destroy_fx_scene and get_parent():
		var fx := destroy_fx_scene.instantiate()
		get_parent().add_child(fx)
		if fx is Node2D:
			fx.global_position = global_position
			fx.rotation = rotation  # mesmo ângulo do projétil
	queue_free()

# O som fica no pai para não ser cortado quando o projétil some
func _play_sound_here(stream: AudioStream, volume_db: float, pitch_min: float, pitch_max: float) -> void:
	if not stream:
		return
	var host := get_parent()
	if not host:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	player.bus = "SFX"
	host.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()
