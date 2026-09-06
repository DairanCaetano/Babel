extends EnemyTexture
class_name ZumbiArqueiroTexture

# Sinais específicos para o ZumbiArqueiro
signal attack_anticipation_finished
signal attack_finished
signal projectile_spawn_frame

@export var projectile_spawn_frame_number: int = 1

# Sobrescreve o método do EnemyTexture para adicionar lógica específica
func _on_animation_finished() -> void:
	var current_anim = animation
	
	# Emite sinais específicos para melhor controle
	match current_anim:
		"Attack_Anticipation":
			attack_anticipation_finished.emit()
			action_animate("Attack")
			return
		"Attack":
			attack_finished.emit()
	
	# Chama a lógica original do EnemyTexture
	super()

# Sobrescreve para adicionar detecção do frame de disparo
func _on_frame_changed() -> void:
	var current_anim = animation
	var current_frame = frame
	
	# Detecta o frame específico para disparar projétil
	if current_anim == "Attack" and current_frame == projectile_spawn_frame_number:
		projectile_spawn_frame.emit()
	
	# Chama a lógica original do EnemyTexture
	super()
