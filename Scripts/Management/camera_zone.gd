extends Area2D
class_name CameraZone

@export_category("Debug Logs")
## Mostra no console as mensagens desta zona (entrar/sair/limites).
@export var debug_logs: bool = false

@export_category("Camera Bounds")
@export var use_custom_limits: bool = false
@export var limit_left: int = 0
@export var limit_top: int = 0
@export var limit_right: int = 1920
@export var limit_bottom: int = 1080

@export_category("Music Control")
@export var stop_level_music: bool = false
@export var boss_music_zone: bool = false
@export var music_fade_duration: float = 2.0

@export_category("Camera Behavior")
@export var camera_zoom: Vector2 = Vector2(1, 1)
@export var follow_player: bool = true
@export var fixed_position: Vector2 = Vector2.ZERO
## Puxa a câmera para o centro horizontal da sala (0 = desligado, 1 = câmera fixa no centro).
@export_range(0.0, 1.0, 0.05) var center_pull: float = 0.0
## Distância máxima (px) entre a Tola e o centro da tela causada pelo puxão (conta o look-ahead).
@export var center_pull_max_px: float = 150.0

@export_category("Transition")
@export var transition_duration: float = 0.5
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_category("Debug")
@export var draw_bounds: bool = true
@export var zone_color: Color = Color(0, 1, 1, 0.2)

var is_active: bool = false
var tween: Tween
var player_inside: bool = false
var is_ready: bool = false
var last_music_change_time: float = 0.0
const MUSIC_CHANGE_COOLDOWN: float = 0.5

var _player_ref: Node2D = null
var _active_tween_id: int = 0

func _ready() -> void:
	await get_tree().process_frame
	
	if not use_custom_limits:
		_calculate_limits_from_shape()
	
	is_ready = true
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	collision_layer = 0
	collision_mask = 1
	
	add_to_group("camera_zones")
	
	if debug_logs: print("\n🔍 ===== ZONA CONFIGURADA: ", name, " =====")
	if debug_logs: print("Use Custom Limits: ", use_custom_limits)
	if debug_logs: print("Limites: L=", limit_left, " R=", limit_right, " T=", limit_top, " B=", limit_bottom)
	if debug_logs: print("=====================================\n")
	
	call_deferred("_check_initial_overlap")

func _process(_delta: float) -> void:
	if not is_ready or not _player_ref or not is_instance_valid(_player_ref):
		return
	
	var currently_inside := _is_body_actually_inside(_player_ref)
	
	if currently_inside and not player_inside:
		player_inside = true
		if debug_logs: print("📷 Player ENTROU na zona: ", name)
		activate_zone()
	elif not currently_inside and player_inside:
		if _another_zone_contains_player():
			player_inside = false
			if debug_logs: print("📷 Player SAIU da zona: ", name)
			deactivate_zone()

func _calculate_limits_from_shape() -> void:
	var collision_shape = get_node_or_null("Collision")
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		push_warning("⚠️ Collision inválido em ", name)
		return
	
	var rect_shape = collision_shape.shape as RectangleShape2D
	var half_size = rect_shape.size / 2.0
	var pos = collision_shape.global_position
	
	limit_left = int(pos.x - half_size.x)
	limit_top = int(pos.y - half_size.y)
	limit_right = int(pos.x + half_size.x)
	limit_bottom = int(pos.y + half_size.y)

func _check_initial_overlap() -> void:
	if not is_ready:
		return
	
	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		if body is BaseCharacter and not player_inside:
			if not _is_body_actually_inside(body):
				continue
			
			var my_area = float(limit_right - limit_left) * float(limit_bottom - limit_top)
			for zone in get_tree().get_nodes_in_group("camera_zones"):
				if zone != self and zone is CameraZone and zone.player_inside:
					var other_area = float(zone.limit_right - zone.limit_left) * float(zone.limit_bottom - zone.limit_top)
					if other_area <= my_area:
						if debug_logs: print("  ⏭️ ", name, ": outra zona menor já ativa (", zone.name, ") - ignorando overlap inicial")
						_player_ref = body
						return
			
			if debug_logs: print("  🎯 Player já dentro de ", name)
			_player_ref = body
			player_inside = true
			activate_zone()
			break

func _is_body_actually_inside(body: Node2D) -> bool:
	var collision_shape = get_node_or_null("Collision")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var half_size = rect_shape.size / 2.0
		var pos = collision_shape.global_position
		var real_left = pos.x - half_size.x
		var real_top = pos.y - half_size.y
		var real_right = pos.x + half_size.x
		var real_bottom = pos.y + half_size.y
		var body_pos = body.global_position
		return (body_pos.x >= real_left and body_pos.x <= real_right and
				body_pos.y >= real_top and body_pos.y <= real_bottom)
	var bpos = body.global_position
	return (bpos.x >= limit_left and bpos.x <= limit_right and
			bpos.y >= limit_top and bpos.y <= limit_bottom)

