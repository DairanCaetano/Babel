extends CharacterBody2D
class_name ProjectileSpear

@export var _attack_damage: int = 4 # dano com ataque base 5 (escala com a força do Tola)
@export var gravity: float = 980.0
@export var initial_velocity_y: float = -300.0
@export var rotation_speed: float = 360.0
@export var move_speed: float = 200.0

var direction: Vector2 = Vector2.RIGHT
var has_hit_target: bool = false
var is_active: bool = true
var initial_velocity: Vector2

# 👻 GHOST TRAIL - ADICIONADO
var ghost_timer: float = 0.0
@export var ghost_interval: float = 0.03
@export var ghost_trail_scene: PackedScene

# Referências de nós
@onready var sprite: AnimatedSprite2D = $Texture
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var attack_area: Area2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ghost_timer = 0.0
	
	# Validar direção
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
		print("AVISO: Direção da lança estava zerada, definindo para direita")
	
	# Definir velocidade inicial
	initial_velocity = Vector2(direction.x * move_speed, initial_velocity_y)
	velocity = initial_velocity
	
	# Rotação inicial baseada na direção
	if direction.x < 0:
		rotation_degrees = 180
	
	print("Lança criada - Direção: ", direction, " Velocidade inicial: ", velocity)
	
	# Conectar sinais
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.area_entered.connect(_on_attack_area_area_entered)
		print("✅ Attack area conectada!")
	else:
		print("⚠️ AVISO: attack_area não encontrada!")
	
	# Timer de segurança
	_setup_safety_timer()

func _setup_safety_timer() -> void:
	var safety_timer = Timer.new()
	safety_timer.wait_time = 10.0
	safety_timer.one_shot = true
	safety_timer.timeout.connect(func():
		print("Lança destruída por timeout de segurança")
		queue_free()
	)
	add_child(safety_timer)
	safety_timer.start()

func _physics_process(delta: float) -> void:
	# 👻 GHOST TRAIL - COM DEBUG
	if is_active and not has_hit_target:
		ghost_timer += delta
		if ghost_timer >= ghost_interval:
			print("🔱 CRIANDO GHOST - Timer:", ghost_timer, " Interval:", ghost_interval)
			print("   Scene:", ghost_trail_scene)
			print("   Sprite:", sprite)
			spawn_ghost_trail()
			ghost_timer = 0.0
	
	if has_hit_target or not is_active:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	_update_rotation_based_on_velocity()
	move_and_slide()
	_check_wall_and_floor_collisions()

func spawn_ghost_trail() -> void:
	if not ghost_trail_scene:
		return
	
	# ✅ USA sprite (que é @onready) em vez de _texture
	if not sprite:
		return
	
	var ghost = ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	
	ghost.setup(sprite)  # ✅ PASSA sprite


func _update_rotation_based_on_velocity() -> void:
	var angle = velocity.angle()
	rotation = angle

func _on_attack_area_body_entered(body: Node2D) -> void:
	pass

func _on_attack_area_area_entered(area: Area2D) -> void:
	if not is_active or has_hit_target:
		return
	
	# Objetos destrutíveis
	if area.is_in_group("destructible_objects"):
		is_active = false
		has_hit_target = true
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(36, 0),
			global_position,
			global.character._character_texture.flip_h
		)
		queue_free()
		return
	
	# Inimigos
	if area.is_in_group("enemy_hitbox"):
		var enemy = global.get_damage_target(area)
		if enemy.has_method("update_health"):
			_handle_enemy_collision(enemy)

func _check_wall_and_floor_collisions() -> void:
	if not is_active or has_hit_target:
		return
	
	if is_on_wall():
		_handle_wall_hit()
		return
	
	if is_on_floor():
		_handle_ground_collision()
		return

