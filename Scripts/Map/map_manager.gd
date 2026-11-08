extends Node

## MAPA (autoload "MapManager")
## - Revela o mapa em volta do Tola conforme ele anda (fica no save).
## - Anota as salas (CameraZones) visitadas (usado para regiões e para o modo "sala inteira").
## - Abre e fecha a tela do mapa.
## Os ajustes ficam no Inspector da cena res://Scenes/Map/map_manager.tscn

const DADOS_MAPA := "res://Mapa/map_data.res"
const CHAVE_SALAS := "map_visited"
const CHAVE_REVELADO := "map_revealed"
const INTERVALO_REGISTRO := 0.1
const ESPERA_REABRIR_MS := 400

@export_group("Revelação")
## Ligado: entrar numa sala revela a sala inteira (modo antigo).
## Desligado: revela só em volta do Tola.
@export var revelar_sala_inteira: bool = false
## Largura do raio de revelação, em pixels do mapa (1 pixel do mapa = 32 px do jogo)
@export_range(2.0, 30.0, 0.5) var raio_horizontal: float = 8.0
## Altura do raio de revelação, em pixels do mapa
@export_range(2.0, 30.0, 0.5) var raio_vertical: float = 5.0
## Tamanho dos "blocos" da borda, em pixels do mapa (maior = mais pixelado)
@export_range(1, 4) var tamanho_pixel: int = 2
## Quanto a borda é irregular (0 = elipse certinha, 0.5 = bem serrilhada)
@export_range(0.0, 0.6, 0.05) var irregularidade: float = 0.3

@export_group("Teto alto")
## Revela o espaço aberto acima do Tola até bater no teto (salas de céu alto)
@export var revelar_teto: bool = true
## Altura máxima revelada acima do raio, em pixels do mapa
@export_range(0, 120) var altura_maxima_teto: int = 30

@export_group("Teste (desligar no jogo final)")
## Libera o mapa sem precisar pegar o item
@export var debug_dar_mapa: bool = false
## Mostra o mapa inteiro, como se tudo tivesse sido visitado
@export var debug_revelar_tudo: bool = false

@onready var _tela = $MapScreen

var dados: MapWorldData = null
var _aberto: bool = false
var _fechou_em: int = -100000
var _timer: float = 0.0
var _cache_caminho: String = "-"
var _cache_fase: MapLevelData = null
var _info_fases: Dictionary = {}   # MapLevelData -> {"w","h","andavel","secreto","zona"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(DADOS_MAPA):
		dados = load(DADOS_MAPA) as MapWorldData
	if dados == null:
		push_warning("[Mapa] " + DADOS_MAPA + " não encontrado. Rode o gerador (Scenes/Map/gerador_mapa.tscn).")


func _process(delta: float) -> void:
	if _aberto or dados == null or get_tree().paused:
		return
	_timer += delta
	if _timer < INTERVALO_REGISTRO:
		return
	_timer = 0.0
	registrar_agora()


# ------------------------------------------------------------------
# Registro
# ------------------------------------------------------------------

func registrar_agora() -> void:
	var fase := fase_atual()
	if fase == null:
		return
	var chave := fase.cena.to_lower()

	# Sala onde a câmera está
	for z in get_tree().get_nodes_in_group("camera_zones"):
		if z.get("is_active") == true:
			_marcar_sala(chave, String(z.name))

	# Revelação em volta do Tola
	var t := tola()
	if t:
		_revelar_em_volta(fase, chave, pixel_do_mundo(t.global_position, fase))


func _marcar_sala(fase: String, sala: String) -> void:
	var gd: Dictionary = serialization.game_data
	if not gd.has(CHAVE_SALAS) or not (gd[CHAVE_SALAS] is Dictionary):
		gd[CHAVE_SALAS] = {}
	var por_fase: Dictionary = gd[CHAVE_SALAS]
	if not por_fase.has(fase) or not (por_fase[fase] is Dictionary):
		por_fase[fase] = {}
	por_fase[fase][sala] = true


