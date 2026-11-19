extends BaseLevel

func _ready() -> void:
	level_name = "santuario_1_2"
	level_music_track = "santuario_1_2"
	super._ready()

func on_level_loaded() -> void:
	super.on_level_loaded()

func setup_dialogs() -> void:
	pass
