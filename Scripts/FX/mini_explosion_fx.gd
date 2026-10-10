extends BaseEffect
class_name MiniExplosionFx

# ==========================================================================
# MINI EXPLOSÃO (Ataque 6 do Rá)
# Toca um som ao nascer, com pitch aleatório (igual aos golpes do Tola),
# para que várias explosões seguidas não soem idênticas.
# ==========================================================================

## Som da explosão. Vazio = sem som.
@export var sound: AudioStream
@export_range(0.5, 2.0) var pitch_min: float = 0.9
@export_range(0.5, 2.0) var pitch_max: float = 1.1
@export var volume_db: float = 0.0

var _audio: AudioStreamPlayer2D

func _ready() -> void:
	if sound:
		_audio = AudioStreamPlayer2D.new()
		_audio.stream = sound
		_audio.volume_db = volume_db
		_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		_audio.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
		add_child(_audio)
		_audio.play()
	super._ready()

func _on_animation_finished() -> void:
	# Se o som for mais longo que a animação, esconde e espera o som acabar
	if _audio and _audio.playing:
		visible = false
		await _audio.finished
	queue_free()
