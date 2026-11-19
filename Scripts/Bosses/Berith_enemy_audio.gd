extends Node2D
class_name BaalBerithAudio

@export var boss_roar_audio: AudioStreamPlayer
@export var boss_idle_audio: AudioStreamPlayer
@export var attack_1_anticipation_audio: AudioStreamPlayer
@export var attack_2_anticipation_audio: AudioStreamPlayer
@export var attack_3_anticipation_audio: AudioStreamPlayer
@export var attack_4_anticipation_audio: AudioStreamPlayer
## Som do charge do Ataque 4 (toca quando o FX de charge aparece)
@export var attack_4_charge_audio: AudioStreamPlayer
@export var attack_1_audio: AudioStreamPlayer
@export var attack_2_audio: AudioStreamPlayer
@export var attack_3_audio: AudioStreamPlayer
## Som de cada disparo do Ataque 4 (use Max Polyphony > 1 para os tiros não se cortarem)
@export var attack_4_audio: AudioStreamPlayer
@export var dead_boss_audio: AudioStreamPlayer
@export var victory_audio: AudioStreamPlayer

@export_range(0.8, 1.2) var pitch_variation: float = 0.15
## Pitch base da antecipação do Ataque 4 (a variação é somada em cima)
@export var attack_4_anticipation_pitch: float = 0.8

func play_roar() -> void:
	_play_with_pitch(boss_roar_audio)

func play_idle() -> void:
	_play_with_pitch(boss_idle_audio)

# Áudios de antecipação
func play_attack_1_anticipation() -> void:
	_play_with_pitch(attack_1_anticipation_audio)

func play_attack_2_anticipation() -> void:
	_play_with_pitch(attack_2_anticipation_audio)

func play_attack_3_anticipation() -> void:
	_play_with_pitch(attack_3_anticipation_audio)

func play_attack_4_anticipation() -> void:
	_play_with_pitch(attack_4_anticipation_audio, attack_4_anticipation_pitch)

func play_attack_4_charge() -> void:
	_play_with_pitch(attack_4_charge_audio)

# Áudios de ataque
func play_attack_1() -> void:
	_play_with_pitch(attack_1_audio)

func play_attack_2() -> void:
	_play_with_pitch(attack_2_audio)

func play_attack_3() -> void:
	_play_with_pitch(attack_3_audio)

func play_attack_4() -> void:
	_play_with_pitch(attack_4_audio)

func play_death() -> void:
	if dead_boss_audio:
		dead_boss_audio.play()

# ===== 🎉 NOVO: TOCAR SOM DE VITÓRIA =====
func play_victory() -> void:
	if victory_audio:
		victory_audio.play()
		print("🎺 Áudio de vitória tocando!")

# Fade out do Attack 1 Audio
func stop_attack_1_with_fade() -> void:
	if not attack_1_audio or not attack_1_audio.playing:
		return
	
	var tween = get_tree().create_tween()
	tween.tween_property(attack_1_audio, "volume_db", -80.0, 0.5)
	tween.tween_callback(func(): 
		attack_1_audio.stop()
		attack_1_audio.volume_db = 0.0
	)

func _play_with_pitch(audio: AudioStreamPlayer, base_pitch: float = 1.0) -> void:
	if not audio:
		return
	
	var random_pitch = base_pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	audio.pitch_scale = random_pitch
	audio.play()
