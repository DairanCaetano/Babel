extends ProjectileComponent
class_name ProjectileGroundExplosion

var is_destroyed: bool = false
var is_moving: bool = false

@export_category("Variables")
@export var move_speed: float = 128.0
@export var attack_damage: int = 10
@export var movement_distance: float = 32.0  # Distância que move a cada "passo"

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var ground_ray: RayCast2D
@export var wall_ray: RayCast2D
@export var attack_audio: AudioStreamPlayer

# ✅ carregado diretamente do path
const PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Projectile/projectile_ground_explosion.tscn")

@export var spawn_child_on_frame: bool = true
var has_spawned_child: bool = false

# ✅ Nova variável para armazenar o flip do atirador
var shooter_flip_h: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if texture:
		if not texture.is_connected("frame_changed", Callable(self, "_on_texture_frame_changed")):
			texture.connect("frame_changed", Callable(self, "_on_texture_frame_changed"))
		if not texture.is_connected("animation_finished", Callable(self, "_on_texture_animation_finished")):
			texture.connect("animation_finished", Callable(self, "_on_texture_animation_finished"))

	if not body_entered.is_connected(Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))

	has_spawned_child = false
	_play_animation("Idle")

	# ✅ NOVO: Toca o som ao surgir
	if attack_audio:
		attack_audio.play()

# ✅ MÉTODO ATUALIZADO - Agora aceita o flip do atirador
func setup(new_direction: Vector2, speed: float = 300.0, shooter_flip: bool = false):
	direction = new_direction.normalized()
	move_speed = speed
	shooter_flip_h = shooter_flip  # ✅ Armazena o flip do atirador
	has_spawned_child = false
	is_destroyed = false
	
	# ✅ CONFIGURA O FLIP_H DO SPRITE BASEADO NO ATIRADOR
	if texture and texture is AnimatedSprite2D:
		# Se o atirador está virado para esquerda (flip_h = true), inverte a lógica
		if shooter_flip:
			texture.flip_h = direction.x < 0  # flip_h = true quando vai para esquerda
		else:
			texture.flip_h = direction.x > 0  # flip_h = true quando vai para direita
	
	# ✅ CONFIGURA AS POSIÇÕES DOS RAYCASTS
	_update_raycasts_position()
	
	print("⚙️ Projétil configurado - Direção: ", direction, " Velocidade: ", move_speed, " Flip: ", texture.flip_h if texture else "N/A")


# ✅ NOVA FUNÇÃO PARA ATUALIZAR OS RAYCASTS BASEADO NO FLIP
func _update_raycasts_position() -> void:
	if shooter_flip_h:
		# ✅ Flip ativado - posições para quando está virado para direita
		if ground_ray:
			ground_ray.position.x = 20  # X positivo quando flip está ativo
		if wall_ray:
			wall_ray.target_position.y = -20  # Y negativo quando flip está ativo
	else:
		# ✅ Flip desativado - posições normais (virado para esquerda)
		if ground_ray:
			ground_ray.position.x = -20  # X negativo quando flip está desativado
		if wall_ray:
			wall_ray.target_position.y = 20  # Y positivo quando flip está desativado
	
	print("🎯 Raycasts configurados - Ground X: ", ground_ray.position.x if ground_ray else "N/A", 
		  " Wall Y: ", wall_ray.target_position.y if wall_ray else "N/A")


func _play_animation(animation_name: String):
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.play(animation_name)
		texture.set_autoplay("")
		print("🎬 Tocando animação: ", animation_name, " (sem loop)")
	else:
		print("❌ Animação não encontrada: ", animation_name)


func _physics_process(_delta: float) -> void:
	# ✅ Verifica se o wall_ray colidiu com uma parede
	if wall_ray and wall_ray.is_colliding() and not is_destroyed:
		print("🧱 Wall_ray detectou parede - destruindo projétil")
		_destroy_projectile()
		return
	
	# ✅ Movimento normal do projétil (herdado do ProjectileComponent)
	pass


func _on_body_entered(_body) -> void:
	if _body is BaseCharacter and not is_destroyed:
		_body.update_health(attack_damage, get_parent())
		print("⚔️ Dano aplicado ao player: ", attack_damage)
		_destroy_projectile()

	print("💥 Projétil colidiu com: ", _body.name)


func _destroy_projectile():
	if is_destroyed:
		return

	is_destroyed = true
	print("💀 Iniciando destruição do projétil")

	if texture:
		_play_animation("Idle")
	else:
		queue_free()


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	print("🗑️ Projétil saiu da tela - destruindo")
	_destroy_projectile()


func _on_texture_animation_finished() -> void:
	if not texture:
		return

	print("🎯 Animação finalizada: ", texture.animation)

	if texture.animation == "Idle":
		print("🗑️ Idle finalizado → queue_free()")
		queue_free()


func _on_texture_frame_changed() -> void:
	if not texture:
		return
	if texture.animation != "Idle":
		return

	if texture.frame == 4 and not is_destroyed and not has_spawned_child and spawn_child_on_frame:
		# ✅ só instancia se ainda houver chão
		if ground_ray and not ground_ray.is_colliding():
			print("⛔ Chão perdido → não vai instanciar mais projéteis")
			return

		# ✅ Instancia novo projétil MANTENDO O FLIP DO ATIRADOR
		var clone := PROJECTILE_SCENE.instantiate() as ProjectileGroundExplosion
		if clone:
			get_parent().add_child(clone)
			
			# ✅ AJUSTA A DIREÇÃO DO CLONE BASEADO NO FLIP
			var clone_direction = direction
			var clone_position_offset = Vector2(-movement_distance, 0)
			
			# Se o atirador original estava virado, ajusta a direção e posição
			if shooter_flip_h:
				clone_direction = Vector2(-direction.x, direction.y)  # Inverte horizontal
				clone_position_offset = Vector2(movement_distance, 0)  # Move para direita
			
			clone.global_position = global_position + clone_position_offset
			
			# ✅ PASSA O MESMO FLIP DO ATIRADOR PARA O CLONE
			clone.setup(clone_direction, move_speed, shooter_flip_h)
			
			# ⚡ AGORA: clones também podem spawnar enquanto houver chão
			clone.spawn_child_on_frame = true  
			print("✨ Instanciado clone em: ", clone.global_position, " Flip: ", shooter_flip_h)
			has_spawned_child = true
