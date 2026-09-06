extends Area2D
class_name EnemyAttackArea

@export_category("Variables")
@export var _attack_damage: int = 10

@export_category("EnemySound")
@export var _damage_audio: AudioStreamPlayer

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		# ✅ TOCAR SOM DE DANO (quando acerta o jogador)
		if _damage_audio:
			_damage_audio.play()
			print("🎯 Som de dano do inimigo tocado!")
		
		_body.update_health(_attack_damage, get_parent())
