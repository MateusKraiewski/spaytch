extends SceneTree
## Testes da Phase 0.6 (First Playable / UX Pass): carregamento do Main Menu,
## API pública da HUD (banner/overlays/rótulos), e comportamento de
## pausa/resume/menu + feedback de wave via Main.tscn real.
##
## Não testa layout pixel-perfect nem faz da UI algo excessivamente testável
## (ver docs/ARCHITECTURE.md, "Phase 0.6") — só a superfície pública que o
## resto do jogo (ou um humano jogando) realmente observa: texto/visibilidade
## de labels e overlays, e o efeito real dos sinais nos sistemas de jogo.
##
## Executar com:
##   godot --headless --path game --script res://tests/ux_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[ux_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_main_menu_loads_and_buttons_exist()
	await _test_hud_public_api()
	await _test_pause_resume_via_main()
	await _test_wave_banners_via_main()
	await _test_dinosaur_button_allows_second_placement()
	await _test_victory_banner_after_last_wave()

	if _failures == 0:
		print("[ux_tests] ALL TESTS PASSED")
	else:
		print("[ux_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_main_menu_loads_and_buttons_exist() -> void:
	var packed := load("res://scenes/MainMenu.tscn") as PackedScene
	_check(packed != null, "MainMenu.tscn should load")
	if packed == null:
		return

	var menu := packed.instantiate()
	var play_button := menu.get_node_or_null("PlayButton") as Button
	var options_button := menu.get_node_or_null("OptionsButton") as Button
	var quit_button := menu.get_node_or_null("QuitButton") as Button

	_check(play_button != null, "MainMenu deveria ter um PlayButton")
	_check(options_button != null, "MainMenu deveria ter um OptionsButton")
	_check(quit_button != null, "MainMenu deveria ter um QuitButton")

	menu.free()


func _test_hud_public_api() -> void:
	var packed := load("res://scenes/ui/HUD.tscn") as PackedScene
	var hud := packed.instantiate() as HUD
	root.add_child(hud)
	await process_frame

	hud.set_coins(150)
	var coins_label := hud.get_node("Root/CoinsLabel") as Label
	_check(coins_label.text.contains("150"), "set_coins deveria refletir o valor no label, got '%s'" % coins_label.text)

	hud.set_eggs(2, 3, [10, 20, 0])
	var eggs_label := hud.get_node("Root/EggsLabel") as Label
	_check(eggs_label.text.contains("2/3"), "set_eggs deveria refletir alive/total, got '%s'" % eggs_label.text)

	hud.set_dinosaur_button_label("🦖 Velociraptor (20)")
	var dino_button := hud.get_node("Root/DinosaurButton") as Button
	_check(dino_button.text == "🦖 Velociraptor (20)", "set_dinosaur_button_label deveria setar o texto do botão")

	var banner := hud.get_node("Root/BannerLabel") as Label
	hud.show_banner("WAVE 1")
	_check(banner.visible and banner.text == "WAVE 1", "show_banner deveria tornar o banner visível com o texto certo")
	hud.hide_banner()
	_check(not banner.visible, "hide_banner deveria esconder o banner")

	var pause_overlay := hud.get_node("Root/PauseOverlay") as Control
	hud.show_pause_overlay()
	_check(pause_overlay.visible, "show_pause_overlay deveria tornar o overlay visível")
	hud.hide_pause_overlay()
	_check(not pause_overlay.visible, "hide_pause_overlay deveria esconder o overlay")

	var game_over_overlay := hud.get_node("Root/GameOverOverlay") as Control
	_check(not game_over_overlay.visible, "GameOverOverlay deveria começar escondido")
	hud.show_game_over()
	_check(game_over_overlay.visible, "show_game_over deveria tornar o overlay visível")

	root.remove_child(hud)
	hud.free()


func _load_main() -> Node:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	return packed.instantiate()


func _test_pause_resume_via_main() -> void:
	var main := _load_main()
	root.add_child(main)
	await process_frame

	var hud := main.get_node("HUD") as HUD
	var pause_overlay := hud.get_node("Root/PauseOverlay") as Control

	hud.pause_pressed.emit()
	_check(root.get_tree().paused, "pause_pressed deveria pausar a árvore")
	_check(pause_overlay.visible, "pause_pressed deveria mostrar o overlay de pausa")

	hud.resume_pressed.emit()
	_check(not root.get_tree().paused, "resume_pressed deveria despausar a árvore")
	_check(not pause_overlay.visible, "resume_pressed deveria esconder o overlay de pausa")

	root.remove_child(main)
	main.free()


func _test_wave_banners_via_main() -> void:
	var main := _load_main()
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var enemy_spawner := main.get_node("EnemySpawner") as EnemySpawner
	var dinosaurs := main.get_node("Dinosaurs") as Node
	var projectiles := main.get_node("Projectiles") as Node
	var hud := main.get_node("HUD") as HUD
	var banner := hud.get_node("Root/BannerLabel") as Label

	root.add_child(main)
	await process_frame

	hud.start_wave_pressed.emit()
	_check(banner.visible and banner.text == "WAVE 1",
		"iniciar a wave 1 deveria mostrar o banner 'WAVE 1', got '%s' (visible=%s)" % [banner.text, banner.visible])

	var dt := 0.05
	var iterations := 0
	var max_iterations := 20000
	while wave_manager.is_wave_active() and iterations < max_iterations:
		wave_manager.step(dt)
		for dino in dinosaurs.get_children():
			if dino is Dinosaur:
				dino.step(dt)
		for proj in projectiles.get_children():
			if proj is Projectile:
				proj.step(dt)
		for enemy in enemy_spawner.get_active_enemies().duplicate():
			enemy.step(dt)
		iterations += 1

	_check(iterations < max_iterations, "wave 1 não deveria exceder o limite de segurança de iterações")
	_check(banner.visible and banner.text.contains("COMPLETE"),
		"completar a wave deveria mostrar um banner de 'COMPLETE', got '%s'" % banner.text)

	root.remove_child(main)
	main.free()


func _test_dinosaur_button_allows_second_placement() -> void:
	var main := _load_main()
	var placement_controller := main.get_node("PlacementController") as PlacementController
	var grid_manager := main.get_node("GridManager") as GridManager
	var dinosaurs := main.get_node("Dinosaurs") as Node
	var hud := main.get_node("HUD") as HUD

	root.add_child(main)
	await process_frame

	var grid := grid_manager.grid
	var buildable := grid_manager.map_definition.get_buildable_cells()
	_check(buildable.size() >= 2, "Vale dos Ovos deveria ter ao menos 2 células BUILDABLE para este teste")
	if buildable.size() < 2:
		root.remove_child(main)
		main.free()
		return

	placement_controller.on_pointer_pressed(grid.cell_center_world(buildable[0]))
	_check(dinosaurs.get_child_count() == 1, "primeiro placement deveria colocar 1 Dinosaur")
	_check(placement_controller.state == PlacementController.State.IDLE,
		"deveria voltar para IDLE após o primeiro placement")

	hud.dinosaur_button_pressed.emit()  # abre o popup de escolha (estado visual só)
	_check(placement_controller.state == PlacementController.State.IDLE,
		"abrir o popup sozinho não deveria rearmar nenhuma seleção ainda")

	hud.dinosaur_option_selected.emit(0)  # escolhe a 1ª espécie de novo
	_check(placement_controller.state == PlacementController.State.PLACING,
		"escolher uma espécie no popup deveria permitir selecionar de novo (colocar mais de um)")

	placement_controller.on_pointer_pressed(grid.cell_center_world(buildable[1]))
	_check(dinosaurs.get_child_count() == 2,
		"deveria ser possível colocar um segundo Dinosaur após reselecionar")

	root.remove_child(main)
	main.free()


## Confirma que a ÚLTIMA wave mostra um banner de conclusão distinto
## ("VITÓRIA"), não o mesmo texto genérico de "wave complete" das
## anteriores — sem isso o jogador só via o botão "Iniciar Onda" ficar
## desabilitado, sem nenhuma explicação de que a campanha (de teste) tinha
## acabado.
##
## Não simula combate real pelas 3 waves (isso dependeria da dificuldade
## crescente/balance atual — sobreviver às 3 sem perder os 3 ovos não é
## garantido e não é o que este teste quer verificar). Em vez disso, avança
## `current_wave_index` direto para a última e emite o sinal real
## `wave_completed` que `Main._on_wave_completed()` escuta — testa
## exatamente a decisão de texto (última wave -> banner de vitória), sem
## depender de quão fácil/difícil o combate real é.
func _test_victory_banner_after_last_wave() -> void:
	var main := _load_main()
	var wave_manager := main.get_node("WaveManager") as WaveManager
	var hud := main.get_node("HUD") as HUD
	var banner := hud.get_node("Root/BannerLabel") as Label

	root.add_child(main)
	await process_frame

	var last_index := wave_manager.waves.size() - 1
	wave_manager.current_wave_index = last_index
	_check(not wave_manager.has_next_wave(), "sanity: não deveria haver próxima wave a partir da última")

	wave_manager.wave_completed.emit(last_index, wave_manager.waves[last_index])

	_check(banner.visible and banner.text.contains("VITÓRIA"),
		"completar a última wave deveria mostrar um banner de vitória, got '%s'" % banner.text)

	# Uma wave que NÃO é a última continua com o banner genérico de sempre —
	# a distinção é só para o fim real da campanha.
	wave_manager.current_wave_index = 0
	wave_manager.wave_completed.emit(0, wave_manager.waves[0])
	_check(banner.visible and banner.text.contains("COMPLETE") and not banner.text.contains("VITÓRIA"),
		"wave que não é a última deveria continuar com o banner genérico, got '%s'" % banner.text)

	root.remove_child(main)
	main.free()
