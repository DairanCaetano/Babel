extends Collectables
class_name CollectableArchive

# ✅ collectible_id herdado da classe pai - configure no Inspector
# Exemplos: "tebes_1_archive_01", "tebes_2_archive_01"

@export_group("Archive Content")
@export var archive_icon: String = "res://sprites/Items/Arquivo_Itens1.png"


func _consume(_body: BaseCharacter) -> void:
	# ✅ Validação de ID
	if collectible_id == "":
		push_error("❌ CollectableArchive sem ID configurado: ", name)
		return
	
	# ✅ Criar dados do arquivo
	var archive_data = {
		"id": collectible_id,
		"title": tr("ARCHIVE_SIEGE_TITLE"),
		"content": tr("ARCHIVE_SIEGE_TEXT"),
		"path": archive_icon
	}
	
	# ✅ Adicionar aos arquivos coletados
	if not serialization.game_data.has("collected_archives"):
		serialization.game_data["collected_archives"] = []
	
	serialization.game_data["collected_archives"].append(archive_data)
	
	# ✅ Salvar
	serialization.save_data()
	
	
	# ✅ Mostrar na tela
	_show_archive_display(archive_data)
	
	# ✅ Atualizar página de arquivos no inventário
	if global.ui_inventory:
		global.ui_inventory.call_deferred("add_archive", archive_data)

func _show_archive_display(archive_data: Dictionary) -> void:
	print("🔍 Instanciando ArchiveDisplaySystem...")
	
	var game_hud = get_tree().get_first_node_in_group("game_main")
	if not game_hud:
		push_error("❌ Game HUD não encontrado!")
		return
	
	var hud_node = game_hud.get_node_or_null("HUD")
	if not hud_node:
		push_error("❌ HUD node não encontrado!")
		return
	
	var archive_scene = preload("res://Scenes/Inventory/archive_display_system.tscn")
	var archive_display = archive_scene.instantiate()
	
	hud_node.add_child(archive_display)
	print("✅ ArchiveDisplaySystem instanciado!")
	
	archive_display.show_archive(archive_data)
