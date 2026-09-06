extends CharacterBody2D
class_name BaseEnemy

const _COLLECTABLE_ITEM: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")

enum _types {
	STATIC = 0, 
	CHASE = 1, 
	WANDER = 2
}

var _direction: Vector2 = Vector2.ZERO
var _player_in_range: BaseCharacter = null

var _camera_2d: Camera2D
var _camera_shake: FastNoiseLite

var _on_knockback: bool = false
var _is_alive: bool = true
var _on_floor: bool = false
var _gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var _drop_items_list: Dictionary = {}

# --- CHASE STATE ---
var _is_chasing: bool = false
var _chase_timer: float = 0.0
var _chase_target: BaseCharacter = null
const _CHASE_DURATION: float = 5.0


@export_category("Objects")
@export var _enemy_texture: EnemyTexture
@export var _floor_detection_ray: RayCast2D
@export var _wall_detection_ray: RayCast2D
@export var _knockback_timer: Timer
@export var _attack_area_collision: CollisionShape2D
@export var _attack_area_detection: CollisionShape2D
@export var _particle_2d: GPUParticles2D
@export var _hurtbox_detection: Area2D
@export var _chase_area: Area2D


@export_category("Variables")
@export var enemy_direction: bool = false

@export var _enemy_type: _types

@export var _move_speed: float = 128.0
@export var _knockback_speed: float = 256.0

@export var _enemy_health: int = 10 
@export var _hit_knockback_timer: float = 0.3
@export var _dead_knockback_timer: float = 0.5

@export var _right_aac_position: int = 16
@export var _left_aac_position: int = -16
@export var _right_ad_position: int = 10
@export var _left_ad_position: int = -10
@export var _hurtbox_Right: int = 10
@export var _hurtbox_left: int = -10


@export_category("EnemySound")
@export var _dead_audio: AudioStreamPlayer
@export var _dead_scream_audio: AudioStreamPlayer
@export var _hit_audio: AudioStreamPlayer
@export var _attack_audio: AudioStreamPlayer

func _ready() -> void:
	add_to_group("enemies")
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if _hurtbox_detection:
		_hurtbox_detection.add_to_group("enemy_hitbox")

	_direction = [Vector2(-1, 0), Vector2(1, 0)].pick_random()
	_drop_items_list = _get_drop_tems()
	_camera_2d = get_node("CharacterCamera")
	_camera_shake = FastNoiseLite.new()
	_update_direction()
	
func _get_drop_tems() -> Dictionary:
	return {}
	
	
func _process(_delta: float) -> void:
	if _on_knockback:
		move_and_slide()
		return

	if _is_chasing and _enemy_type == _types.CHASE:
		_chase_timer -= _delta
		if _chase_timer <= 0.0:
			_stop_chase()
	
	
func _physics_process(_delta: float) -> void:
	_vertical_movement(_delta)
	
	if _is_alive == false:
		move_and_slide()
		return
	
	if is_instance_valid(_player_in_range):
		_attack()
		return
		
		
	match _enemy_type:
		_types.STATIC:
			pass
			
		_types.CHASE:
			_chasing()
			
		_types.WANDER:
			_wandering()
			
	move_and_slide()
	
	_enemy_texture.animate(velocity)
	
	
func _vertical_movement(_delta: float) -> void:
	if is_on_floor():
		if _is_alive == false:
			set_collision_layer_value(4, false)
			set_collision_mask_value(1, false)
			set_collision_layer_value(9, true)
			velocity.x = 0
			return
			
	if is_on_floor():
		if _on_floor == false:
			_enemy_texture.action_animate("Land")
			velocity = Vector2.ZERO
			_on_floor = true
			
	if not is_on_floor():
		_on_floor = false
		velocity.y += _gravity * _delta

func _wandering() -> void:
	if _wall_detection_ray.is_colliding():
		if not _wall_detection_ray.get_collider() is BaseCharacter:
			_update_direction()
			return
			
	if _floor_detection_ray.is_colliding():
		if _floor_detection_ray.get_collider() is TileMapLayer:
			velocity.x = _direction.x * _move_speed
			return
			
	if is_on_floor():
		_update_direction()
		velocity.x = 0


# --- CHASE LOGIC ---

func _chasing() -> void:
	if not _is_chasing:
		velocity.x = 0
		return

	# Atualiza direção continuamente em direção ao alvo
	if is_instance_valid(_chase_target):
		var _to_player: float = _chase_target.global_position.x - global_position.x
		if _to_player > 0:
			_direction.x = 1
		elif _to_player < 0:
			_direction.x = -1
		_update_chase_facing()

	velocity.x = _direction.x * (_move_speed * 2.0)


func _update_chase_facing() -> void:
	if enemy_direction:
		_enemy_texture.flip_h = _direction.x > 0

	if _wall_detection_ray:
		_wall_detection_ray.position.x = 16 * _direction.x
		_wall_detection_ray.target_position.x = 16 * _direction.x

	if _floor_detection_ray:
		_floor_detection_ray.position.x = 9 * _direction.x

	if _attack_area_collision:
		_attack_area_collision.position.x = _right_aac_position if _direction.x > 0 else _left_aac_position

	if _attack_area_detection:
		_attack_area_detection.position.x = _right_ad_position if _direction.x > 0 else _left_ad_position

	if _hurtbox_detection != null:
		_hurtbox_detection.position.x = _hurtbox_Right if _direction.x > 0 else _hurtbox_left


func _start_chase(_player: BaseCharacter) -> void:
	_is_chasing = true
	_chase_timer = _CHASE_DURATION
	_chase_target = _player


func _stop_chase() -> void:
	_is_chasing = false
	_chase_timer = 0.0
	_chase_target = null
	velocity.x = 0


