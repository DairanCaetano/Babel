extends GPUParticles2D
class_name ParticulasTela

## Partículas de ambiente (poeira/brilho no ar) estilo Animal Well.
## O emissor acompanha o CENTRO DA TELA, então as partículas cobrem a fase
## inteira. As que já nasceram ficam no mundo (não "grudam" na câmera).
## As cores podem vir sozinhas do tilemap principal da fase (as mais claras
## do tileset), ou do "Color Initial Ramp" do Process Material.

## Folga (px) além da tela onde as partículas também podem nascer.
@export var margem: Vector2 = Vector2(32, 32)

@export_category("Cores")
## Tilemap principal da fase. As partículas usam as cores mais claras do tileset dele.
## Vazio = acha sozinho (a camada com física que tem mais tiles pintados).
@export var tilemap_cores: TileMapLayer
## Desligado = usa as cores manuais do "Color Initial Ramp" do Process Material.
@export var cores_automaticas: bool = true
## Quantas cores (as mais claras) usar.
@export_range(1, 8) var quantidade_cores: int = 3

func _ready() -> void:
	local_coords = false
	# Cópia própria do material: ajustes em tempo de jogo não vazam para outras fases.
	if process_material:
		process_material = process_material.duplicate()
	_ajustar_area()
	if cores_automaticas:
		_aplicar_cores_do_tilemap()
	RenderingServer.frame_pre_draw.connect(_atualizar)
	_atualizar()
	restart()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_atualizar):
		RenderingServer.frame_pre_draw.disconnect(_atualizar)

func _atualizar() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var centro: Vector2 = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
	global_position = centro.round()

func _ajustar_area() -> void:
	var meia_tela: Vector2 = get_viewport().get_visible_rect().size * 0.5 + margem
	var mat := process_material as ParticleProcessMaterial
	if mat:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(meia_tela.x, meia_tela.y, 1.0)
	# Área de desenho bem maior que a tela, para partículas não sumirem nas bordas.
	visibility_rect = Rect2(-meia_tela * 2.0, meia_tela * 4.0)

# ===== CORES AUTOMÁTICAS =====

func _aplicar_cores_do_tilemap() -> void:
	var mat := process_material as ParticleProcessMaterial
	if mat == null:
		return
	if tilemap_cores == null:
		tilemap_cores = EsteticaUtil.tilemap_principal(EsteticaUtil.raiz_fase(self))
	if tilemap_cores == null or tilemap_cores.tile_set == null:
		push_warning("⚠️ ParticulasTela: não achei o tilemap principal — usando as cores manuais do material.")
		return
	var imagem: Image = _imagem_do_tileset(tilemap_cores.tile_set)
	if imagem == null:
		push_warning("⚠️ ParticulasTela: não achei a textura do tileset — usando as cores manuais.")
		return
	
	# Conta quantas vezes cada cor aparece (pula pixels transparentes).
	# Em tilesets grandes, lê pixels pulados para não travar o carregamento.
	var contagem: Dictionary = {}
	var largura: int = imagem.get_width()
	var altura: int = imagem.get_height()
	var passo: int = maxi(1, int(sqrt(float(largura * altura) / 150000.0)))
	for y in range(0, altura, passo):
		for x in range(0, largura, passo):
			var c: Color = imagem.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var chave: int = c.to_rgba32()
			contagem[chave] = contagem.get(chave, 0) + 1
	if contagem.is_empty():
		return
	
	# Ordena da mais clara para a mais escura e pega as primeiras.
	var cores: Array = contagem.keys()
	cores.sort_custom(func(a: int, b: int) -> bool:
		return Color.hex(a).get_luminance() > Color.hex(b).get_luminance())
	cores = cores.slice(0, quantidade_cores)
	
	# Cada cor ganha uma fatia proporcional ao quanto aparece no tileset.
	var total: float = 0.0
	for chave in cores:
		total += float(contagem[chave])
	var offsets := PackedFloat32Array()
	var lista_cores := PackedColorArray()
	var acumulado: float = 0.0
	for chave in cores:
		offsets.append(acumulado)
		var cor := Color.hex(chave)
		cor.a = 1.0
		lista_cores.append(cor)
		acumulado += float(contagem[chave]) / total
	
	var gradiente := Gradient.new()
	gradiente.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradiente.offsets = offsets
	gradiente.colors = lista_cores
	var rampa := GradientTexture1D.new()
	rampa.gradient = gradiente
	mat.color_initial_ramp = rampa
	
	var nomes: PackedStringArray = []
	for cor in lista_cores:
		nomes.append("#" + cor.to_html(false))
	print("✨ ParticulasTela: cores de ", tilemap_cores.name, " → ", ", ".join(nomes))

func _imagem_do_tileset(tile_set: TileSet) -> Image:
	for i in range(tile_set.get_source_count()):
		var fonte := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if fonte and fonte.texture:
			var imagem: Image = fonte.texture.get_image()
			if imagem == null:
				continue
			if imagem.is_compressed():
				imagem.decompress()
			return imagem
	return null
