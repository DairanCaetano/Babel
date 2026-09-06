extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

var current_music_name: String = ""
var current_volume: float = 1.0

# ========== 🎵 CONFIGURAÇÃO DAS MÚSICAS ==========
const MUSIC_CONFIG := {
	"start_game": {
		"loop": true,
		"fade_in": 1.0,
	},
	"cinematic": {
		"loop": false,
		"fade_in": 1.5,
	},
	"tebe_1": {
		"loop": true,
		"fade_in": 1.5,
	},
	"boss": {
		"loop": true,
		"fade_in": 1.0,
	},
	"egito_1": { 
		"loop": true, 
		"fade_in": 2.0 
		},
}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Ambience"
	add_child(ambience_player)
	
	current_volume = 1.0
	music_player.volume_db = 0.0
	
	music_player.finished.connect(_on_music_finished)
	
	print("🎵 AudioManager inicializado")

func play_music_simple(track_name: String, start_position: float = 0.0) -> void:
	"""
	✅ VERSÃO COM PRELOADER - 100% CONFIÁVEL
	"""
	print("🎵 [PLAY_MUSIC_SIMPLE] Tentando tocar: ", track_name)
	
	# Se já está tocando a mesma música, ignorar
	if current_music_name == track_name and music_player.playing:
		print("✅ Música já está tocando: ", track_name)
		return
	
	# ✅ BUSCAR NO PRELOADER
	var new_music: AudioStream = null
	
	if MusicPreloader.MUSIC_CACHE.has(track_name):
		new_music = MusicPreloader.MUSIC_CACHE[track_name]
		print("  📦 Música obtida do MusicPreloader")
	else:
		print("❌ ERRO: Música '", track_name, "' não encontrada no MusicPreloader!")
		print("  Tracks disponíveis: ", MusicPreloader.MUSIC_CACHE.keys())
		return
	
	if new_music == null:
		print("❌ ERRO: AudioStream é null!")
		return
	
	print("  ✅ AudioStream válido: ", new_music.get_class())
	
	# Parar música atual
	if music_player.playing:
		print("  ⏹️ Parando música atual: ", current_music_name)
		music_player.stop()
	
	# Configurar player
	current_music_name = track_name
	music_player.stream = new_music
	music_player.volume_db = -80.0  # Começa mudo
	
	# Começar a tocar
	music_player.play(start_position)
	print("  ▶️ Música iniciada na posição: ", start_position)
	
	if not music_player.playing:
		print("❌ ERRO: Player não está tocando!")
		return
	
	# Fade in
	var config = MUSIC_CONFIG.get(track_name, {"fade_in": 1.0})
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(current_volume), config["fade_in"])
	
	print("  🔊 Fade in iniciado (", config["fade_in"], "s)")

func _on_music_finished() -> void:
	"""Loop automático"""
	if current_music_name == "":
		return
	
	var config = MUSIC_CONFIG.get(current_music_name, {"loop": false})
	
	if config["loop"]:
		print("🔁 Loop: ", current_music_name)
		music_player.play(0.0)

func stop_music(fade_duration: float = 1.0) -> void:
	"""Para a música com fade out"""
	if not music_player.playing:
		return
	
	print("🔇 Parando música: ", current_music_name)
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
	await tween.finished
	
	music_player.stop()
	current_music_name = ""
	print("  ✅ Música parada")

func stop_music_realtime(duration: float) -> void:
	"""
	✅ Para música em tempo real (não pausa com Engine.time_scale)
	Usado durante sequências de vitória com câmera lenta
	"""
	if not music_player.playing:
		print("⚠️ Música já está parada")
		return
	
	print("🔇 Parando música em tempo real (fade ", duration, "s)")
	
	# Tween em PROCESS_PHYSICS (não afetado por time_scale)
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(music_player, "volume_db", -80.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	music_player.stop()
	current_music_name = ""
	print("  ✅ Música parada completamente")

func set_music_volume(volume: float) -> void:
	current_volume = clamp(volume, 0.0, 1.0)
	if current_volume > 0:
		music_player.volume_db = linear_to_db(current_volume)
	else:
		music_player.volume_db = -80.0

func is_playing() -> bool:
	return music_player.playing

func get_current_track() -> String:
	return current_music_name


# ========== COMPATIBILIDADE COM CÓDIGO ANTIGO ==========
func ensure_music_playing(track_name: String, start_position: float = 0.0, custom_fade_in: float = -1.0) -> void:
	"""
	✅ Função de compatibilidade - redireciona para play_music_simple
	"""
	print("⚠️ ensure_music_playing() é deprecated - usando play_music_simple()")
	
	# Se já está tocando a mesma música, ignorar
	if current_music_name == track_name and music_player.playing:
		print("✅ Música já está tocando: ", track_name)
		return
	
	# Chamar versão simplificada
	play_music_simple(track_name, start_position)

func play_music(track_name: String, fade_in_duration: float = 1.0):
	"""
	✅ Função de compatibilidade - apenas chama a versão simplificada
	RETORNA IMEDIATAMENTE - não trava o código
	"""
	print("⚠️ play_music() chamado (deprecated) - usando play_music_simple()")
	play_music_simple(track_name, 0.0)
	
	# Simula um pequeno delay assíncrono para compatibilidade
	await get_tree().create_timer(0.1).timeout

func fade_out(duration: float):
	"""Versão compatível de fade_out"""
	if not music_player.playing:
		return
	
	print("🔉 Fade out (", duration, "s)")
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
