extends SceneTree
## Teste de integração do vertical slice completo da Phase 0.4: carrega
## Main.tscn de verdade (wiring de produção — GridManager, EnemySpawner,
## PlacementController, PlacementPreview, Dinosaurs, Projectiles) e
## confirma ponta a ponta: Velociraptor pré-selecionado → placement numa
## célula BUILDABLE real do Vale dos Ovos → dinossauro passa a existir →
## inimigo real percorre o caminho → dinossauro mira/dispara → projétil
## acerta → dano é aplicado → inimigo morre antes de alcançar o ninho.
##
## Mesma técnica de Phase 0.3 (integration_tests.gd): `await process_frame`
## uma única vez para deixar NOTIFICATION_READY se propagar depois de
## add_child(main); daí em diante 100% determinístico, avançando
## BasicEnemy/Dinosaur/Projectile via step(delta) chamado diretamente, sem
## depender de frames reais do motor (evita a fragilidade mencionada na
## especificação).
##
## Desde a Phase 0.5, Main._ready() não spawna mais um inimigo sozinho —
## spawning é responsabilidade de WaveManager, disparado pelo jogador via
## HUD (fluxo de wave completo coberto por game_loop_integration_tests.gd).
## Este teste continua focado especificamente na mecânica de combate
## (targeting/disparo/dano/morte), chamando spawn_enemy() diretamente para
## obter UM inimigo, sem envolver wave/economia de recompensa.
##
## Executar com:
##   godot --headless --path game --script res://tests/combat_integration_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[combat_integration_tests] FAIL: %s" % message)


func _initialize() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn should load")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	var enemy_spawner := main.get_node("EnemySpawner") as EnemySpawner
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs_container := main.get_node("Dinosaurs") as Node
	var projectiles_container := main.get_node("Projectiles") as Node

	var spawned_enemy_holder := [null]
	enemy_spawner.enemy_spawned.connect(func(enemy: BasicEnemy) -> void: spawned_enemy_holder[0] = enemy)

	root.add_child(main)
	await process_frame  # deixa NOTIFICATION_READY se propagar (ver comentário no topo)

	enemy_spawner.spawn_enemy()  # Phase 0.5: spawn não é mais automático — chamado direto para este teste

	_check(spawned_enemy_holder[0] != null, "spawn_enemy() should have produced a BasicEnemy via the signal")
	_check(placement_controller.state == PlacementController.State.PLACING,
		"PlacementController deveria iniciar em PLACING (Velociraptor pré-selecionado)")
	_check(placement_controller.selected_definition != null
		and placement_controller.selected_definition.display_name == "Velociraptor",
		"Velociraptor deveria estar pré-selecionado")

	if spawned_enemy_holder[0] == null or placement_controller.state != PlacementController.State.PLACING:
		_finish()
		return

	var enemy: BasicEnemy = spawned_enemy_holder[0]
	var grid := grid_manager.grid

	# Célula BUILDABLE real da zona DPS do Vale dos Ovos, colada ao trecho
	# reto mais longo do caminho — ver docs/GAME_BIBLE.md / ARCHITECTURE.md.
	var placement_coord := Vector2i(9, 7)
	_check(placement_controller.is_valid_placement(placement_coord),
		"(9,7) deveria ser uma célula BUILDABLE livre no Vale dos Ovos")

	placement_controller.on_pointer_pressed(grid.cell_center_world(placement_coord))

	_check(placement_controller.state == PlacementController.State.IDLE,
		"deveria voltar para IDLE depois de colocar o dinossauro")
	_check(grid.get_cell(placement_coord).is_occupied(), "célula deveria ficar ocupada após o placement")
	_check(dinosaurs_container.get_child_count() == 1, "deveria existir exatamente 1 Dinosaur colocado")

	if dinosaurs_container.get_child_count() == 0:
		_finish()
		return

	var dinosaur := dinosaurs_container.get_child(0) as Dinosaur

	# Avança inimigo + dinossauro + projéteis em lockstep, de forma
	# determinística (sem depender de frames reais), até o inimigo morrer,
	# chegar ao ninho, ou o limite de segurança ser atingido.
	var dt := 0.05
	var iterations := 0
	var max_iterations := 5000
	while is_instance_valid(enemy) and enemy.is_active() and iterations < max_iterations:
		dinosaur.step(dt)
		for child in projectiles_container.get_children():
			if child is Projectile:
				child.step(dt)
		enemy.step(dt)
		iterations += 1

	_check(iterations < max_iterations, "combate não deveria exceder o limite de segurança de iterações")
	_check(enemy.is_dead(), "o inimigo deveria morrer pelos disparos do Velociraptor antes de terminar o teste")
	_check(not enemy.is_finished(), "o inimigo deveria morrer ANTES de alcançar o ninho, não depois")

	# Feedback visual de combate (hardening pós Phase 0.6): cada hit gera um
	# DamageNumber, e a morte gera um DeathEffect — ambos autônomos,
	# spawnados como irmãos do inimigo dentro de EnemySpawner (get_parent()).
	# Como o teste não bombeia frames reais depois do único process_frame
	# inicial, os timers internos desses efeitos nunca chegam a disparar —
	# eles continuam presentes como filhos até o fim do teste, o que torna
	# essa contagem confiável de verificar aqui.
	var damage_number_count := 0
	var death_effect_count := 0
	for child in enemy_spawner.get_children():
		if child is DamageNumber:
			damage_number_count += 1
		elif child is DeathEffect:
			death_effect_count += 1
	_check(damage_number_count >= 1, "cada hit deveria ter gerado um DamageNumber, got %d" % damage_number_count)
	_check(death_effect_count >= 1, "a morte do inimigo deveria ter gerado um DeathEffect, got %d" % death_effect_count)

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("[combat_integration_tests] ALL TESTS PASSED")
	else:
		print("[combat_integration_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
