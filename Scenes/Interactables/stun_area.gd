extends Area2D
class_name StunArea

var range_count: float = 0
var character_on_range: BaseCharacter = null

@export var stun_duration: float = 3.0  # Duração total antes de auto-destruir
@export var grow_duration: float = 0.5  # Tempo até atingir a escala alvo
@export var final_scale_multiplier: float = 1.5  # Quanto cresce além da escala alvo, lentamente
@export var _black_hole_visual: Sprite2D  # ✅ Arrastar o Sprite2D com o shader aqui no Inspector

var _target_scale: Vector2
var _rotation_speed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if _black_hole_visual:
		# ✅ Guarda a escala configurada no Inspector como "escala alvo"
		_target_scale = _black_hole_visual.scale
		_black_hole_visual.scale = Vector2.ZERO

		# ✅ Rotação com velocidade e direção aleatórias por instância
		_rotation_speed = randf_range(60.0, 150.0) * (1.0 if randi() % 2 == 0 else -1.0)

		_animate_growth()
	else:
		push_warning("⚠️ StunArea: _black_hole_visual não foi atribuído no Inspector!")

	# Auto-destruir após o tempo configurado
	await get_tree().create_timer(stun_duration).timeout
	queue_free()


func _animate_growth() -> void:
	var _grow_tween: Tween = create_tween()

	# Fase 1: 0 → escala alvo, rápido e com "estouro"
	_grow_tween.tween_property(
		_black_hole_visual, "scale", _target_scale, grow_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Fase 2: escala alvo → escala alvo * multiplicador, devagar, pelo resto da duração
	var _slow_growth_duration: float = max(stun_duration - grow_duration, 0.0)
	if _slow_growth_duration > 0.0:
		_grow_tween.tween_property(
			_black_hole_visual, "scale", _target_scale * final_scale_multiplier, _slow_growth_duration
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)


func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		character_on_range = body
		character_on_range._speed = 60


func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		range_count = 0
		character_on_range._speed = 120
		character_on_range = null


func _process(delta: float) -> void:
	if _black_hole_visual:
		_black_hole_visual.rotation_degrees += _rotation_speed * delta

	if is_instance_valid(character_on_range):
		range_count += delta * 15
		if range_count > 30:
			character_on_range.petrify(self)


func reset() -> void:
	range_count = 0
