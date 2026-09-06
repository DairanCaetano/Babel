extends Boss
class_name BaalBerith

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var fire_rate: float = 1.0
@export var y_offset_range: float = 30.0 

@export_category("Objects")
@export var attack_area: Area2D 
@export var texture: AnimatedSprite2D
@export var attack_point_1: Marker2D 
@export var attack_point_2: Marker2D
@export var attack_point_3: Marker2D
@export var fire_timer: Timer
@export var fire_particle: GPUParticles2D
@export var attack_1_timer: Timer
@export var attack_1_interval: Timer
@export var spawn_area: BaalBerithSpawn
@export var hurt_box: Area2D
@export var attack_impact_area: Area2D
@export var attack_impact_collision: CollisionShape2D
@export var enemy_audio: BaalBerithAudio


@export_category("Projectile Scenes")
@export var projectile_attack_1: PackedScene
@export var projectile_attack_2: PackedScene
@export var projectile_attack_3: PackedScene
@export var roar_fx_scene: PackedScene

@export_category("Health System")
@export var _enemy_health: int = 10
@export var _max_health: int = 10
@export var _hit_knockback_timer: float = 0.3
@export var _dead_knockback_timer: float = 0.5
@export var _knockback_speed: float = 256.0

@export_category("Attack Settings")
@export var shot_interval_phase_1: float = 2.0
@export var shot_interval_phase_2: float = 1.0
@export var attack_1_anticipation_duration: float = 2.0
@export var attack_1_duration: float = 2.0
@export var roar_duration: float = 2.0
@export var attack_3_projectile_delay: float = 0.5
@export var attack_3_second_wave_delay: float = 1.0

var player_in_attack: BaseCharacter = null
var current_state: String = "idle"
var is_attacking: bool = false
var is_in_attack_sequence: bool = false
var shot_interval_timer: Timer
var current_attack_type: int = 1
var last_attack_type: int = 0
var has_roared: bool = false
var initial_roar_complete: bool = false  # 🔓 Vira true só quando o ROAR INICIAL termina de fato (anim + duração)
var _initial_roar_in_progress: bool = false  # Flag interna p/ rastrear o roar inicial (current_state é sobrescrito antes do timer disparar, não pode confiar nele)
var _on_knockback: bool = false
var _knockback_timer: Timer
var attack_3_projectile_timer: Timer
var attack_3_second_wave_timer: Timer
var attack_1_projectile_count: int = 0
var attack_1_max_projectiles: int = 30

var current_phase: int = 1
var has_triggered_phase_2: bool = false
var roar_fx_instance: Node = null 
var _attack_2_target_x: float = 0.0  # Posição X do player travada no início do Attack_2, usada mesmo se ele sair da attack_area depois

func _ready():
	boss_id = "baal_berith"  # ← ID único deste boss
	super._ready()  # ← Chama o _ready da classe Boss
	
	# Se já foi derrotado, não spawnar
	if is_already_defeated():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	attack_area.body_entered.connect(_on_attack_entered)
	attack_area.body_exited.connect(_on_attack_exited)
	
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.one_shot = false
	
	attack_1_timer.one_shot = true
	attack_1_timer.timeout.connect(_on_attack_1_timeout)
	
	attack_1_interval.one_shot = false
	attack_1_interval.timeout.connect(_on_attack_1_interval_timeout)
	
	shot_interval_timer = Timer.new()
	add_child(shot_interval_timer)
	shot_interval_timer.wait_time = shot_interval_phase_1
	shot_interval_timer.one_shot = true
	shot_interval_timer.timeout.connect(_on_shot_interval_timeout)
	
	_knockback_timer = Timer.new()
	add_child(_knockback_timer)
	_knockback_timer.one_shot = true
	_knockback_timer.timeout.connect(_on_knockback_timer_timeout)
	
	attack_3_projectile_timer = Timer.new()
	add_child(attack_3_projectile_timer)
	attack_3_projectile_timer.one_shot = true
	attack_3_projectile_timer.timeout.connect(_on_attack_3_projectile_timeout)
	
	attack_3_second_wave_timer = Timer.new()
	add_child(attack_3_second_wave_timer)
	attack_3_second_wave_timer.one_shot = true
	attack_3_second_wave_timer.timeout.connect(_on_attack_3_second_wave_timeout)
	
	texture.animation_finished.connect(_on_animation_finished)
	
	_play_animation("Idle")
	
	_max_health = _enemy_health

