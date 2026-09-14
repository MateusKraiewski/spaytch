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

## Tipagem via script anônimo (mesmo motivo de main.gd/map_select.gd — `class_name` colidiria
## com o autoload "GameSession").
const _GameSessionScript := preload("res://scripts/core/game_session.gd")

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[game_loop_integration_tests] FAIL: %s" % message)


func _initialize() -> void:
	await _test_full_game_loop()
	await _test_enemy_reaches_nest_damages_egg()
	await _test_full_campaign_plays_through_automatically_after_first_wave()
	await _test_dinosaur_popup_selects_species_directly()
	await _test_hud_button_label_matches_selected_and_placed_definition()
	await _test_player_fuses_two_dinosaurs_via_real_clicks()
	await _test_fusion_via_real_input_event_chain()
	await _test_wave_auto_starts_after_completion_interval()
	await _test_manual_start_during_auto_start_interval_is_not_broken_by_it()
	await _test_no_auto_start_scheduled_after_victory()
	await _test_main_uses_map_selected_via_game_session()

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
	_check(grid.get_cell(placement_coord).is_occupied(), "célula deveria ficar ocupada após o placement")

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
	wave_manager.step(wave_manager.waves[0].get_groups()[0].spawn_interval)  # dispara o primeiro spawn da wave

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


## Verificação de ponta a ponta pedida na auditoria de finalização (V1): a campanha inteira (3
## waves reais do Vale dos Ovos) precisa fluir sozinha depois do primeiro "Iniciar Onda" manual —
## wave 1 -> countdown automático -> wave 2 -> countdown -> wave 3 -> vitória — sem exigir MAIS
## nenhum clique do jogador depois do primeiro. Cobre a interação real entre WaveManager.step()
## (combate) e Main.step() (countdown/auto-start) ao longo de uma campanha completa, coisa que
## nenhum teste anterior exercitava junto. 3 Velociraptor T1 (DPS + reforços) pra dar margem real
## de sobreviver às 3 waves — o objetivo aqui é provar o FLUXO automático, não medir balance fino.
func _test_full_campaign_plays_through_automatically_after_first_wave() -> void:
	var main := _load_main()
	var enemy_spawner := main.get_node("EnemySpawner") as EnemySpawner
	var egg_manager := main.get_node("EggManager") as EggManager
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs := main.get_node("Dinosaurs") as Node
	var projectiles := main.get_node("Projectiles") as Node
	var hud := main.get_node("HUD") as HUD
	var banner := hud.get_node("Root/BannerLabel") as Label

	root.add_child(main)
	await process_frame

	var grid := grid_manager.grid
	var coord_a := Vector2i(9, 7)
	var coord_b := _find_nearby_buildable_coord(placement_controller, coord_a)
	placement_controller.on_pointer_pressed(grid.cell_center_world(coord_a))
	if coord_b != Vector2i(-1, -1):
		hud.dinosaur_option_selected.emit(0)
		placement_controller.on_pointer_pressed(grid.cell_center_world(coord_b))
		var coord_c := _find_nearby_buildable_coord(placement_controller, coord_b)
		if coord_c != Vector2i(-1, -1):
			hud.dinosaur_option_selected.emit(0)
			placement_controller.on_pointer_pressed(grid.cell_center_world(coord_c))
	_check(dinosaurs.get_child_count() >= 1, "deveria existir ao menos 1 Dinosaur colocado antes da campanha começar")

	hud.start_wave_pressed.emit()  # único clique manual de toda a campanha
	_check(wave_manager.is_wave_active(), "wave 1 deveria estar ativa após 'Iniciar Onda'")

	var dt := 0.05
	var iterations := 0
	var max_iterations := 200000  # 3 waves + 2 countdowns completos cabem bem dentro disso
	while (wave_manager.has_next_wave() or wave_manager.is_wave_active()) and not egg_manager.all_destroyed():
		wave_manager.step(dt)
		main.step(dt)
		for dino in dinosaurs.get_children():
			if dino is Dinosaur:
				dino.step(dt)
		for proj in projectiles.get_children():
			if proj is Projectile:
				proj.step(dt)
		for enemy in enemy_spawner.get_active_enemies().duplicate():
			enemy.step(dt)
		iterations += 1
		if iterations >= max_iterations:
			break

	_check(iterations < max_iterations, "campanha completa não deveria exceder o limite de segurança de iterações")
	_check(not egg_manager.all_destroyed(), "a campanha deveria ser vencível com 3 Velociraptor T1 bem posicionados")
	_check(wave_manager.current_wave_index == wave_manager.waves.size() - 1,
		"a campanha deveria ter avançado sozinha até a última wave, got index %d de %d" %
			[wave_manager.current_wave_index, wave_manager.waves.size() - 1])
	_check(not wave_manager.is_wave_active(), "a campanha deveria terminar com nenhuma wave ativa (vitória)")
	_check(banner.text.contains("VITÓRIA"), "banner final deveria mostrar VITÓRIA, got '%s'" % banner.text)

	# Confirma que nada tenta iniciar uma 4ª wave inexistente depois da vitória.
	main.step(30.0)
	_check(not wave_manager.is_wave_active(), "depois da vitória, avançar o tempo não deveria iniciar nenhuma wave nova")

	root.remove_child(main)
	main.free()


