extends Node2D
class_name OldWoodenSupport

@export_category("Visual Settings")
@export var tilemap_layer: TileMapLayer  # Suporte/correntes de madeira
@export var health: int = 3

@export_category("References")
@export var bull_head: RigidBody2D
@export var hit_box: Area2D
@export var collision: CollisionShape2D

@export_category("Effects")
@export var hit_audio: AudioStreamPlayer
@export var break_audio: AudioStreamPlayer
@export var break_particles: GPUParticles2D  # Lascas de madeira

var is_active: bool = true

func _ready() -> void:
	if not tilemap_layer:
		push_error("❌ OldWoodenSupport: Arraste o TileMapLayer no Inspector!")
		return
	
	if not hit_box:
		hit_box = get_node_or_null("HitBox")
	
	if not collision and hit_box:
		collision = hit_box.get_node_or_null("CollisionShape2D")
	
	if not bull_head:
		push_error("❌ OldWoodenSupport: bull_head não configurado!")
	
	if break_particles:
		break_particles.visible = false
		break_particles.emitting = false
	
	if hit_box and not hit_box.area_entered.is_connected(_on_support_hit):
		hit_box.area_entered.connect(_on_support_hit)
	
	if hit_box:
		hit_box.add_to_group("destructible_objects")
	
	print("✅ OldWoodenSupport configurado com TileMapLayer")

func _on_support_hit(area: Area2D) -> void:
	if not is_active:
		return
	
	if area.is_in_group("player_attack"):
		_take_damage(1)

func _take_damage(damage: int) -> void:
	health -= damage
	
	print("🎯 Suporte de madeira atingido! HP: ", health)
	
	# ✅ FEEDBACK VISUAL - BRILHO BRANCO VIA SHADER
	_apply_white_blink()
	
	# ✅ PARTÍCULAS DE LASCAS DE MADEIRA
	if break_particles:
		break_particles.global_position = global_position
		break_particles.visible = true
		break_particles.emitting = true
		break_particles.restart()
	
	# ✅ TOCAR SOM DE MADEIRA RACHANDO
	if hit_audio:
		hit_audio.play()
	
	# ✅ SHAKE NA CÂMERA (REDUZIDO - era até 4.5, agora máximo 2.0)
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		var shake_intensity = (4 - health) * 0.5  # ✅ REDUZIDO de 1.5 para 0.5
		camera.shake_camera(shake_intensity, 0.2)
	
	if HitStopManager:
		HitStopManager.hit_stop_short()
	
	if health <= 0:
		_break_support()

func _apply_white_blink() -> void:
	# ✅ BRILHO BRANCO VIA SHADER (MAIS RÁPIDO)
	if tilemap_layer and tilemap_layer.material:
		_set_shader_blink_intensity(1.0)
		
		# ✅ REDUZIDO de 0.15s para 0.08s
		await get_tree().create_timer(0.08).timeout
		
		if is_instance_valid(self) and tilemap_layer:
			_set_shader_blink_intensity(0.0)

func _set_shader_blink_intensity(new_value: float) -> void:
	if not tilemap_layer:
		return
	
	if not tilemap_layer.material:
		return
	
	tilemap_layer.material.set_shader_parameter("blink_active", new_value > 0.0)
	tilemap_layer.material.set_shader_parameter("blink_intensity", new_value)

func _break_support() -> void:
	if not is_active:
		return
	
	is_active = false
	
	print("💥 Suporte de madeira destruído - liberando cabeça de touro!")
	
	# ✅ SALVAR ESTADO DESTRUÍDO
	var giant_bull_head = get_parent()
	if giant_bull_head and giant_bull_head.has_method("save_destroyed_state"):
		giant_bull_head.save_destroyed_state()
	
	
	# ✅ TOCAR SOM DE MADEIRA QUEBRANDO
	if break_audio:
		break_audio.play()
	
	# ✅ EXPLOSÃO DE LASCAS DE MADEIRA
	if break_particles:
		break_particles.global_position = global_position
		break_particles.emitting = true
		break_particles.restart()
	
	# ✅ DESATIVAR HITBOX
	if hit_box:
		if hit_box.area_entered.is_connected(_on_support_hit):
			hit_box.area_entered.disconnect(_on_support_hit)
		hit_box.monitoring = false
		hit_box.remove_from_group("destructible_objects")
	
	if collision:
		collision.disabled = true
	
	# ✅ FADE OUT DO TILEMAP (suporte desaparece)
	if tilemap_layer:
		var tween = create_tween()
		tween.tween_property(tilemap_layer, "modulate:a", 0.0, 0.3)
		await tween.finished
		tilemap_layer.enabled = false
	
	# ✅ LIBERAR CABEÇA DE TOURO PARA CAIR
	if bull_head and bull_head.has_method("release"):
		bull_head.release()
	
	# ✅ SHAKE FORTE NA CÂMERA (REDUZIDO - era 6, agora 3)
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 0.4)  # ✅ REDUZIDO de 6 para 3
	
	if HitStopManager:
		HitStopManager.hit_stop_medium()
