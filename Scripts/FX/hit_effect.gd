extends BaseEffect
class_name RotatingEffect

# Variável estática compartilhada entre todas as instâncias
static var last_angle: int = -1

func _ready():
	_apply_random_rotation()
	super._ready()  # Chama o _ready do BaseEffect para dar play()

func _apply_random_rotation() -> void:
	var new_angle: int
	var attempts = 0
	
	# Garante que escolhe um ângulo diferente (com limite de tentativas por segurança)
	while attempts < 10:
		new_angle = (randi() % 4) * 90
		if new_angle != last_angle:
			break
		attempts += 1
	
	# Atualiza o último ângulo usado
	last_angle = new_angle
	rotation_degrees = new_angle