func _another_zone_contains_player() -> bool:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return false
	for zone in get_tree().get_nodes_in_group("camera_zones"):
		if zone != self and zone is CameraZone:
			if zone._is_body_actually_inside(_player_ref):
				return true
	return false

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_player_ref = body

func _on_body_exited(_body: Node2D) -> void:
	pass

func activate_zone() -> void:
	if not is_ready or is_active:
		return
	
	is_active = true
	call_deferred("_deactivate_other_zones")
	
	_active_tween_id += 1
	var my_tween_id := _active_tween_id
	
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main or not game_main.camera:
		return
	
	var camera: Camera2D = game_main.camera
	
	# Puxão para o centro da sala (zonas com 0 desligam suavemente o puxão anterior)
	if camera.has_method("set_center_pull"):
		camera.set_center_pull((limit_left + limit_right) / 2.0, center_pull, center_pull_max_px)
	
	if tween and tween.is_running():
		tween.kill()
	
	# ✅ CORRIGIDO: usa interseção de retângulos em vez de distância entre centros
	var is_camera_unlimited = (camera.limit_left <= -9000000 or camera.limit_right >= 9000000)
	
	var current_rect = Rect2(
		camera.limit_left,
		camera.limit_top,
		camera.limit_right - camera.limit_left,
		camera.limit_bottom - camera.limit_top
	)
	var new_rect = Rect2(
		limit_left,
		limit_top,
		limit_right - limit_left,
		limit_bottom - limit_top
	)
	# Zonas adjacentes se tocam na borda — grow(50) garante que bordas coladas sejam detectadas
	var is_camera_far = not current_rect.grow(50).intersects(new_rect)
	
	if is_camera_unlimited or is_camera_far:
		camera.limit_left = limit_left
		camera.limit_top = limit_top
		camera.limit_right = limit_right
		camera.limit_bottom = limit_bottom
		camera.zoom = camera_zoom
	
	var zone_name := name
	var target_left := limit_left
	var target_top := limit_top
	var target_right := limit_right
	var target_bottom := limit_bottom
	var target_zoom := camera_zoom
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(transition_type)
	tween.set_ease(transition_ease)
	
	tween.tween_property(camera, "limit_left", target_left, transition_duration)
	tween.tween_property(camera, "limit_top", target_top, transition_duration)
	tween.tween_property(camera, "limit_right", target_right, transition_duration)
	tween.tween_property(camera, "limit_bottom", target_bottom, transition_duration)
	tween.tween_property(camera, "zoom", target_zoom, transition_duration)
	
	tween.chain().tween_callback(func():
		if my_tween_id != _active_tween_id:
			if debug_logs: print("  ⚠️ Tween stale ignorado: ", zone_name)
			return
		if not is_active:
			if debug_logs: print("  ⚠️ Zona desativada durante tween - ignorando resultado: ", zone_name)
			return
		if debug_logs: print("  ✅ Zona completamente aplicada: ", zone_name)
		if debug_logs: print("  📏 Limites finais: L=", camera.limit_left, " R=", camera.limit_right, " T=", camera.limit_top, " B=", camera.limit_bottom)
		if debug_logs: print("=========================================\n")
	)

func deactivate_zone() -> void:
	if not is_active:
		return
	
	if debug_logs: print("\n🛑 ===== DESATIVANDO ZONA: ", name, " =====")
	is_active = false
	
	if tween and tween.is_running():
		tween.kill()
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if stop_level_music and not boss_music_zone and (current_time - last_music_change_time) > MUSIC_CHANGE_COOLDOWN:
		last_music_change_time = current_time
		
		var game_main = get_tree().get_first_node_in_group("game_main")
		if game_main and game_main.current_level:
			var level_music = game_main.current_level.level_music_track
			if level_music and AudioManager:
				if debug_logs: print("  🎵 Restaurando música da fase: ", level_music)
				AudioManager.ensure_music_playing(level_music, 0.0, music_fade_duration)
	
	if debug_logs: print("=========================================\n")

func _deactivate_other_zones() -> void:
	if not is_active:
		return
	
	var all_zones = get_tree().get_nodes_in_group("camera_zones")
	for zone in all_zones:
		if zone != self and zone is CameraZone and zone.is_active:
			zone.deactivate_zone()
