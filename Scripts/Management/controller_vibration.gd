extends Node

# ✅ Verificar se há controle conectado
func has_controller() -> bool:
	return Input.get_connected_joypads().size() > 0

# ✅ Vibração leve (para ações sutis)
func vibrate_light() -> void:
	_vibrate(0.2, 0.3, 0.15)

# ✅ Vibração média (para dano normal)
func vibrate_medium() -> void:
	_vibrate(0.4, 0.6, 0.25)

# ✅ Vibração forte (para dano alto ou eventos importantes)
func vibrate_heavy() -> void:
	_vibrate(0.6, 0.9, 0.35)

# ✅ Vibração customizada (controle total)
func vibrate_custom(weak_motor: float, strong_motor: float, duration: float) -> void:
	_vibrate(weak_motor, strong_motor, duration)

# ✅ Vibração baseada em intensidade (0.0 a 1.0)
func vibrate_by_intensity(intensity: float, duration: float = 0.25) -> void:
	var clamped_intensity = clamp(intensity, 0.0, 1.0)
	var weak = clamped_intensity * 0.4
	var strong = clamped_intensity * 0.9
	_vibrate(weak, strong, duration)

# ✅ NOVO: Vibração ao pousar no chão (bem suave)
func vibrate_on_land() -> void:
	_vibrate(0.15, 0.2, 0.1)

# ✅ MODIFICADO: Vibração ao receber dano com opção de alta intensidade
func vibrate_on_damage(damage_amount: int, high_intensity: bool = false) -> void:
	# Escolher intensidade base
	var base_multiplier: float = 1.5 if high_intensity else 0.8
	
	# Calcular intensidade baseada no dano
	var base_intensity = clamp(damage_amount / 50.0, 0.3, 1.0) * base_multiplier
	
	var weak_motor = base_intensity * 0.4
	var strong_motor = base_intensity * 0.9
	
	# Duração maior para dano intenso
	var duration = 0.3 if high_intensity else 0.2
	
	_vibrate(weak_motor, strong_motor, duration)

# ✅ NOVO: Vibração ao fazer parry
func vibrate_on_parry() -> void:
	_vibrate(0.5, 0.6, 0.12)

# ✅ NOVO: Vibração ao acertar boss
func vibrate_on_boss_hit() -> void:
	_vibrate(0.5, 0.7, 0.15)

# ✅ Parar vibração de todos os controles
func stop_vibration() -> void:
	var joysticks = Input.get_connected_joypads()
	for controller_id in joysticks:
		Input.stop_joy_vibration(controller_id)

# ✅ Função interna para executar a vibração
func _vibrate(weak_motor: float, strong_motor: float, duration: float) -> void:
	var joysticks = Input.get_connected_joypads()
	
	if joysticks.size() == 0:
		return
	
	# Vibrar o primeiro controle conectado
	var controller_id = joysticks[0]
	
	# Garantir valores entre 0.0 e 1.0
	weak_motor = clamp(weak_motor, 0.0, 1.0)
	strong_motor = clamp(strong_motor, 0.0, 1.0)
	
	Input.start_joy_vibration(controller_id, weak_motor, strong_motor, duration)
