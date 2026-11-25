extends BaseEffect
class_name AttackTellFX

## Aviso visual de ataque poderoso ("attack tell"), estilo Sekiro.
## Uso nos inimigos: coloque um Marker2D onde o brilho deve aparecer e chame
##     AttackTellFX.spawn(marker)
## na antecipação do ataque (ou quando quiser).
## Por padrão o efeito vira filho do marker e acompanha o inimigo.

const SCENE_PATH: String = "res://Scenes/FX/attack_tell_fx.tscn"

## Som de antecipação (toca no anticipation_frame)
@export var anticipation_sound: AudioStream
## Frame da animação (contando do 0) em que o som de antecipação toca
@export var anticipation_frame: int = 0
## Som próprio do aviso (deixe vazio enquanto o áudio não estiver pronto)
@export var tell_sound: AudioStream
## Variação aleatória do pitch do som (0 = sem variação)
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.0
## Frame da animação (contando do 0) em que o som toca
@export var sound_frame: int = 6

@onready var _audio: AudioStreamPlayer2D = $Audio
@onready var _ant_audio: AudioStreamPlayer2D = $AntAudio

var _anim_done: bool = false
var _sound_played: bool = false
var _ant_played: bool = false


func _ready() -> void:
	if tell_sound and _audio:
		_audio.stream = tell_sound
		_audio.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		_audio.finished.connect(_try_free)
	if anticipation_sound and _ant_audio:
		_ant_audio.stream = anticipation_sound
		_ant_audio.finished.connect(_try_free)
	frame_changed.connect(_on_frame_changed)
	play()
	_on_frame_changed()


func _on_frame_changed() -> void:
	# Os dois sons tocam de forma independente (um não corta o outro)
	if not _ant_played and frame >= anticipation_frame:
		_ant_played = true
		if anticipation_sound and _ant_audio:
			_ant_audio.play()
	if not _sound_played and frame >= sound_frame:
		_sound_played = true
		if tell_sound and _audio:
			_audio.play()


## Instancia o aviso num Marker2D (ou qualquer Node2D).
## follow = true: vira filho do marker e acompanha o inimigo.
## follow = false: fica parado na posição do marker, no level.
static func spawn(marker: Node2D, follow: bool = true, flip: bool = false) -> AttackTellFX:
	if marker == null or not is_instance_valid(marker):
		return null
	var fx: AttackTellFX = load(SCENE_PATH).instantiate()
	fx.flip_h = flip
	if follow:
		marker.add_child.call_deferred(fx)
	else:
		var pos := marker.global_position
		var level := marker.get_tree().current_scene
		var game_main := marker.get_tree().get_first_node_in_group("game_main")
		if game_main and game_main.get("current_level"):
			level = game_main.current_level
		level.add_child.call_deferred(fx)
		fx.set_global_position.call_deferred(pos)
	return fx


func _on_animation_finished() -> void:
	# Some ao fim da animação, mas espera o som terminar antes de sair da cena
	_anim_done = true
	visible = false
	_try_free()


func _try_free() -> void:
	if not _anim_done:
		return
	if _audio and _audio.playing:
		return
	if _ant_audio and _ant_audio.playing:
		return
	queue_free()
