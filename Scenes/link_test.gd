extends CharacterBody2D

@export var speed: float = 120.0
@export var dash_speed: float = 350.0
@export var dash_time: float = 0.20
@export var dash_cooldown_time: float = 0.50

var facing: Vector2 = Vector2.DOWN

var is_attacking := false
var is_dashing := false
var is_shielding := false

var dash_timer := 0.0
var dash_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_play_idle_animation()


func _physics_process(delta: float) -> void:

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if is_dashing:
		_process_dash(delta)

	elif is_attacking:
		velocity = Vector2.ZERO

	else:
		_process_input()

	move_and_slide()


func _process_input() -> void:

	# ESCUDO
	if Input.is_action_pressed("sub_weapon"):
		is_shielding = true
		velocity = Vector2.ZERO
		_play_shield_animation()
		return

	is_shielding = false

	# DASH (Jump)
	if Input.is_action_just_pressed("jump"):

		if !is_attacking \
		and !is_shielding \
		and dash_cooldown_timer <= 0:

			_start_dash()

		return


# ATAQUE
	if Input.is_action_just_pressed("attack"):

		if !is_dashing \
		and !is_shielding \
		and !is_attacking:

			_start_attack()

		return

	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:

		facing = input_vector
		velocity = input_vector * speed
		_play_walk_animation()

	else:

		velocity = Vector2.ZERO
		_play_idle_animation()


func _start_attack() -> void:

	if is_attacking:
		return

	is_attacking = true
	velocity = Vector2.ZERO

	_play_attack_animation()


func _start_dash() -> void:

	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input != Vector2.ZERO:
		facing = input.normalized()

	is_dashing = true
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown_time

	velocity = facing * dash_speed

	_play_dash_animation()


func _process_dash(delta: float) -> void:

	velocity = facing * dash_speed

	dash_timer -= delta

	if dash_timer <= 0:

		is_dashing = false

		var input := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

		if input != Vector2.ZERO:

			facing = input.normalized()
			velocity = input.normalized() * speed
			_play_walk_animation()

		else:

			velocity = Vector2.ZERO
			_play_idle_animation()

func _on_animation_finished() -> void:

	if sprite.animation.begins_with("attack"):

		is_attacking = false

		var input := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

		if input != Vector2.ZERO:

			facing = input.normalized()
			velocity = facing * speed

			_play_walk_animation()

		else:

			velocity = Vector2.ZERO

			_play_idle_animation()


func _play_idle_animation() -> void:

	sprite.flip_h = false

	if abs(facing.x) > abs(facing.y):

		sprite.flip_h = facing.x < 0

		if sprite.animation != "idle_left":
			sprite.play("idle_left")

	elif facing.y < 0:

		if sprite.animation != "idle_back":
			sprite.play("idle_back")

	else:

		if sprite.animation != "idle":
			sprite.play("idle")


func _play_walk_animation() -> void:

	sprite.flip_h = false

	if abs(facing.x) > abs(facing.y):

		sprite.flip_h = facing.x > 0

		if sprite.animation != "walk_left":
			sprite.play("walk_left")

	elif facing.y < 0:

		if sprite.animation != "walk_back":
			sprite.play("walk_back")

	else:

		if sprite.animation != "walk_front":
			sprite.play("walk_front")


func _play_attack_animation() -> void:

	sprite.flip_h = false

	if abs(facing.x) > abs(facing.y):

		sprite.flip_h = facing.x > 0

		if sprite.animation != "attack_left":
			sprite.play("attack_left")

	elif facing.y < 0:

		if sprite.animation != "attack_back":
			sprite.play("attack_back")

	else:

		if sprite.animation != "attack":
			sprite.play("attack")


func _play_dash_animation() -> void:

	sprite.flip_h = false

	if abs(facing.x) > abs(facing.y):

		sprite.flip_h = facing.x > 0

		if sprite.animation != "dash_left":
			sprite.play("dash_left")

	elif facing.y < 0:

		if sprite.animation != "dash_back":
			sprite.play("dash_back")

	else:

		if sprite.animation != "dash_front":
			sprite.play("dash_front")


func _play_shield_animation() -> void:

	sprite.flip_h = false

	if abs(facing.x) > abs(facing.y):

		sprite.flip_h = facing.x > 0

		if sprite.animation != "shield_left":
			sprite.play("shield_left")

	elif facing.y < 0:

		if sprite.animation != "shield_back":
			sprite.play("shield_back")

	else:

		if sprite.animation != "shield":
			sprite.play("shield")