## Bug report do jogador — o botão único que só CICLAVA pra próxima espécie foi substituído por um
## popup com as 3 espécies, pra permitir escolha DIRETA (não sequencial). Confirma: (a) o botão
## principal só abre/fecha o popup, sem mudar a seleção sozinho; (b) escolher qualquer espécie no
## popup (inclusive "pulando" direto pro índice 2, sem passar pelo 1) seleciona exatamente ela; (c)
## o placement de verdade funciona para uma espécie que não é a pré-selecionada padrão.
func _test_dinosaur_popup_selects_species_directly() -> void:
	var main := _load_main()
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs := main.get_node("Dinosaurs") as Node
	var hud := main.get_node("HUD") as HUD
	var popup := hud.get_node("Root/DinosaurSelectPopup") as Panel

	root.add_child(main)
	await process_frame

	_check(placement_controller.selected_definition != null
			and placement_controller.selected_definition.species_id == &"velociraptor",
		"Velociraptor deveria ser a espécie pré-selecionada ao iniciar")
	_check(not popup.visible, "popup de escolha deveria começar fechado")

	hud.dinosaur_button_pressed.emit()
	_check(popup.visible, "tocar o botão principal deveria abrir o popup de escolha")
	_check(placement_controller.selected_definition.species_id == &"velociraptor",
		"só abrir o popup não deveria mudar a seleção atual")

	hud.dinosaur_option_selected.emit(2)  # escolhe T-Rex DIRETO, sem passar por Triceratops
	_check(not popup.visible, "escolher uma espécie deveria fechar o popup")
	_check(placement_controller.selected_definition.species_id == &"trex",
		"escolher o índice 2 no popup deveria selecionar T-Rex diretamente, sem precisar ciclar")

	hud.dinosaur_option_selected.emit(1)  # agora escolhe Triceratops
	_check(placement_controller.selected_definition.species_id == &"triceratops",
		"escolher o índice 1 no popup deveria selecionar Triceratops")

	var grid := grid_manager.grid
	var placement_coord := Vector2i(9, 7)
	placement_controller.on_pointer_pressed(grid.cell_center_world(placement_coord))

	_check(dinosaurs.get_child_count() == 1, "deveria existir exatamente 1 Dinosaur colocado (Triceratops)")
	var cell := grid.get_cell(placement_coord)
	_check(cell.is_occupied(), "célula deveria ficar ocupada após colocar o Triceratops")
	if cell.occupant != null:
		_check(cell.occupant.definition.species_id == &"triceratops",
			"o dinossauro colocado deveria ser o Triceratops selecionado, não outra espécie")

	root.remove_child(main)
	main.free()


