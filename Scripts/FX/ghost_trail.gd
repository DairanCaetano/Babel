extends Node2D
class_name GhostTrails

# Material base compartilhado entre TODOS os ghosts
static var _base_material: ShaderMaterial = null

var mat: ShaderMaterial
@export var fade_duration: float = 0.3
@export_category("Objects")
@export var _texture: AnimatedSprite2D
const GHOST_SHADER = preload("res://Shaders/ghost_trail.gdshader")

static func _get_base_material() -> ShaderMaterial:
	if _base_material == null:
		_base_material = ShaderMaterial.new()
		_base_material.shader = GHOST_SHADER
		_base_material.set_shader_parameter("colorize_color", Color(0.3, 0.7, 1.0))
		_base_material.set_shader_parameter("alpha", 0.75)
	return _base_material

func setup(original_sprite: AnimatedSprite2D) -> void:
	if not original_sprite or not _texture:
		return
	
	_texture.sprite_frames = original_sprite.sprite_frames
	_texture.animation = original_sprite.animation
	_texture.frame = original_sprite.frame
	_texture.flip_h = original_sprite.flip_h
	_texture.flip_v = original_sprite.flip_v
	_texture.scale = original_sprite.scale
	_texture.z_index = 1
	
	# Duplicate é muito mais rápido que criar do zero
	mat = _get_base_material().duplicate()
	_texture.material = mat
	
	position += Vector2(randi_range(-2, 2), 0)
	_texture.pause()
	
	fade_out()

func fade_out() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_texture, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mat, "shader_parameter/alpha", 0.0, fade_duration).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
