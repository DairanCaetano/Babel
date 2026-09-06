extends ProjectileComponent
class_name ProjectileAxe

@export var _attack_damage: int = 3
@export var rotation_speed: float = 720.0

# 👻 GHOST TRAIL
var ghost_timer: float = 0.0
@export var ghost_interval: float = 0.03
@export var ghost_trail_scene: PackedScene

@export_category("Objects")
@export var _texture: AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ghost_timer = 0.0
	
	if direction.x < 0:
		_texture.flip_h = true
	else:
		_texture.flip_h = false

# ✅ COLISÃO COM INIMIGOS via hurtbox (Area2D)
func _on_area_entered(area: Area2D) -> void:
	# Objetos destrutíveis
	if area.is_in_group("destructible_objects"):
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn", 
			Vector2(36, 0), global_position, global.character._character_texture.flip_h
		)
		queue_free()
		return
	
	# Hurtbox do inimigo
	if not area.is_in_group("enemy_hitbox"):
		return
	
	var enemy = area.get_parent()
	if not enemy.has_method("update_health"):
		return
	
	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn", 
		Vector2(36, 0), global_position, global.character._character_texture.flip_h
	)
	enemy.update_health(
		_attack_damage + global.character.get_additional_attack(), 
		global.character
	)
	queue_free()

# ✅ COLISÃO COM PAREDES
func _on_body_entered(_body) -> void:
	if _body is TileMapLayer:
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn", 
			Vector2(36, 0), global_position, global.character._character_texture.flip_h
		)
		queue_free()

func _physics_process(_delta: float) -> void:
	# ✅ MOVIMENTO (uma vez só!)
	translate(direction * _delta * _move_speed)
	
	# ✅ ROTAÇÃO
	rotation += deg_to_rad(rotation_speed * _delta)
	
	# ✅ GHOST TRAIL
	ghost_timer += _delta
	if ghost_timer >= ghost_interval:
		spawn_ghost_trail()
		ghost_timer = 0.0

func spawn_ghost_trail() -> void:
	if not ghost_trail_scene:
		return
	
	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	
	ghost.setup(_texture)
