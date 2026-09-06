extends Area2D
class_name BerithAttackImpactArea

@export_category("Variables")
@export var _attack_damage: int = 10

@export_category("EnemySound")
@export var _damage_audio: AudioStreamPlayer

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		if _damage_audio:
			_damage_audio.play()
		
		_body.update_health(_attack_damage, get_parent())
