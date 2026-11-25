extends Node2D
class_name ChainTail

@export_category("References")
@export var anchor: Marker2D
@export var character: CharacterBody2D
@export var sprite: AnimatedSprite2D

@export_category("Chain Settings")
@export var segment_count: int = 5
@export var segment_length_idle: float = 3.0
@export var segment_length_active: float = 6.0
@export var length_lerp_speed: float = 6.0
@export var rest_direction_idle: Vector2 = Vector2(0.0, 1.0)
@export var rest_direction_run: Vector2 = Vector2(0.8, 0.3)
@export var direction_lerp_speed: float = 8.0
@export var rest_curve_offset: Vector2 = Vector2(0.0, 0.0)

@export_category("Animation Offsets")
## Posição local do anchor durante Crounch
@export var anchor_pos_crounch: Vector2 = Vector2(0.0, 0.0)
## Posição local do anchor durante Rolling e RollingSpecial
@export var anchor_pos_rolling: Vector2 = Vector2(5.0, 0.0)

@export_category("Run Sway")
@export var run_speed_threshold: float = 10.0
@export var sway_amplitude: float = 6.0
@export var sway_frequency: float = 6.0

@export_category("Jump/Fall Lag")
@export var velocity_mult: Vector2 = Vector2(0.05, 0.15)
@export var max_lag: float = 6.0
@export var lag_smoothing: float = 8.0

@export_category("Chain Inertia")
@export var follow_speed: float = 14.0

@export_category("Visibilidade")
## Animações da Tola em que o cachecol some (ex.: descanso no save)
@export var hidden_animations: PackedStringArray = ["Rest", "Resting", "Rise", "Crounch", "AttackCrounch", "Attack_Crounch_Crit"]

@export_category("Render")
@export var rope_color: Color = Color.WHITE
@export var pixel_size_start: int = 2
@export var pixel_size_end: int = 1

var _points: Array[Vector2] = []
var _lag_offset: Vector2 = Vector2.ZERO
var _current_segment_length: float = 3.0
var _current_direction: Vector2 = Vector2(0.0, 1.0)
var _time: float = 0.0
var _anchor_base_pos: Vector2 = Vector2.ZERO

var _multimesh: MultiMesh
var _multimesh_instance: RID


func _ready() -> void:
	# ✅ Roda mesmo com o jogo pausado (o menu de save pausa o jogo): só para
	# poder esconder/mostrar. A física do cachecol continua congelada na pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var quad := QuadMesh.new()
	quad.size = Vector2(pixel_size_start, pixel_size_start)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad

	_multimesh_instance = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_multimesh_instance, get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(_multimesh_instance, 0)
	RenderingServer.canvas_item_set_z_index(_multimesh_instance, -1)

	if not anchor or not character:
		push_error("ChainTail: referências não configuradas!")
		return

	_anchor_base_pos = anchor.position

	_current_segment_length = segment_length_idle
	_current_direction = rest_direction_idle

	_points.resize(segment_count + 1)
	_points[0] = anchor.global_position
	for i in range(1, segment_count + 1):
		var curve := rest_curve_offset * float(i)
		_points[i] = _points[i - 1] + _current_direction.normalized() * _current_segment_length + curve


