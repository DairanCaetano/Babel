class_name HazardBlocker
extends AnimatableBody2D

@export var speed: float = 80.0
@export var patrol_distance: float = 150.0
@export var moves: bool = true

var _start_position: Vector2
var _direction: int = 1


func _ready() -> void:
	_start_position = global_position


func _physics_process(delta: float) -> void:
	if not moves:
		return

	var traveled: float = global_position.x - _start_position.x

	if traveled >= patrol_distance:
		_direction = -1
	elif traveled <= 0.0:
		_direction = 1

	global_position.x += speed * _direction * delta
