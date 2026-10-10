extends Node2D
class_name CharacterSubweapon

const _AXE_PROJECTILE: PackedScene = preload("res://Scenes/Projectile/projectile_axe.tscn")
const _SPEAR_PROJECTILE: PackedScene = preload("res://Scenes/Projectile/projectilespear.tscn")
const _CHAKRAM_PROJECTILE: PackedScene = preload("res://Scenes/Projectile/projectile_chakram.tscn")
const _DAGGER_PROJECTILE: PackedScene = preload("res://Scenes/Projectile/projectile_dagger.tscn")
const _WHIP_SCENE: PackedScene = preload("res://Scenes/Projectile/whip_attack.tscn")
const _GREAT_AXE_SCENE: PackedScene = preload("res://Scenes/Projectile/great_axe_melee.tscn")

# Referências
@export var _character: BaseCharacter
@export var _stats: PlayerStats
@export var _character_texture: CharacterTexture
@export var _firefx: GPUParticles2D

# Sub-armas lançáveis
var _has_axe: bool = false
var _axe_cooldown: float = 0.5

var _has_spear: bool = false
var _spear_cooldown: float = 0.5

var _has_chakram: bool = false
@export var _chakram_cooldown: float = 3.0
var _current_chakram: ProjectileChakram = null

var _has_dagger: bool = false
@export var _dagger_cooldown: float = 0.5

var _whip_ready: bool = true
@export var _whip_cooldown: float = 0.6

var _audio: CharacterAudio

# 🔥 Sistema de Fire
var _is_fire_active: bool = false

@export_group("Fire Settings")
@export var _fire_stamina_cost_per_second: float = 3.0
@export var _fire_damage_bonus_percent: float = 40.0 # +40% em todo o dano enquanto o fogo está ativo

var _fire_damage_bonus: int = 0

@export_category("Fire Effects")
@export var fire_activation_effect: PackedScene
@export var fire_attack_effect_1: PackedScene
@export var fire_attack_effect_2: PackedScene
@export var fire_attack_effect_3: PackedScene

# 🌀 Giro do chicote (continua o golpe se o botão seguir pressionado)
var _whip_spin_active: bool = false
@export var _whip_spin_stamina_cost_per_second: float = 4.0
var _current_whip_spin: WhipAttack = null

# Timers criados via código (dinâmicos)
@onready var fire_stamina_timer: Timer
@onready var throw_cooldown_timer: Timer
@onready var whip_spin_stamina_timer: Timer

# ========== MACHADO DE GUERRA (corpo a corpo) ==========
@export_category("Great Axe")
@export var _great_axe_stamina_cost: int = 5
@export var _great_axe_cooldown: float = 1.2 # conta a partir do FIM do golpe (chão ou pouso)
@export var _great_axe_dive_frame: int = 7 # no ar: a partir deste frame o Tola despenca
@export var _great_axe_hold_frame: int = 9 # último frame: segurado durante a queda até tocar o chão
@export var _great_axe_dive_gravity_mult: float = 2.0
@export var _great_axe_max_fall_speed: float = 900.0

var _great_axe_ready: bool = true
var _current_great_axe: GreatAxeAttack = null
var _great_axe_active: bool = false # ✅ estado explícito (não depende de comparar referência com null)
var _great_axe_in_air: bool = false
var _great_axe_diving: bool = false

# Timers fixos na cena (atribuir no Inspector)
@export_category("Cooldown Timers")
@export var dagger_cooldown_timer: Timer
@export var whip_cooldown_timer: Timer

