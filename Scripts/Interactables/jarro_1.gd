extends InteractableComponent
class_name Jarro

func _get_interactable_items() -> Dictionary:
	return {
		"small_shards": {
			"name": "Small Shards",
			"path": "res://sprites/Items/small_fragment.png",
			"type":"resource",
			"description": "A small shard, sells for money",
			"value": 1,
			"spawn_probability": 0.80, #80%
			"amount_to_drop": [1, 5]
		},
		
		"medium_shards":{
			"name": "Medium Shards",
			"path": "res://sprites/Items/medium_fragment.png",
			"type":"resource",
			"description": "A shard, sells for money",
			"value": 10,
			"spawn_probability": 0.15, #15%
			"amount_to_drop": [1, 2]
		},
		
	}
