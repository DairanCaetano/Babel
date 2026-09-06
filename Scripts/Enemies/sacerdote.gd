extends CharacterBody2D
class_name SacerdoteEgito

# 📄 ARQUIVO: SacerdoteEgito.gd
# 📍 ONDE: res://Scenes/Enemies/SacerdoteEgito/
# 🎬 CENA: SacerdoteEgito.tscn (standalone, não herda BaseEnemy — sem gravidade, sem move_and_slide)
#
# ⚠️ IMPORTANTE: as transições de estado (Teleport / Teleport_in / Teleport_out)
# NÃO dependem mais do sinal animation_finished do AnimatedSprite2D. No Godot 4,
# esse sinal só dispara em animações SEM loop — se você deixar "Loop" marcado
# no SpriteFrames de qualquer uma dessas animações, o sinal nunca dispara e o
# inimigo trava no estado. Por isso, cada transição usa um Timer calculado a
# partir dos frames/FPS reais da animação (função _get_animation_duration),
# o que funciona independente da configuração de loop.

const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Projectile/tracker_projectiley.tscn")

# --- Posições padrão (assumindo sprite olhando pra ESQUERDA, como foi desenhado) ---
const BODY_DEFAULT_POS: Vector2 = Vector2(-3.5, 4)
const HURTBOX_DEFAULT_POS: Vector2 = Vector2(-3.5, 4)
const PROJECTILE_SPAWN_DEFAULT_POS: Vector2 = Vector2(-7, 2)

enum State {
	IDLE,
	TELEPORT_AWAY,   # some pela primeira vez (animação "Teleport")
	TELEPORT_IN,     # aparece no loop de combate (animação "Teleport_In")
	ATTACK,          # instancia o projétil e segura por wait_time_after_attack (animação "Attack")
	TELEPORT_OUT,    # some no loop de combate (animação "Teleport_Out")
}

@export var teleport_radius: float = 200.0
@export var min_height_offset: float = 30.0    # altura mínima acima do player (Y menor)
@export var max_height_offset: float = 50.0    # altura máxima acima do player (~altura de pulo)
@export var wait_time_after_attack: float = 2.0
@export var lose_player_timeout: float = 3.0
@export var max_state_anim_time: float = 1.0   # teto de segurança pra Teleport/Teleport_in/Teleport_out
@export var max_health: int = 30

@export_category("Hover (flutuação errática)")
@export var hover_amplitude: float = 14.0       # deslocamento máximo em pixels (X e Y)
@export var hover_noise_speed: float = 0.6      # velocidade da variação do ruído (maior = mais errático)

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _body_collision: CollisionShape2D
@export var _detection_area: Area2D
@export var _hurtbox: Area2D
@export var _hurtbox_collision: CollisionShape2D
@export var _projectile_spawn_point: Marker2D
@export var _hit_audio: AudioStreamPlayer
@export var _dead_audio: AudioStreamPlayer
@export var _dead_scream_audio: AudioStreamPlayer

var current_state: State = State.IDLE
var current_health: int
var player: Node2D = null
var is_dead: bool = false

# Posição inicial (spawn), pra onde ele volta se perder o player de vista
var _home_position: Vector2
var _is_returning_home: bool = false

# Hover errático (aplicado só em TELEPORT_IN/ATTACK, por cima da posição âncora)
var _noise_x: FastNoiseLite
var _noise_y: FastNoiseLite
var _hover_time: float = 0.0
var _combat_anchor_position: Vector2

# Timers criados via código (sem nó na cena), igual ao padrão do ZumbiArqueiro
var _lose_player_timer: Timer
var _wait_timer: Timer
var _state_timer: Timer   # controla a duração de Teleport / Teleport_in / Teleport_out


