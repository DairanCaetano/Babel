extends Node2D
class_name GreatAxeAttack

# ========== MACHADO DE GUERRA (sub-arma corpo a corpo) ==========
# Instanciado pelo CharacterSubweapon na posição do Tola.
# Os frames seguem a animação "Axe_Attack" do player (frame_source),
# então pausas (queda no ar, hitstop) e interrupções (dano) ficam sincronizadas.

@export var _attack_damage: int = 8 # dano com ataque base 5 (escala com a força do Tola)

@export_category("Objects")
@export var attack_area: Area2D
@export var collision_1: CollisionShape2D # golpe amplo (maior) - frame 7
@export var collision_2: CollisionShape2D # lâmina (menor) - frames 8 e 9
@export var _axe_attack_audio: AudioStreamPlayer
@export var impact_fx_marker: Marker2D # onde a poeira do impacto nasce (posicione olhando pra DIREITA)

@export_group("Impact FX")
@export_file("*.tscn") var impact_fx_path: String = "res://Scenes/FX/Great_axe_fx.tscn"
## Explosão extra quando o machado bate no chão (a mesma do ataque 2 do Serpopardo).
## Vazio = desliga. Nasce no impact_fx_marker + offset.
@export_file("*.tscn") var impact_explosion_path: String = "res://Scenes/FX/dust_explosion_fx.tscn"
@export var impact_explosion_offset: Vector2 = Vector2.ZERO
@export var landing_fx_delay: float = 0.1 # golpe aéreo: atraso da poeira depois de tocar o chão

@export_group("Positions")
@export var collision_1_position: Vector2 = Vector2(6, -3)
@export var collision_2_position: Vector2 = Vector2(19, 10)

@export_group("Timing")
@export var source_animation: String = "Axe_Attack"
@export var animation_fps: float = 10.0 # usado só se não houver frame_source
@export var total_frames: int = 10
@export var spawn_frame: int = 0
@export var collision_1_frames: Array[int] = [7]
@export var collision_2_frames: Array[int] = [8, 9]
@export var impact_frame: int = 7 # áudio + tremida de tela

@export_group("Screen Shake")
@export var shake_force: float = 1.0
@export var shake_duration: float = 0.3

# ✅ Setados pelo CharacterSubweapon ANTES do add_child
var direction: Vector2 = Vector2.RIGHT
var base_position: Vector2 = Vector2.ZERO
var follow_target: Node2D # o player: a hitbox acompanha a posição dele
var frame_source: AnimatedSprite2D # a Texture do player (lê o frame atual)
var delay_impact_until_landing: bool = false # no ar, o impacto acontece ao tocar o chão
var holding: bool = false # ✅ true enquanto o player segura o último frame caindo (não encerrar o golpe)

var _hit_enemies: Array = [] # ✅ 1 dano por golpe, por inimigo
var _elapsed: float = 0.0
var _current_frame: int = -1
var _follow_offset: Vector2 = Vector2.ZERO
var _finished: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	z_index = 1000 # ⚠️ ajustar depois pra um valor mais comedido
	z_as_relative = false

	global_position = base_position

	if not attack_area or not collision_1 or not collision_2:
		push_warning("⚠️ GreatAxeAttack: attack_area, collision_1 ou collision_2 não atribuídos no Inspector!")
		queue_free()
		return

	# ✅ Flip: inverte só o X
	var flip_mult: float = -1.0 if direction.x < 0 else 1.0
	collision_1.position = Vector2(collision_1_position.x * flip_mult, collision_1_position.y)
	collision_2.position = Vector2(collision_2_position.x * flip_mult, collision_2_position.y)
	if impact_fx_marker:
		impact_fx_marker.position.x *= flip_mult

	collision_1.disabled = true
	collision_2.disabled = true

	if is_instance_valid(follow_target):
		_follow_offset = global_position - follow_target.global_position

	attack_area.area_entered.connect(_on_area_entered)

	_update_frame()

func _physics_process(delta: float) -> void:
	if _finished:
		return

	if is_instance_valid(follow_target):
		global_position = follow_target.global_position + _follow_offset

	_elapsed += delta
	_update_frame()

