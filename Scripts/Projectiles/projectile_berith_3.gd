extends ProjectileComponent
class_name ProjectileBerith3

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var attack_anticipation_audio: AudioStreamPlayer
@export var attack_audio: AudioStreamPlayer
@export var particles: GPUParticles2D  # ← ADICIONE ESTA LINHA

@export_category("Variables")
@export var attack_damage: int = 10

var _attack_audio_played: bool = false
var _is_finishing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if collision:
		collision.disabled = true
	
	if attack_anticipation_audio:
		attack_anticipation_audio.play()
	
	if texture:
		texture.play("Active")
		
		if not texture.frame_changed.is_connected(_on_texture_frame_changed):
			texture.frame_changed.connect(_on_texture_frame_changed)
		if not texture.animation_finished.is_connected(_on_texture_animation_finished):
			texture.animation_finished.connect(_on_texture_animation_finished)

func _on_texture_animation_finished() -> void:
	if texture.animation == "Active" and not _is_finishing:
		_is_finishing = true
		
		# Esconder sprite e desabilitar colisão
		if texture:
			texture.visible = false
		if collision:
			collision.disabled = true
		
		# Aguardar o áudio de ataque terminar (2 segundos)
		if attack_audio and attack_audio.playing:
			await get_tree().create_timer(2.0).timeout
		
		queue_free()

func _on_texture_frame_changed() -> void:
	if texture.animation == "Active":
		var current_frame = texture.frame
		
		if collision:
			if current_frame == 8 or current_frame == 9:
				collision.disabled = false
				
				if current_frame == 8 and not _attack_audio_played and attack_audio:
					attack_audio.play()
					_attack_audio_played = true
					
					# ← DESLIGAR PARTÍCULAS
					if particles:
						particles.emitting = false
			else:
				collision.disabled = true

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_body.update_health(attack_damage, get_parent())
