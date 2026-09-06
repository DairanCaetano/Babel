extends AnimatedSprite2D
class_name BaseEffect

func _ready():
	play()

func _on_animation_finished() -> void:
	queue_free()