func _get_frame() -> int:
	# ✅ Preferência: frame real da animação do player
	if is_instance_valid(frame_source):
		if frame_source.animation != source_animation:
			return total_frames # animação trocou (dano, etc.) → encerra
		# Animação parou no último frame (terminou, mas o player ainda não trocou de animação)
		if not holding and not frame_source.is_playing() and frame_source.frame >= total_frames - 1:
			return total_frames
		return frame_source.frame
	# Fallback: tempo decorrido
	return spawn_frame + int(_elapsed * animation_fps)

func _update_frame() -> void:
	var frame: int = _get_frame()

	if frame >= total_frames:
		_finish()
		return

	if frame == _current_frame:
		return
	_current_frame = frame

	collision_1.set_deferred("disabled", not collision_1_frames.has(frame))
	collision_2.set_deferred("disabled", not collision_2_frames.has(frame))

	if frame == impact_frame and not delay_impact_until_landing:
		_on_impact()

# ✅ Chamado pelo CharacterSubweapon quando o golpe aéreo toca o chão
func trigger_landing_impact() -> void:
	if _finished:
		return
	_on_impact(landing_fx_delay)

func _on_impact(fx_delay: float = 0.0) -> void:
	if _axe_attack_audio:
		if _axe_attack_audio.playing:
			_axe_attack_audio.stop()
		_axe_attack_audio.play()

	# 💨 Poeira do impacto (no chão: frame 7 | no ar: ao pousar)
	if impact_fx_path != "":
		var fx_position: Vector2 = impact_fx_marker.global_position if impact_fx_marker else global_position
		var flipped: bool = direction.x < 0
		if fx_delay > 0.0:
			# Timer da árvore + global: funciona mesmo se esta cena já tiver sido liberada
			get_tree().create_timer(fx_delay, false).timeout.connect(
				global.spawn_effect.bind(impact_fx_path, Vector2.ZERO, fx_position, flipped)
			)
		else:
			global.spawn_effect(impact_fx_path, Vector2.ZERO, fx_position, flipped)
	
	# 💥 Explosão do impacto (mesma do Serpopardo)
	if impact_explosion_path != "":
		var exp_flipped: bool = direction.x < 0
		var exp_offset: Vector2 = impact_explosion_offset
		if exp_flipped:
			exp_offset.x = -exp_offset.x
		var exp_position: Vector2 = (impact_fx_marker.global_position if impact_fx_marker else global_position) + exp_offset
		if fx_delay > 0.0:
			get_tree().create_timer(fx_delay, false).timeout.connect(
				global.spawn_scene_fx.bind(impact_explosion_path, exp_position, exp_flipped)
			)
		else:
			global.spawn_scene_fx(impact_explosion_path, exp_position, exp_flipped)
	
	# 📳 Tremida de tela
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(shake_force, shake_duration)

# ✅ Chamado se o ataque for interrompido
func cancel() -> void:
	if _axe_attack_audio:
		_axe_attack_audio.stop()
	_finish()

func is_finished() -> bool:
	return _finished

func _finish() -> void:
	if _finished:
		return
	_finished = true

	collision_1.set_deferred("disabled", true)
	collision_2.set_deferred("disabled", true)

	# Espera o áudio terminar antes de destruir
	if _axe_attack_audio and _axe_attack_audio.playing:
		if not _axe_attack_audio.finished.is_connected(_on_audio_finished):
			_axe_attack_audio.finished.connect(_on_audio_finished)
		return

	queue_free()

func _on_audio_finished() -> void:
	queue_free()

# ========== DANO ==========

func _on_area_entered(area: Area2D) -> void:
	if _finished:
		return

	if area.is_in_group("destructible_objects"):
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(0, 0), global_position, direction.x < 0
		)
		return

	if not area.is_in_group("enemy_hitbox"):
		return

	var enemy = global.get_damage_target(area)
	if not enemy or _hit_enemies.has(enemy):
		return

	if not enemy.has_method("update_health"):
		return

	_hit_enemies.append(enemy)

	var damage = _attack_damage
	if is_instance_valid(global.character):
		damage = global.character.scale_damage(_attack_damage)

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(24, 0), global_position, direction.x < 0
	)

	enemy.update_health(damage, global.character if is_instance_valid(global.character) else self)
