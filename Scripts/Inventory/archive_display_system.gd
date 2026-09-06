extends Control
class_name ArchiveDisplaySystem

signal display_finished

@export_category("Objects")
@export var _animated_sprite: AnimatedSprite2D
@export var _archive_title: Label
@export var _archive_content: Label

var _is_finished: bool = false
var _archive_data: Dictionary = {}
var _player: BaseCharacter = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("archive_display")

func show_archive(archive_data: Dictionary) -> void:
	_archive_data = archive_data
	_is_finished = false
	
	# ✅ PEGAR REFERÊNCIA DO PLAYER
	_player = get_tree().get_first_node_in_group("player")
	
	# Configurar textos (mas ainda invisíveis)
	_archive_title.text = archive_data.get("title", "Documento")
	_archive_content.text = archive_data.get("content", "")
	_archive_content.visible_ratio = 0
	_archive_title.modulate.a = 0
	
	print("📋 Mostrando arquivo: ", _archive_title.text)
	
	# ✅ CONGELAR O PLAYER
	if _player:
		_player._is_in_cinematic = true
		_player.velocity = Vector2.ZERO
		
		# ✅ PAUSAR A ANIMAÇÃO (O SEGREDO ESTÁ AQUI!)
		if _player._character_texture:
			_player._character_texture.pause()
	
	# Pausar o jogo
	get_tree().paused = true
	
	# Mostrar com animação
	visible = true
	
	_animated_sprite.play("Text_in")
	await _animated_sprite.animation_finished
	
	_fade_in_title()
	
	await _animate_text()
	
	_is_finished = true

func _fade_in_title() -> void:
	"""Fade in suave do título"""
	var tween = create_tween()
	tween.tween_property(_archive_title, "modulate:a", 1.0, 0.3)

func _input(event: InputEvent) -> void:
	if visible and _is_finished:
		if event.is_action_pressed("EquipWeapon") or event.is_action_pressed("Inventory"):
			_close_display()
			get_viewport().set_input_as_handled()
			return
	
	if visible:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()

func _animate_text() -> void:
	_archive_content.visible_ratio = 0
	
	while _archive_content.visible_ratio < 1:
		_archive_content.visible_ratio += 0.015
		await get_tree().physics_frame

func _close_display() -> void:
	_is_finished = false
	
	print("🔽 Fechando ArchiveDisplaySystem...")
	
	_archive_title.modulate.a = 0
	_archive_content.visible_ratio = 0
	
	_animated_sprite.play("Text_out")
	await _animated_sprite.animation_finished
	
	# ✅ DESCONGELAR O PLAYER
	if _player:
		_player._is_in_cinematic = false
		
		# ✅ RETOMAR A ANIMAÇÃO
		if _player._character_texture:
			_player._character_texture.play()
	
	# Despausar o jogo
	get_tree().paused = false
	
	visible = false
	display_finished.emit()
	
	queue_free()
