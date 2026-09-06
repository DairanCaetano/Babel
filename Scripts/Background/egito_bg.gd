extends ParallaxBackground
class_name BackgroundEgito

const _Y_THRESHOLD: float = 264.0
const _HEIGHT: float = 360.0

@onready var _clouds: Array = [
	$Céu_Deserto
]

#func _physics_process(_delta: float) -> void:
	#for cloud in _clouds:
		#cloud.motion_offset.x -= 10 * _delta
