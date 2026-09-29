extends Node2D
class_name GameMain

@export_category("Objects")
@export var level_container: Node2D 
@export var player_root: Node2D 
@export var character: CharacterBody2D 
@export var camera: Camera2D 
@export var hud: CanvasLayer 

@export_category("Development")
@export_file("*.tscn") var initial_level_override: String = ""
@export var initial_spawn_override: String = "default"

@export_category("Spawn Impulse Settings")
@export var default_impulse_force: float = 300.0
@export var horizontal_impulse_force: float = 350.0
@export var vertical_impulse_component: float = 0.0

var current_level: BaseLevel = null
var is_loading_level: bool = false

func _ready() -> void:
	add_to_group("game_main")
	global.character = character
	print("Player registrado no Global")
	
	_setup_camera()
	
	await get_tree().process_frame
	_load_initial_level()

func _setup_camera() -> void:
	camera.enabled = true
	print("Camera configurada")

func _load_initial_level() -> void:
	var initial_level_path: String
	var initial_spawn: String = ""
	
	if global.should_load_save:
		print("💾 Continue: carregando save (ignorando Dev Override)")
		serialization.load_data()
		
		initial_level_path = serialization.game_data.get("current_scene", "res://Scenes/Fases/Tebes/tebes_1_1.tscn")
		
		load_level(initial_level_path, "continue")
		
		await get_tree().create_timer(0.2).timeout
		await serialization.apply_loaded_data()
		global.should_load_save = false
		serialization.should_apply_save = false
		return
	
	if initial_level_override != "":
		print("🔧 Dev: ", initial_level_override)
		load_level(initial_level_override, initial_spawn_override)
		return
	
	print("🆕 Após cinemática")
	initial_level_path = serialization.game_data.get("current_scene", "")
	if initial_level_path == "":
		initial_level_path = "res://Scenes/Fases/Tebes/tebes_1_1.tscn"
	initial_spawn = serialization.game_data.get("spawn_point", "default")
	
	load_level(initial_level_path, initial_spawn)

func load_level(level_path: String, spawn_point: String = "") -> void:
	if is_loading_level:
		return
	
	# Godot 4.4+: @export_file pode salvar "uid://"; normaliza para "res://" (save e IDs de level)
	if level_path.begins_with("uid://"):
		level_path = ResourceUID.uid_to_path(level_path)
	
	is_loading_level = true
	
	if current_level:
		current_level.queue_free()
		await current_level.tree_exited
	
	var level_scene = load(level_path)
	if not level_scene:
		push_error("Falha ao carregar level: ", level_path)
		is_loading_level = false
		return
	
	current_level = level_scene.instantiate()
	level_container.add_child(current_level)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	global.current_scene_path = level_path
	print("📍 Cena atual atualizada: ", level_path)
	
	if hud and hud.has_method("_find_references"):
		hud.call_deferred("_find_references")
	
	if spawn_point == "continue":
		_position_at_continue()
	elif spawn_point != "":
		_position_player_at_spawn(spawn_point)
	elif serialization.game_data["position"] != Vector2.ZERO:
		character.global_position = serialization.game_data["position"]
	else:
		if not _try_spawn_default():
			character.global_position = Vector2(480, 270)
	
	_snap_camera_to_player()
	_remove_collected_items()
	
	if current_level.has_method("on_level_loaded"):
		current_level.on_level_loaded()
	
	# ✅ FADE IN COM FALLBACK DE SEGURANÇA
	await _fade_in_with_fallback()
	
	is_loading_level = false

# ✅ NOVO - Fade in com timeout de segurança contra tela preta na build exportada
func _fade_in_with_fallback() -> void:
	TransitionScreen.reset()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	TransitionScreen.fade_in_level()
	
	var timer = get_tree().create_timer(2.0)
	
	while TransitionScreen.is_transitioning():
		if timer.time_left <= 0.0:
			print("⚠️ TIMEOUT no fade_in — forçando abertura")
			TransitionScreen.force_show()
			break
		await get_tree().process_frame

func _snap_camera_to_player() -> void:
	if not camera or not character:
		return
	
	var original_smoothness = camera.follow_smoothness
	camera.follow_smoothness = 0.0
	
	if camera.has_method("snap_to_subject"):
		camera.snap_to_subject()
	else:
		camera.global_position = character.global_position + camera.base_offset
	
	await get_tree().process_frame
	
	camera.follow_smoothness = original_smoothness

func _try_spawn_default() -> bool:
	if not current_level:
		return false
	
	var spawn_container = current_level.get_node_or_null("SpawnPoints")
	if not spawn_container:
		return false
	
	for marker in spawn_container.get_children():
		if marker is Marker2D:
			var marker_name = marker.name.to_lower()
			
			if "respawn" in marker_name:
				continue
			
			if marker_name == "spawndefault" or marker_name == "default":
				character.global_position = marker.global_position
				return true
			
			if marker_name == "spawnstart" or marker_name == "start":
				character.global_position = marker.global_position
				return true
	
	return false

