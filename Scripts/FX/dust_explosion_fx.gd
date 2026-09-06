extends Node2D

@export var _texture: AnimatedSprite2D

func _ready() -> void:
	_texture.play("Action")
	await _texture.animation_finished
	queue_free()
