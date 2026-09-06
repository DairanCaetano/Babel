extends AnimatedSprite2D
class_name EnemyTexture

var _on_action: bool = false

@export_category("Objects")
@export var _enemy: BaseEnemy
@export var _attack_area_collision: CollisionShape2D

@export_category("Variables")
@export var _last_attack_frame: int
@export var _initial_run_frame: int
@export var _last_run_frame: int

func animate(_velocity: Vector2) -> void:
	if _on_action:
		return
		
	if _velocity.y:
		if _velocity.y < 0:
			play("Jump")
			
		if _velocity.y > 0:
			play("Fall")
			
		return
		
	if _velocity.x:
		play("Walk")
		return
			
	play("Idle")

func action_animate(_action: String) -> void:
	if _enemy != null:  # Verificação de segurança
		_enemy.set_physics_process(false)
	_on_action = true
	play(_action)

func _on_animation_finished() -> void:
	if animation == "Attack_Anticipation":
		action_animate("Attack")
		return
	
	# ✅ Quando Dead terminar, para a partícula
	if animation == "Dead":
		if _enemy != null and _enemy._particle_2d:
			_enemy._particle_2d.emitting = false
		# Não reseta _on_action nem reativa physics — inimigo está morto
		return
	
	_on_action = false
	if _enemy != null:
		_enemy.set_physics_process(true)
func _on_frame_changed() -> void:
	if animation == "Walk":
		if frame == _initial_run_frame or frame == _last_run_frame:
			var _is_flipped: bool = flip_h
			if _enemy != null and _enemy.enemy_direction:
				_is_flipped = not _is_flipped
			
			if has_method("spawn_effect") or (get_tree() != null and get_tree().has_method("call_group")):
				global.spawn_effect(
					"res://Scenes/FX/run_effect.tscn", 
					Vector2(0, 6), 
					global_position, 
					_is_flipped
				)
			
	if animation == "Attack":
		# ✅ TOCAR O SOM NO FRAME DO ATAQUE
		if frame == 5:  # Ou frame 6, depende de qual você prefere
			if _enemy != null:
				_enemy.play_attack_sound()
		
		if frame == 5 or frame == 6:
			if _attack_area_collision != null:
				_attack_area_collision.disabled = false
			
		if frame == _last_attack_frame:
			if _attack_area_collision != null:
				_attack_area_collision.disabled = true
