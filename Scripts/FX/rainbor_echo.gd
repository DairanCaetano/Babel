extends Node2D
class_name RainbowEcho

const SCENE := preload("res://Scenes/FX/rainbor_echo.tscn")
const ECHO_SHADER := preload("res://Shaders/rainbow_echo.gdshader")

static var _base_material: ShaderMaterial = null

@export var grow_duration: float = 1.0
@export var target_scale: float = 1.1
@export_category("Objects")
@export var _texture: AnimatedSprite2D

var mat: ShaderMaterial

static func _get_base_material() -> ShaderMaterial:
	if _base_material == null:
		_base_material = ShaderMaterial.new()
		_base_material.shader = ECHO_SHADER
	return _base_material

static func spawn(original_sprite: AnimatedSprite2D, parent: Node) -> void:
	if not original_sprite:
		push_warning("⚠️ RainbowEcho: original_sprite nulo, spawn cancelado")
		return
	
	var instance: RainbowEcho = SCENE.instantiate()
	parent.add_child(instance)
	instance.global_position = original_sprite.global_position
	instance.setup(original_sprite)

func setup(original_sprite: AnimatedSprite2D) -> void:
	if not _texture:
		push_error("⚠️ RainbowEcho: campo '_texture' não atribuído na cena!")
		queue_free()
		return
	
	_texture.sprite_frames = original_sprite.sprite_frames
	_texture.animation = original_sprite.animation
	_texture.frame = original_sprite.frame
	_texture.flip_h = original_sprite.flip_h
	_texture.flip_v = original_sprite.flip_v
	_texture.z_index = 2
	
	mat = _get_base_material().duplicate()
	_texture.material = mat
	
	_texture.modulate.a = 0.9
	_texture.pause()
	
	_play()

func _play() -> void:
	scale = Vector2.ONE
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), grow_duration)
	tween.tween_property(_texture, "modulate:a", 0.0, grow_duration)
	
	tween.chain().tween_callback(queue_free)
