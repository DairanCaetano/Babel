# azazel_intro_npc.gd
extends CharacterBody2D

@onready var _sprite: AnimatedSprite2D = $Texture

func play_arrive(flipped: bool = false) -> void:
	_sprite.flip_h = flipped
	_sprite.play("Arrive")
	await _sprite.animation_finished
	_sprite.flip_h = flipped
	_sprite.play("Idle")

func play_gone() -> void:
	_sprite.play("Gone")
	await _sprite.animation_finished
