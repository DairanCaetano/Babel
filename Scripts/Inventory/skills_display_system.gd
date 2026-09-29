extends Control
class_name SkillsDisplaySystem

signal display_finished

@export_category("Objects")
@export var _animated_sprite: AnimatedSprite2D
@export var _skills_title: Label
@export var _skills_content: Label
@export var _skills_texture: TextureRect

var _is_finished: bool = false
var _skill_display_data: Dictionary = {}
var _player: BaseCharacter = null

func _ready() -> void:
	visible = false
	# ✅ REMOVIDO: process_mode = Node.PROCESS_MODE_ALWAYS (não precisa mais)
	add_to_group("skill_display")

func show_skill(skill_display_data: Dictionary) -> void:
	print("=== DEBUG SKILLS ===")
	print("Locale: ", TranslationServer.get_locale())
	print("Traduções carregadas: ", TranslationServer.get_loaded_locales())
	print("title raw: ", skill_display_data.get("title", ""))
	print("tr(title): ", tr(skill_display_data.get("title", "")))
	_skill_display_data = skill_display_data
	_is_finished = false
	
	# ✅ PEGAR REFERÊNCIA DO PLAYER
	_player = get_tree().get_first_node_in_group("player")
	
	# ✅ CONFIGURAR TEXTOS (JÁ COMPLETOS, MAS INVISÍVEIS)
	_skills_title.text = tr(skill_display_data.get("title", "Nova Habilidade"))
	_skills_content.text = tr(skill_display_data.get("description", ""))
	
	# ✅ TEXTOS COMEÇAM INVISÍVEIS (modulate alpha = 0)
	_skills_title.modulate.a = 0
	_skills_content.modulate.a = 0
	
	# ✅ CARREGAR E CONFIGURAR IMAGEM
	_load_skill_icon(skill_display_data.get("icon_path", ""))
	_skills_texture.modulate.a = 0
	
	print("⚡ Mostrando habilidade: ", _skills_title.text)
	
	# ✅ CONGELAR O PLAYER (SEM PAUSAR O JOGO)
	if _player:
		_player._is_in_cinematic = true
		_player.velocity = Vector2.ZERO
		
		if _player._character_texture:
			_player._character_texture.pause()
	
	# ✅ REMOVIDO: get_tree().paused = true
	visible = true
	
	# ✅ SEQUÊNCIA DE ANIMAÇÕES
	_animated_sprite.play("Text_in")
	await _animated_sprite.animation_finished
	
	# ✅ FADE IN SIMULTÂNEO: TÍTULO + DESCRIÇÃO + ÍCONE (0.5s)
	_fade_in_all_elements()
	
	await get_tree().create_timer(0.5).timeout  # ✅ REMOVIDO: parâmetros de processamento pausado
	
	_is_finished = true

func _load_skill_icon(icon_path: String) -> void:
	"""Carrega a imagem da habilidade"""
	if icon_path == "":
		push_warning("⚠️ Caminho do ícone vazio")
		_skills_texture.visible = false
		return
	
	if not ResourceLoader.exists(icon_path):
		push_error("❌ Ícone não encontrado: ", icon_path)
		_skills_texture.visible = false
		return
	
	var texture = load(icon_path)
	if texture:
		_skills_texture.texture = texture
		_skills_texture.visible = true
		print("✅ Ícone carregado: ", icon_path)
	else:
		push_error("❌ Falha ao carregar ícone: ", icon_path)
		_skills_texture.visible = false

func _fade_in_all_elements() -> void:
	"""Fade in simultâneo do título, descrição e ícone (0.5s)"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_skills_title, "modulate:a", 1.0, 0.5)
	tween.tween_property(_skills_content, "modulate:a", 1.0, 0.5)
	tween.tween_property(_skills_texture, "modulate:a", 1.0, 0.5)

func _input(event: InputEvent) -> void:
	if visible and _is_finished:
		if event.is_action_pressed("EquipWeapon") or event.is_action_pressed("Inventory"):
			_close_display()
			get_viewport().set_input_as_handled()
			return
	
	# ✅ BLOQUEAR INPUTS DE GAMEPLAY ENQUANTO ESTIVER VISÍVEL
	if visible:
		# Bloquear apenas inputs de gameplay, permitir UI
		if event.is_action_pressed("ui_accept") or \
		   event.is_action_pressed("ui_cancel") or \
		   event.is_action_pressed("EquipWeapon") or \
		   event.is_action_pressed("Inventory"):
			return  # Permitir esses inputs para fechar
		
		# Bloquear movimento, ataque, etc
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()

func _close_display() -> void:
	_is_finished = false
	
	print("🔽 Fechando SkillsDisplaySystem...")
	
	_skills_title.modulate.a = 0
	_skills_content.modulate.a = 0
	_skills_texture.modulate.a = 0
	
	_animated_sprite.play("Text_out")
	await _animated_sprite.animation_finished
	
	# ✅ Só retoma animação, não solta o player
	if _player and _player._character_texture:
		_player._character_texture.play()
	
	visible = false
	print("📡 Emitindo display_finished...")
	display_finished.emit()
	queue_free()
