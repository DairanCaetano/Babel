extends CharacterBody2D
class_name BerithTree

@export_category("Objects")
@export var _collision_detection: CollisionShape2D
@export var _texture: AnimatedSprite2D
@export var _spawn_point: Marker2D
@export var enemy_scene: PackedScene
@export var _berith_particle: GPUParticles2D

@export_category("Boss Music")
@export var boss_music_track: String = "boss"
@export var music_fade_duration: float = 2.0

var _spawning: bool = false
var _player_entered: Node2D = null
var _boss_spawned: Boss = null
var _alliance_established: bool = false
var _dialog_shown: bool = false

func _ready() -> void:
	if _texture:
		_texture.play("Idle")
		_texture.animation_finished.connect(_on_animation_finished)
	
	# ✅ CHECAR ALIANÇA
	if serialization.game_data.get("baal_berith_alliance", false):
		_alliance_established = true
		print("🤝 Aliança com Baal Berith já foi estabelecida anteriormente")
		return
	
	# ✅ CHECAR SE BOSS JÁ FOI DERROTADO
	var defeated_bosses = serialization.game_data.get("defeated_bosses", [])
	if "baal_berith" in defeated_bosses:
		print("💀 Baal Berith já foi derrotado - BerithTree inativo")
		_alliance_established = true
		if _collision_detection:
			_collision_detection.disabled = true
		if _texture:
			_texture.play("Dead")
		return
	
	# ✅ CONECTAR SINAL DA DETECTION AREA
	var detection_area = get_node_or_null("DetectionArea")
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	
	# ✅ CHECAR SE PLAYER JÁ ESTÁ DENTRO DA ÁREA
	await get_tree().process_frame
	if detection_area:
		for body in detection_area.get_overlapping_bodies():
			if body is BaseCharacter:
				_on_detection_area_body_entered(body)
				break

func _check_player_already_in_area() -> void:
	var detection_area = get_node_or_null("DetectionArea")
	if not detection_area:
		return
	
	for body in detection_area.get_overlapping_bodies():
		if body is BaseCharacter:
			_on_detection_area_body_entered(body)
			break

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is BaseCharacter and not _spawning:
		_player_entered = body
		
		if _alliance_established:
			print("🤝 Aliança já estabelecida - BerithTree inativo")
			return
		
		if _dialog_shown:
			print("💬 Diálogo já foi mostrado anteriormente")
			return
		
		# ✅ TEM O ITEM CERIMONIAL?
		if serialization.game_data.get("has_ceremonial_branch", false):
			print("🌿 Player tem Ceremonial Branch - Mostrando diálogo")
			_dialog_shown = true
			
			# ❌ NÃO CHAMAR _freeze_player() AQUI!
			# Apenas chama o diálogo direto
			_show_alliance_dialog()
		
		# ❌ NÃO TEM O ITEM?
		else:
			print("⚔️ Player não tem Ceremonial Branch - Spawnando boss")
			
			# ✅ SIM, CHAMAR _freeze_player() AQUI!
			_freeze_player()
			_spawning = true
			
			if _texture:
				_texture.play("Bloom")


func _freeze_player() -> void:
	"""Congela o player (para inputs mas mantém animação idle)"""
	if _player_entered and _player_entered is BaseCharacter:
		# ✅ BLOQUEAR INPUTS PRIMEIRO (igual BossDoor)
		_player_entered._is_in_cinematic = true
		
		# ✅ ZERAR VELOCIDADE
		_player_entered.velocity = Vector2.ZERO
		
		# ✅ RESETAR FLAGS DE MOVIMENTO (para ir para Idle)
		_player_entered._was_moving_last_frame = false
		
		if _player_entered._character_texture:
			_player_entered._character_texture._was_moving = false
			_player_entered._character_texture._is_on_action = false
		
		print("🧊 Player congelado")

func _unfreeze_player() -> void:
	"""Descongela o player"""
	if _player_entered and _player_entered is BaseCharacter:
		_player_entered._is_in_cinematic = false
		print("🔓 Player descongelado")

