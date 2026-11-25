extends CharacterBody2D
class_name ZumbiBruto

@export var projectile_scene: PackedScene
@export var special_attack_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var fire_rate: float = 1.0
@export var y_offset_range: float = 30.0 

const _COLLECTABLE_ITEM = preload("res://Scenes/Collectables/collectable_item.tscn")

@export_category("Objects")
@export var detection_area: Area2D 
@export var attack_area: Area2D 
@export var texture: AnimatedSprite2D
@export var fire_point: Marker2D 
@export var fire_timer: Timer
@export var root_point: Marker2D
@export var fire_particle: GPUParticles2D
@export var collision: CollisionShape2D
@export var hurtbox_detection: Area2D 
## Onde aparece o aviso de ataque poderoso (AttackTellFX) no Attack_2. Posição escrita para o lado esquerdo.
@export var attack_tell_marker: Marker2D

@export_category("Health System")
@export var _enemy_health: int = 10
@export var _hit_knockback_timer: float = 0.3
@export var _dead_knockback_timer: float = 0.5
@export var _knockback_speed: float = 256.0

@export_category("Attack Settings")
@export var shot_interval: float = 2.0
@export var special_attack_cooldown: float = 5.0
@export var special_attack_delay: float = 1.4
@export var special_attack_offset: Vector2 = Vector2.ZERO

@export_category("EnemySound")
@export var _dead_audio: AudioStreamPlayer
@export var _dead_scream_audio: AudioStreamPlayer
@export var _hit_audio: AudioStreamPlayer
@export var _attack_audio: AudioStreamPlayer
@export var _attack_scream_audio: AudioStreamPlayer
@export var _attack_1_audio: AudioStreamPlayer
@export var _attack_2_audio: AudioStreamPlayer

var player_detected: BaseCharacter = null
var player_in_attack: BaseCharacter = null
var is_facing_right: bool = true
var current_state: String = "idle"
var is_attacking: bool = false

var is_in_attack_sequence: bool = false 
var shot_interval_timer: Timer
var special_attack_timer: Timer
var special_attack_delay_timer: Timer
var can_attack_after_special: bool = true
var can_use_special_attack: bool = true
var is_executing_special_attack: bool = false
var should_do_special_next: bool = false

var _on_knockback: bool = false
var _is_alive: bool = true
var _knockback_timer: Timer

# ✅ NOVO: Variáveis para controlar se o som já foi tocado
var _attack_1_scream_played: bool = false
var _attack_2_scream_played: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_area.body_entered.connect(_on_attack_entered)
	attack_area.body_exited.connect(_on_attack_exited)
	
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.one_shot = false
	
	shot_interval_timer = Timer.new()
	add_child(shot_interval_timer)
	shot_interval_timer.wait_time = shot_interval
	shot_interval_timer.one_shot = true
	shot_interval_timer.timeout.connect(_on_shot_interval_timeout)
	
	special_attack_timer = Timer.new()
	add_child(special_attack_timer)
	special_attack_timer.one_shot = true
	special_attack_timer.timeout.connect(_on_special_attack_cooldown_timeout)
	
	special_attack_delay_timer = Timer.new()
	add_child(special_attack_delay_timer)
	special_attack_delay_timer.wait_time = special_attack_delay
	special_attack_delay_timer.one_shot = true
	special_attack_delay_timer.timeout.connect(_on_special_attack_delay_timeout)
	
	_knockback_timer = Timer.new()
	add_child(_knockback_timer)
	_knockback_timer.one_shot = true
	_knockback_timer.timeout.connect(_on_knockback_timer_timeout)
	
	# ✅ CONECTA OS SINAIS
	texture.animation_finished.connect(_on_animation_finished)
	# Já conectado na cena (zumbi_bruto_2); evita conectar duas vezes
	if not texture.frame_changed.is_connected(_on_texture_frame_changed):
		texture.frame_changed.connect(_on_texture_frame_changed)
	
	_play_animation("Idle")
	
	texture.flip_h = false
	is_facing_right = false
	_update_direction()

