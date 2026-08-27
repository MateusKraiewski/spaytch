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


func _build_wave(enemy_count: int, spawn_interval: float, reward_per_kill: int = 5, wave_completion_reward: int = 20) -> WaveDefinition:
	var wave := WaveDefinition.new()
	wave.enemy_count = enemy_count
	wave.spawn_interval = spawn_interval
	wave.reward_per_kill = reward_per_kill
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