func _show_alliance_dialog() -> void:
	"""Mostra o diálogo de escolha para estabelecer aliança"""
	
	# ✅ CONGELAR PLAYER IMEDIATAMENTE (só bloquear inputs)
	if _player_entered and _player_entered is BaseCharacter:
		_player_entered._is_in_cinematic = true
		print("🧊 Player congelado - Controle removido")
	
	# ✅ BUSCAR O HUD
	var game_hud = get_tree().get_first_node_in_group("game_main")
	if not game_hud:
		push_error("❌ Game HUD não encontrado!")
		return
	
	var hud_node = game_hud.get_node_or_null("HUD")
	if not hud_node:
		push_error("❌ HUD node não encontrado!")
		return
	
	# ✅ INSTANCIAR O DIÁLOGO
	var dialog_scene = preload("res://Scenes/Inventory/dialog_options.tscn")
	var dialog = dialog_scene.instantiate()
	
	hud_node.add_child(dialog)
	
	# ✅ TREMOR DE TELA PRIMEIRO
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 1.0)
		print("📳 Tremor de tela iniciado")
	
	# ✅ AGUARDAR 1 SEGUNDO (tremor)
	await get_tree().create_timer(1.0).timeout
	
	# ✅ MOSTRAR DIÁLOGO (SEM ATIVAR INPUT E SEM OPÇÕES)
	dialog.visible = true
	dialog._is_active = false
	dialog._options_text.text = tr("BOSS_BERITH_CALMED")
	dialog._current_selection = 1
	
	# ✅ GARANTIR QUE AS OPÇÕES ESTÃO ESCONDIDAS
	if dialog._dialog_option_1:
		dialog._dialog_option_1.visible = false
	if dialog._dialog_option_2:
		dialog._dialog_option_2.visible = false
	
	dialog._update_selection_visual()
	print("💬 Diálogo ativado (sem input, sem opções)")
	
	# ✅ AGUARDAR 2 SEGUNDOS (mensagem inicial)
	await get_tree().create_timer(2.0).timeout
	
	# ✅ VERIFICAR SE O DIÁLOGO AINDA EXISTE
	if not is_instance_valid(dialog):
		print("⚠️ Diálogo foi destruído")
		return
	
	# ✅ ESCONDER TUDO
	if dialog._texture:
		dialog._texture.visible = false
	if dialog._vbox_container:
		dialog._vbox_container.visible = false
	if dialog._options_text:
		dialog._options_text.visible = false
	
	print("🔽 Diálogo escondido temporariamente")
	
	# ✅ AGUARDAR 0.3 SEGUNDOS
	await get_tree().create_timer(0.3).timeout
	
	# ✅ VERIFICAR SE O DIÁLOGO AINDA EXISTE
	if not is_instance_valid(dialog):
		print("⚠️ Diálogo foi destruído")
		return
	
	# ✅ CONECTAR AOS SINAIS AGORA
	dialog.option_1_selected.connect(_on_alliance_accepted)
	dialog.option_2_selected.connect(_on_alliance_refused)
	
	# ✅ MOSTRAR TUDO DE NOVO COM AS OPÇÕES
	if dialog._texture:
		dialog._texture.visible = true
	if dialog._vbox_container:
		dialog._vbox_container.visible = true
	if dialog._options_text:
		dialog._options_text.visible = true
	
	# ✅ AGORA SIM MOSTRAR AS OPÇÕES
	if dialog._dialog_option_1:
		dialog._dialog_option_1.visible = true
	if dialog._dialog_option_2:
		dialog._dialog_option_2.visible = true
	
	# ✅ ATUALIZAR TEXTO E OPÇÕES
	dialog._options_text.text = tr("BOSS_BERITH_ALLIANCE_QUESTION")
	dialog._option_1_text.text = tr("BOSS_BERITH_YES")
	dialog._option_2_text.text = tr("BOSS_BERITH_NO")
	
	# ✅ RESETAR SELEÇÃO VISUAL
	dialog._current_selection = 1
	dialog._update_selection_visual()
	
	# ✅ AGORA SIM ATIVAR INPUT!
	dialog._is_active = true
	
	print("💬 Opções de aliança exibidas (input ativado)")


func _on_alliance_accepted() -> void:
	"""Jogador escolheu SIM - Estabelecer aliança (NÃO spawna boss)"""
	print("🤝 Jogador aceitou a aliança com Baal Berith!")
	
	# ✅ DESCONGELAR PLAYER
	if _player_entered and _player_entered is BaseCharacter:
		_player_entered._is_in_cinematic = false
		print("🔓 Player descongelado")
	
	# ✅ REMOVER CEREMONIAL BRANCH DO INVENTÁRIO
	_remove_ceremonial_branch_from_inventory()
	
	# ✅ SALVAR ALIANÇA (salva o jogo e faz as portas da sala sumirem)
	BossEventManager.register_boss_alliance("baal_berith")
	
	# ✅ MARCAR LOCALMENTE
	_alliance_established = true
	
	# A sequência de vitória (fim da demo) agora fica no Disco do Rá.
	print("✅ Aliança estabelecida")