func _physics_process(delta):
	if _on_knockback:
		move_and_slide()
		return
	
	if _is_alive == false:
		move_and_slide()
		return
	
	if player_detected:
		_look_at_player()
	
	# Lógica de início de ataque
	if player_detected != null and not is_executing_special_attack and can_attack_after_special:
		if can_use_special_attack:
			if not is_executing_special_attack:
				_execute_special_attack_animation()
		elif not is_attacking:
			_start_attack()
	elif player_in_attack != null and not is_executing_special_attack and can_attack_after_special:
		if not is_attacking:
			_start_attack()
	else:
		if is_attacking and not is_executing_special_attack and not is_in_attack_sequence:
			_stop_attack()

func _look_at_player():
	var direction_to_player = (player_detected.global_position - global_position).normalized()
	var should_face_right = direction_to_player.x > 0
	
	if should_face_right != is_facing_right:
		is_facing_right = should_face_right
		_update_direction()

func _update_direction():
	if is_facing_right:
		texture.flip_h = true
		fire_point.position.x = abs(fire_point.position.x)
		if attack_tell_marker:
			attack_tell_marker.position.x = abs(attack_tell_marker.position.x)
		if root_point:
			root_point.position.x = abs(root_point.position.x)
		attack_area.position.x = 210
		attack_area.position.y = 17
		collision.position.x = -6
	else:
		texture.flip_h = false
		fire_point.position.x = -abs(fire_point.position.x)
		if attack_tell_marker:
			attack_tell_marker.position.x = -abs(attack_tell_marker.position.x)
		if root_point:
			root_point.position.x = -abs(root_point.position.x)
		attack_area.position.x = -210
		attack_area.position.y = 17
		collision.position.x = 6

func _start_attack():
	if is_executing_special_attack or not can_attack_after_special:
		return
	
	is_attacking = true
	is_in_attack_sequence = false
	current_state = "attack"
	
	# ✅ RESETA o controle de som ao iniciar novo ataque
	_attack_1_scream_played = false
	
	_play_animation("Attack_1")
	
	if fire_timer.is_stopped():
		fire_timer.start()

func _stop_attack():
	if is_executing_special_attack:
		return
	
	if is_in_attack_sequence:
		return
	else:
		is_attacking = false
		current_state = "idle"
		_play_animation("Idle")
		
		if not fire_timer.is_stopped():
			fire_timer.stop()
		if not shot_interval_timer.is_stopped():
			shot_interval_timer.stop()

func _play_animation(animation_name: String):
	if texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)
		# ✅ O Godot só emite frame_changed se o frame MUDAR: vindo de uma animação
		# que já estava no frame 0 (ex.: Idle de 1 quadro), o frame 0 da nova
		# animação não dispara o sinal. Chamamos à mão; as flags evitam repetir.
		if texture.frame == 0:
			_on_texture_frame_changed()

func _on_fire_timer_timeout():
	if is_attacking and not is_executing_special_attack:
		_execute_attack()

func _execute_attack():
	if current_state != "attack" and not is_executing_special_attack:
		current_state = "attack"
		
		# ✅ RESETA o controle de som ao reiniciar ataque
		_attack_1_scream_played = false
		
		_play_animation("Attack_1")

func _on_animation_finished():
	match texture.animation:
		"Attack_1":
			if is_executing_special_attack:
				return
			
			is_in_attack_sequence = true
			_fire_projectile()
			
			if is_attacking:
				_start_shot_interval()
			else:
				is_in_attack_sequence = false
				current_state = "idle"
				_play_animation("Idle")
		
		"Attack_2":
			is_executing_special_attack = false
			is_in_attack_sequence = false
			is_attacking = false
			
			_execute_special_attack()
			
			can_attack_after_special = false
			special_attack_delay_timer.start()
			
			can_use_special_attack = false
			special_attack_timer.start(special_attack_cooldown)
			
			current_state = "idle"
			_play_animation("Idle")

func _start_shot_interval():
	current_state = "idle"
	_play_animation("Idle")
	
	if not fire_timer.is_stopped():
		fire_timer.stop()
	
	shot_interval_timer.wait_time = shot_interval
	shot_interval_timer.start()

