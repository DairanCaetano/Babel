extends Node

# ✅ PRÉ-CARREGAR TODAS AS MÚSICAS EM TEMPO DE COMPILAÇÃO
const MUSIC_CACHE = {
	"start_game": preload("res://Sound/Music/MenuSound/1. Dunes of Silence.ogg"),
	"cinematic": preload("res://Sound/Music/MenuSound/1. Dunes of Silence.ogg"),
	"tebe_1": preload("res://Sound/Music/LevelSound/Tebes_4. Canyon Echoes.ogg"),
	"boss": preload("res://Sound/Music/LevelSound/Baal_Barith_Boss_Fight.ogg"),
	"egito_1": preload("res://Sound/Music/LevelSound/Egito_2 Moonlit Dunes - Blue Lava.ogg"),
	"santuario_corredor": preload("res://Sound/Music/LevelSound/Santuário_1_Corredor_Infinito_669491__logicmoon__kaleidoscope-0001.ogg"),
	"santuario_1_2": preload("res://Sound/Music/LevelSound/Santuário_3_OST_698104__theojt__psychedelic-hypnotic-theme.ogg"),
}

func _ready() -> void:
	print("🎵 MusicPreloader pronto com ", MUSIC_CACHE.size(), " músicas")
	for track_name in MUSIC_CACHE.keys():
		print("  ✅ ", track_name, " pré-carregado")
