extends Area2D
class_name RaAttackArea

# Área de dano de um golpe do Rá (Shoryuken, deslize do Ataque 6, mergulho do Ataque 4).
# O Rá liga/desliga com activate()/deactivate(). Cada ativação acerta o player no máximo 1 vez.

@export_category("Objects")
@export var _collision: CollisionShape2D

@export_category("Variables")
@export var _attack_damage: int = 10

@export_category("EnemySound")
@export var _damage_audio: AudioStreamPlayer

var _has_hit: bool = false


func _ready() -> void:
	if not _collision:
		for child in get_children():
			if child is CollisionShape2D:
				_collision = child
				break

	body_entered.connect(_on_body_entered)
	deactivate()


func activate() -> void:
	_has_hit = false
	if _collision:
		_collision.set_deferred("disabled", false)


func deactivate() -> void:
	if _collision:
		_collision.set_deferred("disabled", true)


func is_active() -> bool:
	return _collision != null and not _collision.disabled


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return

	if body is BaseCharacter:
		_has_hit = true
		if _damage_audio:
			_damage_audio.play()
		body.update_health(_attack_damage, get_parent())
