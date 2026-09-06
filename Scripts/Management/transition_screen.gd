extends CanvasLayer
class_name TransitionScreens

# ===== SINAIS =====
signal transition_finished
signal start_level
signal respawn_fade_out_complete
signal respawn_fade_in_complete

# ===== ESTADO =====
var scene_path: String = ""
var is_respawn_fade: bool = false
var is_level_transition: bool = false

# ===== REFERÊNCIAS =====
@export_category("Objects")
@export var _animation: AnimationPlayer
@onready var _color_rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 100
	
	# ✅ GARANTIR QUE COMEÇA INVISÍVEL
	if _color_rect:
		_color_rect.visible = false
	
	# ✅ CONECTAR O SIGNAL MANUALMENTE (GARANTIDO)
	if _animation:
		# Desconectar se já estiver conectado (previne duplicação)
		if _animation.animation_finished.is_connected(_on_animation_finished):
			_animation.animation_finished.disconnect(_on_animation_finished)
		
		# Conectar
		_animation.animation_finished.connect(_on_animation_finished)
		print("✅ AnimationPlayer: Signal conectado!")
	else:
		push_error("❌ AnimationPlayer não encontrado!")
	
	print("✅ TransitionScreen pronto (Layer: ", layer, ")")

# ===== FUNÇÕES ORIGINAIS =====

func fade_in() -> void:
	"""Fade original - troca de cena completa"""
	scene_path = global.current_scene_path
	
	print("🔥 fade_in chamado:")
	print("  scene_path: ", scene_path)
	print("  AnimationPlayer válido: ", is_instance_valid(_animation))
	
	if scene_path == "":
		push_error("TransitionScreen: scene_path está vazio!")
		return
	
	# ✅ USAR ResourceLoader.exists() EM VEZ DE FileAccess
	if not ResourceLoader.exists(scene_path):
		push_error("TransitionScreen: Recurso não existe: " + scene_path)
		
		# DEBUG: Tentar listar recursos disponíveis
		print("❌ Cena não encontrada: ", scene_path)
		print("  Tipo esperado: PackedScene")
		
		# Tentar carregar mesmo assim (fallback)
		print("  Tentando carregar mesmo assim...")
		var test_load = load(scene_path)
		if test_load != null:
			print("  ✅ CENA CARREGADA com sucesso apesar do erro de exists()!")
			# Continuar normalmente
		else:
			print("  ❌ Falha total ao carregar")
			return
	
	is_respawn_fade = false
	is_level_transition = false
	
	# ✅ TORNAR VISÍVEL
	if _color_rect:
		_color_rect.visible = true
	
	print("🔥 Tocando animação fade_in...")
	_animation.play("fade_in")
	print("🔥 Animação está rodando: ", _animation.is_playing())
	print("🔥 Animação atual: ", _animation.current_animation)
	print("🌑 Fade in iniciado (troca de cena completa)")

func respawn_fade_out() -> void:
	"""Fade de respawn - apenas efeito visual"""
	is_respawn_fade = true
	is_level_transition = false
	
	if _color_rect:
		_color_rect.visible = true
	
	_animation.play("fade_in")
	print("🌑 Respawn fade out")

func respawn_fade_in() -> void:
	"""Fade de respawn - apenas efeito visual"""
	is_respawn_fade = true
	is_level_transition = false
	_animation.play("fade_out")
	print("☀️ Respawn fade in")

func fade_in_death() -> void:
	"""Fade para morte/respawn (sem trocar cena)"""
	is_respawn_fade = true
	is_level_transition = false
	
	if _color_rect:
		_color_rect.visible = true
	
	_animation.play("fade_in")
	print("💀 Death fade in")

func fade_out_after_load() -> void:
	"""Fade após carregar save"""
	is_respawn_fade = true
	is_level_transition = false
	_animation.play("fade_out")
	print("☀️ Fade out após load")

# ===== NOVAS FUNÇÕES PARA SISTEMA DE LEVELS =====

func fade_out() -> void:
	"""Fade out para transição de level (escurece a tela)"""
	is_level_transition = true
	is_respawn_fade = false
	
	if _color_rect:
		_color_rect.visible = true
	
	_animation.play("fade_in")
	print("🌑 Level transition fade out")

func fade_in_level() -> void:
	"""Fade in para transição de level (clareia a tela)"""
	is_level_transition = true
	is_respawn_fade = false
	_animation.play("fade_out")
	print("☀️ Level transition fade in")

