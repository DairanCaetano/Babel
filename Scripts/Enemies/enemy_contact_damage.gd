extends Area2D
class_name EnemyContactDamage

@export_category("Damage Settings")
@export var _contact_damage: int = 10

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_body.update_health(_contact_damage, get_parent())