func _ready() -> void:
	if not _character:
		return
	
	_audio = _character._audio
	
	if _character.has_node("FireStaminaTimer"):
		fire_stamina_timer = _character.get_node("FireStaminaTimer")
	else:
		fire_stamina_timer = Timer.new()
		fire_stamina_timer.name = "FireStaminaTimer"
		fire_stamina_timer.wait_time = 1.0
		_character.add_child(fire_stamina_timer)
	
	fire_stamina_timer.timeout.connect(_on_fire_stamina_timeout)
	
	if _character.has_node("ThrowCooldown"):
		throw_cooldown_timer = _character.get_node("ThrowCooldown")
	else:
		throw_cooldown_timer = Timer.new()
		throw_cooldown_timer.name = "ThrowCooldown"
		throw_cooldown_timer.one_shot = true
		throw_cooldown_timer.wait_time = 5.0
		_character.add_child(throw_cooldown_timer)
	throw_cooldown_timer.timeout.connect(_on_throw_cooldown_timeout)
	
	if _character.has_node("WhipSpinStaminaTimer"):
		whip_spin_stamina_timer = _character.get_node("WhipSpinStaminaTimer")
	else:
		whip_spin_stamina_timer = Timer.new()
		whip_spin_stamina_timer.name = "WhipSpinStaminaTimer"
		whip_spin_stamina_timer.wait_time = 1.0
		_character.add_child(whip_spin_stamina_timer)
	whip_spin_stamina_timer.timeout.connect(_on_whip_spin_stamina_timeout)
	
	if not dagger_cooldown_timer:
		push_error("⚠️ dagger_cooldown_timer não foi atribuído no Inspector!")
	else:
		dagger_cooldown_timer.timeout.connect(_on_dagger_cooldown_timeout)
	
	if not whip_cooldown_timer:
		push_error("⚠️ whip_cooldown_timer não foi atribuído no Inspector!")
	else:
		whip_cooldown_timer.timeout.connect(_on_whip_cooldown_timeout)

func _process(_delta: float) -> void:
	if is_fire_active() and _stats.current_stamina <= 0:
		_deactivate_fire()
	
	_handle_whip_spin_cancel()

# ========== LÓGICA PRINCIPAL DAS SUB-ARMAS ==========
func handle_sub_weapon_input() -> bool:
	if not Input.is_action_just_pressed("sub_weapon"):
		return false
	
	if can_use_fire():
		var fire_activated = execute_fire_toggle()
		if fire_activated:
			return true
	
	if can_throw_chakram():
		execute_chakram_throw()
		return true

	if can_throw_spear():
		execute_spear_throw()
		return true
	
	if can_throw_axe():
		execute_axe_throw()
		return true
	
	if can_throw_dagger():
		execute_dagger_throw()
		return true

	if can_use_great_axe():
		_execute_great_axe()
		return true

	if can_use_whip():
		_execute_whip_tap()
		return true
	
	return false

# ========== LÓGICA DO MACHADO ==========
func can_throw_axe() -> bool:
	return (
		_has_axe and
		_stats.current_stamina >= 3 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_AXE_NAME"
	)

func execute_axe_throw() -> void:
	_stats.update_stamina("decrease", 3)
	_character_texture.action_animation("Throw_")
	
	if _audio:
		_audio.play_attack_voice()
		_audio.play_throw_axe()
	
	_has_axe = false
	throw_cooldown_timer.wait_time = _axe_cooldown
	throw_cooldown_timer.start()

func throw_axe(is_flipped: bool) -> void:
	var _axe: ProjectileAxe = _AXE_PROJECTILE.instantiate()
	get_tree().root.call_deferred("add_child", _axe)
	_axe.global_position = _character.global_position + Vector2(0, -10)
	_axe.direction = Vector2(-1, 0) if is_flipped else Vector2(1, 0)

# ========== LÓGICA DA LANÇA ==========
func can_throw_spear() -> bool:
	return (
		_has_spear and
		_stats.current_stamina >= 5 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_SPEAR_NAME"
	)


func execute_spear_throw() -> void:
	_stats.update_stamina("decrease", 5)
	_character_texture.action_animation("Throw_Spear")
	
	if _audio:
		_audio.play_attack_voice()
		_audio.play_throw_spear()
	
	_has_spear = false
	throw_cooldown_timer.wait_time = _spear_cooldown
	throw_cooldown_timer.start()

func throw_spear(is_flipped: bool) -> void:
	if not _character or not _character_texture:
		return
	
	var spear = _SPEAR_PROJECTILE.instantiate()
	spear.direction = Vector2(-1, 0) if is_flipped else Vector2(1, 0)
	spear.global_position = _character.global_position + Vector2(0, -10)
	get_tree().root.add_child(spear)

# ========== LÓGICA DO CHAKRAM ==========
func can_throw_chakram() -> bool:
	return (
		_has_chakram and
		_stats.current_stamina >= 10 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_CHAKRAM_NAME"
	)


