extends BaseLevel

func _ready() -> void:
	level_name = "tebes_1_2"
	level_music_track = "tebe_1"
	super._ready()

func setup_dialogs() -> void:
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_FIRST_0_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_FIRST_1_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_FIRST_2_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_FIRST_3_TOLA")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_SECOND_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_SECOND_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_SECOND_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_SECOND_3_AZAZEL")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "third_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_THIRD_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_THIRD_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_THIRD_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_THIRD_3_AZAZEL")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_FINAL_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_FINAL_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_FINAL_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_2_FINAL_3_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_2_FINAL_4_TOLA")}
		]
	})
	print("✅ [Tebes 1-2] ", save_point_dialogs.size(), " diálogos configurados")
