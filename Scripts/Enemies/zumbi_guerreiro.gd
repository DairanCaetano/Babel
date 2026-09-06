extends BaseEnemy
class_name ZumbiGuerreiro

@export var _fire_1: GPUParticles2D

func _attack() -> void:
	if not is_instance_valid(_player_in_range):
		return
		
	if _player_in_range.is_player_alive():
		_enemy_texture.action_animate("Attack_Anticipation")

func _get_drop_tems() -> Dictionary:
	return {
		"small_shards":{
			"name": "Small Shards",
			"path": "res://sprites/Items/small_fragment.png",
			"type":"resource",
			"description": "Descrição aqui",
			"value": 5,
			"spawn_probability": 0.95 #95%
		},
	}

func _kill() -> void:
	super()
	
	_fire_1.visible = true
	# Verifica se existe o _enemy_texture e tenta acessar a área de ataque específica do zumbi
	if _enemy_texture is EnemyTexture and _enemy_texture.has_method("disable_attack_area"):
		_enemy_texture.disable_attack_area()
	elif _enemy_texture is EnemyTexture and _enemy_texture.get("_atack_area_collision") != null:
		_enemy_texture._atack_area_collision.disabled = true