func execute_chakram_throw() -> void:
	if is_instance_valid(_current_chakram):
		_current_chakram.queue_free()
		_current_chakram = null
	
	_stats.update_stamina("decrease", 10)
	_character_texture.action_animation("Throw_")
	
	if _audio:
		_audio.play_attack_voice()
		_audio.play_throw_chakram()
	
	_has_chakram = false
	throw_cooldown_timer.wait_time = _chakram_cooldown
	throw_cooldown_timer.start()

func throw_chakram(is_flipped: bool) -> void:
	if is_instance_valid(_current_chakram):
		_current_chakram.queue_free()
		_current_chakram = null
	
	if not _CHAKRAM_PROJECTILE:
		return
	
	var chakram: ProjectileChakram = _CHAKRAM_PROJECTILE.instantiate()
	if not chakram:
		return
	
	_current_chakram = chakram
	chakram.tree_exited.connect(_on_chakram_destroyed)
	chakram.direction = Vector2(-1, 0) if is_flipped else Vector2(1, 0)
	
	get_tree().root.add_child(chakram)
	chakram.global_position = _character.global_position + Vector2(0, -10)

func _on_chakram_destroyed() -> void:
	_current_chakram = null

func is_chakram_active() -> bool:
	return is_instance_valid(_current_chakram)

func destroy_current_chakram() -> void:
	if is_instance_valid(_current_chakram):
		_current_chakram.queue_free()
		_current_chakram = null

# ========== LÓGICA DO FIRE 🔥 ==========
func can_use_fire() -> bool:
	if is_fire_active():
		return true
	return (
		_character.is_on_floor() and
		_stats.current_stamina >= 5 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_FIRE_NAME"
	)

func execute_fire_toggle() -> bool:
	if is_fire_active():
		_deactivate_fire()
		return true
	else:
		return _activate_fire()

func _activate_fire() -> bool:
	if _stats.current_stamina < 5:
		return false

	_is_fire_active = true
	_stats.allow_stamina_regen = false

	_apply_fire_damage_bonus()

	if _character_texture and _character_texture.material and _character_texture.material.shader:
		_character_texture.material.set_shader_parameter("fire_active", true)

	if _firefx:
		_firefx.emitting = true

	if fire_stamina_timer:
		fire_stamina_timer.start()

	_character_texture.action_animation("Fire")
	_spawn_fire_effect(fire_activation_effect, "ativação")
	
	if _audio:
		_audio.play_fire_activate()
		_audio.play_fire_loop()

	return true

func _deactivate_fire() -> void:
	_is_fire_active = false
	_stats.allow_stamina_regen = true

	_remove_fire_damage_bonus()

	if _character_texture and _character_texture.material and _character_texture.material.shader:
		_character_texture.material.set_shader_parameter("fire_active", false)

	if _firefx:
		_firefx.emitting = false

	if fire_stamina_timer:
		fire_stamina_timer.stop()
	
	if _audio:
		_audio.stop_fire_loop()

func is_fire_active() -> bool:
	return _is_fire_active

# ========== SISTEMA DE BÔNUS DE DANO DO FIRE ==========
# O fogo agora é um MULTIPLICADOR aplicado no cálculo central de dano
# (BaseCharacter.scale_damage). Ex.: 40% → ataque 5 vira 7.
func get_fire_damage_percent() -> float:
	return _fire_damage_bonus_percent

func _apply_fire_damage_bonus() -> void:
	pass # mantido por compatibilidade: o bônus é lido direto em scale_damage()

func _remove_fire_damage_bonus() -> void:
	pass # mantido por compatibilidade

func _spawn_fire_effect(effect_scene: PackedScene, effect_name: String = "efeito", speed: float = 1.0) -> void:
	if not effect_scene:
		return
	
	if not _character or not _character_texture:
		return
	
	var effect = effect_scene.instantiate()
	if not effect:
		return
	
	effect.global_position = _character.global_position
	
	if "flip_h" in effect:
		effect.flip_h = _character_texture.flip_h
	elif effect is GPUParticles2D:
		if _character_texture.flip_h:
			effect.scale.x = -abs(effect.scale.x)
		else:
			effect.scale.x = abs(effect.scale.x)
	
	# ✅ Acompanha a velocidade do ataque (Olhos de Falcão)
	if speed != 1.0 and "speed_scale" in effect:
		effect.speed_scale = speed
	
	get_tree().root.add_child(effect)

