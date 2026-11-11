@tool
extends Node2D
class_name GodRays
## Raios de luz pixelados. Arraste a cena god_rays.tscn para a fase,
## defina o tamanho da área em pixels do jogo e posicione.
## O canto SUPERIOR ESQUERDO da área fica na posição do nó.
## Atrás ou na frente da Tola: ordem dos nós ou z_index.

@export_group("Área")
## Tamanho da área dos raios, em pixels do jogo (mantenha a escala em 1)
@export var size: Vector2i = Vector2i(160, 200):
	set(v):
		size = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_apply()

@export_group("Luz")
@export var ray_color: Color = Color(1.0, 0.9, 0.65, 0.8):
	set(v):
		ray_color = v
		_apply()
@export_range(0.0, 1.0) var opacity: float = 1.0:
	set(v):
		opacity = v
		_apply()
## Mistura com o cenário (0 Screen, 1 Hard Light, 2 Soft Light, 5 Multiply, 7 Lighten...)
@export_enum("Screen", "Hard Light", "Soft Light", "Clamp", "Negative", "Multiply", "Darken", "Lighten", "Difference", "Exclusion") var blend_mode: int = 0:
	set(v):
		blend_mode = v
		_apply()

@export_group("Forma")
## Inclinação dos raios
@export_range(-1.5, 1.5, 0.01) var angle: float = -0.3:
	set(v):
		angle = v
		_apply()
## Ponto de origem (deslocamento horizontal)
@export_range(-1.0, 1.0, 0.01) var origin: float = -0.2:
	set(v):
		origin = v
		_apply()
## Abertura do feixe
@export_range(0.0, 1.0, 0.01) var spread: float = 0.5:
	set(v):
		spread = v
		_apply()
## Esmaecimento na parte de baixo
@export_range(0.0, 1.0, 0.01) var falloff: float = 0.2:
	set(v):
		falloff = v
		_apply()

@export_group("Movimento")
@export var speed: float = 1.0:
	set(v):
		speed = v
		_apply()
@export var ray1_density: float = 8.0:
	set(v):
		ray1_density = v
		_apply()
@export var ray2_density: float = 30.0:
	set(v):
		ray2_density = v
		_apply()

@export_group("Pixel")
## Tamanho do bloco de pixel (1 = pixel do jogo)
@export_range(1.0, 16.0, 1.0) var pixel_size: float = 1.0:
	set(v):
		pixel_size = v
		_apply()

@onready var _rays: Sprite2D = $Rays

func _ready() -> void:
	# Material e textura são "local to scene": cada instância tem os seus
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	if _rays == null:
		_rays = get_node_or_null("Rays")
	if _rays == null:
		return
	var _tex: GradientTexture2D = _rays.texture as GradientTexture2D
	if _tex and (_tex.width != size.x or _tex.height != size.y):
		_tex.width = size.x
		_tex.height = size.y
	var _mat: ShaderMaterial = _rays.material as ShaderMaterial
	if _mat == null:
		return
	_mat.set_shader_parameter("ray_color", ray_color)
	_mat.set_shader_parameter("opacity", opacity)
	_mat.set_shader_parameter("blend_mode", blend_mode)
	_mat.set_shader_parameter("angle", angle)
	_mat.set_shader_parameter("position", origin)
	_mat.set_shader_parameter("spread", spread)
	_mat.set_shader_parameter("falloff", falloff)
	_mat.set_shader_parameter("speed", speed)
	_mat.set_shader_parameter("ray1_density", ray1_density)
	_mat.set_shader_parameter("ray2_density", ray2_density)
	_mat.set_shader_parameter("pixelSizeScale", pixel_size)