func _on_shot_interval_timeout():
	var player_still_present = player_in_attack != null or player_detected != null
	
	if is_attacking and player_still_present and not is_executing_special_attack:
		if fire_timer.is_stopped():
			fire_timer.start()
		current_state = "attack"
		
		# ✅ RESETA o controle de som ao reiniciar sequência
		_attack_1_scream_played = false
		
		_play_animation("Attack_1")
	else:
		is_in_attack_sequence = false
		current_state = "idle"
		_play_animation("Idle")

func _fire_projectile():
	if not projectile_scene or is_executing_special_attack:
		return
	
	_create_projectile()

func _create_projectile():
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	projectile.global_position = fire_point.global_position
	
	var direction = Vector2(1 if is_facing_right else -1, 0)
	var current_flip = texture.flip_h
	
	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_speed, current_flip)

func _execute_special_attack():
	if not special_attack_scene:
		return
	
	var special_attack = special_attack_scene.instantiate()
	get_tree().current_scene.add_child(special_attack)
	
	# ✅ Offset escrito para o lado esquerdo: espelha quando olha para a direita
	var offset := special_attack_offset
	if is_facing_right:
		offset.x = -offset.x
	var spawn_position = root_point.global_position + offset
	special_attack.global_position = spawn_position

func _on_special_attack_cooldown_timeout():
	can_use_special_attack = true

func _on_special_attack_delay_timeout():
	can_attack_after_special = true

func _on_detection_entered(body):
	if body is BaseCharacter:
		player_detected = body

func _on_detection_exited(body):
	if body == player_detected:
		player_detected = null

func _on_attack_entered(body):
	if body is BaseCharacter:
		player_in_attack = body

func _on_attack_exited(body):
	if body == player_in_attack:
		player_in_attack = null

func _player_in_both_areas() -> bool:
	return player_in_attack != null and player_detected != null

func _execute_special_attack_animation():
	if can_use_special_attack and _is_alive and not is_executing_special_attack:
		is_executing_special_attack = true
		
		if is_attacking:
			fire_timer.stop()
			shot_interval_timer.stop()
		
		is_in_attack_sequence = false
		current_state = "special_attack"
		
		# ✅ RESETA o controle de som ao iniciar ataque especial
		_attack_2_scream_played = false
		
		_play_animation("Attack_2")

# ✅ NOVO: Função que detecta mudanças de frame
func _on_texture_frame_changed() -> void:
	var current_animation = texture.animation
	var current_frame = texture.frame
	
	# Attack_1: frame 0 toca scream, frame 7 toca attack_1
	if current_animation == "Attack_1":
		if current_frame == 0 and not _attack_1_scream_played:
			if _attack_scream_audio:
				_attack_scream_audio.play()
			_attack_1_scream_played = true
		elif current_frame == 7:
			if _attack_1_audio:
				_attack_1_audio.play()
	
	# Attack_2: frame 0 toca scream, frame 7 toca attack_2
	elif current_animation == "Attack_2":
		if current_frame == 0 and not _attack_2_scream_played:
			if _attack_scream_audio:
				_attack_scream_audio.play()
			_attack_2_scream_played = true
			# ✅ Aviso de ataque poderoso na antecipação do Attack_2
			if attack_tell_marker:
				AttackTellFX.spawn(attack_tell_marker, true, texture.flip_h)
		elif current_frame == 7:
			if _attack_2_audio:
				_attack_2_audio.play()

func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		return
	
	_knockback(_entity)
	_enemy_health -= _damage
	
	if _hit_audio:
		_hit_audio.play()
	
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)
	
	if _enemy_health <= 0:
		HitStopManager.hit_stop_short()  # ✅ adiciona aqui
		_stop_all_attacks()
		_knockback_timer.start(_dead_knockback_timer)
		_kill()
		return
	
	_knockback_timer.start(_hit_knockback_timer)

func _set_shader_blink_intensity(newValue: float) -> void:
	if not texture:
		return
	
	if not texture.material:
		return
	
	if not texture.material.shader:
		return
	
	texture.material.set_shader_parameter("blink_active", newValue > 0.0)
	texture.material.set_shader_parameter("blink_intensity", newValue)

func _knockback(_entity) -> void:
	var _knockback_direction: Vector2 = _entity.global_position.direction_to(global_position)
	velocity.x = _knockback_direction.x * _knockback_speed
	velocity.y = -1 * _knockback_speed
	_knockback_timer.start(0.2)
	_on_knockback = true

