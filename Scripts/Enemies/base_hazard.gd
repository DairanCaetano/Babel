extends Area2D
class_name BaseHazard
@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _collision: CollisionShape2D
@export_category("Respawn Settings")
## ⚠️ LEGADO — IGNORADO. O Tola sempre volta ao último chão seguro.
## (Mantido só para não quebrar cenas antigas que ainda preenchem este campo.)
@export var respawn_point: Marker2D
@export var dano: int = 1  ## Quantidade de dano causado
@export_category("Visual Effects")
@export var pause_before_teleport: float = 0.1  ## Pausa após o dano antes do fade
var is_processing_respawn: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true

func _on_body_entered(body) -> void:
	if body is BaseCharacter and not is_processing_respawn:
		_processar_respawn(body)

func _processar_respawn(player: BaseCharacter) -> void:
	is_processing_respawn = true
	
	# Ativar modo cinemática
	player._is_in_cinematic = true
	
	# Aplicar dano
	player.update_health(dano, self)
	
	# ✅ REDUZIR GRAVIDADE PARA ESCONDER A QUEDA
	player.velocity = Vector2.ZERO
	player._gravity_multiplier = 0.1
	
	# Pequena pausa (opcional)
	if pause_before_teleport > 0:
		await get_tree().create_timer(pause_before_teleport).timeout
	
	# Fade OUT
	TransitionScreen.respawn_fade_out()
	await TransitionScreen.respawn_fade_out_complete
	
	# ✅ Teleportar
	# Último chão seguro → (reserva) origem do último pulo
	if "last_safe_position" in player and player.last_safe_position != Vector2.ZERO:
		player.global_position = player.last_safe_position
	else:
		player.global_position = player.jump_origin
	
	# ✅ RESTAURAR GRAVIDADE
	player._gravity_multiplier = 1.0
	player.velocity = Vector2.ZERO
	
	# Desativar modo cinemática
	player._is_in_cinematic = false
	
	# Fade IN
	TransitionScreen.respawn_fade_in()
	await TransitionScreen.respawn_fade_in_complete
	
	is_processing_respawn = false