func _handle_wall_hit() -> void:
	if has_hit_target:
		return
	
	print("🧱 Colidiu com parede!")
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is TileMapLayer:
			var collision_point = collision.get_position()
			var tile_pos = collider.local_to_map(collider.to_local(collision_point))
			var tile_data = collider.get_cell_tile_data(tile_pos)
			
			print("📍 Tile pos: ", tile_pos)
			print("📍 Tile data: ", tile_data)
			
			var wall_type = ""
			
			if tile_data:
				var wall_custom_data = tile_data.get_custom_data("Wall")
				print("📍 Custom data 'Wall': ", wall_custom_data)
				
				if wall_custom_data == "Wall_Left":
					wall_type = "wall_left"
				elif wall_custom_data == "Wall_Right":
					wall_type = "wall_right"
			
			if wall_type == "":
				wall_type = "wall_right" if direction.x < 0 else "wall_left"
				print("⚠️ Usando direção da lança para determinar tipo:", wall_type)
			
			is_active = false
			has_hit_target = true
			print("✅ Criando plataforma tipo:", wall_type)
			_create_interactable_spear(wall_type)
			return

func _handle_enemy_collision(enemy: Node) -> void:
	if has_hit_target:
		return
	
	is_active = false
	has_hit_target = true
	
	print("💥 Lança acertou inimigo: ", enemy.name)
	
	var damage = _attack_damage
	if is_instance_valid(global) and is_instance_valid(global.character):
		damage = global.character.scale_damage(_attack_damage)
		
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(36, 0),
			global_position,
			global.character._character_texture.flip_h
		)
	
	enemy.update_health(damage, global.character if is_instance_valid(global.character) else self)
	_stick_to_target(enemy)

func _handle_ground_collision() -> void:
	if has_hit_target:
		return
	
	print("🌍 Colidiu com o chão!")
	is_active = false
	has_hit_target = true
	_stick_to_ground()

func _stick_to_target(target: Node) -> void:
	has_hit_target = true
	velocity = Vector2.ZERO
	
	print("Lança grudou no alvo na posição final: ", global_position)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func():
		print("Lança destruída após grudar no alvo")
		queue_free()
	)
	add_child(timer)
	timer.start()

func _stick_to_ground() -> void:
	has_hit_target = true
	velocity = Vector2.ZERO
	
	print("Lança grudou no chão na posição final: ", global_position)
	
	if abs(initial_velocity.y) > abs(initial_velocity.x):
		rotation_degrees = 90 if direction.x > 0 else -90
	
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		print("Lança destruída após grudar no chão")
		queue_free()
	)
	add_child(timer)
	timer.start()

func _create_interactable_spear(wall_type: String = "") -> void:
	has_hit_target = true
	velocity = Vector2.ZERO
	
	var interactable_spear_scene = preload("res://Scenes/Interactables/spear_platform.tscn")
	if interactable_spear_scene:
		var interactable_spear = interactable_spear_scene.instantiate()
		
		var additional_offset = 10.0
		var impact_direction = velocity.normalized() if velocity.length() > 50.0 else direction
		var spawn_position = global_position + (impact_direction * additional_offset)
		interactable_spear.global_position = spawn_position
		interactable_spear.rotation = 0
		
		global.register_new_platform(interactable_spear)
		get_parent().add_child(interactable_spear)
		
		var should_flip = direction.x < 0
		
		if interactable_spear.has_method("setup_platform"):
			interactable_spear.setup_platform(wall_type, should_flip)
		else:
			var spear_sprite = interactable_spear.get_node("Sprite2D")
			if spear_sprite and spear_sprite is Sprite2D:
				spear_sprite.flip_h = should_flip
		
		print("Plataforma de lança criada com sucesso!")
		print("Debug da plataforma: ", interactable_spear.debug_info() if interactable_spear.has_method("debug_info") else "Debug não disponível")
	
	queue_free()

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()

func set_arc_type(arc_type: String) -> void:
	match arc_type:
		"high_arc":
			initial_velocity_y = -400.0
			gravity = 800.0
		"low_arc":
			initial_velocity_y = -200.0
			gravity = 1200.0
		"normal":
			initial_velocity_y = -300.0
			gravity = 980.0
