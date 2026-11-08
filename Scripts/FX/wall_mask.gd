extends Node
class_name WallMask

## Estética estilo Animal Well para as paredes.
##
## Monta, a cada frame, uma "máscara" (SubViewport) com TODAS as camadas de
## parede listadas em "camadas" — inclusive paredes falsas e quebráveis.
## O shader wall_light lê essa máscara para acender as bordas e escurecer o
## miolo. Como a máscara é a união das camadas, a emenda entre parede real e
## parede secreta fica invisível.
##
## Cada camada ganha um "espelho" leve dentro da máscara (sem colisão e sem
## material) que acompanha sozinho: fade (modulate), enabled, visible,
## células alteradas e queue_free. Os scripts das paredes secretas não
## precisam de nenhuma mudança.

## Camadas de parede que recebem o efeito e entram na máscara.
@export var camadas: Array[TileMapLayer] = []
## Material com o shader wall_light (um por região: Tebes, Egito...).
@export var material_parede: ShaderMaterial
## Folga (px) da máscara além da tela. Deve ser maior que inner_depth + inner_jitter.
@export var margem: int = 16
## Desliga o efeito sem tirar o nó da cena.
@export var ativo: bool = true

@export_category("Detecção automática")
## Liga: entram sozinhas todas as camadas COM física + tudo dentro de SecretAreas
## (somadas às que estiverem em "camadas").
@export var deteccao_automatica: bool = false
## Camadas (ou pastas) que nunca entram, mesmo com a detecção automática.
@export var excluir: Array[Node] = []

var _viewport: SubViewport = null
var _espelhos: Dictionary = {} # TileMapLayer original -> TileMapLayer espelho

func _ready() -> void:
	if not ativo:
		return
	if material_parede == null:
		push_warning("⚠️ WallMask: configure o material_parede no Inspector!")
		return
	
	_viewport = SubViewport.new()
	_viewport.name = "MascaraParedes"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.size = _tamanho_mascara()
	add_child(_viewport)
	
	var lista: Array[TileMapLayer] = camadas.duplicate()
	if deteccao_automatica:
		for camada in EsteticaUtil.tilemaps_de_parede(EsteticaUtil.raiz_fase(self), excluir):
			# Tilemap com material próprio (ex.: piscar de objeto interativo) não é parede.
			if camada.material != null and camada.material != material_parede:
				print("  ↪️ WallMask: ", camada.name, " tem material próprio — fica fora das paredes")
				continue
			if not lista.has(camada):
				lista.append(camada)
	for camada in lista:
		registrar_camada(camada)
	
	material_parede.set_shader_parameter("wall_mask", _viewport.get_texture())
	material_parede.set_shader_parameter("mask_size", Vector2(_viewport.size))
	
	# Sincroniza logo antes de desenhar: a câmera (e o shake) já se moveram
	# neste frame, então a máscara nunca fica 1 frame atrasada.
	RenderingServer.frame_pre_draw.connect(_sincronizar)
	_sincronizar()
	material_parede.set_shader_parameter("mask_ready", true)
	print("✅ WallMask: ", _espelhos.size(), " camada(s) de parede na máscara")

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sincronizar):
		RenderingServer.frame_pre_draw.disconnect(_sincronizar)
	# O material é um recurso compartilhado: desliga para a próxima fase
	# não ler a textura de uma máscara que já não existe.
	if material_parede:
		material_parede.set_shader_parameter("mask_ready", false)

## Adiciona uma camada ao efeito em tempo de execução (ex.: parede criada por script).
func registrar_camada(camada: TileMapLayer) -> void:
	if camada == null or not is_instance_valid(camada) or _espelhos.has(camada):
		return
	if _viewport == null:
		return
	
	camada.material = material_parede
	
	var espelho := TileMapLayer.new()
	espelho.name = "Espelho_" + camada.name
	espelho.collision_enabled = false
	espelho.navigation_enabled = false
	_viewport.add_child(espelho)
	_espelhos[camada] = espelho
	_copiar_celulas(camada)
	
	camada.changed.connect(_copiar_celulas.bind(camada))
	camada.tree_exiting.connect(_remover_camada.bind(camada))

func _copiar_celulas(camada: TileMapLayer) -> void:
	if not _espelhos.has(camada) or not is_instance_valid(camada):
		return
	var espelho: TileMapLayer = _espelhos[camada]
	espelho.tile_set = camada.tile_set
	espelho.tile_map_data = camada.tile_map_data

func _remover_camada(camada: TileMapLayer) -> void:
	if not _espelhos.has(camada):
		return
	var espelho: TileMapLayer = _espelhos[camada]
	_espelhos.erase(camada)
	if is_instance_valid(espelho):
		espelho.queue_free()

func _sincronizar() -> void:
	if _viewport == null or not is_instance_valid(_viewport):
		return
	
	# Mesma câmera da tela, deslocada pela margem.
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var deslocamento := ct.origin + Vector2(margem, margem)
	_viewport.canvas_transform = Transform2D(ct.x, ct.y, deslocamento)
	material_parede.set_shader_parameter("mask_offset", deslocamento)
	material_parede.set_shader_parameter("mask_scale", ct.x.x)
	
	for camada in _espelhos.keys():
		if not is_instance_valid(camada):
			_remover_camada(camada)
			continue
		var espelho: TileMapLayer = _espelhos[camada]
		espelho.global_transform = camada.global_transform
		espelho.visible = camada.enabled and camada.is_visible_in_tree()
		espelho.modulate = Color(1.0, 1.0, 1.0, camada.modulate.a * camada.self_modulate.a)

func _tamanho_mascara() -> Vector2i:
	var tela: Vector2 = get_viewport().get_visible_rect().size
	return Vector2i(int(tela.x) + margem * 2, int(tela.y) + margem * 2)
