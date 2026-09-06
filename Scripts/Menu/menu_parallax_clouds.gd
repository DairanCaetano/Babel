extends ParallaxBackground

var interval := 2.0	# tempo entre cada novo movimento
var tween_speed := 3.0	# tempo do tween (quanto menor, mais rápido)
var timer := 0.0
var tween: Tween

func _ready():
	tween = create_tween()

func _process(delta):
	scroll_base_offset.x -= 40 * delta

	timer += delta

	if timer >= interval:
		timer = 0.0

		var random_offset := randf_range(-10.0, 20.0)

		tween.kill()
		tween = create_tween()

		tween.tween_property(self, "scroll_base_offset:y", scroll_base_offset.y + random_offset, tween_speed)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
