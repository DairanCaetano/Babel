extends Area2D
class_name WhipAttack

@export var _attack_damage: int = 7 # dano com ataque base 5 (escala com a força do Tola)

@export_category("Objects")
@export var _texture: AnimatedSprite2D
@export var _collision_shape: CollisionShape2D
@export var _spin_collision_shape: CollisionShape2D
@export var _whip_attack_audio: AudioStreamPlayer

@export_group("Solo")
@export var solo_size: Vector2 = Vector2(32, 12)
@export var solo_position: Vector2 = Vector2(33, -35)
@export var solo_rotation_degrees: float = -45.0
@export var solo_texture_offset: Vector2 = Vector2(0, 0)

@export_group("Air")
@export var air_size: Vector2 = Vector2(32, 12)
@export var air_position: Vector2 = Vector2(29, 31)
@export var air_rotation_degrees: float = 45.0
@export var air_texture_offset: Vector2 = Vector2(0, 0)

@export_group("Down")
@export var down_size: Vector2 = Vector2(32, 8)
@export var down_position: Vector2 = Vector2(41, 3)
@export var down_rotation_degrees: float = 0.0
@export var down_texture_offset: Vector2 = Vector2(0, 0)

@export_group("Spin")
@export var spin_radius: float = 20.0
@export var spin_position: Vector2 = Vector2(0, 0)
@export var spin_rotation_speed_degrees: float = 360.0
@export var spin_texture_offset: Vector2 = Vector2(0, 0)
@export var spin_hit_interval: float = 0.4
@export var spin_ghost_interval: float = 0.03
@export var spin_ghost_trail_scene: PackedScene

var direction: Vector2 = Vector2.RIGHT
var pending_variant: String = "solo"
var base_position: Vector2 = Vector2.ZERO

var _hit_enemies: Array = []

var _is_spinning: bool = false
var _spin_hit_timer: Timer
var _spin_ghost_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	z_index = 1000  # ⚠️ ajustar depois pra um valor mais comedido
	z_as_relative = false

	global_position = base_position

	if _collision_shape and _collision_shape.shape:
		_collision_shape.shape = _collision_shape.shape.duplicate()

	# ✅ Os dois começam desabilitados - só o setup da variante certa liga o correto
	if _collision_shape:
		_collision_shape.disabled = true
	if _spin_collision_shape:
		_spin_collision_shape.disabled = true

	if _texture:
		_texture.flip_h = direction.x < 0
		_texture.animation_finished.connect(_on_animation_finished)
		_texture.frame_changed.connect(_on_frame_changed)

	area_entered.connect(_on_area_entered)

	_setup_variant(pending_variant)

func _process(delta: float) -> void:
	if _is_spinning and _texture:
		var flip_mult: float = -1.0 if direction.x < 0 else 1.0
		# ✅ Positivo = sentido horário no Godot (eixo Y invertido na tela)
		# Multiplicado pelo flip pra manter o sentido visual consistente
		_texture.rotation_degrees += spin_rotation_speed_degrees * flip_mult * delta
		
		# 👻 GHOST TRAIL - só durante o giro
		_spin_ghost_timer += delta
		if _spin_ghost_timer >= spin_ghost_interval:
			_spawn_spin_ghost_trail()
			_spin_ghost_timer = 0.0

func _spawn_spin_ghost_trail() -> void:
	if not spin_ghost_trail_scene or not _texture:
		return
	
	var ghost = spin_ghost_trail_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = _texture.global_position
	ghost.global_rotation = _texture.global_rotation
	
	ghost.setup(_texture)

func _setup_variant(variant: String) -> void:
	if not _texture or not _collision_shape:
		print("⚠️ AVISO: _texture ou _collision_shape não atribuídos no Inspector do WhipAttack!")
		return

	var flip_mult: float = -1.0 if direction.x < 0 else 1.0

	match variant:
		"spin":
			_setup_spin_shape()
			_texture.position = spin_texture_offset
			_texture.play("Whip_Spin")
			_start_spin()
		"air":
			_apply_shape(air_size, air_position, air_rotation_degrees, flip_mult)
			_texture.position = Vector2(air_texture_offset.x * flip_mult, air_texture_offset.y)
			_texture.play("Whip_Air")
		"down":
			_apply_shape(down_size, down_position, down_rotation_degrees, flip_mult)
			_texture.position = Vector2(down_texture_offset.x * flip_mult, down_texture_offset.y)
			_texture.play("Whip_Down")
		_:
			_apply_shape(solo_size, solo_position, solo_rotation_degrees, flip_mult)
			_texture.position = Vector2(solo_texture_offset.x * flip_mult, solo_texture_offset.y)
			_texture.play("Whip_Solo")

