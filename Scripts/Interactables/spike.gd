extends InteractableComponent
class_name Spike

@export_category("Variables")
@export var _damage: int = 5

func _on_body_entered(_body: Node2D) -> void:
	if _body is BaseCharacter:
		_body.update_health(_damage, self)
