extends CharacterBody2D
class_name SamyazaNPC

@export var trigger_area: Area2D
@export var animated_sprite: AnimatedSprite2D
@export var azazel_scene: PackedScene        ## Arrastar a cena do Azazel aqui
@export var azazel_spawn_point: Marker2D     ## Marker2D de onde o Azazel vai aparecer

const DIALOG_FLAG := "samyaza_egito_met"
const MAP_ID := "map_item"
const MAP_ICON_PATH := "res://sprites/Items/Mapa_Itens.png"

var _player: BaseCharacter = null
var _dialog_done: bool = false
var _azazel: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if serialization.game_data.get(DIALOG_FLAG, false):
		queue_free()
		return

	if not trigger_area:
		push_error("⚠️ [SamyazaNPC] trigger_area não configurado!")
		return

	if not animated_sprite:
		push_error("⚠️ [SamyazaNPC] animated_sprite não configurado!")
		return

	animated_sprite.play("Rest")
	trigger_area.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body is BaseCharacter:
		return

	if _dialog_done:
		return

	trigger_area.body_entered.disconnect(_on_trigger_body_entered)
	trigger_area.monitoring = false

	_player = body
	_start_sequence()

func _start_sequence() -> void:
	_player._is_in_cinematic = true

	animated_sprite.play("Turn")
	await animated_sprite.animation_finished
	animated_sprite.play("Idle")

	await _spawn_azazel()
	await get_tree().create_timer(0.3, true).timeout
	await _play_dialog()
	await _give_map()
	await _finish_sequence()

func _spawn_azazel() -> void:
	if not azazel_scene:
		push_error("⚠️ [SamyazaNPC] azazel_scene não configurado!")
		return
	if not azazel_spawn_point:
		push_error("⚠️ [SamyazaNPC] azazel_spawn_point não configurado!")
		return

	_azazel = azazel_scene.instantiate()
	_azazel.global_position = azazel_spawn_point.global_position
	get_tree().current_scene.add_child(_azazel)

	if _azazel.has_method("play_arrive"):
		await _azazel.play_arrive(false)

func _play_dialog() -> void:
	var dialog_data := {
		"dialog_name": "samyaza_egito",
		"dialog_type": "intro",
		"lines": [
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_0_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_1_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_2_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_3_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_4_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_5_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_6_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_7_AZAZEL")},
			{"character": "tola",    "text": tr("DIALOG_SAMYAZA_EGITO_8_TOLA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_9_SAMYAZA")},
			{"character": "tola",    "text": tr("DIALOG_SAMYAZA_EGITO_10_TOLA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_11_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_12_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_13_SAMYAZA")},
			{"character": "tola",    "text": tr("DIALOG_SAMYAZA_EGITO_14_TOLA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_15_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_16_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_17_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_18_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_19_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_20_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_21_SAMYAZA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_22_SAMYAZA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_23_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_24_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_25_SAMYAZA")},
			{"character": "tola",    "text": tr("DIALOG_SAMYAZA_EGITO_26_TOLA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_27_SAMYAZA")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_28_SAMYAZA")},
			{"character": "azazel",  "text": tr("DIALOG_SAMYAZA_EGITO_29_AZAZEL")},
			{"character": "samyaza", "text": tr("DIALOG_SAMYAZA_EGITO_30_SAMYAZA")},
		]
	}

	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		push_error("⚠️ [SamyazaNPC] HUD não encontrado!")
		return

	var dialog_scene = preload("res://Scenes/Inventory/dialog_system.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.dialog_data = dialog_data
	hud.add_child(dialog)

	await dialog.is_finished

func _give_map() -> void:
	if is_instance_valid(_player):
		_player.update_map_state(true)

	serialization.game_data["has_map"] = true
	if not MAP_ID in serialization.game_data["collected_items"]:
		serialization.game_data["collected_items"].append(MAP_ID)

	_player.collect_item({
		"key": "ITEM_MAP_NAME",
		"name": tr("ITEM_MAP_NAME"),
		"path": MAP_ICON_PATH,
		"type": "key_item",
		"description": tr("ITEM_MAP_DESC"),
		"value": 0,
		"spawn_probability": 1.0,
		"amount_to_drop": 1
	}, false)

	var ability_data := {
		"id": MAP_ID,
		"title": tr("ITEM_MAP_NAME"),
		"description": tr("ITEM_MAP_DESC"),
		"icon_path": MAP_ICON_PATH
	}

	if not serialization.game_data.has("collected_abilities"):
		serialization.game_data["collected_abilities"] = []
	serialization.game_data["collected_abilities"].append(ability_data)

	var game_main = get_tree().get_first_node_in_group("game_main")
	if not game_main:
		return

	var hud_node = game_main.get_node_or_null("HUD")
	if not hud_node:
		return

	var ability_scene = preload("res://Scenes/Inventory/abilities_display_system.tscn")
	var ability_display = ability_scene.instantiate()
	hud_node.add_child(ability_display)

	ability_display.show_ability(ability_data)
	await ability_display.display_finished

func _finish_sequence() -> void:
	_dialog_done = true

	# Azazel vai embora
	if is_instance_valid(_azazel) and _azazel.has_method("play_gone"):
		await _azazel.play_gone()
	if is_instance_valid(_azazel):
		_azazel.queue_free()

	serialization.game_data[DIALOG_FLAG] = true
	serialization.save_data()

	if is_instance_valid(_player):
		_player._is_in_cinematic = false

	# ✅ NÃO faz queue_free aqui — Samyaza some quando a fase recarregar
	# O _ready() checa a flag DIALOG_FLAG e faz queue_free automaticamente
