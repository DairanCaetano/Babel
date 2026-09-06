extends RigidBody2D
class_name DestructibleWallShards

@export_category("Objects")
@export var _texture: Sprite2D

var shard_texture_preloaded: Texture2D = null
var shard_scale: float = 1.0

func _ready() -> void:
	# ✅ APLICAR TEXTURA PRÉ-CARREGADA
	if shard_texture_preloaded and _texture:
		_texture.texture = shard_texture_preloaded
	else:
		queue_free()
		return
	
	await get_tree().process_frame
	
	# ✅ APLICAR ESCALA
	if _texture:
		_texture.scale = Vector2(shard_scale, shard_scale)
	
	# ✅ TEMPO ALEATÓRIO ANTES DE CONGELAR (1.5s a 2.5s)
	var freeze_delay = randf_range(1.5, 2.5)
	await get_tree().create_timer(freeze_delay).timeout
	
	# ✅ CONGELAR FÍSICA
	freeze = true
	
	# ✅ TEMPO ALEATÓRIO ANTES DO FADE (0.2s a 0.8s)
	var fade_delay = randf_range(0.2, 0.8)
	await get_tree().create_timer(fade_delay).timeout
	
	# ✅ FADE SUAVE
	_fade_out(0.5)

func _fade_out(duration: float) -> void:
	var elapsed: float = 0.0
	var initial_alpha: float = modulate.a
	
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var progress = elapsed / duration
		modulate.a = lerp(initial_alpha, 0.0, progress)
		await get_tree().process_frame
	
	modulate.a = 0.0
	queue_free()
