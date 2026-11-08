extends CanvasLayer

## TELA DO MAPA. Quem abre e fecha é o MapManager.
## Navegação: move_up / move_down / move_left / move_right
## Fechar: Map ou close_menu

## Quantos pixels da tela cada pixel do mapa ocupa
@export_range(1, 6) var zoom: int = 2
## Velocidade de rolagem, em pixels da tela por segundo
@export var velocidade: float = 180.0
## Texto da porcentagem (%d = número)
@export var texto_explorado: String = "Mapa explorado: %d%%"
@export var cor_moldura: Color = Color8(110, 85, 60)
@export var cor_tola: Color = Color8(255, 255, 255)
@export var cor_save: Color = Color8(90, 210, 120)

@onready var _janela: Control = $Janela
@onready var _porcentagem: Label = $Porcentagem

var _manager: Node = null
var _camadas: Array = []   # [{"fase": MapLevelData, "tex": ImageTexture, "vis": PackedByteArray}]
var _centro: Vector2 = Vector2.ZERO
var _limites: Rect2 = Rect2()
var _tola_px: Vector2 = Vector2.ZERO
var _tem_tola: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_janela.draw.connect(_desenhar)


func abrir(manager: Node) -> void:
	_manager = manager
	_montar()
	visible = true
	_janela.queue_redraw()


func fechar() -> void:
	visible = false
	_camadas.clear()


func _process(delta: float) -> void:
	if not visible or _manager == null:
		return

	if Input.is_action_just_pressed("Map") or Input.is_action_just_pressed("close_menu"):
		_manager.fechar_tela()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_centro += dir * velocidade * delta / float(zoom)
		_centro = _centro.clamp(_limites.position, _limites.end)

	_janela.queue_redraw()   # também faz o marcador do Tola piscar


# ------------------------------------------------------------------
# Montagem das imagens (só o que foi revelado)
# ------------------------------------------------------------------

func _montar() -> void:
	var mundo: MapWorldData = _manager.dados
	var r: Dictionary = _manager.montar()
	var visiveis: Dictionary = r["visiveis"]
	_camadas.clear()

	for f in mundo.fases:
		var vis: PackedByteArray = visiveis[f]
		var w := f.mascara.get_width()
		var h := f.mascara.get_height()
		var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var tem_algo := false
		for y in h:
			for x in w:
				if vis[y * w + x] == 0:
					continue
				tem_algo = true
				var cor := f.cor
				if _e_borda(vis, w, h, x, y):
					cor = cor.lightened(0.3)
				img.set_pixel(x, y, cor)
		if tem_algo:
			_camadas.append({"fase": f, "tex": ImageTexture.create_from_image(img), "vis": vis})

	_porcentagem.text = texto_explorado % int(r["porcentagem"])
	_limites = Rect2(mundo.limites)

	var fase: MapLevelData = _manager.fase_atual()
	var t: Node2D = _manager.tola()
	_tem_tola = fase != null and t != null
	if _tem_tola:
		_tola_px = _manager.pixel_do_mundo(t.global_position, fase)
		_centro = _tola_px.clamp(_limites.position, _limites.end)
	else:
		_centro = _limites.get_center()


func _e_borda(vis: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	if x == 0 or y == 0 or x == w - 1 or y == h - 1:
		return true
	return vis[y * w + x + 1] == 0 or vis[y * w + x - 1] == 0 or vis[(y + 1) * w + x] == 0 or vis[(y - 1) * w + x] == 0


# ------------------------------------------------------------------
# Desenho
# ------------------------------------------------------------------

func _desenhar() -> void:
	var tam := _janela.size
	var base := (tam * 0.5 - _centro * zoom).floor()

	for c in _camadas:
		var f: MapLevelData = c["fase"]
		var tex: ImageTexture = c["tex"]
		_janela.draw_texture_rect(tex, Rect2(base + Vector2(f.origem) * zoom, Vector2(tex.get_size()) * zoom), false)
		for s in f.saves:
			if _visivel(c, s):
				_ponto(base + s * zoom, cor_save)

	# Tola piscando
	if _tem_tola and (Time.get_ticks_msec() / 300) % 2 == 0:
		_ponto(base + _tola_px * zoom, cor_tola)

	# Moldura da janela
	_janela.draw_rect(Rect2(Vector2.ZERO, tam), cor_moldura, false, 1.0)


func _visivel(camada: Dictionary, p: Vector2) -> bool:
	var f: MapLevelData = camada["fase"]
	var vis: PackedByteArray = camada["vis"]
	var w := f.mascara.get_width()
	var h := f.mascara.get_height()
	var l := Vector2i(p.floor()) - f.origem
	for dy in [0, -1, 1]:
		var y: int = l.y + dy
		if l.x < 0 or l.x >= w or y < 0 or y >= h:
			continue
		if vis[y * w + l.x] != 0:
			return true
	return false


func _ponto(centro: Vector2, cor: Color) -> void:
	var c := centro.floor()
	_janela.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color.BLACK)
	_janela.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), cor)
