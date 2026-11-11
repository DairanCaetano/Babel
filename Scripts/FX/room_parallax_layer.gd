extends Node2D
class_name RoomParallaxLayer
## Parallax em PERSPECTIVA dentro de uma sala, com a Tola como "olho".
## A camada desliza na direção da Tola, proporcional à distância entre ela
## e o ponto de âncora (anchor_x). Com a Tola exatamente na âncora, a camada
## fica onde foi desenhada no editor.
## Uso nas pilastras: desenhe cada trio ALINHADO (uma atrás da outra) e ponha
## a âncora no centro do trio. Quanto mais ao fundo, maior o follow_x.

## CameraZone da sala: o efeito só é calculado com a Tola dentro dela (+ margem)
@export var room_zone: Node2D
## X (no mundo) onde a camada fica alinhada. 0 = centro da sala
@export var anchor_x: float = 0.0
## Quanto a camada acompanha a Tola na horizontal (0 = parada)
@export_range(0.0, 1.0, 0.01) var follow_x: float = 0.25
## Quanto acompanha na vertical, em relação ao centro da sala (0 = desligado)
@export_range(0.0, 1.0, 0.01) var follow_y: float = 0.0
## Limite SUAVE em px (x, y): perto dele o movimento vai ficando mais lento,
## mas nunca para de vez (a camada nunca fica totalmente parada)
@export var max_offset: Vector2 = Vector2(128, 32)
## Quando a Tola passa da âncora em direção à BORDA da sala, a camada se move
## só esta fração (o trio do lado da borda se abre pouco para fora)
@export_range(0.0, 1.0, 0.01) var outward_ratio: float = 0.35
## Suaviza o começo do movimento: com a Tola perto da âncora (pilastras próximas
## dela), a camada se move devagar e vai ganhando velocidade com a distância.
## Fração do max_offset (0 = desligado, maior = começo mais lento)
@export_range(0.0, 2.0, 0.05) var near_softness: float = 0.5
## Margem (px) além da sala em que o efeito ainda é calculado
@export var active_margin: float = 240.0

var _base_position: Vector2
var _room_center: Vector2
var _room_rect: Rect2
var _has_room: bool = false

func _ready() -> void:
	_base_position = position
	_compute_room()

func _compute_room() -> void:
	if room_zone == null:
		push_warning("RoomParallaxLayer: configure a room_zone em " + name)
		return
	var _shape_node: CollisionShape2D = room_zone.get_node_or_null("Collision") as CollisionShape2D
	if _shape_node and _shape_node.shape is RectangleShape2D:
		var _size: Vector2 = (_shape_node.shape as RectangleShape2D).size * _shape_node.global_scale.abs()
		_room_center = _shape_node.global_position
		_room_rect = Rect2(_room_center - _size / 2.0, _size)
	else:
		_room_center = room_zone.global_position
		_room_rect = Rect2(_room_center, Vector2.ZERO)
	if anchor_x == 0.0:
		anchor_x = _room_center.x
	_has_room = true

func _get_eye() -> Variant:
	# Olho = Tola; sem ela, usa o centro da câmera
	if global.character and is_instance_valid(global.character):
		return global.character.global_position
	var _camera: Camera2D = get_viewport().get_camera_2d()
	if _camera:
		return _camera.get_screen_center_position()
	return null

func _process(_delta: float) -> void:
	if not _has_room:
		return
	var _eye = _get_eye()
	if _eye == null:
		return
	# Longe da sala: não faz nada (mantém o último deslocamento)
	if not _room_rect.grow(active_margin).has_point(_eye):
		return
	var _dist_x: float = _eye.x - anchor_x
	# Tola entre a âncora e a borda mais próxima: move menos (para fora)
	var _outward_sign: float = signf(anchor_x - _room_center.x)
	if _outward_sign != 0.0 and signf(_dist_x) == _outward_sign:
		_dist_x *= outward_ratio
	var _offset: Vector2 = Vector2(
		_soft_limit(_ease_in(_dist_x * follow_x, max_offset.x * near_softness), max_offset.x),
		_soft_limit((_eye.y - _room_center.y) * follow_y, max_offset.y)
	)
	# Pixels inteiros: a pixel art não treme
	position = _base_position + _offset.round()

## Limite suave: cresce quase linear no começo e vai desacelerando perto do
## limite, sem nunca parar (curva tanh)
func _soft_limit(value: float, limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	return limit * tanh(value / limit)

## Começo suave: perto de zero o valor cresce devagar; longe, quase linear
func _ease_in(value: float, softness: float) -> float:
	if softness <= 0.0:
		return value
	var _abs: float = absf(value)
	return value * _abs / (_abs + softness)