## Dados rápidos de cada fase (andável / secreto / zona), lidos da máscara uma vez só
func _info(fase: MapLevelData) -> Dictionary:
	if _info_fases.has(fase):
		return _info_fases[fase]
	var m := fase.mascara
	var w := m.get_width()
	var h := m.get_height()
	var andavel := PackedByteArray()
	var secreto := PackedByteArray()
	var zona := PackedByteArray()
	andavel.resize(w * h)
	secreto.resize(w * h)
	zona.resize(w * h)
	andavel.fill(0)
	secreto.fill(0)
	zona.fill(0)
	for y in h:
		for x in w:
			var c := m.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var i := y * w + x
			andavel[i] = 1
			zona[i] = c.r8
			if c.g > 0.5:
				secreto[i] = 1
	var info := {"w": w, "h": h, "andavel": andavel, "secreto": secreto, "zona": zona}
	_info_fases[fase] = info
	return info


func _revelado_da_fase(chave: String, tamanho: int) -> PackedByteArray:
	var gd: Dictionary = serialization.game_data
	if not gd.has(CHAVE_REVELADO) or not (gd[CHAVE_REVELADO] is Dictionary):
		gd[CHAVE_REVELADO] = {}
	var todos: Dictionary = gd[CHAVE_REVELADO]
	var rev = todos.get(chave, null)
	if rev is PackedByteArray and rev.size() == tamanho:
		return rev
	var novo := PackedByteArray()
	novo.resize(tamanho)
	novo.fill(0)
	return novo


func _guardar_revelado(chave: String, rev: PackedByteArray) -> void:
	serialization.game_data[CHAVE_REVELADO][chave] = rev


func _revelar_em_volta(fase: MapLevelData, chave: String, centro: Vector2) -> void:
	var info := _info(fase)
	var w: int = info["w"]
	var h: int = info["h"]
	var andavel: PackedByteArray = info["andavel"]
	var secreto: PackedByteArray = info["secreto"]
	var zona: PackedByteArray = info["zona"]

	# Pixel inicial: onde o Tola está (ou o espaço aberto mais perto)
	var base := Vector2i(centro.floor()) - fase.origem
	var inicio := -1
	for d in [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)]:
		var q: Vector2i = base + d
		if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and andavel[q.y * w + q.x] == 1:
			inicio = q.y * w + q.x
			break
	if inicio < 0:
		return

	var rev := _revelado_da_fase(chave, w * h)
	var mudou := false
	var dentro_secreto := secreto[inicio] == 1

	# 1) "Escorre" pelos espaços abertos, só dentro do raio irregular
	var visto := {}
	var fila: Array[int] = [inicio]
	visto[inicio] = true
	var topo_coluna := {}   # x -> menor y revelado nesta passada
	while not fila.is_empty():
		var i: int = fila.pop_back()
		var x := i % w
		var y := i / w
		if i != inicio and not _no_raio(Vector2i(x, y) + fase.origem, centro):
			continue
		if rev[i] == 0:
			rev[i] = 1
			mudou = true
		if not topo_coluna.has(x) or y < int(topo_coluna[x]):
			topo_coluna[x] = y
		# Não atravessa parede secreta (a não ser que o Tola já esteja dentro dela)
		if secreto[i] == 1 and not dentro_secreto:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n := ny * w + nx
			if visto.has(n) or andavel[n] == 0:
				continue
			visto[n] = true
			fila.append(n)

	# 2) Teto alto: continua subindo pelas colunas enquanto for espaço aberto
	if revelar_teto and altura_maxima_teto > 0:
		for xv in topo_coluna:
			var x: int = int(xv)
			var y: int = int(topo_coluna[x])
			var zona_coluna := zona[y * w + x]
			var subiu := 0
			var ny := y - 1
			while ny >= 0 and subiu < altura_maxima_teto:
				var n := ny * w + x
				if andavel[n] == 0 or secreto[n] == 1 or zona[n] != zona_coluna:
					break
				if rev[n] == 0:
					rev[n] = 1
					mudou = true
				subiu += 1
				ny -= 1

	if mudou:
		_guardar_revelado(chave, rev)


## O pixel (em coordenadas globais do mapa) está dentro do raio irregular?
func _no_raio(gp: Vector2i, centro: Vector2) -> bool:
	var n := maxi(1, tamanho_pixel)
	var b := Vector2i(floori(gp.x / float(n)), floori(gp.y / float(n)))
	var bc := (Vector2(b) + Vector2(0.5, 0.5)) * n
	var d := Vector2((bc.x - centro.x) / raio_horizontal, (bc.y - centro.y) / raio_vertical).length()
	return d <= 1.0 - irregularidade * _sorteio(b)


## Número "aleatório" fixo para cada bloco (sempre o mesmo para a mesma posição)
func _sorteio(b: Vector2i) -> float:
	var hsh := (b.x * 73856093) ^ (b.y * 19349663)
	hsh = (hsh ^ (hsh >> 13)) * 1274126177
	hsh = hsh ^ (hsh >> 16)
	return float(hsh & 0xFFFF) / 65535.0


