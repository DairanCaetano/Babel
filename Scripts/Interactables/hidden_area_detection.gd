extends Area2D
class_name HiddenArea

@export_category("Persistence")
@export var hidden_area_id: String = ""

@export_category("Objects")
@export var tilemap_layer: TileMapLayer

@export_category("Audio Settings")
@export var hidden_area_audio: AudioStreamPlayer2D
@export var audio_cooldown: float = 3.0

var _can_play_audio: bool = true
var _audio_cooldown_timer: Timer

func _ready():
	if hidden_area_id == "":
		push_error("❌ HiddenArea: Configure o hidden_area_id no Inspector!")
		return
	
	if _was_already_destroyed():
		print("🚫 HiddenArea já foi destruída antes: ", hidden_area_id)
		queue_free()
		return
	
	if not tilemap_layer or not is_instance_valid(tilemap_layer):
		push_warning("⚠️ HiddenArea: TileMapLayer inválido - desativando área")
		monitoring = false
		return
	
	print("✅ HiddenArea configurada: ", hidden_area_id)
	
	_audio_cooldown_timer = Timer.new()
	_audio_cooldown_timer.one_shot = true
	_audio_cooldown_timer.wait_time = audio_cooldown
	_audio_cooldown_timer.timeout.connect(_on_audio_cooldown_timeout)
	add_child(_audio_cooldown_timer)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _was_already_destroyed() -> bool:
	return serialization.game_data.get("destroyed_walls", []).has(hidden_area_id)

func save_destroyed_state() -> void:
	if not serialization.game_data.has("destroyed_walls"):
		serialization.game_data["destroyed_walls"] = []
	
	if not serialization.game_data["destroyed_walls"].has(hidden_area_id):
		serialization.game_data["destroyed_walls"].append(hidden_area_id)
		print("💾 HiddenArea salva como destruída: ", hidden_area_id)

func _on_body_entered(body):
	if not tilemap_layer or not is_instance_valid(tilemap_layer):
		return
	if body.is_in_group("player"):
		print("✅ Player entrou - fade iniciado")
		if _can_play_audio and hidden_area_audio:
			hidden_area_audio.play()
			_can_play_audio = false
			_audio_cooldown_timer.start()
			print("🔊 Áudio de área secreta tocado - cooldown iniciado")
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(tilemap_layer, "modulate:a", 0.1, 0.5)

func _on_body_exited(body):
	if not tilemap_layer or not is_instance_valid(tilemap_layer):
		return
	if body.is_in_group("player"):
		print("✅ Player saiu - restaurando alpha")
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(tilemap_layer, "modulate:a", 1.0, 0.5)

func _on_audio_cooldown_timeout() -> void:
	_can_play_audio = true
	print("🔊 Cooldown de áudio resetado")
