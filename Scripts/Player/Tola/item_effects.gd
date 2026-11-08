extends Node2D
class_name CharacterItemEffects

# ==========================================================================
# EFEITOS DE EQUIPAMENTOS COM LÓGICA PRÓPRIA
# --------------------------------------------------------------------------
# Lê os atributos somados em _character._additional_attributes:
#   "shield_block"  → Escudo de Bronze (anula 1 dano por descanso)
#   "counter_blade" → Lâmina do Contra-Ataque (parry cura ou fortalece)
#   "dash_damage"   → Investida do Carneiro (dash para frente causa dano)
#   "vengeance"     → Marca da Vingança (+50% de dano com vida ≤ 30%)
#   "attack_speed"  → Olhos de Falcão (ataques mais rápidos; lido pelo
#                     player/CharacterTexture)
# ==========================================================================

const _SHARD_SCENE: PackedScene = preload("res://Scenes/Collectables/collectable_item.tscn")

@export_category("Escudo de Bronze")
## Sprite do círculo do escudo. Vazio = círculo provisório desenhado por código.
@export var shield_texture: Texture2D
## Posição do sprite do escudo. O PNG tem o tamanho do quadro do Tola (90x60),
## então (0, 0) já fica centralizado nele.
@export var shield_sprite_offset: Vector2 = Vector2.ZERO
## Centro do círculo provisório, dos fragmentos e da área do dash.
@export var shield_offset: Vector2 = Vector2(-1, 1)
## Opacidade do escudo: alterna entre máximo e mínimo.
@export_range(0.0, 1.0) var shield_alpha_max: float = 0.5
@export_range(0.0, 1.0) var shield_alpha_min: float = 0.3
## Tempo (s) para ir do máximo ao mínimo — e o mesmo para voltar.
@export var shield_pulse_time: float = 0.5
@export var shield_placeholder_radius: float = 20.0
@export var shield_placeholder_color: Color = Color(0.85, 0.6, 0.25, 0.85)
## Tempo de invulnerabilidade quando o escudo quebra.
@export var shield_break_invincibility: float = 1.0
## Fragmentos que voam quando o escudo quebra.
@export var shield_shard_paths: Array[String] = [
	"res://sprites/Interactables/INTERACTABLE_Shield_PEDAÇOS__v01.png",
	"res://sprites/Interactables/INTERACTABLE_Shield_PEDAÇOS__v02.png",
	"res://sprites/Interactables/INTERACTABLE_Shield_PEDAÇOS__v03.png",
]
@export var shield_shard_force_x: float = 120.0
@export var shield_shard_force_y_min: float = -60.0
@export var shield_shard_force_y_max: float = -160.0
@export var shield_break_sound: AudioStream

@export_category("Lâmina do Contra-Ataque")
## Cura por contra-ataque, em % da vida MÁXIMA.
@export var counter_heal_percent: float = 10.0
## Bônus de dano por acúmulo, em % (20% = +1 no padrão de ataque 5).
@export var counter_damage_bonus_percent: float = 20.0
@export var counter_max_stacks: int = 2
@export var counter_bonus_duration: float = 10.0
@export var heal_outline_color: Color = Color(0.35, 1.0, 0.45, 1.0)
@export var heal_outline_duration: float = 0.6
@export var rage_outline_color: Color = Color(1.0, 0.2, 0.2, 1.0)

@export_category("Investida do Carneiro")
## Dano do dash em relação ao ataque base (1/3).
@export var dash_damage_ratio: float = 1.0 / 3.0
@export_file("*.tscn") var dash_hit_effect: String = "res://Scenes/FX/hit_effect.tscn"
@export var dash_hitbox_size: Vector2 = Vector2(22, 30)

@export_category("Marca da Vingança")
## Ativa quando a vida está igual ou abaixo deste % da vida máxima.
@export var vengeance_health_threshold: float = 30.0
## Bônus de dano enquanto ativa, em %.
@export var vengeance_damage_bonus_percent: float = 50.0
## Som tocado ao entrar no estado (opcional).
@export var vengeance_sound: AudioStream
## Vinheta nas bordas da tela enquanto a marca está ativa (autoload ScreenVignette).
@export var vengeance_vignette_color: Color = Color(0.35, 0.0, 0.0, 1.0)
@export_range(0.0, 1.0) var vengeance_vignette_intensity: float = 1.0

