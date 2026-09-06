extends Area2D
class_name SaveArea

# ========== EXPORTS - CONFIGURAÇÃO ==========
@export var save_area_id: String = "save_1"
@export var continue_spawn_marker: Marker2D

# ========== EXPORTS - TEXTURAS E EFEITOS ==========
@export var _save_texture: AnimatedSprite2D        # Animação de save (efeito visual)
@export var _azazel_texture: AnimatedSprite2D      # Azazel (sempre visível)
@export var _save_fx: GPUParticles2D               # Partículas de save
@export var _interaction_icon: AnimatedSprite2D    # ✅ ÍCONE que aparece quando player entra

# ========== VARIÁVEIS DE ESTADO ==========
var is_player_inside: bool = false
var can_save: bool = false
var is_save_visible: bool = false

# ========== SINAIS ==========
signal save_completed

# ========== INICIALIZAÇÃO ==========
func _ready() -> void:
	# ✅ CRÍTICO: Adicionar ao grupo para ser encontrado pelo Game.gd
	add_to_group("save_area")
	
	# Conectar sinais
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# ✅ ÍCONE DE INTERAÇÃO - Começa ESCONDIDO
	if _interaction_icon:
		_interaction_icon.visible = false
		_interaction_icon.play("Idle")
	
	# ✅ ANIMAÇÃO DE SAVE - Controlada pelo HUD
	if _save_texture:
		_save_texture.visible = true
	
	# ✅ AZAZEL - SEMPRE VISÍVEL, começa em Await
	if _azazel_texture:
		_azazel_texture.visible = true
		_azazel_texture.play("Await")
	
	# ✅ PARTÍCULAS - Começam desligadas
	if _save_fx:
		_save_fx.emitting = false

# ========== DETECÇÃO DE PLAYER ==========
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		can_save = true
		
		# ✅ MOSTRAR APENAS O ÍCONE DE INTERAÇÃO
		if _interaction_icon:
			_interaction_icon.visible = true
			_interaction_icon.play("Appear")
			is_save_visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		can_save = false
		
		# ✅ ESCONDER APENAS O ÍCONE DE INTERAÇÃO
		if _interaction_icon:
			_interaction_icon.visible = false
			is_save_visible = false

# ========== INPUT - INTERAÇÃO ==========
func _input(event: InputEvent) -> void:
	if not is_player_inside or not can_save:
		return
	
	if event.is_action_pressed("move_up"):
		# ✅ Só permite salvar se o player estiver no chão
		var player = get_tree().get_first_node_in_group("player")
		if player and player.is_on_floor():
			_trigger_save()

# ========== SAVE - LÓGICA PRINCIPAL ==========
func _trigger_save() -> void:
	"""Salva o jogo quando player interage - ABRE O MENU DE SAVE"""
	
	# ✅ PRIMEIRO: Salvar dados da área atual
	_save_current_area_data()
	
	# ✅ SEGUNDO: Chamar HUD para abrir menu
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("toggle_save_container"):
		hud.toggle_save_container()
	else:
		push_error("SaveArea: HUD não encontrado!")
		return
	
	# ✅ TERCEIRO: Esconder ícone de interação (reaparece quando o menu fechar)
	if _interaction_icon:
		_interaction_icon.visible = false

func _save_current_area_data() -> void:
	"""✅ ÚNICA FUNÇÃO QUE ATUALIZA current_scene, save_area_id E currencies"""
	
	# ✅ PEGAR CENA ATUAL DO GLOBAL
	var current_level = global.current_scene_path
	
	if current_level == "":
		push_error("⚠️ current_scene_path está vazio!")
		return
	
	# ✅ PEGAR POSIÇÃO DO MARKER (se existir)
	var spawn_position: Vector2
	
	if continue_spawn_marker:
		spawn_position = continue_spawn_marker.global_position
	else:
		# Fallback: posição da SaveArea
		spawn_position = global_position
		print("⚠️ SaveArea '", save_area_id, "' não tem continue_spawn_marker!")
	
	# ✅ ATUALIZAR DADOS DO SAVE (ÚNICA RESPONSABILIDADE)
	serialization.game_data["current_scene"] = current_level
	serialization.game_data["save_area_id"] = save_area_id
	serialization.game_data["position"] = spawn_position
	
	# ✅ SALVAR MOEDAS (único lugar onde isso acontece!)
	serialization.game_data["currencies"] = global.currencies.duplicate()
	
	print("💾 SaveArea: Dados salvos")
	print("  - Cena: ", current_level)
	print("  - Save ID: ", save_area_id)
	print("  - Posição: ", spawn_position)
	print("  💰 Moedas salvas: ", global.currencies)
