extends Node
class_name Main

func _ready() -> void:
	# Primeira cena do jogo
	get_tree().change_scene_to_file("res://Scenes/Menu/start_cosmos_logo.tscn")
