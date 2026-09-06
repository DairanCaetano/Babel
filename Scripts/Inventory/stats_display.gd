extends Control
class_name StatsDisplay

signal display_finished

@export_category("Objects")
@export var _animated_sprite: AnimatedSprite2D
@export var _label: Label

var _is_finished: bool = false
var _player: BaseCharacter = null

func _ready() -> void:
	visible = false
	add_to_group("stat_boost_display")

func show_text(text: String) -> void:
	_is_finished = false
	_label.text = text
	_label.modulate.a = 0
	
	_player = get_tree().get_first_node_in_group("player")
	
	if _player:
		_player._is_in_cinematic = true
		_player.velocity = Vector2.ZERO
		
		if _player._character_texture:
			_player._character_texture.pause()
	
	visible = true
	
	_animated_sprite.play("Text_in")
	await _animated_sprite.animation_finished
	
	var tween = create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, 0.3)
	await tween.finished
	
	_is_finished = true

func _input(event: InputEvent) -> void:
	if visible and _is_finished:
		if event.is_action_pressed("EquipWeapon") or event.is_action_pressed("Inventory"):
			_close_display()
			get_viewport().set_input_as_handled()
			return
	
	if visible:
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()

func _close_display() -> void:
	_is_finished = false
	
	_label.modulate.a = 0
	
	_animated_sprite.play("Text_out")
	await _animated_sprite.animation_finished
	
	if _player:
		_player._is_in_cinematic = false
		
		if _player._character_texture:
			_player._character_texture.play()
	
	visible = false
	display_finished.emit()
	queue_free()
