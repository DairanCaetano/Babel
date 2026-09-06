extends CharacterBody2D
class_name ZumbiArqueiro

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var fire_rate: float = 1.0
@export var y_offset_range: float = 30.0 

@export_category("Initial Direction")
@export var start_facing_right: bool = false  ## Define se o inimigo começa virado para direita (true) ou esquerda (false)

@export_category("Objects")
@export var detection_area: Area2D 
@export var attack_area: Area2D 
@export var texture: AnimatedSprite2D
@export var fire_point: Marker2D 
@export var fire_timer: Timer
@export var fire_particle: GPUParticles2D
@export var hurt_box: Area2D

@export_category("Health System")
@export var _enemy_health: int = 10
@export var _hit_knockback_timer: float = 0.3
@export var _dead_knockback_timer: float = 0.5
@export var _knockback_speed: float = 256.0

@export_category("Attack Settings")
@export var shot_interval: float = 2.0  # Tempo entre disparos em segundos

@export_category("Physics")
@export var gravity: float = 980.0  # Gravidade padrão do Godot

var player_detected: BaseCharacter = null
var player_in_attack: BaseCharacter = null
var is_facing_right: bool = true
var current_state: String = "idle"
var is_attacking: bool = false

var is_in_attack_sequence: bool = false 
var shot_interval_timer: Timer  # Timer para controlar intervalo entre disparos

var _on_knockback: bool = false
var _is_alive: bool = true
var _knockback_timer: Timer

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Conecta as áreas
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_area.body_entered.connect(_on_attack_entered)
	attack_area.body_exited.connect(_on_attack_exited)
	
	# Configura o timer de disparo
	fire_timer.wait_time = 1.0 / fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.one_shot = false
	
	# Cria e configura o timer de intervalo entre disparos
	shot_interval_timer = Timer.new()
	add_child(shot_interval_timer)
	shot_interval_timer.wait_time = shot_interval
	shot_interval_timer.one_shot = true
	shot_interval_timer.timeout.connect(_on_shot_interval_timeout)
	
	# Cria e configura o timer de knockback
	_knockback_timer = Timer.new()
	add_child(_knockback_timer)
	_knockback_timer.one_shot = true
	_knockback_timer.timeout.connect(_on_knockback_timer_timeout)
	
	# Conecta sinais de animação
	if texture.animation_finished.connect(_on_animation_finished) != OK:
		print("❌ Erro ao conectar animation_finished")
	
	# Inicia com animação idle
	_play_animation("Idle")
	
	# APLICA A DIREÇÃO INICIAL CONFIGURADA NO INSPETOR
	is_facing_right = start_facing_right
	_update_direction()
	
	print("🟢 ZUMBI ARQUEIRO INICIALIZADO")
	print("- Vida inicial: ", _enemy_health)
	print("- Intervalo entre disparos: ", shot_interval, "s")
	print("- Direção inicial: ", "DIREITA" if start_facing_right else "ESQUERDA")
	print("- Script possui update_health: ", has_method("update_health"))

func _physics_process(delta):
	# Aplica gravidade sempre que não estiver no chão
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Zera a velocidade Y quando está no chão e não está em knockback
		if not _on_knockback and _is_alive:
			velocity.y = 0
	
	# Sistema de knockback - apenas aplica o movimento
	if _on_knockback:
		move_and_slide()
		return
	
	# Se morreu, apenas aplica movimento e gravidade
	if _is_alive == false:
		move_and_slide()
		return
	
	# AGORA SIM zera velocidade X quando não está em knockback (inimigo parado)
	velocity.x = 0
	
	# Muda direção APENAS se detectou jogador (não afeta ataque)
	if player_detected:
		_look_at_player()
	
	# Gerencia estado de ataque APENAS baseado na ÁREA DE ATAQUE
	if player_in_attack and not is_attacking:
		_start_attack()
	elif not player_in_attack and is_attacking and not is_in_attack_sequence:
		_stop_attack()
	
	# Sempre aplica o movimento no final
	move_and_slide()

func _look_at_player():
	var direction_to_player = (player_detected.global_position - global_position).normalized()
	var should_face_right = direction_to_player.x > 0
	
	if should_face_right != is_facing_right:
		is_facing_right = should_face_right
		_update_direction()

func _update_direction():
	var direction_x = 1 if is_facing_right else -1
	
	if direction_x > 0:
		# Jogador à direita - ativa flip_h e move attack_area para direita
		texture.flip_h = true
		fire_point.position.x = abs(fire_point.position.x)
		attack_area.position.x = 289
		attack_area.position.y = 22
		hurt_box.position.x = 4  # Posição original quando virado para direita
	
	if direction_x < 0:
		# Jogador à esquerda - mantém flip_h desativado e attack_area à esquerda
		texture.flip_h = false
		fire_point.position.x = -abs(fire_point.position.x)
		attack_area.position.x = -92
		attack_area.position.y = 22
		hurt_box.position.x = -4  # Posição invertida quando virado para esquerda

func _start_attack():
	is_attacking = true
	is_in_attack_sequence = false
	current_state = "attack_anticipation"
	_play_animation("Attack_Anticipaton")
	
	if fire_timer.is_stopped():
		fire_timer.start()

