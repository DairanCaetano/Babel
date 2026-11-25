extends Area2D
class_name EnemyStepArea

## Área de pisada (Enemy Step). Fica alguns pixels acima do hurtbox do inimigo:
## a Tola, caindo sobre ela com a habilidade, ganha um novo impulso.
## A detecção é feita pela Tola (StepCast), que também ignora inimigos mortos.

## Camada física 12 "Enemy Step" (bit 11)
const STEP_LAYER: int = 1 << 11

## Acompanha o deslocamento X do hurtbox do inimigo (BaseEnemy vira o hurtbox com a direção).
@export var follow_hurtbox: bool = true

var _hurtbox: Node2D = null
var _base_x: float = 0.0

func _ready() -> void:
	collision_layer = STEP_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("Step")
	
	var enemy := get_parent()
	if follow_hurtbox and enemy and "_hurtbox_detection" in enemy:
		var hb = enemy.get("_hurtbox_detection")
		if hb is Node2D and hb.get_parent() == enemy:
			_hurtbox = hb
			_base_x = position.x

func _physics_process(_delta: float) -> void:
	if _hurtbox and is_instance_valid(_hurtbox):
		position.x = _base_x + _hurtbox.position.x
