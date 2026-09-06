extends Area2D
class_name ProjectileGroundRoots

@export_category("Variables")
@export var attack_damage: int = 10  # Dano que o ataque especial causa

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _attack_start_audio: AudioStreamPlayer
@export var attack_audio: AudioStreamPlayer

var damaged_bodies: Array = []  # Lista de corpos que já sofreram dano

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Conecta os sinais da animação
	_texture.animation_finished.connect(_on_texture_animation_finished)
	_texture.frame_changed.connect(_on_texture_frame_changed)
	
	# Conecta o sinal de colisão
	body_entered.connect(_on_body_entered)
	
	# Inicia a animação Idle
	_play_animation("Idle")
	
	# ✅ NOVO: Toca o som de início do ataque
	if _attack_start_audio:
		_attack_start_audio.play()

func _process(delta: float) -> void:
	pass

func _play_animation(animation_name: String):
	if _texture.sprite_frames and _texture.sprite_frames.has_animation(animation_name):
		_texture.play(animation_name)

func _on_texture_animation_finished() -> void:
	# Se a animação que terminou foi a Idle, destrói o projétil
	if _texture.animation == "Idle":
		queue_free()

func _on_texture_frame_changed() -> void:
	# ✅ NOVO: Toca o som de ataque no frame 3 da animação Idle
	if _texture.animation == "Idle" and _texture.frame == 3:
		if attack_audio:
			attack_audio.play()

func _on_body_entered(body) -> void:
	if body is BaseCharacter:
		# Verifica se já causou dano neste corpo (evita dano múltiplo)
		if body in damaged_bodies:
			return
		
		# Aplica dano ao jogador
		body.update_health(attack_damage, self)
		damaged_bodies.append(body)
