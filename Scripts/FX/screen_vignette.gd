extends CanvasLayer
class_name ScreenVignetteLayer

# ==========================================================================
# VINHETA DE TELA (autoload "ScreenVignette")
# --------------------------------------------------------------------------
# Bordas escuras com ruído animado. Pode ser pedida por vários sistemas ao
# mesmo tempo (vida baixa, Marca da Vingança, boss...). Cada sistema usa um
# nome próprio ("source"); vale o pedido de MAIOR prioridade (empate: o mais
# recente). Quando ninguém mais pede, a vinheta some suavemente.
#
# Uso:
#   ScreenVignette.request("vengeance", Color(0.35, 0, 0), 1.0, 10)
#   ScreenVignette.release("vengeance")
#   ScreenVignette.clear_all()
# ==========================================================================

@export var default_color: Color = Color(0.251, 0.0, 0.0, 1.0)
@export var default_fade_time: float = 0.4

@onready var _rect: ColorRect = $Vignette

var _requests: Dictionary = {}  # source -> { color, intensity, priority, order }
var _order: int = 0
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_intensity(0.0)
	_rect.visible = false

# ========== API ==========

func request(source: String, color: Color = Color(0, 0, 0, 0), intensity: float = 1.0, priority: int = 0, fade_time: float = -1.0) -> void:
	"""Liga (ou atualiza) a vinheta pedida por 'source'. Cor com alpha 0 = cor padrão."""
	_order += 1
	_requests[source] = {
		"color": default_color if color.a <= 0.0 else color,
		"intensity": clampf(intensity, 0.0, 1.0),
		"priority": priority,
		"order": _order,
	}
	_refresh(fade_time)

func release(source: String, fade_time: float = -1.0) -> void:
	"""Remove o pedido de 'source'. Se era o único, a vinheta some."""
	if _requests.erase(source):
		_refresh(fade_time)

func clear_all(fade_time: float = -1.0) -> void:
	_requests.clear()
	_refresh(fade_time)

func is_active(source: String) -> bool:
	return _requests.has(source)

# ========== INTERNO ==========

func _top_source() -> String:
	var best: String = ""
	for source in _requests:
		if best == "":
			best = source
			continue
		var a: Dictionary = _requests[source]
		var b: Dictionary = _requests[best]
		if a["priority"] > b["priority"] or (a["priority"] == b["priority"] and a["order"] > b["order"]):
			best = source
	return best

func _refresh(fade_time: float) -> void:
	var duration: float = default_fade_time if fade_time < 0.0 else fade_time
	var top: String = _top_source()

	if _tween:
		_tween.kill()
	_tween = create_tween()

	if top == "":
		_tween.tween_method(_set_intensity, _get_intensity(), 0.0, duration)
		_tween.tween_callback(_hide_rect)
		return

	var req: Dictionary = _requests[top]
	if not _rect.visible:
		# Começando do zero: já entra com a cor certa
		_set_color(req["color"])
		_rect.visible = true

	_tween.set_parallel(true)
	_tween.tween_method(_set_intensity, _get_intensity(), req["intensity"], duration)
	_tween.tween_method(_set_color, _get_color(), req["color"], duration)

func _hide_rect() -> void:
	if _requests.is_empty():
		_rect.visible = false

func _material() -> ShaderMaterial:
	return _rect.material as ShaderMaterial

func _set_intensity(value: float) -> void:
	if _material():
		_material().set_shader_parameter("intensity", value)

func _get_intensity() -> float:
	if not _material():
		return 0.0
	var v = _material().get_shader_parameter("intensity")
	return float(v) if v != null else 0.0

func _set_color(value: Color) -> void:
	if _material():
		_material().set_shader_parameter("effect_color", value)

func _get_color() -> Color:
	if not _material():
		return default_color
	var v = _material().get_shader_parameter("effect_color")
	return v if v is Color else default_color
