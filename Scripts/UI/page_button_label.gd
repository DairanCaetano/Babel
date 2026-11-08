extends Label
class_name PageButtonLabel

# Texto do botão de trocar página (topo do menu de pausa):
# LB/RB (Xbox), L1/R1 (PlayStation), L/R (Switch), Q/E (teclado).

## 0 = esquerda (LB/L1/Q), 1 = direita (RB/R1/E)
@export_range(0, 1) var side: int = 0

var _shown_device: int = -2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()


func _input(event: InputEvent) -> void:
	ButtonIcons.detect_from_event(event)


func _process(_delta: float) -> void:
	if ButtonIcons.get_device() != _shown_device:
		_refresh()


func _refresh() -> void:
	_shown_device = ButtonIcons.get_device()
	text = ButtonIcons.get_shoulder_labels()[side]
