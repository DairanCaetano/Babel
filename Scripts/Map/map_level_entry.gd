@tool
class_name MapLevelEntry
extends Resource

## Uma fase que entra no mapa (configuração usada pelo gerador).

## Cena da fase
@export_file("*.tscn") var cena: String = ""
## Nome mostrado no mapa
@export var nome: String = ""
## Posição da fase no "mundo do mapa", em pixels do jogo. Ajuste se duas fases ficarem sobrepostas.
@export var deslocamento: Vector2 = Vector2.ZERO
## Cor da região no mapa
@export var cor: Color = Color8(196, 150, 92)
## Opcional, para fases a céu aberto: nomes (ou começo dos nomes) das camadas de fundo que marcam o que é "interior".
## Vazio = usa a CameraZone inteira.
@export var camadas_interior: PackedStringArray = []
