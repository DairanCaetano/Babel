extends BaseLevel

func _ready() -> void:
	level_name = "santuario_1_3"
	level_music_track = "santuario_corredor"
	super._ready()

func on_level_loaded() -> void:
	super.on_level_loaded()

func setup_dialogs() -> void:
	pass
