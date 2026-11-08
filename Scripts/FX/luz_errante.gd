extends PointLight2D
class_name LuzErrante

## Luz estilo Animal Well que "dança" pela tela: anda em linha levemente
## curva até tocar uma borda da tela e quica para o lado oposto, com um
## pequeno desvio aleatório a cada quique. Fica presa à tela (acompanha a câmera).
## Se "Texture" estiver vazio, a textura da luz é gerada pelo script.

enum Estilo { DISCO, ANEIS }

@export_category("Movimento")
## Até onde a luz vai a partir do centro da tela (px). Metade da tela (240, 135) = encosta nas bordas.
@export var raio: Vector2 = Vector2(240, 135)
## Velocidade (px por segundo).
@export var velocidade: float = 35.0
## Quanto o caminho faz curvas suaves ("dança"). 0 = linha reta entre os quiques.
@export var curva: float = 0.5
## Desvio aleatório (graus) a cada quique, para não repetir sempre o mesmo caminho.
@export var desvio_quique: float = 20.0
## Semente do movimento. 0 = diferente a cada vez que a fase carrega.
@export var semente: int = 0

@export_category("O que a luz ilumina")
## A luz SÓ ilumina o que estiver dentro destes nós (ex.: Terrain e SecretAreas).
## O resto (player, inimigos, partículas) fica fora da luz.
@export var iluminar: Array[Node] = []
## Liga: ilumina TODOS os tilemaps da fase (paredes e decoração), sem precisar preencher "iluminar".
@export var todos_tilemaps_da_fase: bool = false
## Dentro de "iluminar", só os tilemaps recebem luz (sprites e interativos ficam de fora).
@export var apenas_tilemaps: bool = false
## Camada de luz exclusiva do cenário (2 a 20). Só mude se já usar essa camada para outra coisa.
@export_range(2, 20) var camada_luz: int = 2

@export_category("Textura gerada (se Texture estiver vazio)")
## DISCO = igual ao exemplo (miolo aceso + 1 anel). ANEIS = degradê em degraus.
@export var estilo: Estilo = Estilo.ANEIS
## Tamanho da luz gerada (px de diâmetro).
@export var tamanho: int = 256
## ANEIS: quantidade de anéis (mais anéis = degradê mais suave).
@export var aneis: int = 5
## DISCO: espessura do anel da borda (0.06 = igual ao exemplo).
@export_range(0.0, 0.5) var borda_largura: float = 0.06
## DISCO: intensidade do anel da borda (0.53 = igual ao exemplo).
@export_range(0.0, 1.0) var borda_intensidade: float = 0.53

var _ruido := FastNoiseLite.new()
var _t: float = 0.0
var _pos: Vector2 = Vector2.ZERO # posição em relação ao centro da tela
var _dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	if semente != 0:
		seed(semente)
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 0.3
	_ruido.seed = semente if semente != 0 else randi()
	# Começa numa diagonal aleatória (nunca reta na horizontal/vertical).
	_dir = Vector2.RIGHT.rotated(deg_to_rad(randf_range(25.0, 65.0) + 90.0 * randi_range(0, 3)))
	_pos = Vector2(randf_range(-raio.x, raio.x), randf_range(-raio.y, raio.y)) * 0.5
	if texture == null:
		texture = _criar_textura()
	_configurar_alvos()
	# Posiciona logo antes de desenhar: a câmera já se moveu neste frame.
	RenderingServer.frame_pre_draw.connect(_posicionar)
	_posicionar()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_posicionar):
		RenderingServer.frame_pre_draw.disconnect(_posicionar)

func _process(delta: float) -> void:
	_t += delta
	# Dança: a direção gira suavemente para um lado e para o outro.
	_dir = _dir.rotated(_ruido.get_noise_1d(_t) * 2.0 * curva * delta).normalized()
	_pos += _dir * velocidade * delta
	
	# Quique nas bordas da tela.
	if _pos.x > raio.x:
		_pos.x = raio.x
		_quicar(true, -1.0)
	elif _pos.x < -raio.x:
		_pos.x = -raio.x
		_quicar(true, 1.0)
	if _pos.y > raio.y:
		_pos.y = raio.y
		_quicar(false, -1.0)
	elif _pos.y < -raio.y:
		_pos.y = -raio.y
		_quicar(false, 1.0)

## Rebate a direção no eixo que bateu e aplica um pequeno desvio aleatório.
## sinal = para onde o componente daquele eixo deve apontar depois do quique.
func _quicar(eixo_x: bool, sinal: float) -> void:
	_dir = _dir.rotated(deg_to_rad(randf_range(-desvio_quique, desvio_quique)))
	# Garante que sai da borda e não fica deslizando rente a ela.
	var x: float = _dir.x
	var y: float = _dir.y
	if eixo_x:
		x = absf(x) * sinal
	else:
		y = absf(y) * sinal
	if absf(x) < 0.35:
		x = 0.35 * (signf(x) if x != 0.0 else 1.0)
	if absf(y) < 0.35:
		y = 0.35 * (signf(y) if y != 0.0 else 1.0)
	_dir = Vector2(x, y).normalized()

## A luz passa a afetar só a "camada_luz"; os nós em "iluminar" (e tudo
## dentro deles) ganham essa camada. O player continua só na camada 1.
func _configurar_alvos() -> void:
	var bit: int = 1 << (camada_luz - 1)
	range_item_cull_mask = bit
	var total: int = 0
	for no in iluminar:
		if no != null and is_instance_valid(no):
			total += _marcar(no, bit)
	if todos_tilemaps_da_fase:
		for camada in EsteticaUtil.listar_tilemaps(EsteticaUtil.raiz_fase(self)):
			if (camada.light_mask & bit) == 0:
				camada.light_mask |= bit
				total += 1
	print("💡 LuzErrante: ilumina ", total, " item(ns) do cenário")

func _marcar(no: Node, bit: int) -> int:
	var total: int = 0
	if no is CanvasItem and (not apenas_tilemaps or no is TileMapLayer):
		(no as CanvasItem).light_mask |= bit
		total += 1
	for filho in no.get_children():
		total += _marcar(filho, bit)
	return total

func _posicionar() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var centro: Vector2 = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
	global_position = (centro + _pos).round()

func _criar_textura() -> Texture2D:
	var gradiente := Gradient.new()
	gradiente.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var cores := PackedColorArray()
	if estilo == Estilo.DISCO:
		offsets.append(0.0)
		cores.append(Color(1.0, 1.0, 1.0, 1.0))
		offsets.append(1.0 - borda_largura)
		cores.append(Color(1.0, 1.0, 1.0, borda_intensidade))
	else:
		var total: int = maxi(aneis, 1)
		for i in range(total):
			var a: float = 1.0 - float(i) / float(total)
			offsets.append(float(i) / float(total))
			cores.append(Color(1.0, 1.0, 1.0, a * a))
	offsets.append(1.0)
	cores.append(Color(1.0, 1.0, 1.0, 0.0))
	gradiente.offsets = offsets
	gradiente.colors = cores
	
	var tex := GradientTexture2D.new()
	tex.gradient = gradiente
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = tamanho
	tex.height = tamanho
	return tex
