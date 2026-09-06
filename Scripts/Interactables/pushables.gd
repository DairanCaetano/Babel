extends CharacterBody2D
class_name Pushables

const PUSH_SPEED = 100.0
const ACCELERATION = 600.0
const FRICTION = 0.75

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_hanging: bool = true
var is_being_pushed: bool = false

# ✅ CONTROLE DE IMPACTO NO CHÃO
var just_released: bool = false  # ✅ Flag para saber se acabou de ser solta
var peak_fall_velocity: float = 0.0  # ✅ Maior velocidade atingida durante a queda
var min_fall_velocity_for_shake: float = 300.0

func _physics_process(delta):
	if is_hanging:
		velocity = Vector2.ZERO
		peak_fall_velocity = 0.0
		move_and_slide()
		return
	
	# ✅ SE ACABOU DE SER SOLTA, COMEÇAR A RASTREAR A QUEDA
	if just_released:
		print("🎈 Caixa liberada - iniciando queda")
		just_released = false
		peak_fall_velocity = 0.0
	
	# ✅ GUARDAR A MAIOR VELOCIDADE DE QUEDA
	if not is_on_floor():
		if abs(velocity.y) > peak_fall_velocity:
			peak_fall_velocity = abs(velocity.y)
			print("📊 Velocidade de queda: ", peak_fall_velocity)
	
	# Aplicar gravidade
	velocity.y += gravity * delta
	
	# Atrito horizontal
	if not is_being_pushed:
		velocity.x *= FRICTION
		if abs(velocity.x) < 5.0:
			velocity.x = 0
	
	is_being_pushed = false
	
	# Guardar estado anterior
	var was_on_floor_before = is_on_floor()
	
	# Movimento
	move_and_slide()
	
	# ✅ DETECTAR IMPACTO NO CHÃO
	if not was_on_floor_before and is_on_floor():
		_handle_ground_impact()

func _handle_ground_impact() -> void:
	var fall_speed = peak_fall_velocity
	
	print("📦 Caixa caiu no chão! Velocidade de impacto: ", fall_speed)
	
	# ✅ RESETAR PICO
	peak_fall_velocity = 0.0
	
	# ✅ SE A QUEDA FOI FORTE, TREMER TELA E CONTROLE
	if fall_speed >= min_fall_velocity_for_shake:
		var shake_intensity = remap(fall_speed, min_fall_velocity_for_shake, 1000.0, 0.3, 1.0)
		shake_intensity = clamp(shake_intensity, 0.3, 1.0)
		
		print("💥 IMPACTO FORTE! Intensidade: ", shake_intensity)
		
		# ✅ TREMER A CÂMERA
		var camera = get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("shake_camera"):
			var shake_magnitude = shake_intensity * 3.0
			var shake_duration = 0.5
			camera.shake_camera(shake_magnitude, shake_duration)
			print("🎥 Câmera tremendo - Magnitude: ", shake_magnitude)
		else:
			print("⚠️ Câmera não encontrada ou sem método shake_camera")
		
		# ✅ VIBRAR O CONTROLE
		var vibration_strength = shake_intensity
		var vibration_duration = 0.3
		Input.start_joy_vibration(
			0,
			vibration_strength * 0.7,  # Motor fraco
			vibration_strength,         # Motor forte
			vibration_duration
		)
		print("🎮 Controle vibrando - Força: ", vibration_strength)
	else:
		print("⚠️ Velocidade insuficiente para tremor (mínimo: ", min_fall_velocity_for_shake, ")")

func slide_object(direction):
	is_being_pushed = true
	var target_speed = direction.x * PUSH_SPEED
	velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * get_physics_process_delta_time())

func break_rope() -> void:
	print("📦 Corda cortada!")
	print("🎯 Posição inicial Y: ", global_position.y)
	is_hanging = false
	just_released = true  # ✅ Marcar que acabou de ser solta
	peak_fall_velocity = 0.0  # ✅ Resetar velocidade pico
