extends Node2D
class_name BaseLevel

@export_category("Level Info")
@export var level_name: String = "tebes_1_1"

@export_category("Audio")
@export var level_music_track: String = "tebe_1"

# true durante a sequência de vitória: impede a música da fase de voltar
# depois da morte do chefe (AudioManager.resume_level_music)
var victory_sequence_active: bool = false

@export_category("Inimigos fora da tela")
## Pausa os inimigos (filhos do nó "Enemies") enquanto estão longe da tela.
## Eles voltam a funcionar sozinhos quando a câmera chega perto.
@export var pause_offscreen_enemies: bool = true
## Folga (px) em volta de cada inimigo: ele "acorda" um pouco antes de aparecer.
@export var offscreen_margin: Vector2 = Vector2(128, 96)

@export_category("Save Point")
## Abre o diálogo 1 sozinho na PRIMEIRA vez que o jogador usa o save desta fase
## (fins narrativos). Nas próximas vezes, o diálogo só pelo botão Conversar.
@export var auto_first_save_dialog: bool = false

# ✅ Sistema de diálogos progressivos
var save_point_dialogs: Array[Dictionary] = []

func _ready() -> void:
	print("✅ BaseLevel pronto: ", level_name)
	
	# ✅ CONFIGURAR DIÁLOGOS ANTES DE TUDO
	setup_dialogs()
	
	call_deferred("_setup_camera_zones")
	call_deferred("_setup_level_objects")
	
	# ✅ CORRIGIDO - Usar play_music_simple
	if level_music_track != "":
		print("🎵 Iniciando música da fase: ", level_music_track)
		AudioManager.play_music_simple(level_music_track, 0.0)

func setup_dialogs() -> void:
	"""⚠️ SOBRESCREVER esta função em cada fase específica!"""
	pass

func _setup_level_objects() -> void:
	"""Configura objetos do level (coletáveis, paredes, etc)"""
	await get_tree().process_frame
	_remove_collected_items()
	_remove_destroyed_walls()
	_setup_offscreen_enemies()

# ===== INIMIGOS FORA DA TELA =====
# Cada inimigo dentro do nó "Enemies" ganha um VisibleOnScreenEnabler2D:
# fora da tela (+ margem) ele fica pausado (IA, física, timers, animação).
# Para um inimigo específico NUNCA pausar: coloque-o no grupo "always_active".
# Bosses ficam fora do nó Enemies, então não são afetados.
func _setup_offscreen_enemies() -> void:
	if not pause_offscreen_enemies:
		return
	var container: Node = get_node_or_null("Enemies")
	if not container:
		return
	var count: int = _add_offscreen_enablers(container)
	print("  👁️ ", count, " inimigos pausam fora da tela")

