extends BaseLevel

func _ready() -> void:
	level_name = "egito_1_1"
	level_music_track = "egito_1"
	super._ready()

func on_level_loaded() -> void:
	super.on_level_loaded()

func setup_dialogs() -> void:
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_0_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FIRST_1_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_2_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FIRST_3_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_4_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FIRST_5_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_6_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FIRST_7_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_8_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FIRST_9_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FIRST_10_AZAZEL")},
		]
	})
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_SECOND_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_SECOND_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_SECOND_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_SECOND_3_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_SECOND_4_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_SECOND_5_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_SECOND_6_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_SECOND_7_AZAZEL")},
		]
	})
	save_point_dialogs.append({
		"dialog_name": "third_meeting",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_THIRD_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_THIRD_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_THIRD_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_THIRD_3_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_THIRD_4_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_THIRD_5_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_THIRD_6_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_THIRD_7_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_THIRD_8_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_THIRD_9_AZAZEL")},
		]
	})
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_1_1_FINAL_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_1_1_FINAL_1_AZAZEL")},
		]
	})
	print("✅ [Egito 1-1] ", save_point_dialogs.size(), " diálogos configurados")

# ===== SAVE POINT 2 =====
# Os diálogos abaixo são para egito_1_2.gd (fase após o save point 2)
# setup_dialogs() de egito_1_2 deve conter:
#
# FIRST  → DIALOG_EGITO_1_2_FIRST_0..9
# SECOND → DIALOG_EGITO_1_2_SECOND_0..11
# FINAL  → DIALOG_EGITO_1_2_FINAL_0..3
