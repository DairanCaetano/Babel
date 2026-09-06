extends Area2D
class_name Ladder

@export var climb_speed_multiplier: float = 0.6

var player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("ladder")

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		player_inside = true
		body._current_ladder = self

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		player_inside = false
		if body._current_ladder == self:
			body._current_ladder = null

func is_player_inside() -> bool:
	return player_inside

func get_climb_speed() -> float:
	return climb_speed_multiplier

# ✅ NOVA FUNÇÃO: Retorna a posição X da escada
func get_ladder_x_position() -> float:
	return global_position.x