func spawn_fire_attack_effect(attack_type: String) -> void:
	if not is_fire_active():
		return
	
	var attack_speed: float = 1.0
	if _character and _character.has_method("get_attack_speed_multiplier"):
		attack_speed = _character.get_attack_speed_multiplier()
	
	match attack_type:
		"Attack_1", "Attack_Air":
			_spawn_fire_effect(fire_attack_effect_1, "ataque 1", attack_speed)
		"Attack_2":
			_spawn_fire_effect(fire_attack_effect_2, "ataque 2", attack_speed)
		"Counter":
			_spawn_fire_effect(fire_attack_effect_3, "counter")

# ========== LÓGICA DA ADAGA ==========

func can_throw_dagger() -> bool:
	return (
		_has_dagger and
		_stats.current_stamina >= 3 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_DAGGER_NAME"
	)

func execute_dagger_throw() -> void:
	_stats.update_stamina("decrease", 3)
	_character_texture.action_animation("Throw_")

	if _audio:
		_audio.play_attack_voice()
		_audio.play_throw_axe()  # trocar por som próprio da adaga se tiver

	_has_dagger = false
	dagger_cooldown_timer.wait_time = _dagger_cooldown
	dagger_cooldown_timer.start()

func throw_dagger(is_flipped: bool) -> void:
	var dagger: ProjectileDagger = _DAGGER_PROJECTILE.instantiate()
	get_tree().root.call_deferred("add_child", dagger)
	dagger.global_position = _character.global_position + Vector2(0, -10)
	dagger.direction = Vector2(-1, 0) if is_flipped else Vector2(1, 0)

func _on_dagger_cooldown_timeout() -> void:
	_has_dagger = true

# ========== LÓGICA DO CHICOTE (golpe imediato) ==========

func can_use_whip() -> bool:
	return (
		_whip_ready and
		_stats.current_stamina >= 4 and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_WHIP_NAME"
	)

func _execute_whip_tap() -> void:
	if not can_use_whip():
		return
	
	_stats.update_stamina("decrease", 4)

	var variant: String = "solo"
	if not _character.is_on_floor():
		variant = "air"
	elif _character._is_crouching:
		variant = "down"

	match variant:
		"air":
			_character_texture.action_animation("Whip_Air")
		"down":
			_character_texture.action_animation("Whip_Down")
		_:
			_character_texture.action_animation("Whip_Solo")

	_spawn_whip(variant)

	if _audio:
		_audio.play_attack_voice()
		_audio.play_attack_light()

	_whip_ready = false
	whip_cooldown_timer.wait_time = _whip_cooldown
	whip_cooldown_timer.start()

func _spawn_whip(variant: String) -> void:
	var whip: WhipAttack = _WHIP_SCENE.instantiate()
	var facing_direction: float = -1.0 if _character_texture.flip_h else 1.0
	
	whip.direction = Vector2(facing_direction, 0)
	whip.pending_variant = variant
	whip.base_position = _character.global_position + Vector2(6 * facing_direction, 0)  # ⚠️ ajustar se precisar
	get_tree().root.call_deferred("add_child", whip)

func _on_whip_cooldown_timeout() -> void:
	_whip_ready = true

# ========== LÓGICA DO CHICOTE (continuar segurando = giro) ==========

# ✅ Chamado pelo CharacterTexture quando a animação Whip_Solo/Air/Down termina.
# Se o botão ainda estiver pressionado e as condições baterem, entra no giro
# em vez de devolver o controle pro jogador. Retorna true se assumiu o giro.
func try_continue_into_spin() -> bool:
	if not Input.is_action_pressed("sub_weapon"):
		return false
	
	if not _character.is_on_floor() or _character._is_crouching:
		return false
	
	if global.ui_equipments._equipments_inventory["weapon"].is_empty():
		return false
	
	if global.ui_equipments._equipments_inventory["weapon"].get("key", "") != "ITEM_WHIP_NAME":
		return false
	
	if _stats.current_stamina < _whip_spin_stamina_cost_per_second:
		return false
	
	_begin_whip_spin()
	return true

