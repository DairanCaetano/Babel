extends CharacterBody2D
class_name ProjectileDagger

@export var _attack_damage: int = 5
@export var gravity: float = 980.0
@export var initial_velocity_y: float = -350.0
@export var move_speed: float = 180.0
@export var rotation_speed: float = 540.0
@export var lifetime_after_landing: float = 0.6  # janela pra "quicar" antes de sumir de vez

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _collision_shape: CollisionShape2D
@export var attack_area: Area2D

@export_category("Ghost Trail")
@export var ghost_interval: float = 0.03
@export var ghost_trail_scene: PackedScene

var direction: Vector2 = Vector2.RIGHT
var is_active: bool = true
var is_grounded: bool = false

var ghost_timer: float = 0.0
var _vanish_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ghost_timer = 0.0

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
		print("⚠️ Direção da adaga estava zerada, definindo para direita")

	velocity = Vector2(direction.x * move_speed, initial_velocity_y)

	if _texture:
		_texture.flip_h = direction.x < 0

	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_area_entered)
	else:
		print("⚠️ AVISO: attack_area não foi atribuída no Inspector!")

	_vanish_timer = Timer.new()
	_vanish_timer.one_shot = true
	_vanish_timer.timeout.connect(_on_vanish_timer_timeout)
	add_child(_vanish_timer)

	_setup_safety_timer()

func _setup_safety_timer() -> void:
	var safety_timer = Timer.new()
	safety_timer.wait_time = 8.0
	safety_timer.one_shot = true
	safety_timer.timeout.connect(func():
		print("🗡️ Adaga destruída por timeout de segurança")
		queue_free()
	)
	add_child(safety_timer)
	safety_timer.start()

func _physics_process(delta: float) -> void:
	if not is_active or is_grounded:
		return

	# 👻 GHOST TRAIL - só enquanto está no ar
	ghost_timer += delta
	if ghost_timer >= ghost_interval:
		spawn_ghost_trail()
		ghost_timer = 0.0

	velocity.y += gravity * delta
	rotation += deg_to_rad(rotation_speed * delta)

	move_and_slide()
	_check_ground_collision()

func spawn_ghost_trail() -> void:
	if not ghost_trail_scene or not _texture:
		return

	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.setup(_texture)

func _on_attack_area_area_entered(area: Area2D) -> void:
	if not is_active:
		return

	# ✅ Espadada do jogador acerta a adaga -> ela "pula" de novo (quicar)
	if area is CharacterAttackArea:
		_bounce()
		return

	if area.is_in_group("destructible_objects"):
		_destroy_on_impact()
		return

	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy.has_method("update_health"):
			_hit_enemy(enemy)

func _bounce() -> void:
	is_grounded = false
	velocity.y = initial_velocity_y
	# mantém a direção horizontal atual - a espadada só renova o impulso vertical

	if _vanish_timer:
		_vanish_timer.stop()

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(0, -10), global_position,
		global.character._character_texture.flip_h
	)

func _hit_enemy(enemy: Node) -> void:
	is_active = false
	velocity = Vector2.ZERO

	var damage = _attack_damage
	if is_instance_valid(global) and is_instance_valid(global.character):
		damage += global.character.get_additional_attack()

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(36, 0), global_position,
		global.character._character_texture.flip_h
	)

	enemy.update_health(damage, global.character if is_instance_valid(global.character) else self)
	queue_free()

func _destroy_on_impact() -> void:
	is_active = false
	velocity = Vector2.ZERO

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(0, 0), global_position, false
	)
	queue_free()

func _check_ground_collision() -> void:
	if is_grounded or not is_active:
		return

	if is_on_floor():
		_land()

func _land() -> void:
	is_grounded = true
	velocity = Vector2.ZERO

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(0, 0), global_position, false
	)

	_vanish_timer.start(lifetime_after_landing)

func _on_vanish_timer_timeout() -> void:
	# ✅ Só desaparece de vez se ninguém quicou ela nesse meio tempo
	if is_grounded:
		queue_free()