## Bug report do jogador (Sprint 1, pós-Etapa 7): "o botão mostra Velociraptor, mas ao
## clicar/colocar traz outro dinossauro". Diferente de _test_dinosaur_popup_selects_species_
## directly() (que só confere `selected_definition.species_id`), este teste lê o TEXTO DE VERDADE
## do Button (`hud.get_node("Root/DinosaurButton").text`) e compara diretamente contra a espécie
## realmente selecionada E contra a espécie efetivamente colocada na célula — em cada passo,
## incluindo o 1º placement logo após o boot, SEM nenhuma escolha no popup ainda (exatamente o
## cenário descrito no bug report). Percorre as 3 espécies via escolha DIRETA no popup (índice),
## não mais ciclando um botão único.
func _test_hud_button_label_matches_selected_and_placed_definition() -> void:
	var main := _load_main()
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var hud := main.get_node("HUD") as HUD
	var dinosaur_button := hud.get_node("Root/DinosaurButton") as Button

	root.add_child(main)
	await process_frame

	var grid := grid_manager.grid
	var expected_cycle: Array[StringName] = [&"velociraptor", &"triceratops", &"trex", &"velociraptor"]
	var expected_cycle_index: Array[int] = [0, 1, 2, 0]

	for i in range(expected_cycle.size()):
		var expected_species := expected_cycle[i]
		var definition := placement_controller.selected_definition
		_check(definition != null and definition.species_id == expected_species,
			"passo %d do ciclo: selected_definition deveria ser '%s', got '%s'" %
				[i, expected_species, (definition.species_id if definition != null else &"<null>")])
		_check(definition != null and dinosaur_button.text.contains(definition.display_name),
			"passo %d do ciclo: texto do botão ('%s') deveria conter o display_name da definição realmente selecionada ('%s')" %
				[i, dinosaur_button.text, (definition.display_name if definition != null else "<null>")])

		var coord := _find_nearby_buildable_coord(placement_controller, Vector2i(9, 7))
		_check(coord != Vector2i(-1, -1), "passo %d: deveria existir célula BUILDABLE livre perto de (9,7)" % i)
		if coord != Vector2i(-1, -1) and definition != null:
			var label_before_click := dinosaur_button.text
			var species_before_click := definition.species_id
			placement_controller.on_pointer_pressed(grid.cell_center_world(coord))
			var cell := grid.get_cell(coord)
			_check(cell.is_occupied() and cell.occupant != null,
				"passo %d: célula (%d,%d) deveria ficar ocupada após o placement" % [i, coord.x, coord.y])
			if cell.occupant != null:
				_check(cell.occupant.definition.species_id == species_before_click,
					"passo %d: dinossauro efetivamente colocado ('%s') deveria corresponder à espécie selecionada no momento do clique ('%s')" %
						[i, cell.occupant.definition.species_id, species_before_click])
				_check(label_before_click.contains(cell.occupant.definition.display_name),
					"passo %d: texto do botão no momento do clique ('%s') deveria corresponder ao dinossauro efetivamente colocado ('%s')" %
						[i, label_before_click, cell.occupant.definition.display_name])

			# Bug fix: depois do placement, PlacementController volta pra IDLE (nada armado) — o
			# texto do botão NÃO pode continuar afirmando que a espécie antiga ainda está pronta
			# pra colocar, senão um clique seguinte (que agora vira seleção de fusão, não
			# placement) "trai" o que o botão prometia.
			_check(placement_controller.state == PlacementController.State.IDLE,
				"passo %d: state deveria voltar pra IDLE após o placement" % i)
			_check(not dinosaur_button.text.contains(definition.display_name),
				"passo %d: texto do botão ('%s') não deveria mais mostrar '%s' depois dela já ter sido colocada (nada está armado em IDLE)" %
					[i, dinosaur_button.text, definition.display_name])

		if i < expected_cycle.size() - 1:
			hud.dinosaur_option_selected.emit(expected_cycle_index[i + 1])

	root.remove_child(main)
	main.free()