func _physics_process(delta):
	if _on_knockback:
		move_and_slide()
		return
	
	if _is_alive == false:
		move_and_slide()
		return
	
	if player_in_attack and not has_roared:
		_start_roar()

func _check_phase_transition():
	if _enemy_health <= _max_health / 2 and not has_triggered_phase_2:
		has_triggered_phase_2 = true
		_trigger_phase_2()

func _trigger_phase_2():
	_stop_all_attacks()
	
	current_phase = 2
	
	is_attacking = true
	is_in_attack_sequence = true
	current_state = "roar_phase_2"
	_play_animation("Roar_Anticipation")
	
	if enemy_audio:
		enemy_audio.play_roar()

func _start_roar():
	has_roared = true
	_initial_roar_in_progress = true
	is_attacking = true
	is_in_attack_sequence = true
	current_state = "roar_initial"
	_play_animation("Roar_Anticipation")
	
	if enemy_audio:
		enemy_audio.play_roar()

func _start_attack():
	is_attacking = true
	is_in_attack_sequence = true
	current_state = "attack_anticipation"
	
	match current_attack_type:
		1:
			_play_animation("Attack_Anticipation_1")
			attack_1_timer.wait_time = attack_1_anticipation_duration
			attack_1_timer.start()
			if enemy_audio:
				enemy_audio.play_attack_1_anticipation()  # ← ANTECIPAÇÃO 1
		2:
			_play_animation("Attack_Anticipation_2")
			# 🔒 Trava a posição do player AGORA, no início do ataque.
			# Assim o projétil mira onde ele estava quando o ataque começou,
			# mesmo que ele saia da attack_area antes da animação terminar.
			# Se por algum motivo player_in_attack já estiver nulo neste instante
			# exato (caso raro), mantém o último valor conhecido em vez de travar em 0.
			if player_in_attack:
				_attack_2_target_x = player_in_attack.global_position.x
			if enemy_audio:
				enemy_audio.play_attack_2_anticipation()  # ← ANTECIPAÇÃO 2
		3:
			_play_animation("Attack_Anticipation_3")
			if enemy_audio:
				enemy_audio.play_attack_3_anticipation()  # ← ANTECIPAÇÃO 3

func _stop_attack():
	is_attacking = false
	is_in_attack_sequence = false
	current_state = "idle"
	_play_animation("Idle")
	
	if not shot_interval_timer.is_stopped():
		shot_interval_timer.stop()

func _play_animation(animation_name: String):
	if texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)

func _on_fire_timer_timeout():
	pass

