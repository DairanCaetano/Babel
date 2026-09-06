extends CanvasLayer

const TOTAL_LIFE_FRAMES = 5  # Total de frames para representar a vida
var life_sprite: Sprite2D

func _ready():
	# Cria um único sprite para representar a vida
	life_sprite = Sprite2D.new()
	life_sprite.texture = $life.texture
	life_sprite.hframes = TOTAL_LIFE_FRAMES  # Define o número total de quadros de vida
	life_sprite.position = Vector2(0, 0)  # Ajusta a posição se necessário
	$life.add_child(life_sprite)

func _process(delta):
	$frag_number.text = str(player_data.frag)
	display_life()

func display_life():
	# Atualiza o frame do sprite de vida com base na quantidade de vida restante do jogador
	var current_life = int(player_data.life)
	life_sprite.frame = TOTAL_LIFE_FRAMES - current_life
