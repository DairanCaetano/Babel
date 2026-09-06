extends Node2D
class_name BerithWall

@export_category("Objects")
@export var _fire_particle: GPUParticles2D
@export var _texture: AnimatedSprite2D
@export var _hitbox: Area2D
@export var _wall: StaticBody2D 

@export_category("Audio")
@export var _secret_audio: AudioStreamPlayer
@export var _dead_fire_audio: AudioStreamPlayer
@export var _hit_audio: AudioStreamPlayer

@export_category("Stats")
@export var max_hp: int = 3

@export_category("Camera Shake — sem fogo")
@export var shake_weak_intensity: float = 1.5
@export var shake_weak_duration: float = 0.18

@export_category("Camera Shake — com fogo")
@export var shake_fire_intensity: float = 4.0
@export var shake_fire_duration: float = 0.25

@export_category("Flash")
@export var flash_duration: float = 0.2

@export_category("Persistence")
@export var wall_id: String = ""

var _hp: int
var _dead: bool = false


func _ready() -> void:
	if wall_id == "":
		push_error("❌ BerithWall: Configure o wall_id no Inspector!")
	elif _was_already_destroyed():
		queue_free()
		return

	_hp = max_hp
	_fire_particle.emitting = false
	_fire_particle.visible = false
	_texture.play("Idle")
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


# ─── Persistência ─────────────────────────────────────────────────────────────

func _was_already_destroyed() -> bool:
	return serialization.game_data.get("destroyed_walls", []).has(wall_id)


func _save_destroyed_state() -> void:
	if not serialization.game_data.has("destroyed_walls"):
		serialization.game_data["destroyed_walls"] = []
	if not serialization.game_data["destroyed_walls"].has(wall_id):
		serialization.game_data["destroyed_walls"].append(wall_id)
		serialization.save_data()


# ─── Recebimento de hit ───────────────────────────────────────────────────────

func _on_hitbox_area_entered(area: Area2D) -> void:
	if _dead:
		return

	if not area.is_in_group("player_attack"):
		return

	var is_fire: bool = _is_fire_attack(area)

	if is_fire:
		_take_damage()
		_flash()
		_shake(shake_fire_intensity, shake_fire_duration)
		if _hit_audio:
			_hit_audio.play()
	else:
		_shake(shake_weak_intensity, shake_weak_duration)


func _is_fire_attack(area: Area2D) -> bool:
	var node = area.get_parent()
	while node != null:
		if node.is_in_group("player"):
			for child in node.get_children():
				if child is CharacterSubweapon:
					return child.is_fire_active()
			return false
		node = node.get_parent()
	return false


# ─── Dano e morte ─────────────────────────────────────────────────────────────

func _take_damage() -> void:
	_hp -= 1
	if _hp <= 0:
		_die()


func _die() -> void:
	_dead = true

	# Desabilita colisões imediatamente
	_hitbox.set_deferred("monitoring", false)
	_hitbox.set_deferred("monitorable", false)
	if _hitbox.get_child_count() > 0:
		_hitbox.get_child(0).set_deferred("disabled", true)
	if _wall:
		for child in _wall.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)

	_fire_particle.visible = true
	_fire_particle.emitting = true
	if _secret_audio and _secret_audio.stream:
		_secret_audio.play()
	if _dead_fire_audio:
		_dead_fire_audio.play()
	_texture.play("Dead")
	_texture.animation_finished.connect(_on_dead_animation_finished, CONNECT_ONE_SHOT)


func _on_dead_animation_finished() -> void:
	_save_destroyed_state()

	# Aguarda o áudio de segredo terminar (caso ainda esteja tocando)
	if _secret_audio and _secret_audio.playing:
		await _secret_audio.finished

	queue_free()


# ─── Flash branco ─────────────────────────────────────────────────────────────

func _flash() -> void:
	_set_shader_blink_intensity(1.0)
	await get_tree().create_timer(flash_duration).timeout
	_set_shader_blink_intensity(0.0)


func _set_shader_blink_intensity(value: float) -> void:
	if not _texture or not _texture.material or not _texture.material.shader:
		return
	_texture.material.set_shader_parameter("blink_active", value > 0.0)
	_texture.material.set_shader_parameter("blink_intensity", value)


# ─── Camera shake ─────────────────────────────────────────────────────────────

func _shake(intensity: float, duration: float) -> void:
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(intensity, duration)
