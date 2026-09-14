extends SceneTree
## Testes determinísticos de WaveManager: início de wave, não permitir duas
## simultâneas, contagem correta de spawn ao longo do tempo (via step()),
## conclusão de wave, recompensa por kill e por wave, lock() (game over).
##
## Usa um EnemySpawner real com um mapa sintético mínimo (SPAWN-PATH-NEST em
## linha reta) — WaveManager chama EnemySpawner.spawn_enemy() de verdade,
## não um mock, então precisa de Grid/MapPath reais por trás. Os inimigos
## spawnados não são avançados via enemy.step() nestes testes (permanecem
## parados onde nasceram) — isso é intencional: mantém "quantos estão
## ativos" sob controle total do teste, sem side effects de movimento.
##
## Executar com:
##   godot --headless --path game --script res://tests/wave_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_start_next_wave_changes_state_and_emits_signal()
	_test_cannot_start_two_waves_simultaneously()
	_test_spawns_correct_count_over_time()
	_test_wave_completes_when_all_enemies_gone()
	_test_wave_completion_grants_reward()
	_test_kill_grants_reward()
	_test_lock_prevents_new_waves_and_spawning()
	_test_has_next_wave()
	_test_wave_with_multiple_groups_spawns_second_group_only_after_first_finishes()
	_test_reward_per_kill_comes_from_each_enemys_own_definition()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[wave_tests] ALL TESTS PASSED")
	else:
		print("[wave_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[wave_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _build_enemy_spawner() -> EnemySpawner:
	var definition := MapDefinition.new()
	definition.width = 3
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.SPAWN, CellType.PATH, CellType.NEST])

	var grid := Grid.new(definition)
	var map_path := MapPath.build(definition)

	var spawner := EnemySpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/BasicEnemy.tscn") as PackedScene
	spawner.setup(grid, map_path)
	return _track(spawner) as EnemySpawner


func _make_economy(starting: int = 0) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	return _track(economy) as Economy


## V2 — WaveDefinition agora é baseada em grupos (ver wave_definition.gd/wave_enemy_group.gd);
## este helper continua com a MESMA assinatura de sempre (wave_tests.gd testa o FLUXO de
## spawn/reward/conclusão do WaveManager, não a variedade de tipos — isso é coberto por
## enemy_definition_tests.gd) — só monta um único grupo em memória via `groups_override`
## (`EnemyDefinition.new()` sintético, sem precisar de um `.tres` real em disco).
func _build_wave(enemy_count: int, spawn_interval: float, reward_per_kill: int = 5, wave_completion_reward: int = 20) -> WaveDefinition:
	var enemy_def := EnemyDefinition.new()
	enemy_def.reward_per_kill = reward_per_kill
	var wave := WaveDefinition.new()
	wave.groups_override = [WaveEnemyGroup.new(enemy_def, enemy_count, spawn_interval)]
	wave.wave_completion_reward = wave_completion_reward
	return wave


func _build_wave_manager(waves: Array[WaveDefinition], enemy_spawner: EnemySpawner, economy: Economy) -> WaveManager:
	var manager := WaveManager.new()
	manager.waves = waves
	manager.setup(enemy_spawner, economy)
	return _track(manager) as WaveManager


func _kill_all_active(spawner: EnemySpawner) -> void:
	for enemy in spawner.get_active_enemies().duplicate():
		enemy.take_damage(enemy.max_hp)


func _test_start_next_wave_changes_state_and_emits_signal() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var wave := _build_wave(3, 1.0)
	var manager := _build_wave_manager([wave], spawner, economy)

	var received := [false]
	manager.wave_started.connect(func(_i: int, _w: WaveDefinition) -> void: received[0] = true)

	manager.start_next_wave()

	_check(manager.is_wave_active(), "wave should be active after start_next_wave")
	_check(manager.current_wave_index == 0, "current_wave_index should be 0, got %d" % manager.current_wave_index)
	_check(received[0], "wave_started signal should be emitted")


func _test_cannot_start_two_waves_simultaneously() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var manager := _build_wave_manager([_build_wave(3, 1.0), _build_wave(2, 1.0)], spawner, economy)

	manager.start_next_wave()
	var first_index := manager.current_wave_index
	manager.start_next_wave()  # deveria ser ignorado — já existe uma wave ativa
	_check(manager.current_wave_index == first_index,
		"starting a wave while one is already active should be a no-op")


func _test_spawns_correct_count_over_time() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var wave := _build_wave(4, 1.0)
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.start_next_wave()
	for i in range(4):
		manager.step(1.0)  # cada 1.0s (== spawn_interval) deveria spawnar exatamente 1

	_check(spawner.get_active_enemies().size() == 4,
		"should have spawned exactly 4 enemies, got %d" % spawner.get_active_enemies().size())


func _test_wave_completes_when_all_enemies_gone() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var wave := _build_wave(2, 0.5)
	var manager := _build_wave_manager([wave], spawner, economy)

	var completed := [false]
	manager.wave_completed.connect(func(_i: int, _w: WaveDefinition) -> void: completed[0] = true)

	manager.start_next_wave()
	manager.step(0.5)  # spawna #1
	manager.step(0.5)  # spawna #2, entra em WAITING_FOR_CLEAR

	_check(not completed[0], "wave should not be complete while enemies are still active")

	_kill_all_active(spawner)
	manager.step(0.1)  # próximo step deveria detectar a lista vazia e completar

	_check(completed[0], "wave should complete once all spawned enemies are gone")
	_check(manager.state == WaveManager.State.IDLE, "state should return to IDLE after completion")


