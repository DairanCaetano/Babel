extends ProjectileComponent
class_name ProjectileBerith1

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var timer: Timer
@export var flame_hit_audio: AudioStreamPlayer

@export_category("Variables")
@export var attack_damage: int = 10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Configura a direção para mover no eixo X negativo
	direction = Vector2.LEFT
	
	# Inicia a animação "Active"
	if texture:
		texture.play("Active")
	
	# Conecta o sinal do timer
	if timer:
		timer.timeout.connect(_on_timer_timeout)
		timer.start()

func _on_timer_timeout() -> void:
	# Destrói o projetil quando o timer acabar
	queue_free()

func _on_body_entered(_body: Node2D) -> void:
	# Aplica dano no personagem quando colidir
	if _body is BaseCharacter:
		_body.update_health(attack_damage, get_parent())
		
		# Desabilitar colisão e esconder sprite
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		
		if texture:
			texture.visible = false
		
		direction = Vector2.ZERO
		
		# Tocar som e aguardar terminar
		if flame_hit_audio:
			flame_hit_audio.play()
			await flame_hit_audio.finished
		
		queue_free()
