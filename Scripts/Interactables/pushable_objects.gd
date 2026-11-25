extends CharacterBody2D
class_name PushableObjects

const PUSH_SPEED = 100.0
const ACCELERATION = 600.0
const FRICTION = 0.75
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_hanging: bool = false
var is_being_pushed: bool = false

# ===== ENCOLHER AO EMPURRAR =====
# Enquanto é empurrada (ou cai), a colisão fica PUSH_SHRINK px mais baixa, com a base
# no mesmo lugar: assim a caixa passa por aberturas da mesma altura dela (ex.: 32x32).
# Parada e apoiada, volta ao tamanho cheio — só se houver espaço livre em cima.
## Quanto a altura da colisão diminui enquanto é empurrada (px)
@export var push_shrink: float = 1.0
## Tempo sem ser empurrada (s) antes de voltar ao tamanho cheio
@export var regrow_delay: float = 0.15

var _col: CollisionShape2D = null
var _shape: RectangleShape2D = null
var _full_size: Vector2 = Vector2.ZERO
var _base_pos_y: float = 0.0
var _is_shrunk: bool = false
var _time_since_push: float = 0.0


func _ready() -> void:
	_col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _col and _col.shape is RectangleShape2D:
		# Cópia própria: o shape da cena é compartilhado entre todas as caixas
		_shape = (_col.shape as RectangleShape2D).duplicate()
		_col.shape = _shape
		_full_size = _shape.size
		_base_pos_y = _col.position.y


func _physics_process(delta):
	velocity.y += gravity * delta
	
	if not is_being_pushed:
		velocity.x *= FRICTION
		if abs(velocity.x) < 5.0:
			velocity.x = 0
		_time_since_push += delta
	else:
		_time_since_push = 0.0
	
	is_being_pushed = false
	move_and_slide()
	
	# Parada, apoiada e sem empurrão há um tempinho: tenta voltar ao tamanho cheio
	if _is_shrunk and is_on_floor() and velocity.x == 0.0 and _time_since_push >= regrow_delay:
		_try_regrow()


func slide_object(direction):
	is_being_pushed = true
	_time_since_push = 0.0
	_shrink()
	var target_speed = direction.x * PUSH_SPEED
	velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * get_physics_process_delta_time())


func apply_lift() -> void:
	global_position.y -= 9.0
	set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	set_physics_process(true)


func _shrink() -> void:
	if _is_shrunk or _shape == null:
		return
	_shape.size.y = _full_size.y - push_shrink
	_col.position.y = _base_pos_y + push_shrink * 0.5   # base continua no mesmo lugar
	_is_shrunk = true


func _try_regrow() -> void:
	if _shape == null or not _top_strip_is_free():
		return
	_shape.size.y = _full_size.y
	_col.position.y = _base_pos_y
	_is_shrunk = false


func _top_strip_is_free() -> bool:
	# Confere só a faixa de cima que a caixa vai ocupar ao crescer
	var strip := RectangleShape2D.new()
	strip.size = Vector2(maxf(_full_size.x - 4.0, 1.0), maxf(push_shrink - 0.2, 0.1))
	var top_y := _base_pos_y - _full_size.y * 0.5          # topo da caixa cheia (local)
	var center_y := top_y + push_shrink * 0.5               # meio da faixa nova
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = strip
	query.transform = Transform2D(0.0, global_position + Vector2(_col.position.x, center_y))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
