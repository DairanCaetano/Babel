extends StaticBody2D
class_name SpearPlatform

@export_category("Objects")
@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D 

# Variáveis para configuração da plataforma
var wall_type: String = ""
var is_flipped: bool = false
var is_playing_animation: bool = false  # Previne múltiplas animações simultâneas
var player_on_platform: bool = false

func _ready() -> void:
	# Garantir que os nós existam
	if not sprite:
		print("AVISO: Sprite2D não encontrado na SpearPlatform!")
	if not collision_shape:
		print("AVISO: CollisionShape2D não encontrado na SpearPlatform!")
	
	# Garantir que a animação Idle está tocando
	if sprite:
		sprite.play("Idle")
	
	print("SpearPlatform criada - Wall type: ", wall_type, " Flipped: ", is_flipped)

# Função chamada quando um corpo entra na área de detecção
func _on_detection_body_entered(body: Node2D) -> void:
	# Verificar se é o player (BaseCharacter é a classe pai)
	if body is BaseCharacter and not player_on_platform:
		player_on_platform = true
		play_active_animation()
		print("Player entrou na plataforma - tocando animação Active")

# Função chamada quando um corpo sai da área de detecção
func _on_detection_body_exited(body: Node2D) -> void:
	# Verificar se é o player (BaseCharacter é a classe pai)
	if body is BaseCharacter and player_on_platform:
		player_on_platform = false
		play_active_animation()
		print("Player saiu da plataforma - tocando animação Active")

# Função para tocar a animação Active apenas 1x
func play_active_animation() -> void:
	if not sprite or is_playing_animation:
		return
	
	is_playing_animation = true
	sprite.play("Active")
	print("Iniciando animação Active")
	
	# Aguardar a animação terminar
	await sprite.animation_finished
	
	# Voltar para Idle
	sprite.play("Idle")
	is_playing_animation = false
	print("Animação Active concluída - voltando para Idle")

# Função para configurar a plataforma baseada no tipo de parede e flip do projétil
func setup_platform(wall_type_param: String, should_flip: bool = false, projectile_flip: bool = false) -> void:
	wall_type = wall_type_param
	
	# Lógica para determinar o flip da plataforma
	# Se o projétil estava flipado, a plataforma também deve estar
	is_flipped = should_flip or projectile_flip
	
	print("Configurando plataforma - Tipo: ", wall_type, " Should Flip: ", should_flip, " Projectile Flip: ", projectile_flip, " Final Flip: ", is_flipped)
	
	# Aplicar o flip ao sprite
	if sprite:
		sprite.flip_h = is_flipped
		print("✅ Sprite flip_h configurado para: ", is_flipped)
	else:
		print("❌ ERRO: Não foi possível configurar flip - Sprite2D não encontrado!")
	
	# Ajustar a collision baseada no flip
	_adjust_collision_for_flip()

# Função simplificada que mantém compatibilidade
func setup_platform_simple(wall_type_param: String, should_flip: bool = false) -> void:
	setup_platform(wall_type_param, should_flip, false)

# Função para ajustar a collision se necessário
func _adjust_collision_for_flip() -> void:
	if not collision_shape:
		return
	
	# Ajustar a posição da collision baseada no flip se necessário
	# Isso é útil se a lança tem uma forma assimétrica
	match wall_type:
		"wall_left":
			collision_shape.position.x = 0
			print("Collision ajustada para parede esquerda")
		"wall_right":
			collision_shape.position.x = 0  # Mantenha 0 ou ajuste se necessário
			print("Collision ajustada para parede direita")
		_:
			collision_shape.position.x = 0
			print("Collision em posição padrão")

# Função para configuração mais detalhada se necessário
func setup_detailed(config: Dictionary) -> void:
	if config.has("wall_type"):
		wall_type = config.wall_type
	
	if config.has("flip_h"):
		is_flipped = config.flip_h
		if sprite:
			sprite.flip_h = is_flipped
	
	if config.has("position_offset"):
		position += config.position_offset
	
	if config.has("rotation_offset"):
		rotation_degrees += config.rotation_offset
	
	print("Plataforma configurada com config detalhado: ", config)

# Função para verificar se a plataforma foi configurada corretamente
func is_properly_configured() -> bool:
	return sprite != null and collision_shape != null

# Opcional: função para debug visual
func debug_info() -> String:
	var info = "SpearPlatform Debug:\n"
	info += "- Wall Type: " + wall_type + "\n"
	info += "- Is Flipped: " + str(is_flipped) + "\n"
	info += "- Sprite exists: " + str(sprite != null) + "\n"
	info += "- Collision exists: " + str(collision_shape != null) + "\n"
	if sprite:
		info += "- Sprite flip_h: " + str(sprite.flip_h) + "\n"
	return info
