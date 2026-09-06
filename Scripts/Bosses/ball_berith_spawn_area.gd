extends Area2D
class_name BaalBerithSpawn

@export_category("Objects")
@export var collision: CollisionShape2D
@export var spawn: Marker2D

@export_category("Boss Reference")
@export var boss: BaalBerith  # Referência ao boss para checar fase e estado do roar

@export_category("Spawn Settings")
@export var enemy_scene: PackedScene
@export var max_minions: int = 4  # Fallback, usado só se "boss" não estiver setado
@export var delay_between_spawns: float = 1.0  # Delay entre inimigos da mesma leva
@export var respawn_delay: float = 3.0  # Delay entre levas

@export_category("Phase Minion Caps")
@export var phase_1_max_minions: int = 1  # Fase 1: só 1 minion vivo por vez
@export var phase_2_max_minions: int = 2  # Fase 2: até 2 minions vivos por vez

@export_category("Enemy 1 Spawn Range")
@export var enemy1_x_range: Vector2 = Vector2(5, 10)
@export var enemy1_y_range: Vector2 = Vector2(-20, 20)

@export_category("Enemy 2 Spawn Range")
@export var enemy2_x_range: Vector2 = Vector2(100, 120)
@export var enemy2_y_range: Vector2 = Vector2(0, 0)  # por padrão 0..0 = mesmo Y do marker

var player_inside: bool = false
var is_spawning: bool = false   # controla se já existe um ciclo rodando
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_minions: Array = []  # Array para rastrear minions vivos

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	rng.randomize()
	print("🎯 BaalBerithSpawn inicializado")
	print("📊 Cap fase 1: ", phase_1_max_minions, " | Cap fase 2: ", phase_2_max_minions)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		print("👤 Jogador entrou na área de spawn!")
		player_inside = true
		# Só começa se não houver ciclo rodando
		if not is_spawning:
			is_spawning = true
			_spawn_cycle()

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		print("👤 Jogador saiu da área de spawn")
		player_inside = false

# Retorna o limite de minions vivos de acordo com a fase atual do boss.
# Se não houver referência ao boss, cai no "max_minions" antigo como fallback.
func _get_phase_max_minions() -> int:
	if not boss or not is_instance_valid(boss):
		return max_minions

	if boss.current_phase == 1:
		return phase_1_max_minions
	else:
		return phase_2_max_minions

func _spawn_cycle() -> void:
	# 🔒 Trava de roar: não invoca nenhum minion antes do Baal Berith
	# terminar a animação de roar inicial por completo (anticipation + roar + duração).
	# Usa "initial_roar_complete" e não "has_roared", pois has_roared já vira
	# true no INÍCIO do roar (inclusive se o jogador já estiver na área quando
	# o boss é instanciado pelo BerithTree, o que disparava o spawn quase na hora).
	if boss and is_instance_valid(boss):
		while not boss.initial_roar_complete and player_inside:
			await get_tree().create_timer(0.2).timeout

		# Jogador saiu antes do boss terminar o roar
		if not player_inside:
			is_spawning = false
			print("🚪 Jogador saiu antes do roar terminar, spawn cancelado.")
			return

		print("📣 Roar concluído, spawn de minions liberado.")

	# Loop único que roda enquanto o jogador estiver dentro da área
	while player_inside:
		_clean_dead_minions()

		var phase_max = _get_phase_max_minions()

		# Só spawna se tiver espaço dentro do limite da fase atual
		if _get_active_minion_count() < phase_max:
			_spawn_enemies()
		else:
			print("⚠️ Limite de ", phase_max, " minion(s) (fase ", str(boss.current_phase) if boss else "?", ") atingido. Aguardando...")

		# aguarda respawn_delay antes de tentar nova leva
		print("⏳ Esperando ", respawn_delay, " segundos para próxima verificação...")
		await get_tree().create_timer(respawn_delay).timeout

	# jogador saiu -> libera para reiniciar no próximo enter
	is_spawning = false
	print("🚪 Jogador não está mais na área, spawn parado.")

func _clean_dead_minions() -> void:
	# Remove referências de minions que já foram destruídos
	var cleaned_count = 0
	for i in range(active_minions.size() - 1, -1, -1):
		if not is_instance_valid(active_minions[i]):
			active_minions.remove_at(i)
			cleaned_count += 1

	if cleaned_count > 0:
		print("🧹 Limpou ", cleaned_count, " minions mortos. Total ativo: ", active_minions.size())

func _get_active_minion_count() -> int:
	_clean_dead_minions()
	return active_minions.size()

func _spawn_enemies() -> void:
	if not enemy_scene:
		print("❌ Enemy scene não configurado!")
		return

	if not spawn:
		print("❌ Spawn Marker2D não configurado!")
		return

	var phase_max = _get_phase_max_minions()
	var current_count = _get_active_minion_count()
	var can_spawn = phase_max - current_count

	if can_spawn <= 0:
		print("⛔ Não pode spawnar: limite da fase atingido")
		return

	# Nunca spawna mais que 2 por leva (e nunca mais do que o espaço livre na fase)
	var to_spawn = min(2, can_spawn)
	print("🎬 Iniciando spawn de ", to_spawn, " inimigo(s) - Total atual: ", current_count, "/", phase_max)

	# -------- Inimigo 1 --------
	if to_spawn >= 1:
		var enemy1 = enemy_scene.instantiate()
		get_tree().current_scene.add_child(enemy1)
		active_minions.append(enemy1)

		var x_offset1 = rng.randf_range(enemy1_x_range.x, enemy1_x_range.y)
		var y_offset1 = rng.randf_range(enemy1_y_range.x, enemy1_y_range.y)
		var spawn_position1 = spawn.global_position + Vector2(x_offset1, y_offset1)
		enemy1.global_position = spawn_position1
		print("👹 Inimigo 1 spawnado em: ", spawn_position1)

		# Delay entre inimigos (se > 0)
		if delay_between_spawns > 0.0 and to_spawn > 1:
			await get_tree().create_timer(delay_between_spawns).timeout

	# -------- Inimigo 2 --------
	if to_spawn >= 2:
		var enemy2 = enemy_scene.instantiate()
		get_tree().current_scene.add_child(enemy2)
		active_minions.append(enemy2)

		var x_offset2 = rng.randf_range(enemy2_x_range.x, enemy2_x_range.y)
		var y_offset2 = rng.randf_range(enemy2_y_range.x, enemy2_y_range.y)
		var spawn_position2 = spawn.global_position + Vector2(x_offset2, y_offset2)
		enemy2.global_position = spawn_position2
		print("👹 Inimigo 2 spawnado em: ", spawn_position2)

	print("✅ Leva concluída! Total de minions ativos: ", _get_active_minion_count(), "/", phase_max)

# Função para destruir todos os minions (chamada quando Baal Berith morre)
func destroy_all_minions() -> void:
	print("💀 DESTRUINDO TODOS OS MINIONS DO BAAL BERITH")

	for minion in active_minions:
		if is_instance_valid(minion):
			print("👹 Destruindo minion: ", minion.name)
			minion.queue_free()

	active_minions.clear()
	print("✅ Todos os minions foram destruídos!")