@export_category("Bênção de Rafa'el")
## Segundos sem causar nem receber dano para sair de combate.
@export var out_of_combat_delay: float = 4.0
## Cura por tique, em % da vida máxima (mínimo 1 de vida).
@export var raphael_heal_percent: float = 1.0
## Intervalo entre os tiques de cura (s).
@export var raphael_heal_interval: float = 1.0
## Vida extra máxima (reserva azul), em % da vida máxima.
@export var raphael_overheal_max_percent: float = 20.0
## Duração do brilho verde a cada tique de cura.
@export var raphael_flash_duration: float = 0.15
## Partículas de cura (saem enquanto cura; param com vida e reserva cheias).
## Vazio = usa Scenes/FX/raphael_heal_particles.tscn.
@export var raphael_particles_scene: PackedScene

@export_category("Teto de Bônus de Dano")
## Soma MÁXIMA de todos os bônus de dano em % (fogo + Lâmina + Vingança).
## Os Fragmentos de Força não entram aqui: eles sobem o ataque base.
@export var max_total_damage_bonus_percent: float = 60.0

signal vengeance_changed(active: bool)

var _character: BaseCharacter

# Marca da Vingança
var _vengeance_active: bool = false
var _vengeance_audio: AudioStreamPlayer2D

# Escudo
var _shield_charged: bool = true
var _shield_sprite: Sprite2D
var _shield_audio: AudioStreamPlayer2D
var _shield_time: float = 0.0

# Lâmina do Contra-Ataque
var _counter_stacks: int = 0
var _counter_timer: Timer
var _heal_flash_timer: Timer

# Bênção de Rafa'el / estado de combate
var _time_since_combat: float = 999.0
var _raphael_tick: float = 0.0
var overheal: int = 0   # vida extra (reserva azul) — vale para qualquer fonte
var _raphael_fx: Node2D = null
const _RAPHAEL_FX_PATH: String = "res://Scenes/FX/raphael_heal_particles.tscn"

# Investida do Carneiro
var _dash_hitbox: Area2D
var _dash_was_active: bool = false
var _dash_hit_enemies: Array = []

func _ready() -> void:
	_character = get_parent() as BaseCharacter
	z_index = 11

	# --- Escudo ---
	_shield_sprite = Sprite2D.new()
	_shield_sprite.texture = shield_texture
	_shield_sprite.position = shield_sprite_offset
	add_child(_shield_sprite)

	_shield_audio = AudioStreamPlayer2D.new()
	_shield_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_shield_audio)

	_vengeance_audio = AudioStreamPlayer2D.new()
	_vengeance_audio.bus = _shield_audio.bus
	add_child(_vengeance_audio)

	# --- Lâmina ---
	_counter_timer = Timer.new()
	_counter_timer.one_shot = true
	_counter_timer.timeout.connect(_on_counter_bonus_timeout)
	add_child(_counter_timer)

	_heal_flash_timer = Timer.new()
	_heal_flash_timer.one_shot = true
	_heal_flash_timer.timeout.connect(_on_heal_flash_timeout)
	add_child(_heal_flash_timer)

	# --- Investida do Carneiro ---
	_dash_hitbox = Area2D.new()
	_dash_hitbox.name = "DashHitbox"
	_dash_hitbox.collision_layer = 0
	_dash_hitbox.collision_mask = 8  # layer 4: hurtbox dos inimigos
	_dash_hitbox.monitorable = false
	var _shape := CollisionShape2D.new()
	var _rect := RectangleShape2D.new()
	_rect.size = dash_hitbox_size
	_shape.shape = _rect
	_shape.position = shield_offset
	_dash_hitbox.add_child(_shape)
	add_child(_dash_hitbox)

	_update_shield_visual()

