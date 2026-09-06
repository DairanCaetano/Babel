extends CharacterBody2D

var input
@export var speed = 100.0
@export var gravity = 15
@export var jump_force = 400
@export var rolling_speed = 200
@export var dash_distance = 10
@export var dano = 5

var dash_duration = dash_distance / rolling_speed
@export var wall_slide_speed = 50.0
@export var dash_cooldown = 1.0

var can_dash = true
var current_state = player_states.MOVE
enum player_states {MOVE, SWORD, DEAD, STOP, DASH, WALL_SLIDE}

var is_taking_damage: bool = false

var combo_count = 2
var can_attack = true

var was_running = false
var can_combo = false
var is_air_attacking = false

@onready var wall = $wall_ray
var is_wall_sliding = false

@onready var land = $land_ray
var was_in_air = false  # Indica se o personagem estava no ar antes de pousar

@export var wall_jump_force = 600
@export var wall_jump_distance = 200

@export var coyote_time = 0.2
var coyote_timer = 0.0

func _ready():
	$sword/sword_collider.disabled = true
	$Timer.wait_time = 0.5
	wall.enabled = true


func _physics_process(delta):
	gravity_force()
	
	if !is_on_floor():
		coyote_timer -= delta
		was_in_air = true  # Marca que o personagem está no ar
	else:
		coyote_timer = coyote_time
	
	check_landing()
	
	if current_state != player_states.DASH:
		wall_collider()
	
	if current_state == player_states.DASH:
		process_dash()
		move_and_slide()
		return
		
	process_normal_state()
	move_and_slide()

func check_landing():
	# Se o raycast detectar o chão e o personagem estava no ar, reproduz a animação "Land"
	if land.is_colliding() and was_in_air:
		$anim.play("Land")
		was_in_air = false  # Reseta o estado de ar após a aterrissagem
		current_state = player_states.MOVE

	# Atualiza o estado do personagem de acordo com o contato com o chão
	if is_on_floor():
		was_in_air = false  # Define como falso ao detectar o chão com `is_on_floor`
	else:
		was_in_air = true  # Define como verdadeiro se o personagem sair do chão


	# Se o personagem estiver no chão, ele não estava no ar
	if is_on_floor():
		was_in_air = false

func process_dash():
	# Durante o dash, mantém apenas o movimento horizontal fixo na direção que o personagem está olhando
	velocity.x = rolling_speed * $Sprite2D.scale.x
	# A gravidade já está sendo aplicada no _physics_process

func process_normal_state():
	if is_air_attacking and is_on_floor():
		reset_states()
		$anim.play("Idle")
		return
	
	if Input.is_action_just_pressed("ui_sword") and !is_wall_sliding:
		if can_attack or can_combo:
			current_state = player_states.SWORD
			return

	if Input.is_action_just_pressed("ui_roll") and current_state == player_states.MOVE and !is_wall_sliding and is_on_floor() and can_dash:
		start_dash()
		return
	
	if Input.is_action_just_pressed("ui_accept"):
		if is_wall_sliding:
			perform_wall_jump()
		elif is_on_floor() or coyote_timer > 0:  # Permite pular com o coyote time
			velocity.y = -jump_force
			$anim.play("Jump")
			current_state = player_states.MOVE
			coyote_timer = 0  # Reseta o coyote timer após o pulo
			return

	match current_state:
		player_states.MOVE:
			movement()
		player_states.SWORD:
			sword()
		player_states.STOP:
			stop_state()
		player_states.WALL_SLIDE:
			wall_slide()
		player_states.DEAD:
			dead()

func start_dash():
	current_state = player_states.DASH
	$anim.play("Roll")
	$Timer.wait_time = dash_duration
	$Timer.start()
	
	# Desabilita o dash até o cooldown terminar
	can_dash = false
	
	# Cria um novo timer para o cooldown do dash
	var cooldown_timer = Timer.new()
	add_child(cooldown_timer)
	cooldown_timer.wait_time = dash_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.connect("timeout", _on_dash_cooldown_timeout)
	cooldown_timer.start()
	
	# Desabilita todas as outras ações
	can_attack = false
	can_combo = false
	is_air_attacking = false
	$sword/sword_collider.disabled = true
	was_running = false

