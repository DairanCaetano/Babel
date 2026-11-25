extends Area2D
class_name Collectables

const _STAT_BOOST_POPUP: PackedScene = preload("res://Scenes/Inventory/stats_display.tscn")

@export var collectible_id: String = ""

@export_category("Post Dialog")
@export var has_post_dialog: bool = false

var post_dialog_data: Dictionary = {}

@export_category("Audio")
@export var collectable_audio: AudioStreamPlayer

func _ready() -> void:
	print("🔎 Collectable '", name, "' | ID: '", collectible_id, "' | já coletado: ", _is_already_collected())
	
	if collectible_id == "" and not self is CollectablePotion:
		push_warning("⚠️ Collectible sem ID configurado: ", name)
	
	if collectible_id != "" and _is_already_collected():
		queue_free()
		return
	
	add_to_group("collectible")


func _is_already_collected() -> bool:
	return collectible_id in serialization.game_data["collected_items"]

func _on_body_entered(_body) -> void:
	if _body is BaseCharacter:
		_consume(_body)
		
		if collectable_audio and collectable_audio.stream:
			_spawn_collection_audio()
		
		global.spawn_effect(
			"res://Scenes/FX/collect_item_effect.tscn",
			Vector2.ZERO,
			global_position,
			false
		)
		
		_register_collected()
		queue_free()

func _spawn_collection_audio() -> void:
	var temp_audio = AudioStreamPlayer.new()
	temp_audio.stream = collectable_audio.stream
	temp_audio.volume_db = collectable_audio.volume_db
	temp_audio.pitch_scale = collectable_audio.pitch_scale
	temp_audio.bus = collectable_audio.bus
	get_tree().root.add_child(temp_audio)
	temp_audio.play()
	temp_audio.finished.connect(func():
		temp_audio.queue_free()
	)

func _register_collected() -> void:
	if collectible_id != "" and not collectible_id in serialization.game_data["collected_items"]:
		serialization.game_data["collected_items"].append(collectible_id)
		print("✅ Coletável registrado: ", collectible_id)

func _consume(_body: BaseCharacter) -> void:
	pass

func _show_skill_display(skill_display_data: Dictionary) -> void:
	if global.debug_silent_pickup:
		return  # entrega de debug: sem pop-up
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		push_error("❌ game_main não encontrado!")
		return
	
	var hud_node = game_main.get_node_or_null("HUD")
	if not hud_node:
		push_error("❌ HUD node não encontrado!")
		return
	
	var skill_scene = preload("res://Scenes/Inventory/skills_display_system.tscn")
	var skill_display = skill_scene.instantiate()
	hud_node.add_child(skill_display)
	
	if has_post_dialog and not post_dialog_data.is_empty():
		var captured_dialog_data: Dictionary = post_dialog_data.duplicate(true)
		var captured_hud: Node = hud_node
		var dialog_scene: PackedScene = load("res://Scenes/Inventory/dialog_system.tscn")
		
		skill_display.display_finished.connect(func():
			print("📜 Lambda executada! Instanciando diálogo...")
			if captured_hud.player_character and is_instance_valid(captured_hud.player_character):
				captured_hud.player_character._is_in_cinematic = true
			
			var dialog = dialog_scene.instantiate()
			dialog.dialog_data = captured_dialog_data
			captured_hud.add_child(dialog)
			
			dialog.is_finished.connect(func(_type: String):
				if captured_hud.player_character and is_instance_valid(captured_hud.player_character):
					captured_hud.player_character._is_in_cinematic = false
			)
		)
	else:
		# ✅ Sem diálogo — libera o player quando o display fechar
		var captured_hud: Node = hud_node
		skill_display.display_finished.connect(func():
			if captured_hud.player_character and is_instance_valid(captured_hud.player_character):
				captured_hud.player_character._is_in_cinematic = false
		)
	
	skill_display.show_skill(skill_display_data)

func _show_stat_boost_popup(text: String) -> void:
	if global.debug_silent_pickup:
		return  # entrega de debug: sem pop-up
	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		push_error("❌ game_main não encontrado!")
		return
	
	var hud_node = game_main.get_node_or_null("HUD")
	if not hud_node:
		push_error("❌ HUD node não encontrado!")
		return
	
	var popup = _STAT_BOOST_POPUP.instantiate()
	hud_node.add_child(popup)
	popup.show_text(text)

# ← NOVO: gancho pra efeito customizado (partícula/shader próprios).
# Se custom_effect_path estiver vazio, usa a partícula genérica que já roda em _on_body_entered.
func _spawn_custom_collect_effect(custom_effect_path: String) -> void:
	if custom_effect_path == "":
		return
	
	global.spawn_effect(custom_effect_path, Vector2.ZERO, global_position, false)
