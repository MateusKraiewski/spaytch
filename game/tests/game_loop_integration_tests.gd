extends SceneTree
## Teste de integração do game loop completo da Phase 0.5: Main.tscn real,
## ponta a ponta.
##
## Cenário A — ciclo completo: mapa carrega, ovos/economia existem,
## Velociraptor pré-selecionado é colocado (custo descontado), Wave 1 é
## iniciada pelo botão da HUD, inimigos são spawnados e perseguem o
## caminho, o Velociraptor ataca e mata inimigos, coins aumentam, a wave
## termina.
##
## Cenário B — sem nenhum dinossauro colocado: um inimigo alcança o ninho,
## um ovo recebe dano, e o inimigo desaparece (queue_free).
##
## Mesma técnica das fases anteriores (integration_tests.gd,
## combat_integration_tests.gd): `await process_frame` só para deixar
## NOTIFICATION_READY se propagar depois de add_child(main); daí em diante
## 100% determinístico via step(delta) chamado diretamente em cada entidade
## (WaveManager/BasicEnemy/Dinosaur/Projectile), sem depender de frames
## reais.
##
## Executar com:
##   godot --headless --path game --script res://tests/game_loop_integration_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[game_loop_integration_tests] FAIL: %s" % message)


func _initialize() -> void:
	await _test_full_game_loop()
	await _test_enemy_reaches_nest_damages_egg()

	if _failures == 0:
		print("[game_loop_integration_tests] ALL TESTS PASSED")
	else:
		print("[game_loop_integration_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _load_main() -> Node:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	return packed.instantiate()


func _advance(dt: float, wave_manager: WaveManager, enemy_spawner: EnemySpawner, dinosaurs: Node, projectiles: Node) -> void:
	wave_manager.step(dt)
	for dino in dinosaurs.get_children():
		if dino is Dinosaur:
			dino.step(dt)
	for proj in projectiles.get_children():
		if proj is Projectile:
			proj.step(dt)
	for enemy in enemy_spawner.get_active_enemies().duplicate():
		enemy.step(dt)


func _test_full_game_loop() -> void:
	var main := _load_main()
	var enemy_spawner := main.get_node("EnemySpawner") as EnemySpawner
	var egg_manager := main.get_node("EggManager") as EggManager
	var economy := main.get_node("Economy") as Economy
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs := main.get_node("Dinosaurs") as Node
	var projectiles := main.get_node("Projectiles") as Node
	var hud := main.get_node("HUD") as HUD

	root.add_child(main)
	await process_frame

	_check(egg_manager.get_eggs().size() == 3, "Vale dos Ovos deveria criar 3 eggs, got %d" % egg_manager.get_eggs().size())
	_check(economy.coins == economy.starting_coins, "economy deveria começar com starting_coins")
	_check(placement_controller.state == PlacementController.State.PLACING,
		"Velociraptor deveria estar pré-selecionado ao iniciar")

	# Placement: zona DPS do Vale dos Ovos, colada ao trecho reto mais longo do caminho.
	var grid := grid_manager.grid
	var placement_coord := Vector2i(9, 7)
	var coins_before_placement := economy.coins
	var expected_cost := placement_controller.selected_definition.cost

	placement_controller.on_pointer_pressed(grid.cell_center_world(placement_coord))

	_check(dinosaurs.get_child_count() == 1, "deveria existir exatamente 1 Dinosaur colocado")
	_check(economy.coins == coins_before_placement - expected_cost,
		"coins deveriam ser descontados pelo custo do Velociraptor, esperado %d, got %d" %
			[coins_before_placement - expected_cost, economy.coins])
	_check(grid.get_cell(placement_coord).occupied, "célula deveria ficar ocupada após o placement")

	# Wave 1 via o mesmo caminho real do botão da HUD.
	hud.start_wave_pressed.emit()
	_check(wave_manager.is_wave_active(), "wave deveria estar ativa após 'Iniciar Onda'")

	var coins_before_combat := economy.coins
	var dt := 0.05
	var iterations := 0
	var max_iterations := 20000
	while wave_manager.is_wave_active() and iterations < max_iterations:
		_advance(dt, wave_manager, enemy_spawner, dinosaurs, projectiles)
		iterations += 1

	_check(iterations < max_iterations, "wave 1 não deveria exceder o limite de segurança de iterações")
	_check(not wave_manager.is_wave_active(), "wave deveria ter completado")
	_check(economy.coins > coins_before_combat,
		"coins deveriam ter aumentado com kills/recompensa de wave, %d -> %d" %
			[coins_before_combat, economy.coins])
	_check(not egg_manager.all_destroyed(), "o jogo não deveria estar em game over após só a wave 1")

	root.remove_child(main)
	main.free()


func _test_enemy_reaches_nest_damages_egg() -> void:
	var main := _load_main()
	var enemy_spawner := main.get_node("EnemySpawner") as EnemySpawner
	var egg_manager := main.get_node("EggManager") as EggManager
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var hud := main.get_node("HUD") as HUD

	root.add_child(main)
	await process_frame

	var egg := egg_manager.get_eggs()[0]
	var egg_hp_before := egg.hp

	# Nenhum dinossauro é colocado neste cenário — o inimigo percorre o
	# caminho inteiro sem oposição.
	hud.start_wave_pressed.emit()
	wave_manager.step(wave_manager.waves[0].spawn_interval)  # dispara o primeiro spawn da wave

	_check(enemy_spawner.get_active_enemies().size() >= 1, "deveria existir ao menos 1 inimigo spawnado")
	var enemy: BasicEnemy = enemy_spawner.get_active_enemies()[0]

	var dt := 0.05
	var iterations := 0
	var max_iterations := 20000
	while is_instance_valid(enemy) and enemy.is_active() and iterations < max_iterations:
		enemy.step(dt)
		iterations += 1

	_check(iterations < max_iterations,
		"inimigo sem dinossauro no caminho deveria alcançar o ninho dentro do limite de segurança")
	_check(egg.hp < egg_hp_before,
		"o ovo deveria ter recebido dano quando o inimigo chegou ao ninho, hp antes=%d depois=%d" %
			[egg_hp_before, egg.hp])

	await process_frame  # deixa o queue_free() do inimigo (chamado por EggManager) ser processado
	_check(not is_instance_valid(enemy), "o inimigo deveria ter desaparecido (queue_free) após chegar ao ninho")

	root.remove_child(main)
	main.free()
