@tool
extends GodRays
class_name DoorLightRays
## Raios de luz saindo de uma porta de chefe (feito para o Rá, o chefe do sol).
## - Porta fechada: só um fio de luz (closed_opacity)
## - Animação "Open": o leque se abre quadro a quadro junto com a porta
## - Animação "Closing": recolhe junto com a porta
## - Chefe resolvido (derrota ou aliança): fica aberto PARA SEMPRE
##   (inclusive ao recarregar a fase, quando a porta nem existe mais)
## A largura da área (size.x) é a altura da porta; size.y é o alcance.
## Gire o nó 90° (sai para a esquerda) ou -90° (sai para a direita).

@export_category("Porta")
## Mesmo boss_id da porta (ex.: "ra")
@export var boss_id: String = "ra"
## A BossDoor que controla os raios
@export var door: Node2D
## Altura da porta em px (vira a largura do leque)
@export var door_height: int = 144:
	set(v):
		door_height = maxi(v, 1)
		_apply_progress()
## Alcance dos raios com a porta totalmente aberta (px)
@export var reach_open: int = 240:
	set(v):
		reach_open = maxi(v, 1)
		_apply_progress()
## Alcance com a porta fechada (o fio de luz)
@export var reach_closed: int = 24:
	set(v):
		reach_closed = maxi(v, 1)
		_apply_progress()
@export_range(0.0, 1.0, 0.01) var opacity_closed: float = 0.1:
	set(v):
		opacity_closed = v
		_apply_progress()
@export_range(0.0, 1.0, 0.01) var opacity_open: float = 1.0:
	set(v):
		opacity_open = v
		_apply_progress()
## Inclinação do leque com a porta fechada e aberta (gira enquanto abre)
@export_range(-1.5, 1.5, 0.01) var angle_closed: float = 0.0:
	set(v):
		angle_closed = v
		_apply_progress()
@export_range(-1.5, 1.5, 0.01) var angle_open: float = 0.0:
	set(v):
		angle_open = v
		_apply_progress()
## Curva da abertura (1 = linear, maior = começa devagar, menor = começa rápido)
@export_range(0.2, 4.0, 0.05) var open_curve: float = 1.5
## Tempo para abrir de vez quando o chefe é derrotado (s)
@export var resolved_open_time: float = 1.2
## Só no editor: mostra os raios abertos (para posicionar) ou fechados
@export var editor_preview_open: bool = true:
	set(v):
		editor_preview_open = v
		if Engine.is_editor_hint():
			_progress = 1.0 if v else 0.0
			_apply_progress()

var _progress: float = 0.0
var _resolved: bool = false
var _door_sprite: AnimatedSprite2D

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		_progress = 1.0 if editor_preview_open else 0.0
		_apply_progress()
		return
	if boss_id != "" and BossEventManager.is_boss_resolved(boss_id):
		_resolved = true
		_progress = 1.0
		_apply_progress()
		return
	_progress = 0.0
	_apply_progress()
	BossEventManager.boss_resolved.connect(_on_boss_resolved)
	if door and is_instance_valid(door):
		_door_sprite = door.get("texture") as AnimatedSprite2D
		if _door_sprite == null:
			_door_sprite = door.get_node_or_null("Texture") as AnimatedSprite2D
	if _door_sprite:
		_door_sprite.frame_changed.connect(_on_door_frame)
		_door_sprite.animation_changed.connect(_on_door_frame)
	else:
		push_warning("DoorLightRays: configure a porta (door) em " + name)

func _on_door_frame() -> void:
	if _resolved or _door_sprite == null or not is_instance_valid(_door_sprite):
		return
	var _anim: StringName = _door_sprite.animation
	var _count: int = _door_sprite.sprite_frames.get_frame_count(_anim) if _door_sprite.sprite_frames else 1
	var _t: float = float(_door_sprite.frame + 1) / float(maxi(_count, 1))
	match _anim:
		&"Open":
			_progress = _t
		&"Closing":
			_progress = 1.0 - _t
		&"Closed":
			_progress = 0.0
		_:
			return
	_apply_progress()

func _on_boss_resolved(resolved_id: String) -> void:
	if resolved_id != boss_id or _resolved:
		return
	_resolved = true
	var _tween: Tween = create_tween()
	_tween.tween_method(_set_progress, _progress, 1.0, resolved_open_time)

func _set_progress(value: float) -> void:
	_progress = value
	_apply_progress()

func _apply_progress() -> void:
	if not is_node_ready():
		return
	var _e: float = ease(clampf(_progress, 0.0, 1.0), open_curve)
	size = Vector2i(door_height, roundi(lerpf(float(reach_closed), float(reach_open), _e)))
	opacity = lerpf(opacity_closed, opacity_open, _e)
	angle = lerpf(angle_closed, angle_open, _e)