## Sprint 1, Etapa 7 — fluxo real de jogador, ponta a ponta, com Main.tscn de verdade: coloca 2
## Velociraptor T1 (mesmo caminho de sempre — botão da HUD + clique), depois clica nos dois
## dinossauros já colocados (sem nada selecionado pra colocar, mesmo clique de sempre) pra
## fundir. Confirma que a MECÂNICA (Fusion/try_fuse(), Etapas 5-6) continua intacta quando
## disparada pelo fluxo de input real, não só quando chamada diretamente como em fusion_tests.gd.
func _test_player_fuses_two_dinosaurs_via_real_clicks() -> void:
	var main := _load_main()
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs := main.get_node("Dinosaurs") as Node

	root.add_child(main)
	await process_frame

	var grid := grid_manager.grid
	var coord_a := Vector2i(9, 7)  # mesma célula DPS real já usada em _test_full_game_loop
	var coord_b := _find_nearby_buildable_coord(placement_controller, coord_a)
	_check(coord_b != Vector2i(-1, -1), "deveria existir uma 2ª célula BUILDABLE livre perto de (9,7) no Vale dos Ovos")
	if coord_b == Vector2i(-1, -1):
		root.remove_child(main)
		main.free()
		return

	# Velociraptor T1 já vem pré-selecionado (Etapa 4) — coloca o 1º.
	placement_controller.on_pointer_pressed(grid.cell_center_world(coord_a))
	_check(placement_controller.state == PlacementController.State.IDLE,
		"deveria voltar pra IDLE depois do 1º placement")

	# Nada selecionado agora — reseleciona Velociraptor (índice 0) direto pelo popup pra colocar o 2º.
	main.get_node("HUD").dinosaur_option_selected.emit(0)
	placement_controller.on_pointer_pressed(grid.cell_center_world(coord_b))

	_check(dinosaurs.get_child_count() == 2, "deveriam existir 2 Dinosaur colocados antes da fusão")
	_check(placement_controller.state == PlacementController.State.IDLE,
		"deveria estar IDLE depois do 2º placement — é nesse estado que o clique vira seleção de fusão")

	# Mesmo pointer_pressed de sempre, agora em IDLE — 1º clique seleciona, 2º clique funde.
	placement_controller.on_pointer_pressed(grid.cell_center_world(coord_a))
	_check(placement_controller.fusion_pending_coord == coord_a,
		"1º clique num dinossauro colocado deveria marcar a seleção de fusão pendente")

	placement_controller.on_pointer_pressed(grid.cell_center_world(coord_b))

	var fused := grid.get_cell(coord_a).occupant
	_check(fused != null, "a célula A deveria ter o dinossauro fundido depois do 2º clique")
	if fused != null:
		_check(fused.definition.species_id == &"velociraptor" and fused.definition.tier == 2,
			"o resultado da fusão via clique deveria ser um Velociraptor T2")
	_check(grid.get_cell(coord_b).occupant == null, "a célula B deveria ficar livre depois da fusão via clique")
	_check(placement_controller.fusion_pending_coord == Vector2i(-1, -1),
		"seleção de fusão deveria estar limpa depois de fundir")

	await process_frame  # deixa o queue_free() dos 2 dinossauros antigos ser processado
	_check(dinosaurs.get_child_count() == 1,
		"depois da fusão só deveria sobrar 1 Dinosaur (o fundido), got %d" % dinosaurs.get_child_count())

	root.remove_child(main)
	main.free()


## Diferente de _test_player_fuses_two_dinosaurs_via_real_clicks() (que chama
## placement_controller.on_pointer_pressed() diretamente), este teste passa pela cadeia REAL de
## sinais: constrói um InputEventMouseButton de verdade e entrega pra
## InputManager._unhandled_input() (o mesmo método que a engine chama sozinha durante o jogo),
## deixando o sinal pointer_pressed se propagar normalmente até PlacementController. Nasceu de um
## diagnóstico de bug real (Sprint 1) — mantido como regressão permanente porque cobre um caminho
## que _test_player_fuses_two_dinosaurs_via_real_clicks() não cobre (propagação de evento/sinal
## de verdade, não só a chamada direta do método).
func _test_fusion_via_real_input_event_chain() -> void:
	var main := _load_main()
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var input_manager := main.get_node("InputManager") as InputManager
	var dinosaurs := main.get_node("Dinosaurs") as Node

	root.add_child(main)
	await process_frame

	var grid := grid_manager.grid
	var coord_a := Vector2i(9, 7)
	var coord_b := _find_nearby_buildable_coord(placement_controller, coord_a)
	if coord_b == Vector2i(-1, -1):
		root.remove_child(main)
		main.free()
		return

	_click_via_input_event(input_manager, grid.cell_center_world(coord_a))  # coloca T1 #1
	main.get_node("HUD").dinosaur_option_selected.emit(0)  # reseleciona Velociraptor direto pelo popup
	_click_via_input_event(input_manager, grid.cell_center_world(coord_b))  # coloca T1 #2

	_check(dinosaurs.get_child_count() == 2,
		"deveriam existir 2 Dinosaur colocados via evento de input real antes da fusão")
	_check(placement_controller.state == PlacementController.State.IDLE,
		"deveria estar IDLE antes das seleções de fusão")

	_click_via_input_event(input_manager, grid.cell_center_world(coord_a))  # 1º clique de fusão
	_check(placement_controller.fusion_pending_coord == coord_a,
		"1º clique via evento de input real deveria marcar fusion_pending_coord — se isto falhar, " +
		"o problema está na propagação do sinal, não na lógica de fusão")

	_click_via_input_event(input_manager, grid.cell_center_world(coord_b))  # 2º clique de fusão

	var fused := grid.get_cell(coord_a).occupant
	_check(fused != null and fused.definition.tier == 2,
		"fusão via cadeia real de evento/sinal deveria produzir um T2 na célula A")

	root.remove_child(main)
	main.free()


