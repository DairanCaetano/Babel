extends ProjectileComponent
class_name ProjectileBerith2

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var attack_anticipation_audio: AudioStreamPlayer
@export var attack_audio: AudioStreamPlayer

@export_category("Variables")
@export var attack_damage: int = 10

var _attack_audio_played: bool = false  # Flag para tocar som apenas uma vez

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Desabilita a colisão inicialmente
	if collision:
		collision.disabled = true
	
	# Tocar som de antecipação imediatamente ao ser instanciado
	if attack_anticipation_audio:
		attack_anticipation_audio.play()
	
	# Inicia a animação "Active" automaticamente
	if texture:
		texture.play("Active")
		
		# Conecta os sinais
		if not texture.frame_changed.is_connected(_on_texture_frame_changed):
			texture.frame_changed.connect(_on_texture_frame_changed)
		if not texture.animation_finished.is_connected(_on_texture_animation_finished):
			texture.animation_finished.connect(_on_texture_animation_finished)

func _on_texture_animation_finished() -> void:
	if texture.animation == "Active":
		queue_free()

func _on_texture_frame_changed() -> void:
	if texture.animation == "Active":
		var current_frame = texture.frame
		
		if collision:
			# Habilita a colisão dos frames 6 a 11
			if current_frame >= 6 and current_frame <= 11:
				collision.disabled = false
				
				# Tocar som de ataque apenas uma vez quando habilitar a colisão
				if not _attack_audio_played and attack_audio:
					attack_audio.play()
					_attack_audio_played = true
			else:
				collision.disabled = true

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_body.update_health(attack_damage, get_parent())
