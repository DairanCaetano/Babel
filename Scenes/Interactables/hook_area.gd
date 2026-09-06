extends Area2D
class_name HookArea

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		body.apply_dash_impulse(body.global_position.direction_to(global_position))
		print(body)
