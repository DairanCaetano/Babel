extends Control
class_name BarContainer

@export_category("Objects")
@export var health_bar: TextureProgressBar
@export var stamina_bar: TextureProgressBar
@export var trail_bar: TextureProgressBar
@export var trail_stamina_bar: TextureProgressBar
@export var health_border: NinePatchRect
@export var stamina_border: NinePatchRect

@export_category("Growth Animation")
@export var growth_tween_duration: float = 0.9

var current_health: int
var current_stamina: int

var _base_health_width: float
var _base_stamina_width: float
var _base_health_border_width: float  # ← NOVO
var _base_stamina_border_width: float  # ← NOVO

func _ready() -> void:
	global.ui_bars = self
	
	_base_health_width = health_bar.size.x
	_base_stamina_width = stamina_bar.size.x
	
	if health_border:
		_base_health_border_width = health_border.size.x
	if stamina_border:
		_base_stamina_border_width = stamina_border.size.x
	
	health_bar.grow_horizontal = Control.GROW_DIRECTION_END
	stamina_bar.grow_horizontal = Control.GROW_DIRECTION_END
	health_bar.nine_patch_stretch = true
	stamina_bar.nine_patch_stretch = true
	
	if trail_bar:
		trail_bar.grow_horizontal = Control.GROW_DIRECTION_END
		trail_bar.nine_patch_stretch = true
	if trail_stamina_bar:
		trail_stamina_bar.grow_horizontal = Control.GROW_DIRECTION_END
		trail_stamina_bar.nine_patch_stretch = true
	if health_border:
		health_border.grow_horizontal = Control.GROW_DIRECTION_END
	if stamina_border:
		stamina_border.grow_horizontal = Control.GROW_DIRECTION_END

func init_bar(health: int, stamina: int) -> void:
	health_bar.max_value = health
	stamina_bar.max_value = stamina
	
	health_bar.value = health
	stamina_bar.value = stamina
	
	if trail_bar:
		trail_bar.max_value = health
		trail_bar.value = health
	
	if trail_stamina_bar:
		trail_stamina_bar.max_value = stamina
		trail_stamina_bar.value = stamina
	
	current_health = health
	current_stamina = stamina

func increase_max_value(type: String, max_value: int, value: int, growth_ratio: float = 1.0, animate: bool = true) -> void:
	match type:
		"health":
			health_bar.max_value = max_value
			health_bar.value = value
			current_health = value
			
			if trail_bar:
				trail_bar.max_value = max_value
				trail_bar.value = value
			
			_grow_bar_width(health_bar, trail_bar, health_border, _base_health_width, _base_health_border_width, growth_ratio, animate)
			
		"stamina":
			stamina_bar.max_value = max_value
			stamina_bar.value = value
			current_stamina = value
			
			if trail_stamina_bar:
				trail_stamina_bar.max_value = max_value
				trail_stamina_bar.value = value
			
			_grow_bar_width(stamina_bar, trail_stamina_bar, stamina_border, _base_stamina_width, _base_stamina_border_width, growth_ratio, animate)

func _grow_bar_width(bar: TextureProgressBar, trail: TextureProgressBar, border: NinePatchRect, base_width: float, base_border_width: float, growth_ratio: float, animate: bool = true) -> void:
	if growth_ratio == 1.0:
		return
	
	var new_width: float = base_width * growth_ratio
	var duration: float = growth_tween_duration if animate else 0.0
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "custom_minimum_size:x", new_width, duration)
	tween.parallel().tween_property(bar, "size:x", new_width, duration)
	
	if trail:
		tween.parallel().tween_property(trail, "custom_minimum_size:x", new_width, duration)
		tween.parallel().tween_property(trail, "size:x", new_width, duration)
	
	if border:
		# ← CORREÇÃO: alvo absoluto baseado na largura ORIGINAL da moldura,
		# não somando em cima do tamanho atual (que já causava crescimento composto)
		var width_delta: float = new_width - base_width
		var border_new_width: float = base_border_width + width_delta
		tween.parallel().tween_property(border, "custom_minimum_size:x", border_new_width, duration)
		tween.parallel().tween_property(border, "size:x", border_new_width, duration)

func update_bar(type: String, value: int) -> void:
	match type:
		"HealthBar":
			call_tween(health_bar, current_health, value)
			
			if trail_bar:
				call_tween_delayed(trail_bar, current_health, value, 0.3)
			
			current_health = value
			
		"StaminaBar":
			call_tween(stamina_bar, current_stamina, value)
			
			if trail_stamina_bar:
				call_tween_delayed(trail_stamina_bar, current_stamina, value, 0.3)
			
			current_stamina = value

func call_tween(bar: TextureProgressBar, _initial_value: int, final_value: int) -> void:
	var tween = create_tween()
	tween.tween_property(
		bar,
		"value",
		final_value,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT_IN)

func call_tween_delayed(bar: TextureProgressBar, _initial_value: int, final_value: int, delay: float) -> void:
	var tween = create_tween()
	tween.tween_property(
		bar,
		"value",
		final_value,
		0.6
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT_IN).set_delay(delay)

func update_max_value_only(type: String, max_value: int, value: int) -> void:
	match type:
		"health":
			health_bar.max_value = max_value
			health_bar.value = value
			current_health = value
			
			if trail_bar:
				trail_bar.max_value = max_value
				trail_bar.value = value
		
		"stamina":
			stamina_bar.max_value = max_value
			stamina_bar.value = value
			current_stamina = value
			
			if trail_stamina_bar:
				trail_stamina_bar.max_value = max_value
				trail_stamina_bar.value = value
