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

@export_category("Vida Extra (Bênção de Rafa'el)")
## Sprite da reserva azul (continua a barra de vida, depois do fim dela).
## Vazio = usa o sprite padrão Babel_ExtraHealthBar.
@export var overheal_texture: Texture2D
## Tamanho da reserva cheia, em fração do comprimento da barra de vida.
@export var overheal_width_ratio: float = 0.2
## Ajuste vertical da reserva em relação à barra de vida (px).
@export var overheal_offset_y: float = 1.0
## Tempo da borda crescendo/encolhendo.
@export var overheal_grow_duration: float = 0.25

var _overheal_bar: TextureProgressBar
var _overheal_extra_width: float = 0.0   # quanto a borda cresce agora (anima)
var _overheal_tween: Tween

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
	
	_create_overheal_bar()

# ===== VIDA EXTRA (reserva azul) =====
func _create_overheal_bar() -> void:
	_overheal_bar = TextureProgressBar.new()
	_overheal_bar.name = "OverhealBar"
	if not overheal_texture:
		overheal_texture = load("res://sprites/UI/MENU_1/Babel_ExtraHealthBar_Pixel Art_v01.png")
	_overheal_bar.texture_progress = overheal_texture
	_overheal_bar.nine_patch_stretch = true
	_overheal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overheal_bar.max_value = 1
	_overheal_bar.value = 0
	_overheal_bar.visible = false
	health_bar.get_parent().add_child(_overheal_bar)
	# fica atrás da borda, como a barra de vida
	if health_border:
		health_bar.get_parent().move_child(_overheal_bar, health_border.get_index())

func update_overheal(value: int, max_value: int) -> void:
	if not _overheal_bar:
		return
	_overheal_bar.max_value = maxi(1, max_value)
	var tw := create_tween()
	tw.tween_property(_overheal_bar, "value", value, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var want_open: bool = value > 0
	# A borda cresce junto com a reserva, ponto a ponto (não abre tudo de uma vez)
	var ratio: float = clampf(float(value) / float(maxi(1, max_value)), 0.0, 1.0)
	var target_extra: float = roundf(_overheal_full_width() * ratio) + 1.0 if want_open else 0.0
	if want_open:
		_overheal_bar.visible = true
	if _overheal_tween:
		_overheal_tween.kill()
	_overheal_tween = create_tween()
	_overheal_tween.tween_property(self, "_overheal_extra_width", target_extra, overheal_grow_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not want_open:
		_overheal_tween.tween_callback(func(): _overheal_bar.visible = false)

func _overheal_full_width() -> float:
	return roundf(health_bar.size.x * overheal_width_ratio)

func _process(_delta: float) -> void:
	if not _overheal_bar or (not _overheal_bar.visible and _overheal_extra_width <= 0.0):
		return
	# Reserva colada no fim da barra de vida (acompanha o crescimento da vida máxima)
	var full_w: float = _overheal_full_width()
	_overheal_bar.position = Vector2(health_bar.position.x + health_bar.size.x, health_bar.position.y + overheal_offset_y)
	_overheal_bar.size = Vector2(full_w, maxf(1.0, health_bar.size.y - overheal_offset_y * 2.0))
	# A borda (container) cresce junto para envolver a reserva
	if health_border:
		var pad: float = _base_health_border_width - _base_health_width
		var border_w: float = health_bar.size.x + pad + roundf(_overheal_extra_width)
		health_border.custom_minimum_size.x = border_w
		health_border.size.x = border_w

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
