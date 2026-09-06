extends BaseEnemy
class_name Zumbi


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