func _ready() -> void:
	current_health = max_health
	_home_position = global_position

	_body_collision.position = BODY_DEFAULT_POS
	_hurtbox_collision.position = HURTBOX_DEFAULT_POS
	_projectile_spawn_point.position = PROJECTILE_SPAWN_DEFAULT_POS

	_texture.play("Idle")

	if _texture.sprite_frames:
		print("📋 [Sacerdote] Animações disponíveis no SpriteFrames: ", _texture.sprite_frames.get_animation_names())
	else:
		print("⚠️ [Sacerdote] _texture não tem SpriteFrames configurado!")

	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_detection_area.body_exited.connect(_on_detection_area_body_exited)
	_hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	_lose_player_timer = Timer.new()
	add_child(_lose_player_timer)
	_lose_player_timer.wait_time = lose_player_timeout
	_lose_player_timer.one_shot = true
	_lose_player_timer.timeout.connect(_on_lose_player_timeout)

	_wait_timer = Timer.new()
	add_child(_wait_timer)
	_wait_timer.wait_time = wait_time_after_attack
	_wait_timer.one_shot = true
	_wait_timer.timeout.connect(_on_wait_timer_timeout)

	_state_timer = Timer.new()
	add_child(_state_timer)
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timer_timeout)

	_noise_x = FastNoiseLite.new()
	_noise_x.seed = randi()
	_noise_x.frequency = 0.5

	_noise_y = FastNoiseLite.new()
	_noise_y.seed = randi() + 9999   # seed diferente do X pra não ficarem sincronizados
	_noise_y.frequency = 0.5


func _physics_process(delta: float) -> void:
	# Continuamente vira de frente pro player enquanto estiver fora do
	# estado Idle (visível/tangível ou não — não faz mal atualizar).
	if is_dead or current_state == State.IDLE:
		return
	if not is_instance_valid(_get_player_target()):
		return

	_update_facing()

	# Hover errático: só enquanto visível/tangível apresentando ou atacando.
	if current_state == State.TELEPORT_IN or current_state == State.ATTACK:
		_hover_time += delta * hover_noise_speed
		var offset_x: float = _noise_x.get_noise_1d(_hover_time) * hover_amplitude
		var offset_y: float = _noise_y.get_noise_1d(_hover_time) * hover_amplitude
		global_position = _combat_anchor_position + Vector2(offset_x, offset_y)


# ---------------------------------------------------------------------------
# DURAÇÃO DE ANIMAÇÃO (frames / fps), independente de loop estar ligado
# ---------------------------------------------------------------------------

func _get_animation_duration(anim_name: String) -> float:
	if not _texture.sprite_frames or not _texture.sprite_frames.has_animation(anim_name):
		print("⚠️ [Sacerdote] Animação '", anim_name, "' não encontrada no SpriteFrames — usando duração padrão.")
		return max_state_anim_time

	var frame_count: int = _texture.sprite_frames.get_frame_count(anim_name)
	var speed: float = _texture.sprite_frames.get_animation_speed(anim_name)

	if speed <= 0.0 or frame_count <= 0:
		return max_state_anim_time

	return float(frame_count) / speed


# Duração usada nas transições Teleport/Teleport_in/Teleport_out, sempre
# limitada por max_state_anim_time como teto de segurança.
func _start_state_timer_for_animation(anim_name: String) -> void:
	var duration: float = min(_get_animation_duration(anim_name), max_state_anim_time)
	_state_timer.wait_time = max(duration, 0.05)
	_state_timer.start()
	print("⏱️ [Sacerdote] Timer de estado iniciado pra '", anim_name, "': ", _state_timer.wait_time, "s")


# ---------------------------------------------------------------------------
# FLIP / ORIENTAÇÃO
# ---------------------------------------------------------------------------

func _update_facing() -> void:
	var target: Node2D = _get_player_target()
	if not is_instance_valid(target):
		return

	var facing_right: bool = target.global_position.x > global_position.x
	_texture.flip_h = facing_right

	# Sprite base olha pra ESQUERDA, então quando vira pra direita
	# o X das colisões/spawn point precisa inverter de sinal.
	var sign_mult: float = -1.0 if facing_right else 1.0

	_body_collision.position.x = BODY_DEFAULT_POS.x * sign_mult
	_hurtbox_collision.position.x = HURTBOX_DEFAULT_POS.x * sign_mult
	_projectile_spawn_point.position.x = PROJECTILE_SPAWN_DEFAULT_POS.x * sign_mult


# Retorna a referência mais confiável do player: prioriza global.character
# (fonte central do projeto), com fallback pro corpo detectado via Area2D.
func _get_player_target() -> Node2D:
	if is_instance_valid(global.character):
		return global.character
	return player


# ---------------------------------------------------------------------------
# DETECÇÃO
# ---------------------------------------------------------------------------

