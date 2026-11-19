extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

var current_music_name: String = ""
var current_volume: float = 1.0
var _fade_out_tween: Tween   # fade-out em andamento (stop_music_realtime)

# ========== PAUSA: a música continua, mais baixa ==========
# Com o jogo pausado (inventário, arquivos, escolha de slot...) a música
# e o ambiente seguem tocando com volume reduzido; voltam ao normal ao despausar.
## Quanto o volume abaixa na pausa (dB). 0 = não abaixa.
var pause_duck_db: float = -8.0
## Tempo da transição do volume (s).
var pause_duck_time: float = 0.3
var _duck_effects: Array[AudioEffectAmplify] = []
var _duck_tween: Tween
var _was_paused: bool = false

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
	"santuario_corredor": {
		"loop": true,
		"fade_in": 2.0,
	},
	"santuario_1_2": {
		"loop": true,
		"fade_in": 2.0,
	},
}

func _ready() -> void:
	# ✅ Não pausa junto com o jogo (a música segue nos menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_pause_duck()
	
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
	
	# Um fade-out antigo ainda rodando abaixaria a música nova: cancela
	_kill_fade_out_tween()
	
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

func _setup_pause_duck() -> void:
	"""Um 'Amplify' em cada bus (Music/Ambience) faz o abaixar na pausa,
	sem brigar com os fades da música nem com o volume das opções."""
	for _bus_name in ["Music", "Ambience"]:
		var _idx: int = AudioServer.get_bus_index(_bus_name)
		if _idx == -1:
			continue
		var _fx := AudioEffectAmplify.new()
		_fx.volume_db = 0.0
		AudioServer.add_bus_effect(_idx, _fx)
		_duck_effects.append(_fx)

func _process(_delta: float) -> void:
	var _paused: bool = get_tree().paused
	if _paused == _was_paused:
		return
	_was_paused = _paused
	if _duck_tween:
		_duck_tween.kill()
	if _duck_effects.is_empty():
		return
	_duck_tween = create_tween().set_parallel(true)
	var _target: float = pause_duck_db if _paused else 0.0
	for _fx in _duck_effects:
		_duck_tween.tween_property(_fx, "volume_db", _target, pause_duck_time)

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
	if not music_player.playing or current_music_name == "":
		print("⚠️ Música já está parada (ou sendo cortada)")
		return
	
	print("🔇 Parando música em tempo real (fade ", duration, "s)")
	var _fading_track: String = current_music_name
	
	# Tween em PROCESS_PHYSICS (não afetado por time_scale)
	_kill_fade_out_tween()
	var tween = create_tween()
	_fade_out_tween = tween
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_ignore_time_scale(true)   # tempo real de verdade: não desacelera na câmera lenta
	tween.tween_property(music_player, "volume_db", -80.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Se outra música começou durante o fade, não corta a nova
	if current_music_name != _fading_track:
		print("  ↪️ Outra música começou durante o fade — mantida")
		return
	
	music_player.stop()
	current_music_name = ""
	print("  ✅ Música parada completamente")

func _kill_fade_out_tween() -> void:
	if _fade_out_tween and _fade_out_tween.is_valid():
		_fade_out_tween.kill()
	_fade_out_tween = null

func cut_music(fade: float = 0.1) -> void:
	"""
	✂️ Corte (quase) seco da música, em tempo real. fade = 0 corta na hora;
	um fade curtinho (0.1s) evita estalo. Usado na tela preta da morte do chefe.
	"""
	if not music_player.playing:
		return
	_kill_fade_out_tween()
	print("✂️ Cortando música: ", current_music_name)
	current_music_name = ""   # já conta como parada (stop_music_realtime ignora)
	if fade <= 0.0:
		music_player.stop()
		return
	var tween := create_tween()
	_fade_out_tween = tween
	tween.set_ignore_time_scale(true)
	tween.tween_property(music_player, "volume_db", -80.0, fade)
	tween.tween_callback(func():
		if current_music_name == "":
			music_player.stop()
	)

func resume_level_music(delay: float = 4.0) -> void:
	"""
	✅ Volta a tocar a música da fase atual depois de `delay` segundos REAIS
	(não desacelera com câmera lenta). Usado depois da morte de um chefe.
	Não faz nada se já houver música tocando ou se a fase estiver na
	sequência de vitória.
	"""
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	
	var level = _get_current_level()
	if not level or not "level_music_track" in level:
		return
	if "victory_sequence_active" in level and level.victory_sequence_active:
		print("🎵 Música da fase não retomada: sequência de vitória em andamento")
		return
	# Música tocando: só desiste se ela não estiver sumindo (ex.: cutscene).
	# Se for a do chefe ainda em fade, a da fase entra no lugar.
	var _fading: bool = _fade_out_tween != null and _fade_out_tween.is_valid() and _fade_out_tween.is_running()
	if music_player.playing and not _fading:
		return
	var track: String = level.level_music_track
	if track == "":
		return
	print("🎵 Retomando música da fase: ", track)
	play_music_simple(track, 0.0)

func _get_current_level() -> Node:
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main and "current_level" in game_main and is_instance_valid(game_main.current_level):
		return game_main.current_level
	return get_tree().current_scene

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