func _add_offscreen_enablers(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if not child is Node2D:
			continue
		var is_enemy: bool = child is PhysicsBody2D or child.has_method("update_health")
		if not is_enemy:
			# Pasta/agrupador dentro de Enemies → procura dentro dela
			count += _add_offscreen_enablers(child)
			continue
		if child.is_in_group("always_active") or child.has_node("OffscreenEnabler"):
			continue
		var enabler := VisibleOnScreenEnabler2D.new()
		enabler.name = "OffscreenEnabler"
		enabler.rect = Rect2(-offscreen_margin, offscreen_margin * 2.0)
		enabler.enable_mode = VisibleOnScreenEnabler2D.ENABLE_MODE_INHERIT
		child.add_child(enabler)
		count += 1
	return count

func _remove_collected_items() -> void:
	"""Remove coletáveis já obtidos"""
	var collectibles = get_tree().get_nodes_in_group("collectible")
	print("  📦 Verificando ", collectibles.size(), " coletáveis...")
	
	var removed_count = 0
	for collectible in collectibles:
		if collectible is Collectables:
			if "collectible_id" in collectible:
				if collectible.collectible_id in serialization.game_data["collected_items"]:
					print("    → Removendo coletável: ", collectible.collectible_id)
					collectible.queue_free()
					removed_count += 1
	
	if removed_count > 0:
		print("  ✓ ", removed_count, " coletáveis já obtidos foram removidos")

func _remove_destroyed_walls() -> void:
	var walls = get_tree().get_nodes_in_group("breakable_wall")
	print("  🧱 Verificando ", walls.size(), " paredes...")
	
	var removed_count = 0
	for wall in walls:
		if wall is ObjectTriggeredWall:
			if wall.wall_id in serialization.game_data["destroyed_walls"]:
				print("    → Removendo parede: ", wall.wall_id)
				if is_instance_valid(wall.tilemap_layer):
					wall.tilemap_layer.queue_free()
				wall.queue_free()
				removed_count += 1
		elif wall is GiantBullHead:
			if wall.bull_head_id in serialization.game_data["destroyed_walls"]:
				print("    → Removendo GiantBullHead: ", wall.bull_head_id)
				wall._remove_all()
				removed_count += 1
	
	if removed_count > 0:
		print("  ✓ ", removed_count, " objetos já destruídos foram removidos")

func _setup_camera_zones() -> void:
	"""Configura as zonas de câmera do level"""
	var zones_container = get_node_or_null("CameraZones")
	if not zones_container:
		print("  ⚠️ Nenhuma CameraZone configurada")
		return
	
	var zones = zones_container.get_children()
	print("  📷 ", zones.size(), " zona(s) de câmera encontrada(s)")
	
	# Desativar todas as zonas
	for zone in zones:
		if zone is CameraZone:
			zone.is_active = false

func on_level_loaded() -> void:
	"""Chamado quando level termina de carregar"""
	_setup_camera_zones()
	
	# ✅ PixelTransition só quando a passagem que trouxe o jogador pediu
	# (ex.: Tebes 1-4 → Egito 1-1). Save, Continue e reload não usam.
	if global.pending_pixel_transition:
		global.pending_pixel_transition = false
		PixelTransition.fade_in()

func load_save_point_dialog() -> void:
	"""Carrega diálogo progressivo do save point"""
	
	if save_point_dialogs.is_empty():
		print("⚠️ [", level_name, "] Nenhum diálogo configurado!")
		_fallback_no_dialog()
		return
	
	var dialog_key = level_name + "_save_dialog_index"
	var current_index = serialization.game_data.get(dialog_key, 0)
	
	if current_index >= save_point_dialogs.size():
		current_index = save_point_dialogs.size() - 1
	
	print("💬 [", level_name, "] Carregando diálogo ", current_index + 1, "/", save_point_dialogs.size())
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		push_error("load_save_point_dialog: game_main não encontrado!")
		_fallback_no_dialog()
		return
	
	var game_hud = game_main.get_node_or_null("HUD")
	if not game_hud:
		push_error("load_save_point_dialog: HUD não encontrado!")
		_fallback_no_dialog()
		return
	
	var dialog_copy = save_point_dialogs[current_index].duplicate(true)
	dialog_copy["dialog_type"] = "save_point"
	
	game_hud.spawn_dialog(dialog_copy)
	
	# ✅ CORRIGIDO: usar save_data() ao invés de save_game()
	if current_index < save_point_dialogs.size() - 1:
		serialization.game_data[dialog_key] = current_index + 1
		serialization.save_data()  # ← CORRIGIDO!
		print("  → Próximo será: diálogo ", current_index + 2)
	else:
		print("  → Último diálogo alcançado (vai repetir)")

func should_auto_start_save_dialog() -> bool:
	"""True só na primeira vez que o save desta fase é usado (e se a fase pediu)."""
	if not auto_first_save_dialog or save_point_dialogs.is_empty():
		return false
	return not serialization.game_data.get(level_name + "_auto_dialog_done", false)

func mark_auto_save_dialog_done() -> void:
	serialization.game_data[level_name + "_auto_dialog_done"] = true

func _fallback_no_dialog() -> void:
	"""Fallback caso não tenha diálogos configurados"""
	print("  ↩️ Reabrindo menu de save (sem diálogo)")
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if game_main:
		var hud = game_main.get_node_or_null("HUD")
		if hud and hud.has_method("_reopen_save_menu"):
			hud._reopen_save_menu()

func reset_dialogs() -> void:
	"""Reseta os diálogos para o início (útil para debug)"""
	var dialog_key = level_name + "_save_dialog_index"
	serialization.game_data[dialog_key] = 0
	serialization.save_data()  # ← CORRIGIDO!
	print("🔄 Diálogos resetados para: ", level_name)

# ===== SEQUÊNCIA DE VITÓRIA (vale para qualquer fase) =====
func _start_victory_sequence() -> void:
	"""Sequência de vitória (fim da demo). Chamada pelo spawner do chefe
	(Disco do Rá) via BossAlliance.trigger_victory_sequence()."""
	print("🎉 Iniciando sequência de vitória!")
	victory_sequence_active = true
	
	# Desabilitar controle do jogador
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
	
	# CÂMERA LENTA
	Engine.time_scale = 0.3
	
	# TREMOR DA CÂMERA
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 5.0 / Engine.time_scale)
	
	# VIBRAÇÃO DO CONTROLE
	ControllerVibration.vibrate_custom(0.6, 0.6, 5.0)
	
	# AGUARDAR 5 SEGUNDOS (em tempo real)
	await get_tree().create_timer(5.0, true, false, true).timeout
	
	# RESTAURAR VELOCIDADE NORMAL
	Engine.time_scale = 1.0
	
	print("⏰ Câmera lenta finalizada, iniciando transição...")
	
	# FADE OUT DA MÚSICA
	if AudioManager:
		AudioManager.stop_music(2.0)
	
	# TRANSIÇÃO PARA CRÉDITOS
	TransitionScreen.fade_out()
	await TransitionScreen.transition_finished
	
	print("✅ Fade out completo, pausa dramática...")
	
	# PAUSA DRAMÁTICA (1.5 segundos no escuro)
	await get_tree().create_timer(1.5).timeout
	
	print("✅ Trocando para cena de créditos...")
	
	# TROCAR CENA
	get_tree().change_scene_to_file("res://Scenes/Credits/agradecimento.tscn")