func _apply_shape(size: Vector2, pos: Vector2, rot_degrees: float, flip_mult: float) -> void:
	if _collision_shape.shape is RectangleShape2D:
		_collision_shape.shape.size = size

	_collision_shape.position = Vector2(pos.x * flip_mult, pos.y)
	_collision_shape.rotation_degrees = rot_degrees * flip_mult

# ✅ Liga a colisão só nos frames 3 e 4; desativada nos frames 0, 1, 2
# (não se aplica durante o giro, que controla a colisão de outro jeito)
func _on_frame_changed() -> void:
	if _is_spinning:
		return

	if not _collision_shape:
		return

	if _texture.frame == 3 or _texture.frame == 4:
		_collision_shape.set_deferred("disabled", false)

		if _texture.frame == 3 and _whip_attack_audio:
			if _whip_attack_audio.playing:
				_whip_attack_audio.stop()
			_whip_attack_audio.play()
	else:
		_collision_shape.set_deferred("disabled", true)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("destructible_objects"):
		global.spawn_effect(
			"res://Scenes/FX/hit_effect.tscn",
			Vector2(0, 0), global_position, direction.x < 0
		)
		return

	if not area.is_in_group("enemy_hitbox"):
		return

	var enemy = global.get_damage_target(area)
	if not enemy or _hit_enemies.has(enemy):
		return

	if not enemy.has_method("update_health"):
		return

	_hit_enemies.append(enemy)

	var damage = _attack_damage
	if is_instance_valid(global) and is_instance_valid(global.character):
		damage = global.character.scale_damage(_attack_damage)

	global.spawn_effect(
		"res://Scenes/FX/hit_effect.tscn",
		Vector2(24, 0), global_position, direction.x < 0
	)

	enemy.update_health(damage, global.character if is_instance_valid(global.character) else self)

# ✅ Só destrói o nó depois que a animação E o áudio (se ainda tocando) terminarem
func _on_animation_finished() -> void:
	if _is_spinning:
		return

	if _whip_attack_audio and _whip_attack_audio.playing:
		if not _whip_attack_audio.finished.is_connected(_on_audio_finished):
			_whip_attack_audio.finished.connect(_on_audio_finished)
		return

	queue_free()

func _on_audio_finished() -> void:
	queue_free()

# ========== GIRO (Whip_Spin) ==========

func _setup_spin_shape() -> void:
	if not _spin_collision_shape:
		print("⚠️ AVISO: _spin_collision_shape não foi atribuído no Inspector do WhipAttack!")
		return

	_spin_collision_shape.position = spin_position
	_spin_collision_shape.rotation_degrees = 0.0
	_spin_collision_shape.disabled = false  # ✅ liga só a colisão do giro
	# ✅ Não mexe mais no raio - o Shape configurado no editor é quem manda

func _start_spin() -> void:
	_is_spinning = true

	_spin_hit_timer = Timer.new()
	_spin_hit_timer.wait_time = spin_hit_interval
	_spin_hit_timer.timeout.connect(_on_spin_hit_tick)
	add_child(_spin_hit_timer)
	_spin_hit_timer.start()

func _on_spin_hit_tick() -> void:
	if not _is_spinning:
		return

	for area in get_overlapping_areas():
		if not area.is_in_group("enemy_hitbox"):
			continue

		var enemy = global.get_damage_target(area)
		if not enemy or not enemy.has_method("update_health"):
			continue

		var damage = _attack_damage
		if is_instance_valid(global) and is_instance_valid(global.character):
			damage = global.character.scale_damage(_attack_damage)

		enemy.update_health(damage, global.character if is_instance_valid(global.character) else self)

# ✅ Chamado pelo CharacterSubweapon quando o jogador solta o botão (ou é cancelado)
func stop_spin() -> void:
	_is_spinning = false
	if _spin_hit_timer:
		_spin_hit_timer.stop()
	queue_free()