func _on_alliance_refused() -> void:
	"""Jogador escolheu NÃO - Spawnar boss"""
	print("⚔️ Jogador recusou a aliança - Spawnando boss")
	
	# ✅ SPAWNAR BOSS NORMALMENTE (player já está congelado)
	_spawning = true
	
	if _texture:
		_texture.play("Bloom")

func _remove_ceremonial_branch_from_inventory() -> void:
	"""Remove o Ceremonial Branch do inventário do jogador"""
	
	if not global.inventory:
		push_error("❌ CharacterInventory não encontrado!")
		return
	
	# ✅ PERCORRER OS SLOTS DO INVENTÁRIO
	var inventory_data = global.inventory._inventory_data
	
	for slot_index in range(inventory_data.size()):
		var item = inventory_data[slot_index]
		
		# ✅ VERIFICAR SE É O CEREMONIAL BRANCH
		if not item.is_empty() and item.get("key", "") == "ITEM_CEREMONIAL_BRANCH_NAME":
			print("🗑️ Ceremonial Branch encontrado no slot ", slot_index)
			
			# ✅ REMOVER DO INVENTÁRIO
			global.inventory.remove_item(slot_index)
			
			# ✅ LIMPAR FLAG DO SAVE
			serialization.game_data["has_ceremonial_branch"] = false
			
			print("✅ Ceremonial Branch removido com sucesso!")
			return
	
	# ✅ Se não encontrou no inventário, apenas limpar a flag
	print("⚠️ Ceremonial Branch não encontrado no inventário - limpando flag")
	serialization.game_data["has_ceremonial_branch"] = false

func _on_animation_finished() -> void:
	if _spawning and _texture.animation == "Bloom":
		# DESATIVAR PARTÍCULAS
		if _berith_particle:
			_berith_particle.emitting = false
			print("✨ Partículas de BerithTree desativadas")
		
		# INSTANCIAR O BOSS
		if enemy_scene and _spawn_point:
			var boss_instance = enemy_scene.instantiate()
			get_parent().add_child(boss_instance)
			boss_instance.global_position = _spawn_point.global_position
			
			if boss_instance is Boss:
				_boss_spawned = boss_instance
				boss_instance.boss_defeated.connect(_on_boss_defeated)
				print("✅ Boss spawned e conectado: ", boss_instance.boss_id)
				
				# ✅ AGUARDAR O ROAR TERMINAR (2.3s) E DESCONGELAR PLAYER
				_wait_for_boss_roar()
			
			# ===== 🎵 TOCAR MÚSICA DO BOSS APÓS SPAWN =====
			if AudioManager:
				print("🎵 Iniciando música do boss: ", boss_music_track)
				AudioManager.play_music(boss_music_track, music_fade_duration)
		
		# TOCAR ANIMAÇÃO DEAD E DESABILITAR COLISÃO
		_texture.play("Dead")
		if _collision_detection:
			_collision_detection.disabled = true
		
		set_physics_process(false)

func _wait_for_boss_roar() -> void:
	"""Aguarda o roar do boss terminar para descongelar o player"""
	print("⏰ Aguardando roar do boss (2.3s)...")
	
	# ✅ AGUARDAR 2.3 SEGUNDOS
	await get_tree().create_timer(2.3).timeout
	
	# ✅ DESCONGELAR O PLAYER
	_unfreeze_player()
	print("✅ Roar terminado - Player liberado!")

func _on_boss_defeated(boss_id: String):
	"""Callback quando o boss spawned morre"""
	print("💀 Boss spawned foi derrotado: ", boss_id)
	
	# O boss já salvou a derrota (Boss._save_boss_death → BossEventManager).
	# A sequência de vitória (fim da demo) agora fica no Disco do Rá.

func _trigger_victory_sequence():
	"""Aciona a sequência de vitória na fase"""
	print("🎬 Tentando acionar sequência de vitória...")
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	
	if not game_main:
		push_error("❌ GameMain não encontrado!")
		return
	
	var current_level = game_main.current_level
	
	if not current_level:
		push_error("❌ current_level é null no GameMain!")
		return
	
	if current_level.has_method("_start_victory_sequence"):
		print("✅ Fase encontrada! Iniciando sequência...")
		current_level._start_victory_sequence()
	else:
		push_error("❌ Fase não tem método _start_victory_sequence!")
		print("  📍 Tipo da fase: ", current_level.get_class())
		print("  📍 Nome da fase: ", current_level.name)

func _on_detection_area_body_exited(body: Node2D) -> void:
	pass
