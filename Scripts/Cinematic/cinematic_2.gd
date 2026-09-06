extends BaseLevel
class_name CinematicLevel

# ✅ Variável para definir qual cena carregar após a cinemática
@export var next_scene_path: String = "res://Scenes/Fases/tebes_t1.tscn"

# ✅ ADICIONAR REFERÊNCIA AO ANIMATION PLAYER
@export var _animation_player: AnimationPlayer

func _ready() -> void:
	# Chamar o _ready da classe pai
	super._ready()
	
	print("🎬 ========== CINEMATIC INICIADA ==========")
	
	# ✅ DESABILITAR CONTROLE DO JOGADOR IMEDIATAMENTE
	var character = get_node_or_null("Player/Character")  # ← MUDOU AQUI
	if character:
		character._is_in_cinematic = true
		print("  ✓ Controle do jogador desabilitado")
	else:
		print("  ⚠️ Player não encontrado!")
	
	# ✅ VERIFICAR E INICIAR ANIMATION PLAYER
	if _animation_player:
		print("  ✓ AnimationPlayer encontrado")
		
		# Conectar sinal de animação terminada
		if not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
			print("  ✓ Sinal animation_finished conectado")
		
		# Iniciar a animação da cinemática
		_animation_player.play("cinematic")
		print("  ✓ Animação iniciada: cinematic")
	else:
		print("  ❌ AnimationPlayer não encontrado! Conecte no Inspector")
		# Fallback: iniciar diálogo direto
		#_start_dialog()
	
	print("=============================================")

# ✅ CHAMADA QUANDO A ANIMAÇÃO TERMINA
func _on_animation_finished(anim_name: String) -> void:
	print("🎬 Animação terminada: ", anim_name)
	
	if anim_name == "cinematic":
		print("  ✓ Iniciando diálogo...")
		#_start_dialog()

# ✅ NOVA FUNÇÃO: Iniciar diálogo
#func _start_dialog() -> void:
	# Marcar que é uma cinemática
	#if _initial_dialog.has(0):
		#_initial_dialog["dialog_type"] = "cinematic"
	
	# Iniciar o diálogo
	#load_dialog()

# ✅ CHAMADA QUANDO O DIÁLOGO TERMINA
func _on_dialog_finished(dialog_type: String) -> void:
	print("🎬 CinematicLevel: Diálogo terminado - tipo: ", dialog_type)
	
	if dialog_type == "cinematic":
		print("  ✓ Carregando próxima cena: ", next_scene_path)
		
		# Verificar se a cena existe
		if FileAccess.file_exists(next_scene_path):
			global.current_scene_path = next_scene_path
			TransitionScreen.fade_in()
		else:
			push_error("  ❌ Cena não encontrada: " + next_scene_path)
