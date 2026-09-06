extends Node2D
class_name HangingBox

@export_category("References")
@export var rope_anchor: StaticBody2D
@export var pushable_box: CharacterBody2D  # ← MUDOU AQUI
@export var rope_visual: Node2D

func _ready() -> void:
	if not rope_anchor or not pushable_box:
		push_error("❌ HangingBox: Configure as referências no Inspector!")
		return
	
	print("✅ HangingBox configurado")
