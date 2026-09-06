class_name Trail
extends Line2D

@export var point_length = 30
@export var y_offset_start: float = -20 # Deslocamento inicial no eixo Y
var point_velocity = Vector2()

# Variáveis para o movimento sutil
var amplitude: float = 3.0 # altura do movimento
var frequency: float = 6.0 # velocidade da oscilação
var time_passed: float = 0.0

func _process(delta):
	# Obtém a posição global do player
	point_velocity = get_parent().global_position
	
	# Converte a posição global do player para o espaço local do Trail e adiciona o deslocamento Y
	var local_point_velocity = to_local(point_velocity) + Vector2(0, y_offset_start)
	
	# Adiciona o ponto convertido à posição atual do Trail
	add_point(local_point_velocity)
	
	# Remove os pontos extras para manter o tamanho da trilha
	while get_point_count() > point_length:
		remove_point(0)
	
	# Incrementa o tempo para controlar a oscilação
	time_passed += delta
	
	# Aplica um movimento sutil para cima e para baixo no último ponto da trilha
	if get_point_count() > 0:
		var end_point_index = get_point_count() - 1
		var end_point = get_point_position(end_point_index)
		
		# Aplica a oscilação ao ponto final
		var y_offset = amplitude * sin(frequency * time_passed)
		set_point_position(end_point_index, end_point + Vector2(0, y_offset))