func _process(delta: float) -> void:
	if not _is_shield_ready():
		return
	# Pulsar suave do escudo
	_shield_time += delta
	# 50% → 30% em 0,5 s → 50% em 0,5 s ... (suave)
	var _wave: float = 0.5 + 0.5 * cos(_shield_time * PI / maxf(shield_pulse_time, 0.01))
	modulate.a = lerpf(shield_alpha_min, shield_alpha_max, _wave)
	if shield_texture == null:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_process_dash_damage()
	_process_vengeance()
	_process_raphael(delta)

func _get_attr(attr_name: String) -> int:
	if not _character:
		return 0
	return int(_character._additional_attributes.get(attr_name, 0))

func on_attributes_changed() -> void:
	"""Chamado pelo player sempre que os equipamentos mudam."""
	if _get_attr("counter_blade") <= 0 and _counter_stacks > 0:
		_clear_counter_bonus()
	_update_shield_visual()

func on_rest() -> void:
	"""Descanso no save / respawn: recarrega o escudo e limpa bônus temporários."""
	_shield_charged = true
	_shield_time = 0.0  # recomeça o pulsar em 50%
	_clear_counter_bonus()
	_update_shield_visual()

# ==========================================================================
# ESCUDO DE BRONZE
# ==========================================================================
func _is_shield_ready() -> bool:
	return _get_attr("shield_block") > 0 and _shield_charged

func _update_shield_visual() -> void:
	if not _shield_sprite:
		return
	var _ready_to_block: bool = _is_shield_ready()
	_shield_sprite.texture = shield_texture
	_shield_sprite.visible = _ready_to_block and shield_texture != null
	if not _ready_to_block:
		modulate.a = 1.0
	queue_redraw()

func _draw() -> void:
	# Círculo provisório enquanto o sprite do escudo não existe
	if shield_texture != null or not _is_shield_ready():
		return
	draw_arc(shield_offset, shield_placeholder_radius, 0.0, TAU, 32, shield_placeholder_color, 1.0)
	var _inner := shield_placeholder_color
	_inner.a *= 0.15
	draw_circle(shield_offset, shield_placeholder_radius - 1.0, _inner)

func try_block_damage() -> bool:
	"""Retorna true se o escudo anulou o dano."""
	if not _is_shield_ready():
		return false

	_shield_charged = false
	_update_shield_visual()
	_spawn_shield_shards()

	if shield_break_sound:
		_shield_audio.stream = shield_break_sound
		_shield_audio.play()

	HitStopManager.hit_stop_short()
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.shake_camera(2, 0.15)
	ControllerVibration.vibrate_light()

	_character._activate_invincibility(shield_break_invincibility)
	print("🛡️ Escudo de Bronze bloqueou o dano! (recarrega no próximo descanso)")
	return true

func _spawn_shield_shards() -> void:
	var level: Node = _get_current_level()
	if not level:
		return
	var origin: Vector2 = global_position + shield_offset
	for _path in shield_shard_paths:
		if _path == "" or not ResourceLoader.exists(_path):
			continue
		var shard = _SHARD_SCENE.instantiate()
		shard.is_collectable = false
		shard.item_texture = _path
		level.add_child(shard)
		shard.global_position = origin + Vector2(randf_range(-6, 6), randf_range(-8, 8))
		if shard is RigidBody2D:
			var _dir: float = -1.0 if randf() < 0.5 else 1.0
			shard.apply_central_impulse(Vector2(
				randf_range(30.0, shield_shard_force_x) * _dir,
				randf_range(shield_shard_force_y_max, shield_shard_force_y_min)
			))
			shard.apply_torque_impulse(randf_range(-200.0, 200.0))

func _get_current_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and game_main.current_level:
		return game_main.current_level
	return get_tree().current_scene

# ==========================================================================
# LÂMINA DO CONTRA-ATAQUE
# ==========================================================================
func on_parry_success() -> void:
	if _get_attr("counter_blade") <= 0:
		return
	var stats = _character._stats
	if not stats:
		return

	if stats.current_health < stats.max_health:
		# Ferido: cura 10% da vida máxima
		var heal: int = max(1, roundi(stats.max_health * counter_heal_percent / 100.0))
		stats.update_health("increase", heal)
		_play_heal_feedback()
		print("💚 Lâmina do Contra-Ataque: +", heal, " de vida")
	else:
		# Vida cheia: acumula bônus de dano
		_counter_stacks = min(_counter_stacks + 1, counter_max_stacks)
		_counter_timer.start(counter_bonus_duration)
		if _heal_flash_timer.is_stopped():
			_set_outline(true, rage_outline_color)
		print("🔴 Lâmina do Contra-Ataque: bônus x", _counter_stacks, " (+", _counter_stacks * counter_damage_bonus_percent, "% dano)")