func _get_bresenham_points(from: Vector2, to: Vector2, px_size: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var x0 := int(round(from.x / px_size))
	var y0 := int(round(from.y / px_size))
	var x1 := int(round(to.x / px_size))
	var y1 := int(round(to.y / px_size))
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		points.append(Vector2(x0 * px_size, y0 * px_size))
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return points


func _mirrored_x(pos: Vector2) -> Vector2:
	# espelha o X da posição conforme o flip_h do sprite
	if sprite and sprite.flip_h:
		return Vector2(-pos.x, pos.y)
	return pos


func _update_anchor_position() -> void:
	if not sprite or not anchor:
		return

	var anim := sprite.animation

	match anim:
		"Crounch":
			anchor.position = _mirrored_x(anchor_pos_crounch)
		"Rolling", "RollingSpecial":
			anchor.position = _mirrored_x(anchor_pos_rolling)
		_:
			anchor.position = _mirrored_x(_anchor_base_pos)


func _process(delta: float) -> void:
	if not anchor or not character:
		return

	# ✅ Some durante o descanso; ao voltar, recomeça pendurado (sem "esticão")
	if sprite and hidden_animations.has(String(sprite.animation)):
		if visible:
			visible = false
		return
	if not visible:
		visible = true
		_reset_chain()

	# Pausado: mantém o cachecol parado, como antes
	if get_tree().paused:
		return

	_time += delta

	_update_anchor_position()

	_points[0] = anchor.global_position

	var vel: Vector2 = character.velocity
	var is_grounded: bool = character.is_on_floor()
	var is_running: bool = is_grounded and absf(vel.x) > run_speed_threshold
	var is_active: bool = is_running or not is_grounded

	# --- comprimento dinâmico ---
	var target_length: float = segment_length_active if is_active else segment_length_idle
	_current_segment_length = lerpf(_current_segment_length, target_length, length_lerp_speed * delta)

	# --- direção dinâmica ---
	var target_direction: Vector2
	if is_running:
		var trail_x: float = absf(rest_direction_run.x) * -signf(vel.x)
		target_direction = Vector2(trail_x, rest_direction_run.y)
	else:
		target_direction = rest_direction_idle
	_current_direction = _current_direction.lerp(target_direction, direction_lerp_speed * delta)

	# --- lag de salto/queda ---
	var target_lag := Vector2.ZERO
	if not is_grounded:
		target_lag.x = -vel.x * velocity_mult.x
		target_lag.y = -vel.y * velocity_mult.y
		target_lag = target_lag.clamp(Vector2(-max_lag, -max_lag), Vector2(max_lag, max_lag))
	_lag_offset = _lag_offset.lerp(target_lag, lag_smoothing * delta)

	# --- balanço de corrida ---
	var sway := Vector2.ZERO
	if is_running:
		sway.y = sin(_time * sway_frequency) * sway_amplitude

	for i in range(1, segment_count + 1):
		var weight: float = float(i) / float(segment_count)
		var dir := _current_direction.normalized()
		var curve := rest_curve_offset * float(i)
		var desired: Vector2 = _points[i - 1] + dir * _current_segment_length + curve + (_lag_offset + sway) * weight

		_points[i] = _points[i].lerp(desired, follow_speed * delta)

		var seg_dir: Vector2 = _points[i] - _points[i - 1]
		seg_dir = seg_dir.normalized() if seg_dir.length() > 0.001 else dir
		_points[i] = _points[i - 1] + seg_dir * _current_segment_length

	# --- renderização pixel-perfect ---
	var all_pixels: Array[Vector2] = []
	var all_sizes: Array[int] = []

	for i in range(segment_count):
		var t: float = float(i) / float(segment_count - 1) if segment_count > 1 else 0.0
		var px_size: int = roundi(lerp(float(pixel_size_start), float(pixel_size_end), t))
		px_size = maxi(px_size, 1)

		var seg_points := _get_bresenham_points(_points[i], _points[i + 1], px_size)

		if i > 0 and seg_points.size() > 0:
			seg_points.remove_at(0)

		for p in seg_points:
			all_pixels.append(p)
			all_sizes.append(px_size)

	if all_pixels.is_empty():
		RenderingServer.canvas_item_clear(_multimesh_instance)
		return

	_multimesh.instance_count = all_pixels.size()

	for i in range(all_pixels.size()):
		var px := float(all_sizes[i])
		var t := Transform2D()
		t = t.scaled(Vector2(px / float(pixel_size_start), px / float(pixel_size_start)))
		t.origin = to_local(all_pixels[i])
		_multimesh.set_instance_transform_2d(i, t)
		_multimesh.set_instance_color(i, rope_color)

	RenderingServer.canvas_item_clear(_multimesh_instance)
	RenderingServer.canvas_item_add_multimesh(_multimesh_instance, _multimesh.get_rid())


func _reset_chain() -> void:
	_update_anchor_position()
	_lag_offset = Vector2.ZERO
	_current_segment_length = segment_length_idle
	_current_direction = rest_direction_idle
	_points[0] = anchor.global_position
	for i in range(1, _points.size()):
		var curve := rest_curve_offset * float(i)
		_points[i] = _points[i - 1] + _current_direction.normalized() * _current_segment_length + curve


func _exit_tree() -> void:
	RenderingServer.free_rid(_multimesh_instance)
