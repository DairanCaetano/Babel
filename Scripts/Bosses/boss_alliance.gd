extends RefCounted
class_name BossAlliance

# Funções compartilhadas pelos spawners que oferecem aliança (Disco do Rá, ...).
#
#   var accepted: bool = await BossAlliance.ask(self, "BOSS_RA_CALMED",
#   		"BOSS_RA_ALLIANCE_QUESTION", "BOSS_RA_YES", "BOSS_RA_NO")
#
# Mostra a mesma sequência da BerithTree: tremor → mensagem → pergunta Sim/Não.
# Retorna true se o player escolheu a opção 1 (Sim).

const DIALOG_SCENE: String = "res://Scenes/Inventory/dialog_options.tscn"


static func ask(caller: Node, calmed_key: String, question_key: String, yes_key: String, no_key: String) -> bool:
	var tree: SceneTree = caller.get_tree()

	var game_main = tree.get_first_node_in_group("game_main")
	var hud_node: Node = game_main.get_node_or_null("HUD") if game_main else null
	if not hud_node:
		push_error("BossAlliance: HUD não encontrado — seguindo sem aliança")
		return false

	var dialog = (load(DIALOG_SCENE) as PackedScene).instantiate()
	hud_node.add_child(dialog)

	var camera = tree.get_first_node_in_group("camera")
	if camera and camera.has_method("shake_camera"):
		camera.shake_camera(3, 1.0)
	await tree.create_timer(1.0, false).timeout

	# 1) Mensagem sem opções
	dialog.visible = true
	dialog._is_active = false
	dialog._options_text.text = tr_key(calmed_key)
	if dialog._dialog_option_1:
		dialog._dialog_option_1.visible = false
	if dialog._dialog_option_2:
		dialog._dialog_option_2.visible = false
	dialog._current_selection = 1
	dialog._update_selection_visual()
	await tree.create_timer(2.0, false).timeout
	if not is_instance_valid(dialog):
		return false

	# 2) Some rapidinho
	_set_dialog_parts_visible(dialog, false)
	await tree.create_timer(0.3, false).timeout
	if not is_instance_valid(dialog):
		return false

	# 3) Pergunta com Sim / Não
	_set_dialog_parts_visible(dialog, true)
	if dialog._dialog_option_1:
		dialog._dialog_option_1.visible = true
	if dialog._dialog_option_2:
		dialog._dialog_option_2.visible = true
	dialog._options_text.text = tr_key(question_key)
	dialog._option_1_text.text = tr_key(yes_key)
	dialog._option_2_text.text = tr_key(no_key)
	dialog._current_selection = 1
	dialog._update_selection_visual()
	dialog._is_active = true

	var choice: int = await dialog.option_selected
	dialog.get_tree().create_timer(0.1, false).timeout.connect(dialog.queue_free)
	return choice == 1


static func _set_dialog_parts_visible(dialog: Node, value: bool) -> void:
	if dialog._texture:
		dialog._texture.visible = value
	if dialog._vbox_container:
		dialog._vbox_container.visible = value
	if dialog._options_text:
		dialog._options_text.visible = value


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


# Remove do inventário o item com essa key e zera a flag do save.
static func remove_item(item_key: String, flag_key: String) -> void:
	serialization.game_data[flag_key] = false
	if not global.inventory:
		return
	var inventory_data = global.inventory._inventory_data
	for slot_index in range(inventory_data.size()):
		var item = inventory_data[slot_index]
		if not item.is_empty() and item.get("key", "") == item_key:
			global.inventory.remove_item(slot_index)
			return


# Chama a sequência de vitória da fase atual (BaseLevel._start_victory_sequence)
static func trigger_victory_sequence(caller: Node) -> void:
	var game_main = caller.get_tree().get_first_node_in_group("game_main")
	var level: Node = game_main.current_level if game_main else caller.get_tree().current_scene
	if level and level.has_method("_start_victory_sequence"):
		level._start_victory_sequence()
	else:
		push_warning("BossAlliance: fase atual não tem _start_victory_sequence")
