extends Node2D
class_name RainbowPulse

const SCENE := preload("res://Scenes/FX/rainbow_effect.tscn")
static var active_instance: RainbowPulse = null

@export var duration: float = 2.7
@export var thickness: float = 0.2
@export var start_scale: float = 0.15
@export var fade_completion: float = 0.7  # em que % do radius o alpha já chega a 0 (1.0 = igual antes)
@export var sprite: Sprite2D


var pulse_material: ShaderMaterial
var target_player: Node2D = null


static func spawn(global_pos: Vector2, parent: Node, player: Node2D = null) -> void:
	if is_instance_valid(active_instance):
		active_instance.queue_free()
		active_instance = null
	
	var instance: RainbowPulse = SCENE.instantiate()
	instance.target_player = player
	parent.add_child(instance)
	instance.global_position = global_pos
	active_instance = instance
	
	if player != null and player.has_method("freeze"):
		player.freeze()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if sprite == null:
		push_error("⚠️ RainbowPulse: campo 'sprite' não atribuído na cena!")
		queue_free()
		return
	
	pulse_material = sprite.material as ShaderMaterial
	if pulse_material == null:
		push_error("⚠️ RainbowPulse: Sprite2D não tem ShaderMaterial atribuído.")
		queue_free()
		return
	
	scale = Vector2(start_scale, start_scale)
	pulse_material.set_shader_parameter("radius", 0.0)
	pulse_material.set_shader_parameter("thickness", thickness)
	_play()

func _play() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.parallel().tween_property(self, "scale", Vector2.ONE, duration)
	tween.parallel().tween_method(_update_radius, 0.0, 1.0, duration)
	
	tween.tween_callback(queue_free)

func _update_radius(value: float) -> void:
	pulse_material.set_shader_parameter("radius", value)
	var fade: float = 1.0 - clamp(value / fade_completion, 0.0, 1.0)
	pulse_material.set_shader_parameter("global_alpha", fade)

func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null
