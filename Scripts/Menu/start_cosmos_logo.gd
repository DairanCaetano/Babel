extends Node2D
class_name CosmosLogo

# ===== ESTADO =====
var _transition_started := false
var _animation_started := false

# ===== REFERÊNCIAS =====
@export_category("Objects")
@export var _animated_sprite: AnimatedSprite2D
@export var _animation_player: AnimationPlayer

func _ready() -> void:
	_animation_player.animation_finished.connect(_on_animation_finished)
	_animation_player.play("LogoAnim")
	_animation_started = true

func _process(_delta: float) -> void:
	if not _animation_started or _transition_started:
		return
	
	if Input.is_action_just_pressed("EquipWeapon") or Input.is_action_just_pressed("Inventory"):
		_go_to_menu()

func _on_animation_finished(_anim_name: StringName) -> void:
	if _transition_started:
		return
	
	_go_to_menu()

func _go_to_menu() -> void:
	_transition_started = true
	get_tree().change_scene_to_file("res://Scenes/Menu/start_menu.tscn")