func _kill() -> void:
	_play_animation("Dead")
	
	# ✅ DESATIVA TODAS AS COLLISION LAYERS E MASKS
	set_collision_layer_value(4, false)  # Layer do inimigo
	set_collision_mask_value(1, false)   # Mask do chão
	set_collision_layer_value(9, true)   # Layer de morto (se necessário)
	
	_is_alive = false
	player_detected = null
	player_in_attack = null
	
	# ✅ DESATIVA A COLLISION PRINCIPAL (CollisionShape2D)
	if collision:
		collision.set_deferred("disabled", true)
	
	# ✅ DESATIVA A HURTBOX COMPLETAMENTE
	if hurtbox_detection:
		hurtbox_detection.set_deferred("monitoring", false)
		hurtbox_detection.set_deferred("monitorable", false)
		# Desabilita o CollisionShape2D da hurtbox também
		for child in hurtbox_detection.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	# ✅ DESATIVA AS ÁREAS DE DETECÇÃO E ATAQUE
	if detection_area:
		detection_area.set_deferred("monitoring", false)
		detection_area.set_deferred("monitorable", false)
		for child in detection_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)
		for child in attack_area.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	# ✅ ADICIONAR AQUI
	_drop_items()
	
	if _dead_audio:
		_dead_audio.play()
	if _dead_scream_audio:
		_dead_scream_audio.play()
	
	if fire_particle:
		fire_particle.visible = true
		fire_particle.emitting = true
	
	var wait_time = 0.8
	
	if _dead_audio and _dead_audio.stream:
		var dead_audio_length = _dead_audio.stream.get_length()
		wait_time = max(wait_time, dead_audio_length)
	
	if _dead_scream_audio and _dead_scream_audio.stream:
		var dead_scream_length = _dead_scream_audio.stream.get_length()
		wait_time = max(wait_time, dead_scream_length)
	
	var timer = get_tree().create_timer(wait_time)
	await timer.timeout
	queue_free()

func _stop_all_attacks() -> void:
	is_attacking = false
	is_in_attack_sequence = false
	is_executing_special_attack = false
	
	if not fire_timer.is_stopped():
		fire_timer.stop()
	if not shot_interval_timer.is_stopped():
		shot_interval_timer.stop()
	if not special_attack_timer.is_stopped():
		special_attack_timer.stop()
	if not special_attack_delay_timer.is_stopped():
		special_attack_delay_timer.stop()

func _on_knockback_timer_timeout() -> void:
	_on_knockback = false


# ✅ ADICIONAR LOGO APÓS AS VARIÁVEIS @export

func _get_drop_items() -> Dictionary:
	return {
		"small_shards": {
			"name": "Small Shards",
			"path": "res://sprites/Items/small_fragment.png",
			"type": "resource",
			"description": "A small shard, sells for money",
			"value": 1,
			"spawn_probability": 0.90,  # 90% de chance
			"amount_to_drop": [2, 5]    # Dropa entre 2 e 5 shards
		},
		
		"medium_shards": {
			"name": "Medium Shards",
			"path": "res://sprites/Items/medium_fragment.png",
			"type": "resource",
			"description": "A shard, sells for money",
			"value": 10,
			"spawn_probability": 0.15,  # 15% de chance
			"amount_to_drop": [1, 2]
		}
	}


# ✅ ADICIONAR NO FINAL DO ARQUIVO ZumbiBruto.gd
func _drop_items() -> void:
	var drop_data = _get_drop_items()
	
	for item_key in drop_data:
		var item = drop_data[item_key]
		var rand_value = randf()
		
		if rand_value < item["spawn_probability"]:
			var amount_range = item["amount_to_drop"]
			var amount = randi_range(amount_range[0], amount_range[1])
			
			for i in range(amount):
				var collectable_item = _COLLECTABLE_ITEM.instantiate()
				collectable_item.item_texture = item["path"]
				collectable_item.item_data = {
					"name": item["name"],
					"type": item["type"],
					"description": item["description"],
					"value": item["value"],
					"amount": 1
				}
				collectable_item.global_position = global_position
				get_tree().current_scene.call_deferred("add_child", collectable_item)
