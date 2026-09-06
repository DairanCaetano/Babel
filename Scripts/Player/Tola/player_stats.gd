extends Node2D
class_name PlayerStats

var base_health: int = 100
var base_stamina: int = 15
var base_attack_damage: int = 5
var bonus_health: int = 0
var bonus_stamina: int = 0
var bonus_attack: int = 0
var current_stamina: int
var current_health: int
var max_stamina: int
var max_health: int

var allow_stamina_regen: bool = true

@export_group("Stamina Regeneration")
@export var regen_delay: float = 0.5
@export var regen_tick_rate: float = 0.1
@export var regen_amount_low: int = 1
@export var regen_amount_medium: int = 2
@export var regen_amount_high: int = 3
@export var use_progressive_regen: bool = true

var last_stamina_use_time: float = 0.0

@export_group("Health Cap")
@export var max_raw_health: int = 200
@export var max_equipment_health_bonus: int = 100  # ← NOVO: teto do bônus vindo de equipamento

var equipment_bonus_health: int = 0  # ← NOVOde equipamento

@export_group("Stamina Cap")
@export var max_raw_stamina: int = 30  # ← NOVO: teto de stamina BRUTA (dobro da base de 15)

@export_category("Objects")
@export var _character: BaseCharacter
@export var particle2d: GPUParticles2D

func _ready() -> void:
	# ← CORREÇÃO: restaura os bônus de coletáveis do save (estava faltando)
	bonus_health = serialization.game_data.get("bonus_health_total", 0)
	bonus_stamina = serialization.game_data.get("bonus_stamina_total", 0)
	
	max_stamina = base_stamina + bonus_stamina
	current_stamina = max_stamina
	current_health = base_health + bonus_health
	max_health = current_health
	
	print("Stats iniciais - Health: ", current_health, " Stamina: ", current_stamina)
	
	await get_tree().physics_frame
	
	global.ui_bars.init_bar(max_health, max_stamina)
	
	# ← Aplica a largura da barra SEM animação, se já vier com bônus salvo
	if bonus_health > 0:
		var health_ratio: float = float(max_health) / float(base_health)
		global.ui_bars.increase_max_value("health", max_health, current_health, health_ratio, false)
	
	if bonus_stamina > 0:
		var stamina_ratio: float = float(max_stamina) / float(base_stamina)
		global.ui_bars.increase_max_value("stamina", max_stamina, current_stamina, stamina_ratio, false)
	
	if global.ui_equipments and not global.ui_equipments.equipment_changed.is_connected(_on_equipment_changed):
		global.ui_equipments.equipment_changed.connect(_on_equipment_changed)
	
	if _character and _character.has_node("StaminaRegenTimer"):
		var timer = _character.get_node("StaminaRegenTimer")
		
		timer.wait_time = regen_tick_rate
		
		if not timer.timeout.is_connected(_on_stamina_regen_timer_timeout):
			timer.timeout.connect(_on_stamina_regen_timer_timeout)
		timer.start()
		print("Timer de regeneração configurado e iniciado")
		print("Configurações: Tick rate: ", regen_tick_rate, "s, Delay: ", regen_delay, "s")
		print("Valores regen: Baixo=", regen_amount_low, " Médio=", regen_amount_medium, " Alto=", regen_amount_high)
	else:
		print("ERRO: StaminaRegenTimer não foi encontrado em BaseCharacter!")

func update_health(type: String, value: int) -> void:
	print("Atualizando health: ", type, " valor: ", value)
	match type:
		"increase":
			current_health += value
			if current_health >= max_health:
				current_health = max_health
		"decrease":
			particle2d.restart()
			particle2d.emitting = true
			current_health -= value
			if current_health <= 0:
				current_health = 0
				_character.is_alive = false
				
	global.ui_bars.update_bar("HealthBar", current_health)

func update_stamina(type: String, value: int) -> void:
	print("Atualizando stamina: ", type, " valor: ", value, " atual: ", current_stamina)
	match type:
		"increase":
			current_stamina += value
			if current_stamina >= max_stamina:
				current_stamina = max_stamina
		"decrease":
			current_stamina -= value
			if current_stamina < 0:
				if has_node("../FireCooldown"):
					$"../FireCooldown".stop()
				current_stamina = 0
			last_stamina_use_time = Time.get_ticks_msec() / 1000.0
			print("Último uso de stamina registrado em: ", last_stamina_use_time)
		
	global.ui_bars.update_bar("StaminaBar", current_stamina)
	print("Stamina após atualização: ", current_stamina, "/", max_stamina)

