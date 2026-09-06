extends BaseLevel  # ← Herda de BaseLevel!
class_name TestLevel

@export_category("Test Settings")
@export_file("*.tscn") var level_to_test: String = "res://Scenes/Fases/tebes_t1.tscn"
@export var spawn_point: String = "default"

var game_instance: GameMain

func _ready() -> void:
	super._ready()  # Chama o _ready do BaseLevel
	print("🧪 Level de teste carregado: ", level_name)
	print("\n🧪 ========== TEST SCENE ==========")
	print("  📂 Level a testar: ", level_to_test)
	print("  📍 Spawn: ", spawn_point)
	print("===================================\n")
	
	_load_game()
	
	# ✅ Aguarda mais frames para garantir que Game está pronto
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	_load_test_level()
	
	print("✅ Test Scene pronta!\n")

func _load_game() -> void:
	print("🎮 Carregando Game.tscn...")
	
	var game_path = "res://Scenes/Base/game.tscn"
	
	if not ResourceLoader.exists(game_path):
		push_error("❌ Game.tscn não encontrada em: ", game_path)
		return
	
	var game_scene = load(game_path)
	game_instance = game_scene.instantiate()
	
	# ✅ CRÍTICO: Setar ANTES de add_child
	game_instance.skip_auto_load = true
	
	add_child(game_instance)
	
	print("  ✓ Game.tscn carregada (modo teste)")
	print("  ✓ Player: ", game_instance.character.name if game_instance.character else "não encontrado")
	print("  ✓ Camera: ", game_instance.camera.name if game_instance.camera else "não encontrada")
	print("  ✓ HUD: ", game_instance.hud.name if game_instance.hud else "não encontrado")

func _load_test_level() -> void:
	print("📦 Carregando level de teste...")
	
	if not game_instance:
		push_error("❌ Game não foi instanciado!")
		return
	
	if not game_instance.has_method("load_level"):
		push_error("❌ Game não tem método load_level!")
		return
	
	game_instance.load_level(level_to_test, spawn_point)
	
	print("  ✓ Level de teste carregado via Game.load_level()")

# Exemplo: debug info
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		print("📍 Player em: ", global.character.global_position)