# ------------------------------------------------------------------
# Consultas
# ------------------------------------------------------------------

func fase_atual() -> MapLevelData:
	if dados == null:
		return null
	var caminho: String = global.current_scene_path
	if caminho.begins_with("uid://"):
		caminho = ResourceUID.uid_to_path(caminho)
	caminho = caminho.to_lower()
	if caminho == _cache_caminho:
		return _cache_fase
	_cache_caminho = caminho
	_cache_fase = null
	for f in dados.fases:
		if f.cena.to_lower() == caminho:
			_cache_fase = f
			break
	return _cache_fase


func tola() -> Node2D:
	var c = global.character
	if c != null and is_instance_valid(c) and c is Node2D:
		return c
	return null


## Posição do jogo -> pixel do mapa
func pixel_do_mundo(pos: Vector2, fase: MapLevelData) -> Vector2:
	return (pos + fase.deslocamento) / float(dados.px_por_pixel)


## Região = primeira palavra do nome da fase ("Tebes 1-2" -> "Tebes")
func regiao(fase: MapLevelData) -> String:
	return fase.nome.get_slice(" ", 0)


## Monta o que está revelado em cada fase e a porcentagem explorada.
## Retorna {"visiveis": {MapLevelData: PackedByteArray}, "porcentagem": int}
func montar() -> Dictionary:
	var visiveis := {}
	var totais := {}
	var vistos_por_fase := {}
	var regioes := {}
	var gd: Dictionary = serialization.game_data
	var salas_todas: Dictionary = gd.get(CHAVE_SALAS, {})
	var rev_todos: Dictionary = gd.get(CHAVE_REVELADO, {})

	for f in dados.fases:
		var chave := f.cena.to_lower()
		var salas: Dictionary = salas_todas.get(chave, {})
		if debug_revelar_tudo or not salas.is_empty():
			regioes[regiao(f)] = true

		var info := _info(f)
		var w: int = info["w"]
		var h: int = info["h"]
		var andavel: PackedByteArray = info["andavel"]
		var zona: PackedByteArray = info["zona"]
		var rev = rev_todos.get(chave, null)
		var tem_rev: bool = rev is PackedByteArray and rev.size() == w * h

		var vis := PackedByteArray()
		vis.resize(w * h)
		vis.fill(0)
		var total := 0
		var vistos := 0
		for i in w * h:
			if andavel[i] == 0:
				continue
			total += 1
			var mostra := false
			if debug_revelar_tudo:
				mostra = true
			elif revelar_sala_inteira:
				var zi := zona[i]
				mostra = zi > 0 and zi <= f.zonas.size() and salas.has(f.zonas[zi - 1])
			else:
				mostra = tem_rev and rev[i] == 1
			if mostra:
				vis[i] = 1
				vistos += 1
		visiveis[f] = vis
		totais[f] = total
		vistos_por_fase[f] = vistos

	# Porcentagem: só conta as regiões que o jogador já alcançou
	var soma_total := 0
	var soma_vistos := 0
	for f in dados.fases:
		if regioes.has(regiao(f)):
			soma_total += int(totais[f])
			soma_vistos += int(vistos_por_fase[f])
	var pct := 0
	if soma_total > 0:
		pct = floori(soma_vistos * 100.0 / soma_total)

	return {"visiveis": visiveis, "porcentagem": pct}


# ------------------------------------------------------------------
# Tela
# ------------------------------------------------------------------

func esta_aberto() -> bool:
	return _aberto


func pode_abrir() -> bool:
	if _aberto or dados == null:
		return false
	if get_tree().paused:
		return false
	if Time.get_ticks_msec() - _fechou_em < ESPERA_REABRIR_MS:
		return false
	return fase_atual() != null


func abrir_tela() -> void:
	if _aberto or dados == null:
		return
	registrar_agora()
	_aberto = true
	_tela.abrir(self)
	get_tree().paused = true   # congela o jogo; o AudioManager abaixa a música sozinho


func fechar_tela() -> void:
	if not _aberto:
		return
	_tela.fechar()
	get_tree().paused = false
	_aberto = false
	_fechou_em = Time.get_ticks_msec()
	var t := tola()
	if t and t.has_method("fechar_mapa_animacao"):
		t.fechar_mapa_animacao()
