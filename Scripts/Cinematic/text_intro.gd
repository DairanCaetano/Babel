extends Label

@export var scroll_speed: float = 30.0
@export var reveal_speed: float = 0.02  # Velocidade de revelação das palavras

var is_scrolling: bool = false
var text_offset: float = 0.0
var is_revealing: bool = false
var full_text: String = ""


func _ready() -> void:
	clip_text = true
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	
	# Texto com formatação exata
	full_text = "Os deuses desapareceram dos céus. 
E uma misteriosa torre 
ergueu-se no horizonte.

A torre no crepúsculo, 
sua silhueta pode ser vista 
de todos os cantos, 
atraindo olhares e corações para si.

O mundo se vê privado 
de toda a sua magia. 
Azazel, o anjo do deserto, 
senhor das expiações, 
o único dentre os celestiais 
que parece ter resistido ao expurgo, 
une-se a um enigmático guerreiro 
para desvendar o mistério 
da queda dos céus."
	
	text = full_text
	visible_ratio = 0


func _process(delta: float) -> void:
	if is_scrolling:
		# Calcula a altura do texto visível atual
		var current_text_height = size.y * visible_ratio
		
		# Se o texto ultrapassar a altura da label, começa a rolar
		if current_text_height > size.y:
			text_offset -= scroll_speed * delta
			position.y = text_offset


# Função principal para iniciar - chame isso no AnimationPlayer
func start_scroll() -> void:
	is_scrolling = true
	text_offset = 0
	position.y = 0
	_reveal_text()


# Revela o texto palavra por palavra
func _reveal_text() -> void:
	if is_revealing:
		return
		
	is_revealing = true
	visible_ratio = 0
	
	while visible_ratio < 1:
		visible_ratio += reveal_speed
		
		# Calcula a altura do texto revelado
		var revealed_height = get_minimum_size().y * visible_ratio
		
		# Se ultrapassar a altura da label, ajusta o offset para rolar
		if revealed_height > size.y:
			var excess = revealed_height - size.y
			text_offset = -excess
			position.y = text_offset
		
		await get_tree().physics_frame
	
	is_revealing = false


func stop_scroll() -> void:
	is_scrolling = false
	is_revealing = false


func reset_and_start() -> void:
	text_offset = 0
	position.y = 0
	visible_ratio = 0
	start_scroll()
