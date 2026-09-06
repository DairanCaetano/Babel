extends Area2D
class_name LevelTransition

## Sistema de transição entre levels
## Suporta tanto passagens automáticas (corredor) quanto portas com interação

@export_category("Transition Settings")
@export_file("*.tscn") var target_level: String = ""  ## Level de destino
@export var target_spawn: String = "default"  ## Nome do spawn point no destino

@export_category("Transition Type")
enum TransitionMode {
	CORRIDOR,  ## Passagem automática (ao entrar, transiciona)
	DOOR       ## Porta com interação (precisa pressionar UP)
}
@export var transition_mode: TransitionMode = TransitionMode.CORRIDOR

@export_category("Door Settings (apenas se mode = DOOR)")
@export var door_texture: AnimatedSprite2D  ## Texture da porta (arrastar Texture aqui)
@export var play_door_animation: bool = false  ## Se true, toca animação de abrir
@export var door_open_animation: String = "opening"  ## Nome da animação de abrir
@export var door_close_animation: String = "closing"  ## Nome da animação de fechar (futuro)
@export var door_idle_animation: String = "idle"  ## Nome da animação parada

@export_category("Visual Feedback")
@export var show_prompt: bool = false  ## Mostrar ícone "↑" (apenas para DOOR)
@export var prompt_icon: Sprite2D  ## Ícone do prompt (arrastar do nó filho)

var player_in_range: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	# Configurar sinais
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Validar configuração
	if target_level == "":
		push_warning("⚠️ LevelTransition '", name, "' não tem target_level configurado!")
	
	# Configurar visibilidade baseada no modo
	_setup_visual_feedback()
	
	# Iniciar animação idle se for porta
	if transition_mode == TransitionMode.DOOR and door_texture:
		if door_texture.sprite_frames and door_texture.sprite_frames.has_animation(door_idle_animation):
			door_texture.play(door_idle_animation)

func _setup_visual_feedback() -> void:
	"""Configura visibilidade dos elementos visuais baseado no modo"""
	
	match transition_mode:
		TransitionMode.CORRIDOR:
			# Corredor: esconder tudo (passagem invisível)
			if door_texture:
				door_texture.visible = false
			if prompt_icon:
				prompt_icon.visible = false
		
		TransitionMode.DOOR:
			# Porta: mostrar texture da porta, esconder prompt até player estar perto
			if door_texture:
				door_texture.visible = true
			if prompt_icon:
				prompt_icon.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		player_in_range = true
		
		# Se for CORREDOR, transicionar automaticamente
		if transition_mode == TransitionMode.CORRIDOR:
			_trigger_transition()
		
		# Se for PORTA com prompt, mostrar ícone
		elif transition_mode == TransitionMode.DOOR and show_prompt and prompt_icon:
			prompt_icon.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		player_in_range = false
		
		# Esconder prompt ao sair
		if prompt_icon:
			prompt_icon.visible = false

func _process(_delta: float) -> void:
	# Apenas processar input se for PORTA
	if transition_mode != TransitionMode.DOOR:
		return
	
	# Não processar se não há player ou já está em transição
	if not player_in_range or is_transitioning:
		return
	
	# Detectar input para abrir porta
	if Input.is_action_just_pressed("move_up"):
		_trigger_transition()

func _trigger_transition() -> void:
	"""Inicia a transição para o level de destino"""
	
	# Validar target_level
	if target_level == "":
		push_error("❌ LevelTransition: target_level não configurado em '", name, "'!")
		return
	
	# Verificar se o arquivo existe
	if not ResourceLoader.exists(target_level):
		push_error("❌ LevelTransition: Level não encontrado: ", target_level)
		return
	
	is_transitioning = true
	
	# Tocar animação da porta abrindo (se configurado)
	if transition_mode == TransitionMode.DOOR and play_door_animation:
		await _play_door_animation()
	
	# Buscar Game
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		push_error("❌ LevelTransition: Game não encontrado!")
		is_transitioning = false
		return
	
	# Verificar se Game tem o método de transição
	if not game_main.has_method("transition_to_level"):
		push_error("❌ LevelTransition: Game não tem método transition_to_level!")
		is_transitioning = false
		return
	
	# Chamar transição
	game_main.transition_to_level(target_level, target_spawn)

func _play_door_animation() -> void:
	"""Toca animação da porta abrindo"""
	
	if not door_texture:
		return
	
	# Verificar se tem a animação de abrir
	if door_texture.sprite_frames and door_texture.sprite_frames.has_animation(door_open_animation):
		door_texture.play(door_open_animation)
		await door_texture.animation_finished
	else:
		# Se não tem animação, apenas aguardar um tempo
		await get_tree().create_timer(0.2).timeout
