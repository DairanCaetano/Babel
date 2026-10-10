extends Node2D
class_name EgitoIntroSequencer

@export var trigger_area: Area2D          ## Arrastar a Area2D com a colisão do player
@export var npc_spawn_point: Marker2D     ## Arrastar o Marker2D onde Azazel vai aparecer
@export var npc_scene: PackedScene        ## Cena do Azazel

const INTRO_FLAG := "egito_intro_played"

var _player: Node
var _npc: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if serialization.game_data.get(INTRO_FLAG, false):
		queue_free()
		return

	if not trigger_area:
		push_error("⚠️ [EgitoIntroSequencer] trigger_area não configurado!")
		return

	trigger_area.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	trigger_area.body_entered.disconnect(_on_trigger_body_entered)
	trigger_area.monitoring = false

	_player = body
	_start_intro()

func _start_intro() -> void:
	_player._is_in_cinematic = true

	await get_tree().create_timer(0.3, true).timeout
	await _spawn_npc()
	await get_tree().create_timer(0.3, true).timeout
	await _play_dialog()
	await _finish_intro()

func _spawn_npc() -> void:
	if not npc_scene:
		push_error("⚠️ [EgitoIntroSequencer] npc_scene não configurado!")
		return

	if not npc_spawn_point:
		push_error("⚠️ [EgitoIntroSequencer] npc_spawn_point não configurado!")
		return

	_npc = npc_scene.instantiate()
	get_tree().current_scene.add_child(_npc)
	_npc.global_position = npc_spawn_point.global_position

	if _npc.has_method("play_arrive"):
		await _npc.play_arrive()
	else:
		push_error("⚠️ [EgitoIntroSequencer] NPC não tem método play_arrive!")

func _play_dialog() -> void:
	var dialog_data := {
		"dialog_name": "egito_intro",
		"dialog_type": "intro",
		"lines": [
			{"character": "tola",    "text": tr("DIALOG_EGITO_INTRO_0_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_INTRO_1_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_EGITO_INTRO_2_TOLA")},
			{"character": "azazel",  "text": tr("DIALOG_EGITO_INTRO_3_AZAZEL")},
		]
	}

	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		push_error("⚠️ [EgitoIntroSequencer] HUD não encontrado!")
		return

	var dialog_scene = preload("res://Scenes/Inventory/dialog_system.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.dialog_data = dialog_data
	hud.add_child(dialog)

	await dialog.is_finished

func _finish_intro() -> void:
	if is_instance_valid(_npc) and _npc.has_method("play_gone"):
		await _npc.play_gone()

	if is_instance_valid(_npc):
		_npc.queue_free()

	serialization.game_data[INTRO_FLAG] = true
	serialization.save_data()

	if is_instance_valid(_player):
		_player._is_in_cinematic = false

	queue_free()