func _on_chase_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter and _is_alive:
		_start_chase(body)


func _on_chase_area_body_exited(body: Node2D) -> void:
	# Timer continua correndo — a perseguição só para quando o timer zerar
	pass


# --- FIM CHASE LOGIC ---


func _update_direction() -> void:
	_direction.x = -_direction.x
	if enemy_direction:
		if _direction.x > 0:
			_enemy_texture.flip_h = true
			
		if _direction.x < 0:
			_enemy_texture.flip_h = false
			
	if _direction.x > 0:
		if _wall_detection_ray:
			_wall_detection_ray.position.x = 16
			_wall_detection_ray.target_position.x = 16
		
		if _floor_detection_ray:
			_floor_detection_ray.position.x = 9
		
		if _attack_area_collision:
			_attack_area_collision.position.x = _right_aac_position
		
		if _attack_area_detection:
			_attack_area_detection.position.x = _right_ad_position
		
		if _hurtbox_detection != null and _enemy_type != _types.STATIC:
			_hurtbox_detection.position.x = _hurtbox_Right
		
	if _direction.x < 0:
		if _wall_detection_ray:
			_wall_detection_ray.position.x = -16
			_wall_detection_ray.target_position.x = -16
		
		if _floor_detection_ray:
			_floor_detection_ray.position.x = -9
		
		if _attack_area_collision:
			_attack_area_collision.position.x = _left_aac_position
		
		if _attack_area_detection:
			_attack_area_detection.position.x = _left_ad_position
		
		if _hurtbox_detection != null and _enemy_type != _types.STATIC:
			_hurtbox_detection.position.x = _hurtbox_left

func _attack() -> void:
	pass

func play_attack_sound() -> void:
	if _attack_audio:
		_attack_audio.play()
	
	
func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		return  # era queue_free() — apenas isso muda
	
	_knockback(_entity)
	_enemy_health -= _damage
	
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	var camera = get_tree().get_first_node_in_group("camera")
	camera.shake_camera(1,0.1)
	
	_particle_2d.restart()
	_particle_2d.emitting = true
	
	if _enemy_health <= 0:
		HitStopManager.hit_stop_short()
		_particle_2d.restart()
		_particle_2d.emitting = true
		_attack_area_collision.set_deferred("disabled", true)
		_knockback_timer.start(_dead_knockback_timer)
		
		_play_death_sounds()
		
		_kill()
		return
	
	if _hit_audio:
		_hit_audio.play()
	
	_knockback_timer.start(_hit_knockback_timer)

func _play_death_sounds() -> void:
	if _dead_scream_audio:
		_dead_scream_audio.play()
	
	if _dead_audio:
		# Timer no lugar de await — não bloqueia
		get_tree().create_timer(0.05).timeout.connect(
			func(): 
				if is_instance_valid(self) and _dead_audio:
					_dead_audio.play()
		)
		
		
func _set_shader_blink_intensity(new_value: float) -> void:
	if not _enemy_texture:
		return
	
	var mat: ShaderMaterial = _enemy_texture.material as ShaderMaterial
	if not mat:
		return
	
	mat.set_shader_parameter("blink_active", new_value > 0.0)
	mat.set_shader_parameter("blink_intensity", new_value)
	
	
func _knockback(_entity: BaseCharacter) -> void:
	var _knockback_direction: Vector2 = _entity.global_position.direction_to(global_position)
	velocity.x = _knockback_direction.x * _knockback_speed
	velocity.y = -1 * _knockback_speed
	_knockback_timer.start(0.2)
	_on_knockback = true
	
	
func _kill() -> void:
	_enemy_texture.action_animate("Dead")
	set_collision_layer_value(4, false)
	set_collision_layer_value(7, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	_is_alive = false
	
	if _hurtbox_detection:
		_hurtbox_detection.set_deferred("monitoring", false)
		_hurtbox_detection.set_deferred("monitorable", false)
	
	for _item in _drop_items_list:
		var _item_spawn_probability: float = _drop_items_list[_item]["spawn_probability"]
		var _rng: float = randf()
		if _rng < _item_spawn_probability:
			_drop_item(_drop_items_list[_item])
	
	# Calcula duração sem await
	var max_duration: float = 1.0
	if _dead_scream_audio and _dead_scream_audio.stream:
		max_duration = max(max_duration, _dead_scream_audio.stream.get_length())
	if _dead_audio and _dead_audio.stream:
		max_duration = max(max_duration, _dead_audio.stream.get_length() + 0.2)
	
	# Timer no lugar de await — não bloqueia o fluxo
	get_tree().create_timer(max_duration).timeout.connect(queue_free)


func _wait_for_death_audio() -> void:
	var max_duration: float = 0.0
	
	if _dead_scream_audio and _dead_scream_audio.stream:
		var scream_duration = _dead_scream_audio.stream.get_length()
		max_duration = max(max_duration, scream_duration)
	
	if _dead_audio and _dead_audio.stream:
		var death_duration = _dead_audio.stream.get_length() + 0.2
		max_duration = max(max_duration, death_duration)
	
	if max_duration == 0.0:
		max_duration = 1.0
	
	await get_tree().create_timer(max_duration).timeout
	
	
func _drop_item(_item_data: Dictionary ) -> void:
	var _collectable: CollectableItem = _COLLECTABLE_ITEM.instantiate()
	_collectable.item_texture = _item_data["path"]
	_collectable.item_data = _item_data
	
	_collectable.global_position = global_position
	get_tree().root.call_deferred("add_child", _collectable)
	
	
func _on_detection_area_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_player_in_range = _body
		
		
func _on_detection_area_body_exited(_body) -> void:
	if _body is BaseCharacter:
		_player_in_range = null
		
		
func _on_knockback_timer_timeout() -> void:
	_on_knockback = false