func _begin_whip_spin() -> void:
	_whip_spin_active = true
	_stats.allow_stamina_regen = false
	
	_character_texture.action_animation("Whip_Spin")
	
	var facing_direction: float = -1.0 if _character_texture.flip_h else 1.0
	
	_current_whip_spin = _WHIP_SCENE.instantiate()
	_current_whip_spin.direction = Vector2(facing_direction, 0)
	_current_whip_spin.pending_variant = "spin"
	_current_whip_spin.base_position = _character.global_position + Vector2(6 * facing_direction, 0)
	get_tree().root.call_deferred("add_child", _current_whip_spin)
	
	if _audio:
		_audio.play_attack_voice()
	
	whip_spin_stamina_timer.start()

func _end_whip_spin() -> void:
	_whip_spin_active = false
	_stats.allow_stamina_regen = true
	whip_spin_stamina_timer.stop()
	
	if is_instance_valid(_current_whip_spin):
		_current_whip_spin.stop_spin()
	_current_whip_spin = null
	
	_whip_ready = false
	whip_cooldown_timer.wait_time = _whip_cooldown
	whip_cooldown_timer.start()
	
	_character_texture._is_on_action = false
	_character.set_physics_process(true)

func _on_whip_spin_stamina_timeout() -> void:
	if _whip_spin_active:
		if _stats.current_stamina > 0:
			_stats.update_stamina("decrease", _whip_spin_stamina_cost_per_second)
		else:
			_end_whip_spin()

func _handle_whip_spin_cancel() -> void:
	if not _whip_spin_active:
		return
	
	var cancel_action := _get_whip_cancel_action()
	if cancel_action != "":
		_end_whip_spin()
		_apply_whip_cancel_action(cancel_action)
		return
	
	if not Input.is_action_pressed("sub_weapon") or _stats.current_stamina <= 0:
		_end_whip_spin()

func _get_whip_cancel_action() -> String:
	if Input.is_action_just_pressed("jump"):
		return "jump"
	if Input.is_action_just_pressed("dash"):
		return "dash"
	if Input.is_action_just_pressed("attack"):
		return "attack"
	if Input.is_action_just_pressed("parry"):
		return "parry"
	if Input.is_action_just_pressed("hook"):
		return "hook"
	return ""

# ✅ Executa a ação que cancelou o giro na hora, em vez de "engolir" o input
func _apply_whip_cancel_action(action: String) -> void:
	match action:
		"jump":
			if _character.is_on_floor():
				_character._attack_index = 1
				_character.velocity.y = _character._jump_velocity
				global.spawn_effect(
					"res://Scenes/FX/jump_effect.tscn",
					Vector2(0, 0), _character.global_position, _character_texture.flip_h
				)
		"dash":
			if _character.is_on_floor():
				_character._skills.handle_dash_input()
		"attack":
			_character._attack_animation_handler("Attack_", 3)
		"parry":
			_character_texture.action_animation("Parry")
		"hook":
			_character._skills.handle_hook_input()

# ========== CALLBACKS DOS TIMERS ==========
func _on_throw_cooldown_timeout() -> void:
	_has_axe = true
	_has_spear = true
	_has_chakram = true

func _on_fire_stamina_timeout() -> void:
	if is_fire_active():
		if _stats.current_stamina > 0:
			_stats.update_stamina("decrease", _fire_stamina_cost_per_second)
		else:
			_deactivate_fire()

# ========== GETTERS E SETTERS ==========
func update_axe_state(state: bool) -> void:
	_has_axe = state

func has_axe() -> bool:
	return _has_axe

func update_spear_state(state: bool) -> void:
	_has_spear = state

func has_spear() -> bool:
	return _has_spear

func update_chakram_state(state: bool) -> void:
	_has_chakram = state

func has_chakram() -> bool:
	return _has_chakram

func update_dagger_state(state: bool) -> void:
	_has_dagger = state

func has_dagger() -> bool:
	return _has_dagger


# ========== LÓGICA DO MACHADO DE GUERRA ==========
# No chão: golpe pesado parado (o player fica sem physics como nas outras sub-armas).
# No ar: o Tola fica suspenso até o frame 7; aí despenca com gravidade 2x,
# segurando o frame 8 (lâmina pra baixo) até tocar o chão → impacto + tremida.

