extends BaseLevel

func _ready() -> void:
	level_name = "egito_1_2"
	level_music_track = "egito_1"
	super._ready()

func on_level_loaded() -> void:
	super.on_level_loaded()

func setup_dialogs() -> void:
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FIRST_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FIRST_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FIRST_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FIRST_3_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FIRST_4_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FIRST_5_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FIRST_6_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FIRST_7_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FIRST_8_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FIRST_9_AZAZEL")},
		]
	})
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_3_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_4_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_5_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_6_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_7_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_8_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_9_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_SECOND_10_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_SECOND_11_AZAZEL")},
		]
	})
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FINAL_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FINAL_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_2_FINAL_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_2_FINAL_3_AZAZEL")},
		]
	})
	print("✅ [Egito 1-2] ", save_point_dialogs.size(), " diálogos configurados")
