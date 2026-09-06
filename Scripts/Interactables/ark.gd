extends InteractableComponent
class_name Ark

var _can_interact: bool = true
var _body_in_range: BaseCharacter

@export_category("Objects AX")
@export var _lifetime: Timer

func _on_interactable_area_entered(_area: Area2D) -> void:
	if not _is_interactable:
		return

func _on_body_entered(_body: Node2D) -> void:
	if _body is BaseCharacter:
		_body_in_range = null


func _on_body_exited(_body: Node2D) -> void:
	if _body_in_range != null and _can_interact:
		if Input.is_action_just_pressed("attack"):
			#print("interagindo com o: " + str(_body_in_range))
			_can_interact = false
			_sprite.play("Open")


func _on_texture_animation_finished() -> void:
	if _sprite.animation == "Open":
		_lifetime.start()


func _on_lifetime_timeout() -> void:
	queue_free()
	pass # Replace with function body.