func _stop_attack():
	if is_in_attack_sequence:
		is_attacking = false
		if not fire_timer.is_stopped():
			fire_timer.stop()
		if not shot_interval_timer.is_stopped():
			shot_interval_timer.stop()
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
	else:
		print("❌ Animação não encontrada: ", animation_name)
		if texture.sprite_frames:
			print("📋 Animações disponíveis: ", texture.sprite_frames.get_animation_names())
		else:
			print("❌ SpriteFrames não configurado!")

func _on_fire_timer_timeout():
	if is_attacking:
		_execute_attack()

func _execute_attack():
	if current_state != "attack_anticipation":
		current_state = "attack_anticipation"
		_play_animation("Attack_Anticipaton")

func _on_animation_finished():
	match texture.animation:
		"Attack_Anticipaton":
			is_in_attack_sequence = true
			_fire_projectile()
			current_state = "attack"
			_play_animation("Attack")
		
		"Attack":
			is_in_attack_sequence = false
			
			if is_attacking and player_in_attack:
				# Inicia o timer de intervalo entre disparos
				_start_shot_interval()
			else:
				is_attacking = false
				current_state = "idle"
				_play_animation("Idle")
		
		"Idle":
			# Não há mais lógica de idle pause aleatória
			# O idle só acontece quando não está atacando
			if is_attacking and player_in_attack:
				current_state = "attack_anticipation"
				_play_animation("Attack_Anticipaton")
			else:
				current_state = "idle"
				_play_animation("Idle")

func _start_shot_interval():
	"""Inicia o intervalo fixo entre disparos"""
	current_state = "idle"
	_play_animation("Idle")
	
	# Para o timer de disparo durante o intervalo
	if not fire_timer.is_stopped():
		fire_timer.stop()
	
	# Atualiza o tempo do timer com o valor do inspetor
	shot_interval_timer.wait_time = shot_interval
	shot_interval_timer.start()
	
	print("⏱️ Iniciando intervalo de ", shot_interval, "s entre disparos")

func _on_shot_interval_timeout():
	"""Callback quando o intervalo entre disparos termina"""
	print("✅ Intervalo terminado, pronto para próximo disparo")
	
	if is_attacking and player_in_attack:
		# Reinicia o ciclo de ataque
		if fire_timer.is_stopped():
			fire_timer.start()
		current_state = "attack_anticipation"
		_play_animation("Attack_Anticipaton")
	else:
		# Se não está mais atacando, volta para idle
		current_state = "idle"
		_play_animation("Idle")

func _fire_projectile():
	if not projectile_scene:
		return
	
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var random_y_offset = randf_range(-y_offset_range, y_offset_range)
	projectile.global_position = fire_point.global_position + Vector2(0, random_y_offset)
	
	var direction = Vector2(1 if is_facing_right else -1, 0)
	
	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_speed)
	
	print("🏹 Projétil disparado!")

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

# Sistema de dano e morte
func update_health(_damage: int, _entity) -> void:
	print("=== DEBUG update_health ===")
	print("Dano recebido: ", _damage)
	print("Vida ANTES: ", _enemy_health)
	print("is_alive ANTES: ", _is_alive)
	print("Entidade atacante: ", _entity)
	
	if _is_alive == false:
		print("Inimigo já está morto - destruindo")
		queue_free()
		return
		
	_knockback(_entity)
	_enemy_health -= _damage
	
	print("Vida DEPOIS: ", _enemy_health)
	
	# Efeito visual de piscar quando leva dano
	var tween = get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)
	
	# Shake da camera
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)
	
	if _enemy_health <= 0:
		print("💀 VIDA ZERO - INICIANDO MORTE")
		_stop_all_attacks()
		_knockback_timer.start(_dead_knockback_timer)
		_kill()
		return
	else:
		print("💥 Inimigo ferido mas vivo")
		
	_knockback_timer.start(_hit_knockback_timer)
	print("==============================")

func _set_shader_blink_intensity(new_value: float) -> void:
	if not texture:
		return
	
	if not texture.material:
		return
	
	if not texture.material.shader:
		return
	
	# Ativar/desativar blink + definir intensidade
	texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	texture.material.set_shader_parameter("blink_intensity", new_value)


func _knockback(_entity) -> void:
	print("=== KNOCKBACK ===")
	var _knockback_direction: Vector2 = _entity.global_position.direction_to(global_position)
	velocity.x = _knockback_direction.x * _knockback_speed
	velocity.y = -1 * _knockback_speed
	_knockback_timer.start(0.2)
	_on_knockback = true
	print("Knockback aplicado: ", velocity)
	print("==================")

func _kill() -> void:
	print("=== INICIANDO MORTE ===")
	_play_animation("Dead")
	set_collision_layer_value(4, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	_is_alive = false
	player_detected = null
	player_in_attack = null
	
	# Desativa a hurt_box para não causar mais dano
	if hurt_box:
		hurt_box.monitoring = false
		hurt_box.monitorable = false
	
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	print("💀 DESTRUINDO ZUMBI ARQUEIRO")
	queue_free()

func _stop_all_attacks() -> void:
	is_attacking = false
	is_in_attack_sequence = false
	
	if not fire_timer.is_stopped():
		fire_timer.stop()
	if not shot_interval_timer.is_stopped():
		shot_interval_timer.stop()

func _on_knockback_timer_timeout() -> void:
	print("🔄 Knockback finalizado")
	_on_knockback = false
