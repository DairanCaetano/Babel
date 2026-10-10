extends Node2D
class_name RaArena

# Sala do chefe Rá.
# Fica NA FASE (não dentro do Rá). Os filhos são Marker2D comuns, sem código:
# arraste cada um para o lugar certo no mapa com "Editable Children" ligado.
#
# Pontos onde o Rá pode surgir (a posição do marker = o CENTRO do Rá,
# ~60px acima do chão, porque o sprite é centralizado):
#   Left / Center / Right
# Pontos de onde os pilares do Ataque 1 nascem (NO CHÃO — a origem do pilar
# fica na base). A sala é dividida em duas metades pelo PillarCenter: os pilares
# saem só das pontas da metade onde o player está.
#   PillarLeft / PillarCenter / PillarRight
# Centro da fileira de lanças do Rá-Pássaro (fase 2):
#   SpearLine

enum Point { LEFT = 0, CENTER = 1, RIGHT = 2 }

const NO_POINT: int = -1

@export_category("Objects")
@export var _left: Marker2D
@export var _center: Marker2D
@export var _right: Marker2D
@export var _pillar_left: Marker2D
@export var _pillar_center: Marker2D  # divide a sala em duas metades para o Ataque 1
@export var _pillar_right: Marker2D
@export var _spear_line: Marker2D   # centro da fileira de lanças do pássaro (altura onde elas surgem)


func _ready() -> void:
	add_to_group("ra_arena")

	# Fallback por nome, caso os exports não tenham sido ligados no inspector
	if not _left:
		_left = get_node_or_null("Left")
	if not _center:
		_center = get_node_or_null("Center")
	if not _right:
		_right = get_node_or_null("Right")
	if not _pillar_left:
		_pillar_left = get_node_or_null("PillarLeft")
	if not _pillar_right:
		_pillar_right = get_node_or_null("PillarRight")
	if not _pillar_center:
		_pillar_center = get_node_or_null("PillarCenter")
	if not _spear_line:
		_spear_line = get_node_or_null("SpearLine")


func get_point_position(point: int) -> Vector2:
	match point:
		Point.LEFT:
			return _left.global_position
		Point.CENTER:
			return _center.global_position
		Point.RIGHT:
			return _right.global_position
	return _center.global_position


func is_edge(point: int) -> bool:
	return point == Point.LEFT or point == Point.RIGHT


func opposite_edge(point: int) -> int:
	if point == Point.LEFT:
		return Point.RIGHT
	if point == Point.RIGHT:
		return Point.LEFT
	return NO_POINT


func get_random_point_except(except_point: int) -> int:
	var options: Array[int] = [Point.LEFT, Point.CENTER, Point.RIGHT]
	options.erase(except_point)
	return options.pick_random()


# Ponto de nascimento do pilar no lado pedido (LEFT ou RIGHT).
# Se os markers de pilar não existirem, usa os markers Left/Right do Rá.
func get_pillar_spawn(side: int) -> Vector2:
	if side == Point.LEFT:
		return _pillar_left.global_position if _pillar_left else _left.global_position
	return _pillar_right.global_position if _pillar_right else _right.global_position


# Centro dos pilares. Sem o marker, usa o meio entre PillarLeft e PillarRight.
func get_pillar_center() -> Vector2:
	if _pillar_center:
		return _pillar_center.global_position
	return (get_pillar_spawn(Point.LEFT) + get_pillar_spawn(Point.RIGHT)) * 0.5


# As duas pontas da metade da sala onde x está: [ponta esquerda, ponta direita]
#   x à esquerda do centro → [PillarLeft, PillarCenter]
#   x à direita do centro  → [PillarCenter, PillarRight]
func get_pillar_lane(x: float) -> Array[Vector2]:
	var center: Vector2 = get_pillar_center()
	if x < center.x:
		return [get_pillar_spawn(Point.LEFT), center]
	return [center, get_pillar_spawn(Point.RIGHT)]


# Limites horizontais da sala (usado pra não deixar o mergulho do Ataque 4 sair da arena)
func get_min_x() -> float:
	return _left.global_position.x


func get_max_x() -> float:
	return _right.global_position.x


# Centro da fileira de lanças do Rá-Pássaro. Sem o marker, usa 120px acima do Center.
func get_spear_line() -> Vector2:
	if _spear_line:
		return _spear_line.global_position
	return _center.global_position + Vector2(0, -120)
