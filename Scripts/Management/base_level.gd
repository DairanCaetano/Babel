extends Node2D
class_name BaseLevel

@export_category("Level Info")
@export var level_name: String = "tebes_1_1"

@export_category("Audio")
@export var level_music_track: String = "tebe_1"

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
