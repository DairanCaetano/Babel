extends Area2D
class_name CollectableComponent

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_consume(_body)
		
		
func _consume(_body: BaseCharacter) -> void:
	pass