func can_use_great_axe() -> bool:
	return (
		_great_axe_ready and
		not _great_axe_active and
		_stats.current_stamina >= _great_axe_stamina_cost and
		not global.ui_equipments._equipments_inventory["weapon"].is_empty() and
		global.ui_equipments._equipments_inventory["weapon"].get("key", "") == "ITEM_GREAT_AXE_NAME"
	)

func _execute_great_axe() -> void:
	_stats.update_stamina("decrease", _great_axe_stamina_cost)
	
	_great_axe_in_air = not _character.is_on_floor()
	_great_axe_diving = false
	_character.velocity = Vector2.ZERO
	
	_character_texture.action_animation("Axe_Attack")
	
	var facing_direction: float = -1.0 if _character_texture.flip_h else 1.0
	var axe: GreatAxeAttack = _GREAT_AXE_SCENE.instantiate()
	axe.direction = Vector2(facing_direction, 0)
	axe.base_position = _character.global_position
	axe.follow_target = _character
	axe.frame_source = _character_texture
	axe.delay_impact_until_landing = _great_axe_in_air
	_current_great_axe = axe
	_great_axe_active = true
	get_tree().root.call_deferred("add_child", axe)
	
	if _audio:
		_audio.play_attack_voice()
	
	# ✅ Bloqueia até o golpe terminar; o cooldown começa só no fim (ver _update_great_axe)
	_great_axe_ready = false

func _start_great_axe_cooldown() -> void:
	"""Cooldown sempre igual, contado depois que o golpe acaba (no chão ou após o pouso)"""
	get_tree().create_timer(_great_axe_cooldown, false).timeout.connect(_on_great_axe_cooldown_timeout)

func _on_great_axe_cooldown_timeout() -> void:
	_great_axe_ready = true

func _physics_process(delta: float) -> void:
	_update_great_axe(delta)

func _update_great_axe(delta: float) -> void:
	if not _great_axe_active:
		return
	
	# ✅ Golpe acabou (terminou, foi cancelado ou a cena já foi liberada)
	# Obs.: no Godot 4 um objeto liberado compara igual a null, por isso
	# o controle é feito pelo bool _great_axe_active, não pela referência.
	if not is_instance_valid(_current_great_axe) or _current_great_axe.is_finished():
		_end_great_axe_dive()
		_current_great_axe = null
		_great_axe_active = false
		_start_great_axe_cooldown()
		return
	
	if not _great_axe_in_air:
		return
	
	# ✅ Interrompido (dano, etc.)
	if _character_texture.animation != "Axe_Attack":
		_end_great_axe_dive()
		return
	
	if not _great_axe_diving:
		if _character_texture.frame < _great_axe_dive_frame:
			return # ainda suspenso no ar
		_great_axe_diving = true
	
	# ✅ A animação roda até o último frame e fica parada nele enquanto cai
	if _character_texture.frame >= _great_axe_hold_frame and _character_texture.is_playing():
		_character_texture.frame = _great_axe_hold_frame
		_character_texture.pause()
		if is_instance_valid(_current_great_axe):
			_current_great_axe.holding = true
	
	var dive_gravity: float = _character._gravity * _great_axe_dive_gravity_mult
	_character.velocity.x = 0.0
	_character.velocity.y = min(_character.velocity.y + dive_gravity * delta, _great_axe_max_fall_speed)
	_character.move_and_slide()
	
	if _character.is_on_floor():
		_land_great_axe()

func _land_great_axe() -> void:
	_great_axe_diving = false
	_great_axe_in_air = false
	_character.velocity = Vector2.ZERO
	
	if is_instance_valid(_current_great_axe):
		_current_great_axe.holding = false
		_current_great_axe.trigger_landing_impact()
	
	global.spawn_effect(
		"res://Scenes/FX/fall_effect.tscn",
		Vector2(0, 0), _character.global_position, false
	)
	
	# ✅ Retoma a animação: frame 9 → fim → CharacterTexture devolve o controle
	if _character_texture.animation == "Axe_Attack" and not _character_texture.is_playing():
		_character_texture.play()

func _end_great_axe_dive() -> void:
	if is_instance_valid(_current_great_axe):
		_current_great_axe.holding = false
	if _great_axe_diving and _character_texture.animation == "Axe_Attack" and not _character_texture.is_playing():
		_character_texture.play()
	_great_axe_diving = false
	_great_axe_in_air = false
