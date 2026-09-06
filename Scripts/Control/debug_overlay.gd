extends CanvasLayer

var label: Label
var _spike_threshold_ms: float = 20.0  # considera spike acima de 20ms

func _ready() -> void:
	visible = false
	label = Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			visible = not visible

func _process(delta: float) -> void:
	var delta_ms = delta * 1000.0
	
	# ✅ Loga automaticamente qualquer spike
	if delta_ms > _spike_threshold_ms:
		print("🚨 SPIKE DETECTADO | Delta: %.2fms | FPS: %d | Objects: %d | Nodes: %d" % [
			delta_ms,
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		])
	
	if not visible:
		return
		
	label.text = "FPS: %d\nDelta: %.2f ms\nMem: %.1f MB\nObjects: %d\nDrawcalls: %d" % [
		Engine.get_frames_per_second(),
		delta_ms,
		OS.get_static_memory_usage() / 1_048_576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	]
