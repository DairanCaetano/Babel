extends Node2D

@export_enum("left", "right") var start_side: String = "left"
@export var rope_length: float = 120.0
@export var swing_speed: float = 1.2
@export var max_angle: float = 45.0

@export_category("References")
@export var pivot: Marker2D
@export var bob: RigidBody2D

var _time: float = 0.0

func _ready() -> void:
	if start_side == "right":
		_time = PI

func _process(delta: float) -> void:
	if not pivot or not bob:
		return

	_time += delta * swing_speed
	var angle := deg_to_rad(max_angle) * sin(_time)
	var offset := Vector2(sin(angle), cos(angle)) * rope_length

	bob.global_position = pivot.global_position + offset