func _test_wave_completion_grants_reward() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy(0)
	var wave := _build_wave(1, 0.1, 5, 20)
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.start_next_wave()
	manager.step(0.1)  # spawna o único inimigo
	_kill_all_active(spawner)
	manager.step(0.1)  # completa a wave

	_check(economy.coins == 5 + 20,
		"should have received kill reward (5) + wave completion reward (20), got %d" % economy.coins)


func _test_kill_grants_reward() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy(0)
	var wave := _build_wave(2, 0.1, 5, 20)
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.start_next_wave()
	manager.step(0.1)  # spawna #1

	var enemy: BasicEnemy = spawner.get_active_enemies()[0]
	enemy.take_damage(enemy.max_hp)

	_check(economy.coins == 5, "killing one enemy should grant reward_per_kill, got %d" % economy.coins)


func _test_lock_prevents_new_waves_and_spawning() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var wave := _build_wave(3, 0.1)
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.lock()
	manager.start_next_wave()
	_check(not manager.is_wave_active(), "locked WaveManager should not start a new wave")

	manager.step(1.0)
	_check(spawner.get_active_enemies().is_empty(),
		"locked WaveManager should not spawn anything even if step() is called")


func _test_has_next_wave() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()
	var manager := _build_wave_manager([_build_wave(1, 0.1)], spawner, economy)
	_check(manager.has_next_wave(), "should have a next wave before starting any")
	manager.start_next_wave()
	_check(not manager.has_next_wave(), "should not have a next wave after starting the only one available")


## V2 — "waves intermediárias: combinação de inimigos" (ver EnemyDefinition/WaveEnemyGroup):
## um grupo só começa a spawnar depois que o grupo anterior termina, mesmo que os dois usem
## intervalos diferentes.
func _test_wave_with_multiple_groups_spawns_second_group_only_after_first_finishes() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy()

	var group_a_def := EnemyDefinition.new()
	group_a_def.display_name = "A"
	var group_b_def := EnemyDefinition.new()
	group_b_def.display_name = "B"

	var wave := WaveDefinition.new()
	wave.groups_override = [
		WaveEnemyGroup.new(group_a_def, 2, 1.0),
		WaveEnemyGroup.new(group_b_def, 3, 0.5),
	]
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.start_next_wave()
	manager.step(1.0)  # spawna A #1
	manager.step(1.0)  # spawna A #2 — grupo A completo (2/2)
	_check(spawner.get_active_enemies().size() == 2, "deveriam existir 2 inimigos do grupo A antes do grupo B começar")
	for enemy in spawner.get_active_enemies():
		_check(enemy.definition == group_a_def, "os 2 primeiros inimigos deveriam ser do grupo A")

	manager.step(0.5)  # grupo B começa: spawna B #1
	_check(spawner.get_active_enemies().size() == 3, "grupo B deveria começar a spawnar assim que o grupo A terminar")
	_check(spawner.get_active_enemies()[2].definition == group_b_def, "o 3º inimigo deveria já ser do grupo B")

	manager.step(0.5)  # B #2
	manager.step(0.5)  # B #3 — wave inteira (2 + 3) spawnada
	_check(spawner.get_active_enemies().size() == 5, "wave deveria ter spawnado os 5 inimigos dos 2 grupos ao todo, got %d" % spawner.get_active_enemies().size())
	_check(manager.state == WaveManager.State.WAITING_FOR_CLEAR,
		"depois do último grupo spawnar tudo, o estado deveria virar WAITING_FOR_CLEAR")


## V2 — reward_per_kill agora vem do EnemyDefinition de CADA inimigo (não mais um valor único por
## wave) — necessário pra uma wave mista fazer sentido economicamente (Tanque vale mais que Enxame).
func _test_reward_per_kill_comes_from_each_enemys_own_definition() -> void:
	var spawner := _build_enemy_spawner()
	var economy := _make_economy(0)

	var cheap_def := EnemyDefinition.new()
	cheap_def.reward_per_kill = 2
	var expensive_def := EnemyDefinition.new()
	expensive_def.reward_per_kill = 20

	var wave := WaveDefinition.new()
	wave.groups_override = [
		WaveEnemyGroup.new(cheap_def, 1, 0.1),
		WaveEnemyGroup.new(expensive_def, 1, 0.1),
	]
	var manager := _build_wave_manager([wave], spawner, economy)

	manager.start_next_wave()
	manager.step(0.1)  # spawna o "barato"
	spawner.get_active_enemies()[0].take_damage(999)
	_check(economy.coins == 2, "matar o inimigo 'barato' deveria dar só a recompensa dele (2), got %d" % economy.coins)

	manager.step(0.1)  # spawna o "caro"
	spawner.get_active_enemies()[0].take_damage(999)
	_check(economy.coins == 2 + 20,
		"matar o inimigo 'caro' deveria somar a recompensa DELE (20), não repetir a do primeiro, got %d" % economy.coins)
