extends Node
class_name AplicarMaterial

## Aplica um material em camadas da fase, sem precisar editar as cenas originais.
## Dois modos:
##  - "tilemaps_sem_fisica" LIGADO: aplica em todos os tilemaps de decoração da
##    fase (sem física e fora de SecretAreas). BG nunca entra.
##  - DESLIGADO: aplica em tudo que é desenhado dentro de "alvo".
## Funciona só com o jogo rodando.

## Material a aplicar. Ex.: Shaders/decor_noise_tebes.tres
@export var material_alvo: Material
## Desliga sem tirar o nó da cena.
@export var ativo: bool = true

@export_category("Modo automático")
## Aplica sozinho em todos os tilemaps SEM física da fase (decoração).
@export var tilemaps_sem_fisica: bool = false
## Camadas (ou pastas) que nunca recebem o material.
@export var excluir: Array[Node] = []
## Tilemaps que recebem o material mesmo fora da regra (ex.: dentro de SecretAreas
## ou com material próprio, que é SUBSTITUÍDO).
@export var incluir: Array[Node] = []

@export_category("Modo manual")
## Nó cujos filhos (e netos) recebem o material (usado com o modo automático desligado).
@export var alvo: Node

func _ready() -> void:
	if not ativo:
		return
	if material_alvo == null:
		push_warning("⚠️ AplicarMaterial: configure o material_alvo no Inspector!")
		return
	if tilemaps_sem_fisica:
		var total: int = 0
		for camada in EsteticaUtil.tilemaps_de_decoracao(EsteticaUtil.raiz_fase(self), excluir):
			if camada.material != null and camada.material != material_alvo and not camada.is_in_group(EsteticaUtil.GRUPO_DECORACAO):
				push_warning("⚠️ AplicarMaterial: " + camada.name + " já tem material próprio — mantido.")
				continue
			camada.material = material_alvo
			total += 1
		# Sprites (e outros itens) marcados como decoração, ex.: cabeça do boi.
		var raiz: Node = EsteticaUtil.raiz_fase(self)
		for no in get_tree().get_nodes_in_group(EsteticaUtil.GRUPO_DECORACAO):
			if no is CanvasItem and not no is TileMapLayer and raiz.is_ancestor_of(no):
				(no as CanvasItem).material = material_alvo
				total += 1
		for no in incluir:
			if no is TileMapLayer and is_instance_valid(no):
				(no as TileMapLayer).material = material_alvo
				total += 1
		print("✅ AplicarMaterial: noise de decoração em ", total, " tilemap(s)")
		return
	if alvo == null:
		push_warning("⚠️ AplicarMaterial: configure o alvo no Inspector!")
		return
	var total_manual: int = _aplicar(alvo)
	print("✅ AplicarMaterial: material aplicado em ", total_manual, " item(ns) de ", alvo.name)

func _aplicar(no: Node) -> int:
	var total: int = 0
	if no is TextureRect or no is Sprite2D or no is AnimatedSprite2D or no is TileMapLayer or no is Polygon2D:
		(no as CanvasItem).material = material_alvo
		total += 1
	for filho in no.get_children():
		total += _aplicar(filho)
	return total
