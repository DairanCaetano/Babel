extends BaseLevel


var fps_timer: float = 0.0
var frame_count: int = 0
var last_fps: float = 0.0

func _process(delta: float) -> void:
	fps_timer += delta
	frame_count += 1
	
	# Atualizar a cada 1 segundo
	if fps_timer >= 1.0:
		last_fps = frame_count / fps_timer
		
		# Pegar estatísticas
		var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
		var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
		var objects_count = Performance.get_monitor(Performance.OBJECT_COUNT)
		var nodes_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		
		print("📊 FPS: ", snappedf(last_fps, 0.1))
		print("   Process: ", snappedf(process_time, 0.01), "ms")
		print("   Physics: ", snappedf(physics_time, 0.01), "ms")
		print("   Objects: ", objects_count)
		print("   Nodes: ", nodes_count)
		print("   --------")
		
		fps_timer = 0.0
		frame_count = 0

func _ready() -> void:
	print("🔍 ===== PERFORMANCE MONITOR ATIVADO =====")
	print("📊 Monitorando FPS e carga de processamento...")
	level_name = "tebes_1_4"
	level_music_track = "tebe_1"
	super._ready()

func setup_dialogs() -> void:
	save_point_dialogs.append({
		"dialog_name": "first_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_FIRST_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_FIRST_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_FIRST_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_FIRST_3_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_FIRST_4_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_FIRST_5_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_FIRST_6_TOLA")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "second_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_SECOND_0_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_SECOND_1_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_SECOND_2_TOLA")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_SECOND_3_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_SECOND_4_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_SECOND_5_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_SECOND_6_AZAZEL")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "third_meeting",
		"lines": [
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_THIRD_0_TOLA")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_THIRD_1_TOLA")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_THIRD_2_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_THIRD_3_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_THIRD_4_TOLA")}
		]
	})
	save_point_dialogs.append({
		"dialog_name": "final_loop",
		"lines": [
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_FINAL_0_AZAZEL")},
			{"character": "tola", "text": tr("DIALOG_TEBES_1_4_FINAL_1_TOLA")},
			{"character": "azazel", "text": tr("DIALOG_TEBES_1_4_FINAL_2_AZAZEL")}
		]
	})
	print("✅ [Tebes 1-4] ", save_point_dialogs.size(), " diálogos configurados")