func get_damage_bonus_percent() -> float:
	"""Bônus de dano dos itens em % (Lâmina + Vingança, somados, SEM teto).
	O teto total (com o fogo) é aplicado em BaseCharacter.scale_damage()."""
	var bonus: float = _counter_stacks * counter_damage_bonus_percent
	if _vengeance_active:
		bonus += vengeance_damage_bonus_percent
	return bonus

func _play_heal_feedback() -> void:
	if _character._heal_1:
		_character._heal_1.restart()
		_character._heal_1.emitting = true
	if _character._heal_2:
		_character._heal_2.restart()
		_character._heal_2.emitting = true
	_set_outline(true, heal_outline_color)
	_heal_flash_timer.start(heal_outline_duration)

func _on_heal_flash_timeout() -> void:
	if not _character.is_consuming:
		if _character._heal_1:
			_character._heal_1.emitting = false
		if _character._heal_2:
			_character._heal_2.emitting = false
	if _counter_stacks > 0:
		_set_outline(true, rage_outline_color)
	else:
		_set_outline(false)

func _on_counter_bonus_timeout() -> void:
	_clear_counter_bonus()

func _clear_counter_bonus() -> void:
	_counter_stacks = 0
	if _counter_timer:
		_counter_timer.stop()
	if _heal_flash_timer and _heal_flash_timer.is_stopped():
		_set_outline(false)

func _set_outline(active: bool, color: Color = Color.WHITE) -> void:
	if not _character or not _character._character_texture:
		return
	var mat = _character._character_texture.material
	if not mat or not mat is ShaderMaterial or not mat.shader:
		return
	mat.set_shader_parameter("outline_active", active)
	if active:
		mat.set_shader_parameter("outline_color", color)

# ==========================================================================
# ESTADO DE COMBATE + BÊNÇÃO DE RAFA'EL
# ==========================================================================
# Combate = causar OU receber dano. Sai de combate após out_of_combat_delay s.
func mark_combat() -> void:
	_time_since_combat = 0.0
	_raphael_tick = 0.0

func is_in_combat() -> bool:
	return _time_since_combat < out_of_combat_delay

func get_max_overheal() -> int:
	var stats = _character._stats if _character else null
	if not stats:
		return 0
	return int(round(stats.max_health * raphael_overheal_max_percent / 100.0))

func absorb_overheal(damage: int) -> int:
	"""Dano tira primeiro da reserva azul. Retorna o que sobra para a vida normal."""
	if overheal <= 0 or damage <= 0:
		return damage
	var absorbed: int = mini(overheal, damage)
	overheal -= absorbed
	_update_overheal_bar()
	return damage - absorbed

func clear_overheal() -> void:
	"""Morte: a reserva some."""
	overheal = 0
	_update_overheal_bar()

func _process_raphael(delta: float) -> void:
	_time_since_combat += delta
	var healing: bool = _can_raphael_heal()
	_set_raphael_fx(healing)
	if not healing:
		return
	var stats = _character._stats
	var max_overheal: int = get_max_overheal()
	
	_raphael_tick += delta
	if _raphael_tick < raphael_heal_interval:
		return
	_raphael_tick = 0.0
	
	var amount: int = maxi(1, int(round(stats.max_health * raphael_heal_percent / 100.0)))
	var missing: int = stats.max_health - stats.current_health
	if missing > 0:
		var heal: int = mini(amount, missing)
		stats.update_health("increase", heal)
		amount -= heal
	if amount > 0 and overheal < max_overheal:
		overheal = mini(max_overheal, overheal + amount)
		_update_overheal_bar()
	_flash_outline(heal_outline_color, raphael_flash_duration)

