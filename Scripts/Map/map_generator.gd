@tool
extends Node

## GERADOR DO MAPA. Use só no editor:
## 1) Clique em "Carregar fases padrão" (só na primeira vez)
## 2) Clique em "Gerar mapa"
## Resultado: res://Mapa/map_data.res (lido pelo jogo) e res://Mapa/previa_mapa.png (para conferir)
##
## Tiles secretos (camadas dentro de SecretAreas) entram na CameraZone que os contém
## (ou na mais próxima). Assim aparecem quando o Tola visita aquela sala; salas escondidas
## com CameraZone própria só aparecem quando ele entra nelas.

const PASTA := "res://Mapa"
const ARQUIVO_DADOS := "res://Mapa/map_data.res"
const ARQUIVO_PREVIA := "res://Mapa/previa_mapa.png"
const TILE := 16

const COR_FUNDO := Color8(18, 16, 22)
const COR_SECRETO := Color8(220, 90, 170)
const COR_SAVE := Color8(90, 210, 120)
const COR_ITEM := Color8(255, 150, 40)

@export_tool_button("Carregar fases padrão", "Load") var _btn_padrao: Callable = carregar_padrao
@export_tool_button("Gerar mapa", "Play") var _btn_gerar: Callable = gerar

@export var fases: Array[MapLevelEntry] = []
## Pixels do jogo por pixel do mapa (32 = 2x2 tiles, igual à prévia aprovada)
@export_range(8, 64, 8) var px_por_pixel: int = 32
## Camadas que são parede/chão sólido (nome ou começo do nome)
@export var camadas_solidas: PackedStringArray = ["Chão", "Chao"]
## Ampliação da imagem de prévia
@export_range(1, 8) var escala_previa: int = 3


func carregar_padrao() -> void:
	var tebes := Color8(196, 150, 92)
	var egito := Color8(120, 160, 190)
	var santuario := Color8(110, 170, 120)
	var lista := [
		["res://Scenes/Fases/Tebes/tebes_1_1.tscn", "Tebes 1-1", Vector2(0, 0), tebes],
		["res://Scenes/Fases/Tebes/tebes_1_2.tscn", "Tebes 1-2", Vector2(7344, 453), tebes],
		["res://Scenes/Fases/Tebes/tebes_1_3.tscn", "Tebes 1-3", Vector2(8606, 194), tebes],
		["res://Scenes/Fases/Tebes/tebes_1_4.tscn", "Tebes 1-4", Vector2(9111, -680), tebes],
		["res://Scenes/Fases/Egito/Egito_1_1.tscn", "Egito 1-1", Vector2(11570, -1628), egito],
		["res://Scenes/Fases/Egito/Egito_1_2.tscn", "Egito 1-2", Vector2(11564, -3075), egito],
		["res://Scenes/Fases/Santuario/santuario_1_1.tscn", "Santuário 1-1", Vector2(11236, -1982), santuario],  # à esquerda do Egito 1-2 (ajustar quando as salas crescerem)
		["res://Scenes/Fases/Santuario/santuario_1_2.tscn", "Santuário 1-2", Vector2(10756, -1982), santuario],  # à esquerda do Egito 1-2 (ajustar quando as salas crescerem)
		["res://Scenes/Fases/Santuario/santuario_1_3.tscn", "Santuário 1-3", Vector2(10276, -1982), santuario],  # à esquerda do Egito 1-2 (ajustar quando as salas crescerem)
	]
	var novas: Array[MapLevelEntry] = []
	for d in lista:
		var e := MapLevelEntry.new()
		e.cena = d[0]
		e.nome = d[1]
		e.deslocamento = d[2]
		e.cor = d[3]
		novas.append(e)
	fases = novas
	notify_property_list_changed()
	print("[Mapa] ", fases.size(), " fases carregadas. Agora clique em 'Gerar mapa'.")


func gerar() -> void:
	if not Engine.is_editor_hint():
		return
	if fases.is_empty():
		push_warning("[Mapa] Lista de fases vazia. Clique em 'Carregar fases padrão' primeiro.")
		return

	DirAccess.make_dir_recursive_absolute(PASTA)

	var mundo := MapWorldData.new()
	mundo.px_por_pixel = px_por_pixel
	var lista_dados: Array[MapLevelData] = []
	var limites := Rect2i()
	var primeiro := true

	for entrada in fases:
		if entrada == null or entrada.cena.is_empty():
			continue
		var dados := _processar_fase(entrada)
		if dados == null:
			continue
		lista_dados.append(dados)
		var r := Rect2i(dados.origem, dados.mascara.get_size())
		limites = r if primeiro else limites.merge(r)
		primeiro = false

	if lista_dados.is_empty():
		push_error("[Mapa] Nenhuma fase gerou dados.")
		return

	mundo.fases = lista_dados
	mundo.limites = limites

	var err := ResourceSaver.save(mundo, ARQUIVO_DADOS)
	if err != OK:
		push_error("[Mapa] Erro ao salvar " + ARQUIVO_DADOS + " (código " + str(err) + ")")
		return

	_salvar_previa(mundo)

	var editor := Engine.get_singleton(&"EditorInterface")
	if editor:
		editor.get_resource_filesystem().scan()

	print("[Mapa] Pronto! Dados em ", ARQUIVO_DADOS, " | prévia em ", ARQUIVO_PREVIA)