func _on_animation_finished():
	match texture.animation:
		"Roar_Anticipation":
			current_state = "roar"
			_play_animation("Roar")
			attack_1_timer.wait_time = roar_duration
			attack_1_timer.start()
			
			# INSTANCIAR O EFEITO VISUAL DO ROAR
			if roar_fx_scene:
				roar_fx_instance = roar_fx_scene.instantiate()
				add_child(roar_fx_instance)
			
			# SHAKE DA CÂMERA (duração sincronizada com o rugido)
			var camera = get_tree().get_first_node_in_group("camera")
			if camera and camera.has_method("shake_camera"):
				camera.shake_camera(5, roar_duration)
			
			# VIBRAÇÃO DO CONTROLE (duração sincronizada com o rugido)
			ControllerVibration.vibrate_custom(0.8, 0.8, roar_duration)
		
		"Roar":
			pass
		
		"Attack_Anticipation_1":
			pass
		"Attack_1":
			# FADE OUT DO ATTACK 1 AUDIO
			if enemy_audio:
				enemy_audio.stop_attack_1_with_fade()
		"Attack_Anticipation_2":
			is_in_attack_sequence = true
			current_state = "attack"
			_play_animation("Attack_2")
		"Attack_2":
			_spawn_projectile_attack_2()
			_finish_attack()
		"Attack_Anticipation_3":
			is_in_attack_sequence = true
			current_state = "attack"
			_play_animation("Attack_3")
			attack_3_projectile_timer.wait_time = attack_3_projectile_delay
			attack_3_projectile_timer.start()
		"Attack_3":
			_finish_attack()
		"Idle":
			pass

func _finish_attack():
	is_in_attack_sequence = false
	is_attacking = false
	current_state = "idle"
	_play_animation("Idle")
	
	shot_interval_timer.wait_time = shot_interval_phase_1 if current_phase == 1 else shot_interval_phase_2
	shot_interval_timer.start()

func _on_shot_interval_timeout():
	if player_in_attack and not is_attacking:
		# Garantir que o próximo ataque seja diferente do anterior
		var available_attacks = [1, 2, 3]
		available_attacks.erase(last_attack_type)  # Remove o último ataque usado
		
		current_attack_type = available_attacks[randi() % available_attacks.size()]
		last_attack_type = current_attack_type  # Guarda para a próxima vez
	
	_start_attack()

func _on_attack_1_timeout():
	match texture.animation:
		"Roar":
			# Detecta se esse era o roar INICIAL usando a flag dedicada.
			# (Não dá pra confiar em current_state == "roar_initial" aqui, pois
			# _on_animation_finished já sobrescreveu current_state para "roar"
			# no momento em que a animação Roar_Anticipation terminou, bem antes
			# desse timeout disparar.)
			var was_initial_roar = _initial_roar_in_progress
			_initial_roar_in_progress = false
			
			# DESTRUIR O EFEITO VISUAL DO ROAR
			if roar_fx_instance and is_instance_valid(roar_fx_instance):
				roar_fx_instance.queue_free()
				roar_fx_instance = null
			
			if current_state == "roar_phase_2":
				shot_interval_timer.wait_time = shot_interval_phase_2
			
			is_in_attack_sequence = false
			is_attacking = false
			current_state = "idle"
			_play_animation("Idle")
			
			# 🔓 Só agora o roar inicial está REALMENTE completo
			# (animação + roar_duration rodaram por completo).
			# É essa flag que o BaalBerithSpawn espera antes de soltar o primeiro minion.
			if was_initial_roar:
				initial_roar_complete = true
			
			_start_attack()
		"Attack_Anticipation_1":
			is_in_attack_sequence = true
			current_state = "attack"
			_play_animation("Attack_1")
			attack_1_timer.wait_time = attack_1_duration
			attack_1_timer.start()
			attack_1_projectile_count = 0
			attack_1_interval.start()
			if enemy_audio:
					enemy_audio.play_attack_1()
		"Attack_1":
			attack_1_interval.stop()
			_finish_attack()

func _on_attack_3_projectile_timeout():
	_spawn_stationary_projectile_attack_3([0, -100, -200])
	
	if current_phase == 2:
		attack_3_second_wave_timer.wait_time = attack_3_second_wave_delay
		attack_3_second_wave_timer.start()

func _on_attack_3_second_wave_timeout():
	_spawn_stationary_projectile_attack_3([-50, -150, -250])

func _on_attack_1_interval_timeout():
	if attack_1_projectile_count < attack_1_max_projectiles:
		_spawn_projectile_attack_1()
		attack_1_projectile_count += 1
	else:
		attack_1_interval.stop()

