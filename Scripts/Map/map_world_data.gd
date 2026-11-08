@tool
class_name MapWorldData
extends Resource

## Mapa completo do jogo, gerado pelo gerador de mapa.

## Quantos pixels do jogo cabem em 1 pixel do mapa (32 = 2x2 tiles)
@export var px_por_pixel: int = 32
## Área total ocupada por todas as fases, em pixels do mapa
@export var limites: Rect2i = Rect2i()
@export var fases: Array[MapLevelData] = []
