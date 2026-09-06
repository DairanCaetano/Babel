extends ParallaxBackground
class_name Background

const _Y_THRESHOLD: float = 264.0
const _HEIGHT: float = 360.0

@onready var _clouds: Array = [
	$Cloud
]

@export_category("Objects")
#@export var _additional_sky: ParallaxLayer
#@export var _additional_city: ParallaxLayer
#@export var _character: BaseCharacterg

func _physics_process(_delta: float) -> void:
	for cloud in _clouds:
		cloud.motion_offset.x -= 10 * _delta 
		
		
	#if _character.global_position.y > _Y_THRESHOLD:
		#_additional_city.motion_mirroring.y = _HEIGHT
		#_additional_sky.motion_mirroring.y = 0
		
	#if _character.global_position.y < _Y_THRESHOLD:
		#_additional_city.motion_mirroring.y = 0
		#_additional_sky.motion_mirroring.y = _HEIGHT
