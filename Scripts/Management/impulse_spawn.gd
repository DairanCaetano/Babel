extends Marker2D
class_name ImpulseSpawn

## Spawn que impulsiona o player ao aparecer

@export var impulse_direction: Vector2 = Vector2(0, -1)  ## Direção (0, -1 = cima)
@export var impulse_force: float = 800.0  ## Força do impulso

func apply_impulse(character: BaseCharacter) -> void:
	"""Aplica impulso no personagem"""
	
	if not character:
		return
	
	print("🚀 Aplicando impulso!")
	print("  Direção: ", impulse_direction)
	print("  Força: ", impulse_force)
	
	# Aplicar velocidade
	var direction = impulse_direction.normalized()
	character.velocity = direction * impulse_force
	
	# Forçar animação de pulo
	if character.has_node("Texture"):
		var texture = character.get_node("Texture")
		texture.play("Jump")
	
	print("  ✅ Impulso aplicado!")
