extends CanvasLayer
class_name PixelTransitions

# ===== SINAIS =====
signal transition_finished

# ===== EXPORTS =====
@export var transition_color: Color = Color.BLACK
@export var duration_in: float = 0.8   # pixelação até cor sólida
@export var duration_out: float = 0.8  # cor sólida até limpo

# ===== REFERÊNCIAS =====
@onready var _rect: ColorRect = $ColorRect

var _material: ShaderMaterial

func _ready() -> void:
	layer = 99
	
	_material = _rect.material as ShaderMaterial
	if _material:
		_material.set_shader_parameter("progress_trans", 0.0)
		_material.set_shader_parameter("transition_color", transition_color)
	
	# ✅ Começa invisível
	_rect.visible = false
	
	print("✅ PixelTransition pronto (Layer: ", layer, ")")

# ===== FADE OUT — pixela e escurece =====
func fade_out() -> void:
	"""Pixela e escurece — chama antes de trocar de fase"""
	if not _material:
		transition_finished.emit()
		return
	
	_rect.visible = true
	_material.set_shader_parameter("progress_trans", 0.0)
	
	var tween = create_tween()
	tween.tween_method(
		func(v: float): _material.set_shader_parameter("progress_trans", v),
		0.0, 1.0, duration_in
	)
	await tween.finished
	transition_finished.emit()
	print("🟫 PixelTransition: fade_out concluído")

# ===== FADE IN — despixela e clareia =====
func fade_in() -> void:
	"""Despixela e clareia — chama após carregar a fase"""
	if not _material:
		_rect.visible = false
		transition_finished.emit()
		return
	
	_material.set_shader_parameter("progress_trans", 1.0)
	_rect.visible = true
	
	var tween = create_tween()
	tween.tween_method(
		func(v: float): _material.set_shader_parameter("progress_trans", v),
		1.0, 0.0, duration_out
	)
	await tween.finished
	
	_rect.visible = false
	transition_finished.emit()
	print("✨ PixelTransition: fade_in concluído")

# ===== AUXILIARES =====
func is_transitioning() -> bool:
	return _rect.visible

func reset() -> void:
	if _material:
		_material.set_shader_parameter("progress_trans", 0.0)
	_rect.visible = false
