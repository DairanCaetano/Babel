extends Node2D
class_name BronzeGate

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var door_collision: StaticBody2D
@export var interaction_area: Area2D

@export_category("Audio")
@export var open_gate_audio: AudioStreamPlayer2D
@export var hidden_area_audio: AudioStreamPlayer2D

var player_in_range: bool = false
var is_open: bool = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Garantir que começa fechado
	texture.play("Closed")

func _process(_delta: float) -> void:
	if player_in_range and not is_open:
		if Input.is_action_just_pressed("move_up"):
			open_gate()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func open_gate() -> void:
	if is_open:
		return
	
	is_open = true
	
	texture.play("Open")
	
	# Tocar efeitos sonoros
	if open_gate_audio:
		open_gate_audio.play()
	
	if hidden_area_audio:
		hidden_area_audio.play()
	
	disable_collision()

func disable_collision() -> void:
	door_collision.set_collision_layer_value(5, false)
	door_collision.set_collision_mask_value(1, false)