func _spawn_projectile_attack_1():
	if not projectile_attack_1 or not attack_point_1:
		return
	
	var projectile = projectile_attack_1.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var random_y_offset = randf_range(-y_offset_range, y_offset_range)
	projectile.global_position = attack_point_1.global_position + Vector2(0, random_y_offset)
	
	var direction = Vector2(1, 0)
	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_speed)

func _spawn_projectile_attack_2():
	if not projectile_attack_2 or not attack_point_2:
		return
	
	var projectile = projectile_attack_2.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# Usa a posição X travada no início do ataque (_attack_2_target_x),
	# garantindo que o projétil sempre spawne mesmo se o player saiu da area.
	projectile.global_position = Vector2(_attack_2_target_x, attack_point_2.global_position.y)
	
	if projectile.has_method("setup"):
		projectile.setup(Vector2.ZERO, 0)

func _spawn_stationary_projectile_attack_3(offsets: Array):
	if not projectile_attack_3 or not attack_point_3:
		return
	
	for i in range(3):
		var projectile = projectile_attack_3.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		var offset = Vector2(offsets[i], 0)
		projectile.global_position = attack_point_3.global_position + offset

func _on_attack_entered(body):
	if body is BaseCharacter:
		player_in_attack = body

func _on_attack_exited(body):
	if body == player_in_attack:
		player_in_attack = null

func update_health(_damage: int, _entity) -> void:
	if _is_alive == false:
		queue_free()
		return
		
	_knockback(_entity)
	_enemy_health -= _damage
	
	_check_phase_transition()
	
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)
	
	if _enemy_health <= 0:
		if hurt_box:
			hurt_box.monitoring = false
			hurt_box.monitorable = false
		
		if spawn_area and is_instance_valid(spawn_area):
			spawn_area.destroy_all_minions()
		
		_stop_all_attacks()
		_knockback_timer.start(_dead_knockback_timer)
		_kill()
		return

func _set_shader_blink_intensity(newValue: float) -> void:
	if not texture:
		return
	
	if not texture.material:
		return
	
	if not texture.material.shader:
		return
	
	# Ativar/desativar blink + definir intensidade
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
	
	if fire_particle:
		fire_particle.visible = true
		fire_particle.emitting = true
	
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	player_in_attack = null
	
	# SALVAR MORTE E EMITIR SIGNAL
	if not _is_alive:
		return
	
	_is_alive = false
	_save_boss_death()
	boss_defeated.emit(boss_id)
	
	# ===== 🎵 FADE OUT DA MÚSICA DO BOSS (TEMPO REAL) =====
	if AudioManager:
		AudioManager.stop_music_realtime(5.0)
		print("🎵 Fade out da música do boss iniciado (5s tempo real)")
	
	# ===== 🎺 TOCAR SOM DE VITÓRIA =====
	if enemy_audio:
		enemy_audio.play_victory()
	
	# Aguardar animação terminar
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	queue_free()

func _stop_all_attacks() -> void:
	is_attacking = false
	is_in_attack_sequence = false
	
	if not shot_interval_timer.is_stopped():
		shot_interval_timer.stop()
	if not attack_1_timer.is_stopped():
		attack_1_timer.stop()
	if not attack_1_interval.is_stopped():
		attack_1_interval.stop()
	if not attack_3_projectile_timer.is_stopped():
		attack_3_projectile_timer.stop()
	if not attack_3_second_wave_timer.is_stopped():
		attack_3_second_wave_timer.stop()
func _on_knockback_timer_timeout() -> void:
	_on_knockback = false


func _on_frame_changed() -> void:
	# Controle da hitbox do Attack_2
	if attack_impact_collision:
		attack_impact_collision.disabled = not (texture.animation == "Attack_2" and texture.frame in range(2, 6))
	
	# Tocar som do Attack 2 no frame 2
	if texture.animation == "Attack_2" and texture.frame == 2:
		if enemy_audio:
			enemy_audio.play_attack_2()