# ------------------------------------------------------------------
# Uma fase
# ------------------------------------------------------------------

func _processar_fase(entrada: MapLevelEntry) -> MapLevelData:
	var caminho := entrada.cena
	if caminho.begins_with("uid://"):
		caminho = ResourceUID.uid_to_path(caminho)

	var pacote := load(caminho) as PackedScene
	if pacote == null:
		push_error("[Mapa] Não consegui abrir a cena: " + caminho)
		return null

	var raiz := pacote.instantiate()
	var off := entrada.deslocamento

	# 1) Retângulos das CameraZones
	var nomes := PackedStringArray()
	var retangulos: Array[Rect2] = []
	var no_zonas := raiz.get_node_or_null("CameraZones")
	if no_zonas:
		for z in no_zonas.get_children():
			var col := z.get_node_or_null("Collision") as CollisionShape2D
			if col == null or not (col.shape is RectangleShape2D):
				continue
			var tam: Vector2 = (col.shape as RectangleShape2D).size
			var r: Rect2 = _para_raiz(col, raiz) * Rect2(-tam / 2.0, tam)
			nomes.append(String(z.name))
			retangulos.append(r)

	if retangulos.is_empty():
		push_warning("[Mapa] " + caminho + " não tem CameraZones válidas. Pulando.")
		raiz.free()
		return null
	if retangulos.size() > 255:
		push_warning("[Mapa] " + caminho + " tem mais de 255 zonas; as extras serão ignoradas.")

	# 2) Tiles sólidos, de interior (opcional) e secretos
	var terreno := raiz.get_node_or_null("Terrain")
	var solidos := _celulas(terreno, camadas_solidas, raiz)
	var usa_interior := not entrada.camadas_interior.is_empty()
	var interior := _celulas(terreno, entrada.camadas_interior, raiz) if usa_interior else {}
	var secretos := _celulas(raiz.get_node_or_null("SecretAreas"), PackedStringArray(), raiz)

	# 3) Pixels andáveis: dentro da zona e sem tile sólido
	var pixels := {}
	var secreto := {}
	for i in mini(retangulos.size(), 255):
		var r := retangulos[i]
		for ty in range(floori(r.position.y / TILE), ceili(r.end.y / TILE)):
			for tx in range(floori(r.position.x / TILE), ceili(r.end.x / TILE)):
				var k := Vector2i(tx, ty)
				var centro := Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)
				if not r.has_point(centro):
					continue
				if solidos.has(k):
					continue
				if usa_interior and not interior.has(k):
					continue
				var px := _pixel(centro, off)
				if not pixels.has(px):
					pixels[px] = i + 1

	# 4) Tiles secretos: entram na zona que os contém (ou na mais próxima)
	for k in secretos:
		var centro := Vector2(k.x * TILE + TILE * 0.5, k.y * TILE + TILE * 0.5)
		var px := _pixel(centro, off)
		pixels[px] = mini(_zona_mais_proxima(centro, retangulos), 254) + 1
		secreto[px] = true

	if pixels.is_empty():
		push_warning("[Mapa] " + caminho + " não gerou nenhum pixel.")
		raiz.free()
		return null

	# 5) Monta a imagem-máscara
	var minp := Vector2i(1 << 30, 1 << 30)
	var maxp := Vector2i(-(1 << 30), -(1 << 30))
	for p in pixels:
		minp = minp.min(p)
		maxp = maxp.max(p)
	var tamanho := maxp - minp + Vector2i.ONE

	var img := Image.create_empty(tamanho.x, tamanho.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in pixels:
		var g := 255 if secreto.has(p) else 0
		img.set_pixelv(p - minp, Color8(int(pixels[p]), g, 0, 255))

	# 6) Save points e itens
	var saves := PackedVector2Array()
	var no_save := raiz.get_node_or_null("SaveArea")
	if no_save:
		for s in no_save.get_children():
			if s is Node2D:
				saves.append(_pixel_f(_para_raiz(s, raiz).origin, off))

	var itens := []
	var no_itens := raiz.get_node_or_null("Collectables")
	if no_itens:
		for it in no_itens.get_children():
			if it is Node2D:
				itens.append({"nome": String(it.name), "pos": _pixel_f(_para_raiz(it, raiz).origin, off)})

	var dados := MapLevelData.new()
	dados.cena = caminho
	dados.nome = entrada.nome
	dados.cor = entrada.cor
	dados.origem = minp
	dados.deslocamento = off
	dados.mascara = img
	dados.zonas = nomes
	dados.saves = saves
	dados.itens = itens

	print("[Mapa] ", entrada.nome, ": ", nomes.size(), " zonas, ", pixels.size(), " pixels, ", saves.size(), " saves, ", itens.size(), " itens")
	raiz.free()
	return dados


# ------------------------------------------------------------------
# Auxiliares
# ------------------------------------------------------------------

## Junta as células de todas as TileMapLayers sob "base" cujo nome começa com um dos prefixos.
## Prefixos vazios = todas as camadas. Chave = tile (16px) em coordenadas da fase.
func _celulas(base: Node, prefixos: PackedStringArray, raiz: Node) -> Dictionary:
	var res := {}
	if base == null:
		return res
	for camada in base.find_children("*", "TileMapLayer", true, false):
		var tml := camada as TileMapLayer
		if not prefixos.is_empty() and not _comeca_com(String(tml.name), prefixos):
			continue
		var xf := _para_raiz(tml, raiz)
		for c in tml.get_used_cells():
			var p: Vector2 = xf * tml.map_to_local(c)
			res[Vector2i(floori(p.x / TILE), floori(p.y / TILE))] = true
	return res


func _comeca_com(nome: String, prefixos: PackedStringArray) -> bool:
	for p in prefixos:
		if nome.begins_with(p):
			return true
	return false


## Transformação do nó até a raiz da fase, incluindo a posição da própria raiz
## (funciona sem a cena estar rodando)
func _para_raiz(no: Node, raiz: Node) -> Transform2D:
	var t := Transform2D.IDENTITY
	var n := no
	while n != null and n != raiz:
		if n is Node2D:
			t = (n as Node2D).transform * t
		n = n.get_parent()
	if raiz is Node2D:
		t = (raiz as Node2D).transform * t
	return t


func _pixel(p: Vector2, off: Vector2) -> Vector2i:
	var g := p + off
	return Vector2i(floori(g.x / px_por_pixel), floori(g.y / px_por_pixel))


func _pixel_f(p: Vector2, off: Vector2) -> Vector2:
	return (p + off) / float(px_por_pixel)


func _zona_mais_proxima(p: Vector2, rets: Array[Rect2]) -> int:
	var melhor := 0
	var menor := INF
	for i in rets.size():
		var d := p.distance_to(p.clamp(rets[i].position, rets[i].end))
		if d < menor:
			menor = d
			melhor = i
	return melhor


# ------------------------------------------------------------------
# Prévia (só para conferir; o jogo não usa esta imagem)
# Na prévia os tiles secretos aparecem em rosa; no jogo terão a cor normal da região.
# ------------------------------------------------------------------

func _salvar_previa(mundo: MapWorldData) -> void:
	var L := mundo.limites.grow(2)
	var img := Image.create_empty(L.size.x, L.size.y, false, Image.FORMAT_RGBA8)
	img.fill(COR_FUNDO)

	for f in mundo.fases:
		var m := f.mascara
		for y in m.get_height():
			for x in m.get_width():
				var c := m.get_pixel(x, y)
				if c.a == 0.0:
					continue
				var cor := f.cor
				if c.g > 0.5:
					cor = COR_SECRETO
				elif _e_borda(m, x, y):
					cor = cor.lightened(0.3)
				img.set_pixelv(f.origem + Vector2i(x, y) - L.position, cor)

	var e := escala_previa
	img.resize(L.size.x * e, L.size.y * e, Image.INTERPOLATE_NEAREST)

	for f in mundo.fases:
		for s in f.saves:
			_marcador(img, s, L.position, e, COR_SAVE)
		for it in f.itens:
			_marcador(img, it["pos"], L.position, e, COR_ITEM)

	var err := img.save_png(ARQUIVO_PREVIA)
	if err != OK:
		push_warning("[Mapa] Não consegui salvar a prévia (código " + str(err) + ")")


func _e_borda(m: Image, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= m.get_width() or ny >= m.get_height():
			return true
		if m.get_pixel(nx, ny).a == 0.0:
			return true
	return false


func _marcador(img: Image, pos: Vector2, origem: Vector2i, e: int, cor: Color) -> void:
	var c := Vector2i((pos - Vector2(origem)) * e)
	img.fill_rect(Rect2i(c - Vector2i(3, 3), Vector2i(7, 7)), Color.BLACK)
	img.fill_rect(Rect2i(c - Vector2i(2, 2), Vector2i(5, 5)), cor)