func _click_via_input_event(input_manager: InputManager, world_pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = world_pos
	input_manager._unhandled_input(event)


func _find_nearby_buildable_coord(placement_controller: PlacementController, near: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	]
	for offset in offsets:
		var candidate := near + offset
		if placement_controller.is_valid_placement(candidate):
			return candidate
	return Vector2i(-1, -1)


## Wave automática (etapa separada, pedida depois da fusão/seleção já fechadas) — depois de uma
## wave completar (havendo próxima), a próxima deve iniciar sozinha depois de um pequeno intervalo,
## sem exigir o botão "Iniciar Onda". `2.0` aqui precisa bater com Main._WAVE_AUTO_START_DELAY
## (não referenciável direto — Main.gd não tem `class_name`). Avança o tempo via `main.step(delta)`
## direto (mesma convenção determinística do resto da suíte, ver doc comment no topo do arquivo)
## em vez de esperar tempo real — `get_tree().create_timer()` não seria testável assim, por isso
## a implementação usa um acumulador de delta próprio (ver Main.step()).
## Wave automática com countdown "3, 2, 1, GO!" (pedido explícito da missão de finalização V1) —
## depois de uma wave completar (havendo próxima), o banner mostra "WAVE X COMPLETE" por
## Main._WAVE_COMPLETE_BANNER_DURATION, depois cada passo de Main._WAVE_COUNTDOWN_STEPS em
## sequência, e só então a próxima wave inicia sozinha — sem exigir o botão "Iniciar Onda". Os
## valores de tempo aqui precisam bater com as constantes de Main.gd (não referenciáveis direto —
## Main.gd não tem `class_name`). Avança o tempo via `main.step(delta)` direto (mesma convenção
## determinística do resto da suíte, ver doc comment no topo do arquivo) em vez de esperar tempo
## real — `get_tree().create_timer()` não seria testável assim.
func _test_wave_auto_starts_after_completion_interval() -> void:
	var main := _load_main()
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var hud := main.get_node("HUD") as HUD
	var banner := hud.get_node("Root/BannerLabel") as Label

	root.add_child(main)
	await process_frame

	wave_manager.current_wave_index = 0
	wave_manager.wave_completed.emit(0, wave_manager.waves[0])
	_check(not wave_manager.is_wave_active(),
		"sanity: a próxima wave não deveria iniciar no instante exato do wave_completed, antes do intervalo")
	_check(banner.text.contains("COMPLETE"),
		"banner deveria mostrar 'WAVE 1 COMPLETE' assim que a wave termina, got '%s'" % banner.text)

	main.step(1.99)
	_check(not wave_manager.is_wave_active(), "a próxima wave não deveria iniciar antes do banner COMPLETE terminar")
	_check(banner.text.contains("COMPLETE"), "banner ainda deveria mostrar COMPLETE pouco antes do countdown começar")

	main.step(0.02)  # cruza os 2.0s do banner COMPLETE -> 1º passo do countdown
	_check(banner.text == "3", "countdown deveria mostrar '3' assim que o banner COMPLETE terminar, got '%s'" % banner.text)
	_check(not wave_manager.is_wave_active(), "a wave não deveria iniciar durante o '3'")

	main.step(1.0)  # "3" -> "2"
	_check(banner.text == "2", "countdown deveria avançar para '2', got '%s'" % banner.text)

	main.step(1.0)  # "2" -> "1"
	_check(banner.text == "1", "countdown deveria avançar para '1', got '%s'" % banner.text)

	main.step(1.0)  # "1" -> "GO!"
	_check(banner.text == "GO!", "countdown deveria avançar para 'GO!', got '%s'" % banner.text)
	_check(not wave_manager.is_wave_active(), "a wave ainda não deveria ter iniciado durante o 'GO!'")

	main.step(0.61)  # "GO!" termina -> wave 2 inicia de verdade
	_check(wave_manager.is_wave_active() and wave_manager.current_wave_index == 1,
		"a próxima wave deveria iniciar sozinha assim que o countdown terminar")
	_check(banner.text == "WAVE 2", "banner deveria trocar para 'WAVE 2' ao iniciar de verdade, got '%s'" % banner.text)

	root.remove_child(main)
	main.free()


## O botão manual continua funcionando durante o intervalo de espera, e não deve ser "atrapalhado"
## quando o timer do auto-start eventualmente vence depois (WaveManager.start_next_wave() já tem
## guarda própria via is_wave_active()/has_next_wave() — chamar de novo não faz nada).
func _test_manual_start_during_auto_start_interval_is_not_broken_by_it() -> void:
	var main := _load_main()
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var hud := main.get_node("HUD") as HUD

	root.add_child(main)
	await process_frame

	wave_manager.current_wave_index = 0
	wave_manager.wave_completed.emit(0, wave_manager.waves[0])

	hud.start_wave_pressed.emit()  # jogador não espera o intervalo, inicia manualmente
	_check(wave_manager.is_wave_active() and wave_manager.current_wave_index == 1,
		"o botão manual deveria iniciar a próxima wave imediatamente, sem esperar o intervalo")

	main.step(5.0)  # deixa o intervalo do auto-start "vencer" de sobra
	_check(wave_manager.current_wave_index == 1,
		"o auto-start não deveria ter avançado pra outra wave depois do jogador já ter iniciado manualmente")

	root.remove_child(main)
	main.free()


## V2 — seleção de mapa (GameSession/MapSelect.tscn): confirma que Main.tscn realmente usa o mapa
## escolhido via GameSession.select_map() ANTES de instanciar a cena, e que a seleção é CONSUMIDA
## (não vaza pra uma partida seguinte que não passou pela tela de seleção de novo).
func _test_main_uses_map_selected_via_game_session() -> void:
	var game_session := root.get_node("GameSession") as _GameSessionScript
	game_session.select_map("res://data/maps/trilha_sinuosa.tres")

	var main := _load_main()
	root.add_child(main)
	await process_frame

	var grid_manager := main.get_node("GridManager") as GridManager
	_check(grid_manager.map_definition == load("res://data/maps/trilha_sinuosa.tres"),
		"GridManager.map_definition deveria ser exatamente o mapa selecionado via GameSession")

	root.remove_child(main)
	main.free()

	# Confirma que a seleção foi CONSUMIDA — uma 2ª partida sem nova seleção volta ao default do
	# próprio Main.tscn (Vale dos Ovos), não herda silenciosamente a escolha da partida anterior.
	var main2 := _load_main()
	root.add_child(main2)
	await process_frame
	var grid_manager2 := main2.get_node("GridManager") as GridManager
	_check(grid_manager2.map_definition == load("res://data/maps/vale_dos_ovos.tres"),
		"sem nova seleção, a 2ª partida deveria voltar ao mapa default (Vale dos Ovos)")
	root.remove_child(main2)
	main2.free()


## Última wave (vitória) não agenda nenhum auto-start — não existe próxima wave pra iniciar.
func _test_no_auto_start_scheduled_after_victory() -> void:
	var main := _load_main()
	var wave_manager := main.get_node("WaveManager") as WaveManager

	root.add_child(main)
	await process_frame

	var last_index := wave_manager.waves.size() - 1
	wave_manager.current_wave_index = last_index
	wave_manager.wave_completed.emit(last_index, wave_manager.waves[last_index])

	main.step(10.0)  # bem mais que qualquer intervalo de auto-start
	_check(not wave_manager.is_wave_active(),
		"depois da vitória (última wave), nenhuma wave nova deveria iniciar sozinha")
	_check(wave_manager.current_wave_index == last_index,
		"current_wave_index não deveria ter avançado depois da vitória")

	root.remove_child(main)
	main.free()