func _on_detection_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if not body.is_in_group("player"):
		return

	player = body
	_lose_player_timer.stop()
	_is_returning_home = false  # cancela qualquer retorno pra casa em andamento

	if current_state == State.IDLE:
		_start_combat()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body != player:
		return
	# Não larga a referência do player na hora, só começa a contagem
	# regressiva pra desistir e voltar ao Idle.
	if current_state != State.IDLE:
		_lose_player_timer.start()


func _on_lose_player_timeout() -> void:
	if is_dead:
		return

	_is_returning_home = true

	# Se estiver visível/tangível agora (apresentando ou atacando), interrompe
	# na hora e começa a sumir. Se já estiver no meio de uma animação de
	# sumiço/reaparição, deixa ela terminar normalmente — o flag
	# _is_returning_home já desvia o fluxo quando ela acabar.
	if current_state == State.TELEPORT_IN or current_state == State.ATTACK:
		_wait_timer.stop()
		current_state = State.TELEPORT_OUT
		_set_collision_enabled(false)
		_texture.play("Teleport_Out")
		_start_state_timer_for_animation("Teleport_Out")


# ---------------------------------------------------------------------------
# MÁQUINA DE ESTADOS
# ---------------------------------------------------------------------------

func _start_combat() -> void:
	current_state = State.TELEPORT_AWAY
	# Fica visível a animação inteira (efeito de sumiço), mas a colisão
	# desliga já de cara — pra não esbarrar nele enquanto ele está saindo.
	_set_collision_enabled(false)
	_texture.play("Teleport")
	_start_state_timer_for_animation("Teleport")


func _return_to_idle() -> void:
	current_state = State.IDLE
	player = null
	_is_returning_home = false
	_set_visible(true)
	_set_collision_enabled(true)
	_texture.play("Idle")


func _on_state_timer_timeout() -> void:
	if is_dead:
		return

	match current_state:
		State.TELEPORT_AWAY:
			_vanish_and_reappear()

		State.TELEPORT_IN:
			if _is_returning_home:
				_return_to_idle()
			else:
				current_state = State.ATTACK
				# Colisão só liga AGORA — quando a animação de aparição
				# (Teleport_In) realmente terminou, não quando começou.
				_set_collision_enabled(true)
				# O timer de saída começa ANTES de tudo — mesmo que algo dê
				# errado em _perform_attack() (projétil não configurado, etc.),
				# a transição pra Teleport_out está garantida.
				_wait_timer.start()
				_texture.play("Attack")
				_perform_attack()

		State.TELEPORT_OUT:
			_vanish_and_reappear()


func _on_wait_timer_timeout() -> void:
	if is_dead:
		return
	current_state = State.TELEPORT_OUT
	# Fica visível a animação inteira (efeito de sumiço), mas a colisão
	# desliga já de cara — pra não esbarrar nele enquanto ele está saindo.
	_set_collision_enabled(false)
	_texture.play("Teleport_Out")
	_start_state_timer_for_animation("Teleport_Out")


func _vanish_and_reappear() -> void:
	# Chamado quando o _state_timer de "Teleport" ou "Teleport_Out" estoura:
	# a colisão já foi desligada lá atrás (no início dessas animações) — aqui
	# só cuida de ficar invisível de fato, se mover, e reaparecer visível.
	print("🌀 [Sacerdote] Vanish and reappear disparado. Estado atual: ", current_state)
	_set_visible(false)
	_teleport_to_new_position()
	print("🌀 [Sacerdote] Nova posição: ", global_position)
	current_state = State.TELEPORT_IN
	_set_visible(true)
	# Colisão continua DESLIGADA aqui de propósito — só liga quando o
	# Teleport_In terminar (ver _on_state_timer_timeout).
	_texture.play("Teleport_In")
	_start_state_timer_for_animation("Teleport_In")
	print("🌀 [Sacerdote] Reapareceu, tocando Teleport_in. visible=", visible)


# ---------------------------------------------------------------------------
# ATAQUE / TELEPORTE
# ---------------------------------------------------------------------------

