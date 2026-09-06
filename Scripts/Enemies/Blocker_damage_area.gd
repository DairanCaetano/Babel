extends Area2D
class_name HazardDamageArea

@export_category("Variables")
@export var _attack_damage: int = 10
@export_category("EnemySound")
@export var _damage_audio: AudioStreamPlayer


func _on_body_entered(body: Node2D) -> void:
	if not body is BaseCharacter:
		return

	if _is_dashing(body):
		return

	if _damage_audio:
		_damage_audio.play()
		print("🎯 Som de dano do inimigo tocado!")

	body.update_health(_attack_damage, get_parent())


func _is_dashing(player: Node) -> bool:
	if player.has_method("is_dashing"):
		return player.is_dashing()
	return false
