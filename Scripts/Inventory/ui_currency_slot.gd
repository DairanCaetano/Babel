extends Control
class_name UICurrencySlot

@export var currency_type: String = "shards"
@export var currency_icon: TextureRect
@export var currency_label: Label

func _ready() -> void:
	update_display()
	
	# Conectar ao signal de mudança de moeda
	if global.has_signal("currency_changed"):
		global.currency_changed.connect(_on_currency_changed)

func update_display() -> void:
	"""Atualiza a exibição da moeda"""
	var amount = global.get_currency(currency_type)
	if currency_label:
		currency_label.text = str(amount)

func _on_currency_changed(_currency_type: String, _new_amount: int) -> void:
	"""Callback quando a moeda muda"""
	if _currency_type == currency_type:
		update_display()
