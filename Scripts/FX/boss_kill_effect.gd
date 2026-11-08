extends Node2D
class_name BossKillEffect

# ==========================================================================
# EFEITO DE MORTE DO CHEFE
# --------------------------------------------------------------------------
# Quando a vida do chefe chega a zero (Boss → boss_defeated):
#   • corte seco: a fase fica preta e Tola + chefe viram silhuetas vermelhas
#   • câmera superlenta (time_scale) por `duration` segundos REAIS
#   • tremor de tela + vibração do controle + som de impacto (opcional)
#   • saída com fade; tudo volta ao material/camada originais
# Disparado por Boss._play_kill_effect() (Scripts/Bosses/boss_base.gd).
# ==========================================================================

## Duração do efeito em segundos reais
@export var duration: float = 2.0
## Velocidade do jogo durante o efeito (0.1 = 10%)
@export var time_scale: float = 0.1
## Fade de saída (segundos reais)
@export var fade_out_time: float = 0.3
@export var silhouette_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var shake_strength: float = 3.0
## Vibração do controle (motores fraco/forte)
@export var vibration_strength: float = 0.6
## Som tocado no instante do corte. Vazio = sem som.
@export var sound: AudioStream
@export var sound_volume_db: float = 0.0
## Esconde HUD e vinheta durante o efeito (fica só preto + silhuetas)
@export var hide_hud: bool = true
## Corta a música do chefe no instante da tela preta (o som do efeito fica sozinho)
@export var cut_music: bool = true
## Duração do corte em segundos reais (0 = corte totalmente seco; 0.1 evita estalo)
@export var music_cut_time: float = 0.1
## Segundos (reais) depois que a tela preta some para a música da fase voltar.
## 0 ou menos = a música não volta sozinha.
@export var resume_music_delay: float = 4.0

const _SILHOUETTE_SHADER_PATH: String = "res://Shaders/silhouette.gdshader"
const _Z_BACKGROUND: int = 4000
const _Z_SILHOUETTE: int = 4001

var _targets: Array = []          # [{node, material, z_index, z_as_relative}]
var _material: ShaderMaterial
var _background: ColorRect
var _hidden_nodes: Array = []
var _active: bool = false


func start(sprites: Array) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = _Z_BACKGROUND
	
	# Fundo preto gigante (cobre a tela qualquer que seja a câmera)
	_background = ColorRect.new()
	_background.color = background_color
	_background.size = Vector2(40000, 40000)
	_background.position = Vector2(-20000, -20000)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	
	# Silhuetas
	_material = ShaderMaterial.new()
	if ResourceLoader.exists(_SILHOUETTE_SHADER_PATH):
		_material.shader = load(_SILHOUETTE_SHADER_PATH)
	_material.set_shader_parameter("silhouette_color", silhouette_color)
	_material.set_shader_parameter("amount", 1.0)
	for _sprite in sprites:
		if not _sprite is CanvasItem or not is_instance_valid(_sprite):
			continue
		_targets.append({
			"node": _sprite,
			"material": _sprite.material,
			"z_index": _sprite.z_index,
			"z_as_relative": _sprite.z_as_relative,
		})
		_sprite.material = _material
		_sprite.z_as_relative = false
		_sprite.z_index = _Z_SILHOUETTE
	
	if hide_hud:
		_hide_node(get_tree().get_first_node_in_group("hud"))
		_hide_node(get_node_or_null("/root/ScreenVignette"))
	
	if cut_music and AudioManager:
		AudioManager.cut_music(music_cut_time)
	_play_sound()
	
	var _camera = get_tree().get_first_node_in_group("camera")
	if _camera and _camera.has_method("shake_camera"):
		# A câmera conta o tempo do jogo (lento): converte para durar `duration` reais
		_camera.shake_camera(shake_strength, duration * time_scale)
	ControllerVibration.vibrate_custom(vibration_strength, vibration_strength, duration)
	
	Engine.time_scale = time_scale
	_active = true
	print("💀 Efeito de morte do chefe (", duration, "s a ", time_scale, "x)")
	
	await get_tree().create_timer(duration, true, false, true).timeout
	_finish()


func _process(_delta: float) -> void:
	if not _active:
		return
	# Hit stop pode devolver o time_scale para 1 no meio do efeito: reafirma
	if is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = time_scale
	# O chefe pode trocar de material ao mudar de animação: reafirma a silhueta
	for _t in _targets:
		var _node = _t["node"]
		if is_instance_valid(_node) and _node.material != _material:
			_node.material = _material


func _finish() -> void:
	_active = false
	# Só devolve a velocidade se ninguém mudou no meio (ex.: câmera lenta de vitória)
	if is_equal_approx(Engine.time_scale, time_scale):
		Engine.time_scale = 1.0
	
	var _tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_property(_background, "color:a", 0.0, fade_out_time)
	_tween.tween_method(func(v: float): _material.set_shader_parameter("amount", v), 1.0, 0.0, fade_out_time)
	await _tween.finished
	_restore()
	# A música do chefe já foi apagada pelo próprio chefe: a da fase volta depois
	if resume_music_delay > 0.0 and AudioManager:
		AudioManager.resume_level_music(resume_music_delay)
	queue_free()


func _restore() -> void:
	for _t in _targets:
		var _node = _t["node"]
		if not is_instance_valid(_node):
			continue
		_node.material = _t["material"]
		_node.z_index = _t["z_index"]
		_node.z_as_relative = _t["z_as_relative"]
	_targets.clear()
	for _n in _hidden_nodes:
		if is_instance_valid(_n):
			_n.visible = true
	_hidden_nodes.clear()


func _hide_node(node: Node) -> void:
	if node and "visible" in node and node.visible:
		node.visible = false
		_hidden_nodes.append(node)


func _play_sound() -> void:
	if not sound:
		return
	var _player := AudioStreamPlayer.new()
	_player.stream = sound
	_player.volume_db = sound_volume_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	# Fica na raiz: continua tocando mesmo depois que o efeito some
	get_tree().root.add_child(_player)
	_player.play()
	_player.finished.connect(_player.queue_free)


func _exit_tree() -> void:
	# Segurança: se a cena trocar no meio do efeito, nada fica preso
	if _active:
		_active = false
		if is_equal_approx(Engine.time_scale, time_scale):
			Engine.time_scale = 1.0
		_restore()
