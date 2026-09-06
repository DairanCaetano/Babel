extends BaseLevel

func _ready() -> void:
	level_name = "tebes_1_1"
	level_music_track = "tebe_1"
	super._ready()

func setup_dialogs() -> void:
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_1_FIRST_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_FIRST_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_1_FIRST_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_FIRST_3_AZAZEL")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_SECOND_0_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_1_SECOND_1_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_SECOND_2_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_1_SECOND_3_TOLA")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_1_FINAL_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_FINAL_1_AZAZEL")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_1_FINAL_2_AZAZEL")}
		]
	})
	print("✅ [Tebes 1-1] ", save_point_dialogs.size(), " diálogos configurados")
