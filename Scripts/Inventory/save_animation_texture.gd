extends AnimatedSprite2D
class_name SaveAnimation

signal animation_sequence_finished

@onready var _label: Label = $Label

func _ready():
	visible = false
	if _label:
		_label.visible = false
	animation_finished.connect(_on_animation_finished)

func play_save_sequence() -> void:
	visible = true
	play("save_in")

func _on_animation_finished():
	if animation == "save_in":
		# Ativar a label PRIMEIRO
		if _label:
			_label.visible = true
		
		# DEPOIS aguardar 0.3 segundos
		await get_tree().create_timer(1.0).timeout
		
		# Desativar a label
		if _label:
			_label.visible = false
		
		# Tocar save_out
		play("save_out")
		
	elif animation == "save_out":
		# Esconder a animação
		visible = false
		animation_sequence_finished.emit()
