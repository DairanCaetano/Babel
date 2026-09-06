extends Area2D
class_name ProjectileEnemyShooter

@export_category("Variables")
@export var attack_damage: int = 1
@export var speed: float = 300.0
@export var _health: int = 1
@export var is_static: bool = true
@export var is_interactable: bool = true
@export var interactable_pieces: Array
@export var is_special: bool = false

var direction: Vector2 = Vector2.ZERO
var is_destroyed: bool = false

# Variáveis para física de knockback
var knockback_velocity: Vector2 = Vector2.ZERO
var _gravity: float = 980.0  # Força da gravidade
var is_physics_active: bool = false

@export_category("Objects")
@export var _sprite: AnimatedSprite2D
@export var body_collision: CollisionShape2D
@export var _arrow_hit_audio: AudioStreamPlayer2D

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_interactable_area_entered)
	
	# Pega a referência do nó Texture (AnimatedSprite2D)
	_sprite = get_node("Texture")
	
	# Conecta o sinal de animação finalizada
	if _sprite:
		_sprite.animation_finished.connect(_on_texture_animation_finished)

func _physics_process(_delta: float) -> void:
	if is_physics_active:
		# Aplica física de knockback com gravidade
		knockback_velocity.y += _gravity * _delta
		global_position += knockback_velocity * _delta
	elif not is_destroyed:
		# Movimento normal do projétil
		translate(direction * _delta * speed)

func _on_body_entered(_body) -> void:
	if is_destroyed:
		return
		
	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn", 
		Vector2(36, 0), 
		global_position, 
		false
	)
	
	if _body is BaseCharacter:
		# Toca o áudio quando acertar o jogador
		if _arrow_hit_audio:
			_arrow_hit_audio.play()
		
		_body.update_health(attack_damage, self)
		_destroy_projectile_with_audio()
		
	if _body is TileMapLayer:
		_destroy_projectile()

func _on_interactable_area_entered(_area: Area2D) -> void:
	if not is_interactable or is_destroyed:
		return
		
	if _area is CharacterAttackArea:
		_interact(_area)

func _interact(_area) -> void:
	var _damage: int = _area.get_damaged()
	if is_special:
		if not _area.get_parent().is_on_rage():
			return
			
	global.spawn_effect(
	"res://Scenes/FX/hit_effect.tscn", 
	Vector2(0, 0), global_position, global.character._character_texture.flip_h
	)
	_health -= _damage
	if _health <= 0:
		is_destroyed = true
		if _sprite:
			_sprite.play("Destroyed")
		_destroyed()
		return

func _destroyed() -> void:
	is_destroyed = true
	
	# Ativa física de knockback
	_apply_knockback()
	
	# Projeta os estilhaços (se houver)
	for _piece in interactable_pieces:
		var _non_c_item: CollectableItem = preload("res://Scenes/Collectables/collectable_item.tscn").instantiate()
		_non_c_item.is_collectable = false
		_non_c_item.item_texture = _piece
		
		_non_c_item.global_position = global_position
		get_tree().root.call_deferred("add_child", _non_c_item)
	
	# Timer para queue_free após 1 segundo
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_destroy_timer_timeout)
	add_child(timer)
	timer.start()
	
	# Se não tem animação "Destroyed" ou não tem sprite, remove imediatamente
	if not _sprite or not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation("Destroyed"):
		queue_free()

func _apply_knockback() -> void:
	# Força aleatória entre 8 e 80
	var knockback_force: float = randf_range(20.0, 80.0)
	
	# Direção aleatória (esquerda ou direita)
	var knockback_direction: float = 1.0 if randf() > 0.5 else -1.0
	
	# Aplica o knockback (horizontal + vertical para cima para criar o arco)
	knockback_velocity.x = knockback_force * knockback_direction
	knockback_velocity.y = -knockback_force * 0.8  # Velocidade para cima (negativa)
	
	# Ativa o sistema de física
	is_physics_active = true
	
	print("Knockback aplicado! Força: ", knockback_force, " Direção: ", knockback_direction)

func _on_destroy_timer_timeout() -> void:
	queue_free()

func _destroy_projectile() -> void:
	is_destroyed = true
	queue_free()

func _destroy_projectile_with_audio() -> void:
	is_destroyed = true
	
	# Esconde visualmente o projétil
	if _sprite:
		_sprite.visible = false
	if body_collision:
		body_collision.set_deferred("disabled", true)
	
	# Aguarda o áudio terminar antes de destruir
	if _arrow_hit_audio and _arrow_hit_audio.playing:
		await _arrow_hit_audio.finished
	
	queue_free()

func _on_texture_animation_finished() -> void:
	# Não remove mais automaticamente quando a animação termina
	# O timer de 1 segundo vai cuidar disso
	pass

# Métodos para o inimigo configurar
func setup(projectile_direction: Vector2, projectile_speed: float):
	# Usa a direção já calculada pelo inimigo
	direction = projectile_direction  
	speed = projectile_speed
	
	# Configura o flip_h do AnimatedSprite2D filho "Texture"
	var texture_node = get_node("Texture")
	if texture_node and texture_node is AnimatedSprite2D:
		texture_node.flip_h = direction.x > 0  # flip_h = true quando vai para direita
	
	print("Projétil configurado! Direção: ", direction, " Speed: ", speed, " Flip: ", direction.x > 0)

func set_direction(projectile_direction: Vector2, projectile_speed: float):
	setup(projectile_direction, projectile_speed)