# ===== CALLBACKS =====

func _on_animation_finished(_anim_name: StringName) -> void:
	print("🔥🔥🔥 _on_animation_finished CHAMADO! 🔥🔥🔥")
	print("🎬 Animação finalizada: ", _anim_name, " (respawn: ", is_respawn_fade, ", level: ", is_level_transition, ")")
	
	var was_level_transition = is_level_transition
	var was_respawn = is_respawn_fade
	
	# ===== MODO 1: TRANSIÇÃO DE LEVEL =====
	if was_level_transition:
		is_level_transition = false
		
		match _anim_name:
			"fade_in":
				print("  ✓ Tela escurecida (pronto para trocar level)")
				transition_finished.emit()
			
			"fade_out":
				print("  ✓ Tela clareada (transição completa)")
				transition_finished.emit()
		return
	
	# ===== MODO 2: RESPAWN/MORTE =====
	if was_respawn:
		is_respawn_fade = false
		
		match _anim_name:
			"fade_in":
				print("  ✓ Respawn fade out completo")
				respawn_fade_out_complete.emit()
			
			"fade_out":
				print("  ✓ Respawn fade in completo")
				respawn_fade_in_complete.emit()
				
				# Esconder após respawn
				if _color_rect:
					_color_rect.visible = false
		return
	
	# ===== MODO 3: TROCA DE CENA COMPLETA (Original) =====
	print("🔥 Entrando no MODO 3 - Troca de cena")

	match _anim_name:
		"fade_in":
			print("  → Trocando para cena: ", scene_path)
			print("  → Verificando se cena existe...")
			
			# ✅ VERIFICAR ANTES DE TROCAR
			if not ResourceLoader.exists(scene_path):
				print("  ❌ ERRO: Cena não existe no ResourceLoader!")
				
				# Tentar carregar diretamente
				print("  → Tentando load() direto...")
				var loaded = load(scene_path)
				if loaded == null:
					push_error("  ❌ FALHA TOTAL: Não foi possível carregar a cena!")
					if _color_rect:
						_color_rect.visible = false
					return
				else:
					print("  ✅ Cena carregada via load()!")
			
			print("  → Chamando change_scene_to_file()...")
			var error = get_tree().change_scene_to_file(scene_path)
			
			if error != OK:
				push_error("TransitionScreen: Erro ao carregar cena - código: " + str(error))
				print("  ❌ Códigos de erro:")
				print("    0 = OK")
				print("    12 = ERR_CANT_OPEN (arquivo não encontrado)")
				print("    30 = ERR_FILE_NOT_FOUND")
				print("  → Erro recebido: ", error)
				
				if _color_rect:
					_color_rect.visible = false
				return
			
			print("  ✅ change_scene_to_file() retornou OK!")
			print("🔥 Esperando 1 frame...")
			await get_tree().process_frame
			
			print("🔥 AnimationPlayer ainda válido: ", is_instance_valid(_animation))
			
			if not is_instance_valid(_animation):
				print("⚠️ AnimationPlayer inválido após troca de cena")
				start_level.emit()
				transition_finished.emit()
				return
			
			print("  → Tocando fade_out")
			_animation.play("fade_out")
		
		"fade_out":
			print("  ✓ Cena carregada, fade out completo")
			
			# Esconder após fade out
			if _color_rect:
				_color_rect.visible = false
			
			start_level.emit()
			transition_finished.emit()

# ===== FUNÇÕES AUXILIARES =====

func is_transitioning() -> bool:
	"""Retorna true se alguma transição está acontecendo"""
	return _animation and _animation.is_playing()

func get_current_fade_type() -> String:
	"""Retorna o tipo de fade atual"""
	if is_level_transition:
		return "level_transition"
	elif is_respawn_fade:
		return "respawn"
	else:
		return "scene_change"

func reset() -> void:
	is_level_transition = false
	is_respawn_fade = false
	if _animation and _animation.is_playing():
		_animation.stop()
	# ✅ GARANTE QUE A ANIMAÇÃO VOLTA PRO ESTADO INICIAL
	if _animation:
		_animation.play("RESET")
	if _color_rect:
		_color_rect.modulate.a = 1.0
		_color_rect.visible = true


func force_show() -> void:
	reset()
	if _color_rect:
		_color_rect.modulate.a = 0.0
		_color_rect.visible = false
	transition_finished.emit()
