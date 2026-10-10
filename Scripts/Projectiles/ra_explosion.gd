extends Area2D
class_name RaExplosion

# Explosão do Rá-Pássaro: instanciada onde ele toca o chão no fim da Gone.
#
#   Start  (1x)    frames 0 e 1
#   Loop   (loop)  frames 2 e 3 por _loop_time segundos — dano LIGADO só aqui
#   End    (1x)    frames 1 e 0 (Start de trás pra frente)
#   → emite `finished` e some (o Rá espera esse sinal para rodar a Shine)
#
# O Texture fica centralizado no nó (0, 0). A coluna tem 260px de altura.

signal finished

@export_category("Objects")
@export var texture: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var explosion_audio: AudioStreamPlayer

@export_category("Variables")
@export var attack_damage: int = 15
@export var _loop_time: float = 2.0

var _has_hit: bool = false
var _ending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if not texture:
		texture = get_node_or_null("Texture")
	if not collision:
		collision = get_node_or_null("Collision")

	if collision:
		collision.disabled = true

	body_entered.connect(_on_body_entered)
	if texture:
		texture.animation_finished.connect(_on_animation_finished)

	_play("Start")


func _on_animation_finished() -> void:
	match texture.animation:
		"Start":
			_start_loop()
		"End":
			finished.emit()
			queue_free()


func _start_loop() -> void:
	_play("Loop")
	if collision:
		collision.set_deferred("disabled", false)   # dano só nos frames em loop
	if explosion_audio:
		explosion_audio.play()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, _loop_time)

	get_tree().create_timer(_loop_time, false).timeout.connect(_start_end)


func _start_end() -> void:
	if _ending:
		return
	_ending = true
	if collision:
		collision.set_deferred("disabled", true)
	_play("End")


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	if body is BaseCharacter:
		_has_hit = true
		body.update_health(attack_damage, self)


func _play(animation_name: String) -> void:
	if texture and texture.sprite_frames and texture.sprite_frames.has_animation(animation_name):
		texture.stop()
		texture.play(animation_name)
	elif animation_name == "End":
		finished.emit()
		queue_free()
