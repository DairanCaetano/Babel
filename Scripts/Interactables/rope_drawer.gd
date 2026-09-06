extends Node2D
class_name PendulumRope

@export_category("References")
@export var anchor: Marker2D
@export var bob: RigidBody2D

@export_category("Rope Settings")
@export var rope_color: Color = Color.WHITE
@export var pixel_size: int = 2

var _multimesh: MultiMesh
var _multimesh_instance: RID

func _ready() -> void:
	# cria o multimesh independente das referências
	var quad := QuadMesh.new()
	quad.size = Vector2(pixel_size, pixel_size)
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	
	_multimesh_instance = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_multimesh_instance, get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(_multimesh_instance, 0)
	
	# verifica referências separado
	if not anchor or not bob:
		push_error("PendulumRope: referências não configuradas!")


func _get_bresenham_points(from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []

	var x0 := int(round(from.x / pixel_size))
	var y0 := int(round(from.y / pixel_size))
	var x1 := int(round(to.x / pixel_size))
	var y1 := int(round(to.y / pixel_size))

	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy

	while true:
		points.append(Vector2(x0 * pixel_size, y0 * pixel_size))
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

func _process(_delta: float) -> void:
	if not anchor or not bob:
		return
	
	var points := _get_bresenham_points(anchor.global_position, bob.global_position)
	
	_multimesh.instance_count = points.size()
	
	for i in range(points.size()):
		var t := Transform2D()
		t.origin = to_local(points[i])  # <- conversão para espaço local
		_multimesh.set_instance_transform_2d(i, t)
		_multimesh.set_instance_color(i, rope_color)
	
	RenderingServer.canvas_item_clear(_multimesh_instance)
	RenderingServer.canvas_item_add_multimesh(_multimesh_instance, _multimesh.get_rid())

func _exit_tree() -> void:
	RenderingServer.free_rid(_multimesh_instance)