func _position_player_at_spawn(spawn_name: String) -> void:
	if not current_level:
		return
	
	if spawn_name == "continue":
		_position_at_continue()
		return
	
	var spawn_container = current_level.get_node_or_null("SpawnPoints")
	if not spawn_container:
		return
	
	var search_lower = spawn_name.to_lower()
	var exact_match: Marker2D = null
	var partial_match: Marker2D = null
	
	for marker in spawn_container.get_children():
		if marker is Marker2D:
			var marker_lower = marker.name.to_lower()
			
			if "respawn" in marker_lower:
				continue
			
			if marker_lower == "spawn" + search_lower or marker_lower == search_lower:
				exact_match = marker
				break
	
	if not exact_match:
		for marker in spawn_container.get_children():
			if marker is Marker2D:
				var marker_lower = marker.name.to_lower()
				if "respawn" in marker_lower:
					continue
				if search_lower in marker_lower:
					partial_match = marker
					break
	
	var selected_spawn = exact_match if exact_match else partial_match
	
	if selected_spawn:
		character.global_position = selected_spawn.global_position
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		if selected_spawn is ImpulseSpawn:
			selected_spawn.apply_impulse(character)
		else:
			_check_and_apply_impulse_by_name(selected_spawn)
	else:
		character.global_position = Vector2(480, 270)

func _position_at_continue() -> void:
	print("🔄 Continue: Posicionando player...")
	
	if serialization.game_data.has("position") and serialization.game_data["position"] != Vector2.ZERO:
		var saved_position = serialization.game_data["position"]
		character.global_position = saved_position
		print("✅ Continue: Player posicionado em: ", saved_position)
		print("  📍 Cena: ", serialization.game_data.get("current_scene", "desconhecida"))
		print("  🏷️ Save Area ID: ", serialization.game_data.get("save_area_id", "nenhuma"))
	else:
		print("⚠️ Nenhuma posição salva encontrada, usando spawn default")
		_try_spawn_default()

func _check_and_apply_impulse_by_name(spawn: Marker2D) -> void:
	var spawn_name_lower = spawn.name.to_lower()
	var impulse: Vector2 = Vector2.ZERO
	var should_apply = false
	
	if "impulse" in spawn_name_lower:
		if "right" in spawn_name_lower:
			impulse = Vector2(horizontal_impulse_force, vertical_impulse_component)
			should_apply = true
		elif "left" in spawn_name_lower:
			impulse = Vector2(-horizontal_impulse_force, vertical_impulse_component)
			should_apply = true
		else:
			impulse = Vector2(0, -default_impulse_force)
			should_apply = true
	
	if should_apply:
		_apply_impulse_to_character(impulse)

func _apply_impulse_to_character(impulse: Vector2) -> void:
	if not character:
		return
	
	character.velocity = impulse
	
	if character.has_method("set_animation"):
		character.set_animation("jump")
	
	if character.has_method("set_can_move"):
		character.set_can_move(false)
		await get_tree().create_timer(0.15).timeout
		character.set_can_move(true)

func _remove_collected_items() -> void:
	if not serialization.game_data.has("collected_items"):
		return
	
	var collected_ids = serialization.game_data["collected_items"]
	if collected_ids.is_empty():
		return
	
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	for node in collectibles:
		if "collectible_id" in node:
			if node.collectible_id in collected_ids:
				node.queue_free()

func transition_to_level(target_level_path: String, spawn_point: String) -> void:
	if character:
		character._is_in_cinematic = true
	
	TransitionScreen.fade_out()
	await TransitionScreen.transition_finished
	
	await load_level(target_level_path, spawn_point)  # ← só adiciona o await aqui
	
	if character:
		character._is_in_cinematic = false

func reload_current_level() -> void:
	if is_loading_level:
		return

	is_loading_level = true

	var level_path = global.current_scene_path
	var player_position = character.global_position
 
	if current_level:
		current_level.queue_free()
		await current_level.tree_exited

	var level_scene = load(level_path)
	if not level_scene:
		push_error("reload_current_level: Falha ao carregar ", level_path)
		is_loading_level = false
		return

	current_level = level_scene.instantiate()
	level_container.add_child(current_level)

	await get_tree().process_frame
	await get_tree().process_frame

	character.global_position = player_position

	if hud and hud.has_method("_find_references"):
		hud.call_deferred("_find_references")

	_remove_collected_items()

	if current_level.has_method("on_level_loaded"):
		current_level.on_level_loaded()
	
	# ✅ MESMO FALLBACK DO load_level
	await _fade_in_with_fallback()
	
	is_loading_level = false
