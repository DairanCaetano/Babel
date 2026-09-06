class_name SpearTrap
extends RigidBody2D

@export var animation_player: AnimationPlayer
@export var animated_sprite: AnimatedSprite2D
@export var trigger_area: Area2D
@export var lift_area: Area2D

@export var lift_impulse: float = -350.0

var _triggered: bool = false
var _is_attacking: bool = false


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	lift_area.body_entered.connect(_on_lift_area_body_entered)
	lift_area.monitoring = false


func _on_trigger_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _triggered:
		_triggered = true
		animation_player.play("Activate")


func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Activate":
			_is_attacking = true
			lift_area.monitoring = true   # ← liga colisão de lift
			animation_player.play("Attack")
		"Attack":
			_is_attacking = false
			lift_area.monitoring = false  # ← desliga colisão de lift
			animation_player.play("Deactivate")
		"Deactivate":
			_triggered = false
			animation_player.play("Idle")


func _on_lift_area_body_entered(body: Node2D) -> void:
	if body is PushableObjects:
		body.apply_lift()