func _perform_attack() -> void:
	var target: Node2D = _get_player_target()
	if not is_instance_valid(target):
		print("⚠️ [Sacerdote] _perform_attack: alvo inválido, projétil NÃO instanciado.")
		return

	if not is_instance_valid(_projectile_spawn_point):
		print("⚠️ [Sacerdote] _perform_attack: _projectile_spawn_point não está ligado no Inspector!")
		return

	if not PROJECTILE_SCENE:
		print("⚠️ [Sacerdote] _perform_attack: PROJECTILE_SCENE não carregou (verifique o caminho do preload).")
		return

	var projectile = PROJECTILE_SCENE.instantiate()
	if not is_instance_valid(projectile):
		print("⚠️ [Sacerdote] _perform_attack: falha ao instanciar o projétil.")
		return

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_spawn_point.global_position

	if projectile.has_method("set_target"):
		projectile.set_target(target)

	print("🎯 [Sacerdote] Projétil instanciado em: ", projectile.global_position, " mirando: ", target.global_position)


func _teleport_to_new_position() -> void:
	var target: Node2D = _get_player_target()

	if _is_returning_home or not is_instance_valid(target):
		_is_returning_home = true
		_combat_anchor_position = _home_position
		_hover_time = 0.0
		global_position = _combat_anchor_position
		return

	var angle: float = randf() * TAU
	var radius: float = randf() * teleport_radius
	var offset := Vector2(cos(angle), sin(angle)) * radius

	# Garante que a posição final fica SEMPRE mais alta que o player
	# (Y menor), independente do ângulo sorteado.
	offset.y = -abs(offset.y)
	offset.y = clamp(offset.y, -max_height_offset, -min_height_offset)

	_combat_anchor_position = target.global_position + offset
	_hover_time = 0.0
	global_position = _combat_anchor_position
	print("🎯 [Sacerdote] Posição do alvo usada: ", target.global_position, " (via ", ("global.character" if target == global.character else "player detectado"), ")")


# ---------------------------------------------------------------------------
# COLISÃO / VISIBILIDADE
# ---------------------------------------------------------------------------

func _set_collision_enabled(enabled: bool) -> void:
	_body_collision.set_deferred("disabled", not enabled)
	_hurtbox_collision.set_deferred("disabled", not enabled)


func _set_visible(is_visible: bool) -> void:
	visible = is_visible


# ---------------------------------------------------------------------------
# DANO AO JOGADOR (hurtbox)
# ---------------------------------------------------------------------------

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)  # TODO: ajustar valor de dano


# ---------------------------------------------------------------------------
# DANO RECEBIDO / MORTE
# ---------------------------------------------------------------------------

func update_health(_damage: int, _entity) -> void:
	if is_dead:
		return

	current_health -= _damage

	if _hit_audio:
		_hit_audio.play()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(1, 0.1)

	_play_hit_blink()

	if current_health <= 0:
		HitStopManager.hit_stop_short()
		_die()


func _play_hit_blink() -> void:
	var tween := get_tree().create_tween()
	tween.tween_method(_set_shader_blink_intensity, 1.0, 0.0, 0.4)


func _set_shader_blink_intensity(new_value: float) -> void:
	if not _texture:
		return
	if not _texture.material:
		return
	if not _texture.material.shader:
		return

	_texture.material.set_shader_parameter("blink_active", new_value > 0.0)
	_texture.material.set_shader_parameter("blink_intensity", new_value)


func _die() -> void:
	is_dead = true
	_lose_player_timer.stop()
	_wait_timer.stop()
	_state_timer.stop()

	_body_collision.set_deferred("disabled", true)
	_hurtbox_collision.set_deferred("disabled", true)
	visible = true

	if _dead_audio:
		_dead_audio.play()
	else:
		print("⚠️ [Sacerdote] _dead_audio não está ligado no Inspector!")

	if _dead_scream_audio:
		_dead_scream_audio.play()
	else:
		print("⚠️ [Sacerdote] _dead_scream_audio não está ligado no Inspector!")

	_texture.play("Dead")

	# Não depende de animation_finished (mesmo motivo do resto do arquivo:
	# quebra se "Dead" estiver com loop ligado). Usa duração calculada.
	var dead_duration: float = _get_animation_duration("Dead")
	if dead_duration <= 0.0:
		dead_duration = 1.0
	await get_tree().create_timer(dead_duration).timeout

	queue_free()