func _on_dash_cooldown_timeout():
	can_dash = true
	# Remove o timer temporário
	var cooldown_timer = get_children().filter(func(node): return node is Timer and node != $Timer).front()
	if cooldown_timer:
		cooldown_timer.queue_free()

func movement():
	if is_wall_sliding:
		return
	
	input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if input != 0:
		if input > 0:
			velocity.x = speed
			$Sprite2D.scale.x = 1
			wall.scale.x = 1
			$sword.position.x = 21
			$anim.play("Run")
			was_running = true
		elif input < 0:
			velocity.x = -speed
			$Sprite2D.scale.x = -1
			wall.scale.x = -1
			$sword.position.x = -21
			$anim.play("Run")
			was_running = true

	if input == 0:
		velocity.x = 0
		if was_running:
			current_state = player_states.STOP
			was_running = false
		else:
			$anim.play("Idle")
			
	if !is_on_floor():
		if velocity.y < 0:
			$anim.play("Jump")
			was_running = false
		elif velocity.y > 0 and !is_wall_sliding:
			$anim.play("Fall")
			was_running = false

func perform_wall_jump():
	if current_state != player_states.DASH:  # Previne wall jump durante dash
		var wall_direction = -sign(wall.position.x - position.x)
		velocity.y = -wall_jump_force
		velocity.x = wall_direction * wall_jump_distance
		is_wall_sliding = false
		current_state = player_states.MOVE
		$anim.play("Jump")

func wall_slide():
	$anim.play("Wall_slide")
	velocity.y = wall_slide_speed

func wall_collider():
	if wall.is_colliding() and !is_on_floor() and input != 0:
		is_wall_sliding = true
		current_state = player_states.WALL_SLIDE
	else:
		is_wall_sliding = false

func gravity_force():
	if !is_wall_sliding:
		velocity.y += gravity

func stop_state():
	if current_state != player_states.DASH:  # Previne ações durante dash
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = -jump_force
			current_state = player_states.MOVE
			$anim.play("Jump")
			return
		
		if Input.is_action_just_pressed("ui_sword") and (can_attack or can_combo):
			current_state = player_states.SWORD
			return
			
		velocity.x = 0
		$anim.play("Stop")
		velocity.x = 0

func sword():
	if current_state != player_states.DASH:  # Previne ataques durante dash
		if !is_on_floor():
			$anim.play("Atk_Air")
			can_attack = false
			can_combo = false
			$sword/sword_collider.disabled = false
			$Timer.start()
			is_air_attacking = true
			
			if input != 0:
				velocity.x = speed * sign(input)
		else:
			if can_combo and combo_count == 1:
				$anim.play("Atk_2")
				combo_count = 0
				can_attack = false
				can_combo = false
				$Timer.start()
				$sword/sword_collider.disabled = false
				velocity.x = 0
			elif can_attack:
				$anim.play("Atk_1")
				combo_count = 1
				can_attack = false
				$Timer.start()
				$sword/sword_collider.disabled = false
				velocity.x = 0

func reset_states():
	current_state = player_states.MOVE
	combo_count = 0
	can_attack = true
	can_combo = false
	is_air_attacking = false
	$sword/sword_collider.disabled = true

func dead():
	$anim.play("Dead")
	velocity.x = 0
	gravity_force()
	move_and_slide()
	
	await $anim.animation_finished
	player_data.life = 5
	if get_tree():
		get_tree().reload_current_scene()

func _on_timer_timeout():
	if current_state == player_states.DASH:
		reset_states()
	can_combo = false
	if combo_count > 0:
		combo_count = 0
		can_attack = true

func take_damage(amount):
	pass 

func _on_anim_animation_finished(anim_name):
	pass


func _on_sword_body_entered(body):
	if body.is_in_group("enemies") and current_state == player_states.SWORD:
		body.take_damage(dano)


func _on_damage_timer_timeout():
	is_taking_damage = false