# ← NOVA FUNÇÃO: chamada pelo coletável HPMax
func increase_max_health(bonus_amount: int) -> void:
	var max_bonus_allowed: int = max_raw_health - base_health
	var actual_bonus: int = min(bonus_amount, max_bonus_allowed - bonus_health)
	
	if actual_bonus <= 0:
		print("💗 Vida máxima bruta já está no teto (", base_health + bonus_health, "/", max_raw_health, ") — bônus ignorado")
		return
	
	bonus_health += actual_bonus
	max_health = base_health + bonus_health
	current_health = max_health
	
	var growth_ratio: float = float(max_health) / float(base_health)
	global.ui_bars.increase_max_value("health", max_health, current_health, growth_ratio, true)
	
	print("💗 HP máximo aumentado! Novo máximo: ", max_health, " (ratio visual: ", growth_ratio, ")")

# ← ATUALIZADA: agora com teto, igual ao HP
func increase_max_stamina(bonus_amount: int) -> void:
	var max_bonus_allowed: int = max_raw_stamina - base_stamina
	var actual_bonus: int = min(bonus_amount, max_bonus_allowed - bonus_stamina)
	
	if actual_bonus <= 0:
		print("⚡ Stamina máxima bruta já está no teto (", base_stamina + bonus_stamina, "/", max_raw_stamina, ") — bônus ignorado")
		return
	
	bonus_stamina += actual_bonus
	max_stamina = base_stamina + bonus_stamina
	current_stamina = max_stamina
	
	var growth_ratio: float = float(max_stamina) / float(base_stamina)
	global.ui_bars.increase_max_value("stamina", max_stamina, current_stamina, growth_ratio, true)
	
	print("⚡ Stamina máxima aumentada! Novo máximo: ", max_stamina, " (ratio visual: ", growth_ratio, ")")

func _on_stamina_regen_timer_timeout() -> void:
	if not allow_stamina_regen:
		return

	var now = Time.get_ticks_msec() / 1000.0
	
	if current_stamina >= max_stamina:
		return
	
	if now - last_stamina_use_time < regen_delay:
		return
	
	var regen_amount: int
	
	if use_progressive_regen:
		if current_stamina <= 5:
			regen_amount = regen_amount_low
		elif current_stamina <= 10:
			regen_amount = regen_amount_medium
		else:
			regen_amount = regen_amount_high
	else:
		regen_amount = regen_amount_low
	
	update_stamina("increase", regen_amount)
	print("Regenerando stamina: +", regen_amount, " Total: ", current_stamina, "/", max_stamina)

func _on_equipment_changed() -> void:
	recalculate_equipment_health_bonus()

func recalculate_equipment_health_bonus() -> void:
	if not _character:
		return
	
	var raw_bonus: int = _character._additional_attributes.get("health", 0)
	var capped_bonus: int = clamp(raw_bonus, 0, max_equipment_health_bonus)
	
	if capped_bonus == equipment_bonus_health:
		return  # nada mudou, evita recálculo desnecessário
	
	var old_max: int = max_health
	var ratio: float = float(current_health) / float(old_max) if old_max > 0 else 1.0
	
	equipment_bonus_health = capped_bonus
	max_health = base_health + bonus_health + equipment_bonus_health
	current_health = clamp(round(ratio * max_health), 0, max_health)
	
	global.ui_bars.update_max_value_only("health", max_health, current_health)
	
	print("🛡️ Bônus de vida por equipamento: +", equipment_bonus_health, " | Max total: ", max_health, " | HP atual: ", current_health)

func set_regen_delay(new_delay: float) -> void:
	regen_delay = new_delay
	print("Delay de regeneração alterado para: ", regen_delay, "s")

func set_regen_tick_rate(new_rate: float) -> void:
	regen_tick_rate = new_rate
	if _character and _character.has_node("StaminaRegenTimer"):
		var timer = _character.get_node("StaminaRegenTimer")
		timer.wait_time = regen_tick_rate
		print("Taxa de regeneração alterada para: ", regen_tick_rate, "s")

func set_regen_amounts(low: int, medium: int, high: int) -> void:
	regen_amount_low = low
	regen_amount_medium = medium
	regen_amount_high = high
	print("Valores de regeneração alterados - Baixo: ", low, " Médio: ", medium, " Alto: ", high)

func toggle_progressive_regen(enabled: bool) -> void:
	use_progressive_regen = enabled
	print("Regeneração progressiva: ", "Ativada" if enabled else "Desativada")