func _can_raphael_heal() -> bool:
	if _get_attr("raphael_blessing") <= 0:
		return false
	if not _character or not _character._is_alive or _character._is_in_cinematic:
		return false
	if is_in_combat():
		return false
	var stats = _character._stats
	if not stats:
		return false
	# Vida e reserva cheias = nada a curar
	return not (stats.current_health >= stats.max_health and overheal >= get_max_overheal())

func _set_raphael_fx(active: bool) -> void:
	if _raphael_fx == null:
		if not active:
			return
		var scene: PackedScene = raphael_particles_scene
		if scene == null and ResourceLoader.exists(_RAPHAEL_FX_PATH):
			scene = load(_RAPHAEL_FX_PATH)
		if scene == null:
			return
		_raphael_fx = scene.instantiate() as Node2D
		if _raphael_fx == null:
			return
		add_child(_raphael_fx)
	if _raphael_fx.get("emitting") != active:
		_raphael_fx.set("emitting", active)   # ao desligar, as partículas no ar terminam sozinhas

func _flash_outline(color: Color, duration: float) -> void:
	_set_outline(true, color)
	_heal_flash_timer.start(duration)   # ao acabar, volta o contorno anterior (ou nenhum)

func _update_overheal_bar() -> void:
	if global.ui_bars and global.ui_bars.has_method("update_overheal"):
		global.ui_bars.update_overheal(overheal, get_max_overheal())

# ==========================================================================
# MARCA DA VINGANÇA
# ==========================================================================
func is_vengeance_active() -> bool:
	return _vengeance_active

func _process_vengeance() -> void:
	var stats = _character._stats if _character else null
	var should_be_active: bool = false
	if stats and _get_attr("vengeance") > 0 and _character._is_alive and stats.max_health > 0:
		should_be_active = stats.current_health <= stats.max_health * vengeance_health_threshold / 100.0

	if should_be_active == _vengeance_active:
		return

	_vengeance_active = should_be_active
	if _vengeance_active:
		if vengeance_sound:
			_vengeance_audio.stream = vengeance_sound
			_vengeance_audio.play()
		var vignette = get_node_or_null("/root/ScreenVignette")
		if vignette:
			vignette.request("vengeance", vengeance_vignette_color, vengeance_vignette_intensity, 10)
		print("🩸 Marca da Vingança ATIVA (+", vengeance_damage_bonus_percent, "% dano)")
	else:
		_vengeance_audio.stop()
		var vignette = get_node_or_null("/root/ScreenVignette")
		if vignette:
			vignette.release("vengeance")
		print("🩸 Marca da Vingança desativada")
	# Ponto de ligação para o shader/efeito futuro
	vengeance_changed.emit(_vengeance_active)

# ==========================================================================
# INVESTIDA DO CARNEIRO
# ==========================================================================
func _process_dash_damage() -> void:
	var active: bool = (
		_get_attr("dash_damage") > 0
		and _character._skills
		and _character._skills.is_rolling()
		and _character._character_texture.animation == "Rolling"
	)

	if active and not _dash_was_active:
		_dash_hit_enemies.clear()
	_dash_was_active = active

	if not active:
		return

	for _area in _dash_hitbox.get_overlapping_areas():
		if not _area.is_in_group("enemy_hitbox"):
			continue
		var enemy = global.get_damage_target(_area)
		if not enemy or not enemy.has_method("update_health"):
			continue
		if enemy in _dash_hit_enemies:
			continue
		if "_is_alive" in enemy and not enemy._is_alive:
			continue
		_dash_hit_enemies.append(enemy)

		var damage: int = _character.scale_damage(BaseCharacter.ATTACK_REFERENCE * dash_damage_ratio)
		var flipped: bool = _character._character_texture.flip_h
		if dash_hit_effect != "" and ResourceLoader.exists(dash_hit_effect):
			global.spawn_effect(dash_hit_effect, Vector2.ZERO, enemy.global_position, flipped)
		if _character._audio:
			_character._audio.play_attack_hit()
		enemy.update_health(damage, _character)
		ControllerVibration.vibrate_light()
		print("🐏 Investida do Carneiro: ", damage, " de dano em ", enemy.name)
