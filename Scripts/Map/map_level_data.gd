@tool
class_name MapLevelData
extends Resource

## Dados gerados de UMA fase. Não edite à mão: rode o gerador de novo.

@export var cena: String = ""
@export var nome: String = ""
@export var cor: Color = Color.WHITE
## Canto superior esquerdo da imagem, em pixels do mapa
@export var origem: Vector2i = Vector2i.ZERO
## Deslocamento da fase no mundo do mapa (pixels do jogo)
@export var deslocamento: Vector2 = Vector2.ZERO
## R = número da zona (1, 2, 3...), G = 255 se for tile secreto, A = 255 se tiver chão andável
@export var mascara: Image
## Nome de cada zona (índice 0 = zona 1 na máscara)
@export var zonas: PackedStringArray = []
## Posição dos save points, em pixels do mapa
@export var saves: PackedVector2Array = []
## Itens: [{"nome": String, "pos": Vector2}]
@export var itens: Array = []
