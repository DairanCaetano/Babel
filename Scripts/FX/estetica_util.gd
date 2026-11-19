class_name EsteticaUtil
extends RefCounted

## Funções de apoio da estética (WallMask, AplicarMaterial, LuzErrante,
## ParticulasTela) para achar sozinhas as camadas certas de cada fase.
##
## Regras:
##  - PAREDE  = TileMapLayer cujo TileSet tem física  +  tudo dentro de "SecretAreas"
##              + qualquer tilemap no grupo "estetica_parede"
##  - DECORAÇÃO = TileMapLayer sem física (fora de "SecretAreas" e fora de "estetica_parede")
##  - BG (ParallaxBackground) e outras CanvasLayer ficam sempre de fora.

const PASTA_SECRETA: String = "SecretAreas"
## Tilemap neste grupo é SEMPRE decoração (nunca parede), mesmo dentro de
## SecretAreas ou com material próprio (que é substituído pelo noise do fundo).
const GRUPO_DECORACAO: String = "estetica_decoracao"
## Tilemap neste grupo é SEMPRE parede (recebe o efeito de chão/parede), mesmo
## SEM física e sem colisão nenhuma (ex.: raízes da sala do chefe no Tebes_1_4).
const GRUPO_PAREDE: String = "estetica_parede"

## A fase (BaseLevel) que contém este nó.
static func raiz_fase(no: Node) -> Node:
	var atual: Node = no.get_parent()
	while atual != null:
		if atual is BaseLevel:
			return atual
		atual = atual.get_parent()
	# Fallback: a cena mais externa que "possui" este nó.
	var dono: Node = no.owner
	if dono == null:
		return no.get_parent()
	while dono.owner != null:
		dono = dono.owner
	return dono

static func tem_fisica(camada: TileMapLayer) -> bool:
	return camada.tile_set != null and camada.tile_set.get_physics_layers_count() > 0

static func em_area_secreta(no: Node, raiz: Node) -> bool:
	var atual: Node = no
	while atual != null and atual != raiz:
		if atual.name == PASTA_SECRETA:
			return true
		atual = atual.get_parent()
	return false

static func excluido(no: Node, excluir: Array[Node]) -> bool:
	for e in excluir:
		if e != null and is_instance_valid(e) and (e == no or e.is_ancestor_of(no)):
			return true
	return false

## Todos os TileMapLayer da fase (ignora BG/CanvasLayer e viewports internos).
static func listar_tilemaps(raiz: Node) -> Array[TileMapLayer]:
	var saida: Array[TileMapLayer] = []
	_coletar(raiz, saida)
	return saida

static func _coletar(no: Node, saida: Array[TileMapLayer]) -> void:
	if no is TileMapLayer:
		saida.append(no)
	for filho in no.get_children():
		if filho is CanvasLayer or filho is SubViewport:
			continue
		_coletar(filho, saida)

static func tilemaps_de_parede(raiz: Node, excluir: Array[Node] = []) -> Array[TileMapLayer]:
	var saida: Array[TileMapLayer] = []
	for c in listar_tilemaps(raiz):
		if excluido(c, excluir) or c.is_in_group(GRUPO_DECORACAO):
			continue
		if tem_fisica(c) or em_area_secreta(c, raiz) or c.is_in_group(GRUPO_PAREDE):
			saida.append(c)
	return saida

static func tilemaps_de_decoracao(raiz: Node, excluir: Array[Node] = []) -> Array[TileMapLayer]:
	var saida: Array[TileMapLayer] = []
	for c in listar_tilemaps(raiz):
		if excluido(c, excluir) or c.is_in_group(GRUPO_PAREDE):
			continue
		if c.is_in_group(GRUPO_DECORACAO) or (not tem_fisica(c) and not em_area_secreta(c, raiz)):
			saida.append(c)
	return saida

## Tilemap principal = camada de parede (fora de SecretAreas) com mais células pintadas.
static func tilemap_principal(raiz: Node) -> TileMapLayer:
	var melhor: TileMapLayer = null
	var maior: int = -1
	for c in listar_tilemaps(raiz):
		if not tem_fisica(c) or em_area_secreta(c, raiz):
			continue
		var total: int = c.get_used_cells().size()
		if total > maior:
			maior = total
			melhor = c
	return melhor
