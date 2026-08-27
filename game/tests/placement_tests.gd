extends SceneTree
## Testes determinísticos de PlacementController: validade de célula por
## CellType, o efeito real de colocar um dinossauro (ocupação + instância),
## e (Phase 0.5) integração com Economy — custo descontado ao colocar,
## placement recusado sem coins suficientes.
##
## Mesmo padrão de map_tests.gd/path_tests.gd: MapDefinition/Grid sintéticos
## construídos em memória, sem depender do Vale dos Ovos.
##
## Todo objeto criado (Grid é RefCounted, liberado sozinho; mas
## PlacementController, EnemySpawner, Economy, containers Node e qualquer
## Dinosaur real instanciado por um placement) é registrado em `_to_free` e
## liberado no final — evita vazamento de RID/CanvasItem no motor (o
## placement de verdade instancia Dinosaur.tscn com nodes Polygon2D reais).
##
## Executar com:
##   godot --headless --path game --script res://tests/placement_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_buildable_is_valid()
	_test_path_is_invalid()
	_test_spawn_is_invalid()
	_test_nest_is_invalid()
	_test_egg_is_invalid()
	_test_obstacle_is_invalid()
	_test_empty_is_invalid()
	_test_occupied_buildable_is_invalid()
	_test_out_of_bounds_is_invalid()
	_test_place_marks_cell_occupied_and_instantiates_dinosaur()
	_test_place_on_invalid_cell_does_nothing()
	_test_place_deducts_cost()
	_test_place_fails_without_enough_coins()
	_test_place_failed_does_not_deduct_coins()
	_test_place_emits_dinosaur_placed()
	_test_can_afford_selected_reflects_economy()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[placement_tests] ALL TESTS PASSED")
	else:
		print("[placement_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[placement_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _make_single_cell_grid(type: int) -> Grid:
	var definition := MapDefinition.new()
	definition.width = 1
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([type])
	return Grid.new(definition)


func _make_enemy_spawner() -> EnemySpawner:
	return _track(EnemySpawner.new()) as EnemySpawner


func _make_container() -> Node:
	return _track(Node.new()) as Node


func _make_economy(starting: int = 100) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	return _track(economy) as Economy


func _controller_for(grid: Grid, economy: Economy = null) -> PlacementController:
	var controller := PlacementController.new()
	controller.setup(grid, _make_enemy_spawner(), _make_container(), _make_container(),
		economy if economy != null else _make_economy())
	return _track(controller) as PlacementController


func _make_definition(cost: int = 10) -> DinosaurDefinition:
	var definition := DinosaurDefinition.new()
	definition.display_name = "TestDino"
	definition.projectile_scene = load("res://scenes/combat/Projectile.tscn") as PackedScene
	definition.cost = cost
	return definition


func _check_type_validity(type: int, type_name: String, expected_valid: bool) -> void:
	var grid := _make_single_cell_grid(type)
	var controller := _controller_for(grid)
	var actual := controller.is_valid_placement(Vector2i(0, 0))
	if expected_valid:
		_check(actual, "%s deveria ser válido para placement" % type_name)
	else:
		_check(not actual, "%s deveria ser inválido para placement" % type_name)


func _test_buildable_is_valid() -> void:
	_check_type_validity(CellType.BUILDABLE, "BUILDABLE", true)


func _test_path_is_invalid() -> void:
	_check_type_validity(CellType.PATH, "PATH", false)


func _test_spawn_is_invalid() -> void:
	_check_type_validity(CellType.SPAWN, "SPAWN", false)


func _test_nest_is_invalid() -> void:
	_check_type_validity(CellType.NEST, "NEST", false)


func _test_egg_is_invalid() -> void:
	_check_type_validity(CellType.EGG, "EGG", false)


func _test_obstacle_is_invalid() -> void:
	_check_type_validity(CellType.OBSTACLE, "OBSTACLE", false)


func _test_empty_is_invalid() -> void:
	_check_type_validity(CellType.EMPTY, "EMPTY", false)


func _test_occupied_buildable_is_invalid() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	grid.get_cell(Vector2i(0, 0)).occupied = true
	var controller := _controller_for(grid)
	_check(not controller.is_valid_placement(Vector2i(0, 0)),
		"BUILDABLE já ocupado deveria ser inválido")


func _test_out_of_bounds_is_invalid() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var controller := _controller_for(grid)
	_check(not controller.is_valid_placement(Vector2i(5, 5)),
		"coordenada fora dos limites deveria ser inválida")


func _test_place_marks_cell_occupied_and_instantiates_dinosaur() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var dinosaurs := _make_container()
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), dinosaurs, _make_container(), _make_economy())

	var definition := _make_definition()
	controller.select_dinosaur(definition)
	_check(controller.state == PlacementController.State.PLACING,
		"select_dinosaur deveria mudar o estado para PLACING")

	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(grid.get_cell(Vector2i(0, 0)).occupied, "célula deveria ficar ocupada após colocar")
	_check(dinosaurs.get_child_count() == 1, "deveria ter instanciado exatamente 1 Dinosaur")
	_check(controller.state == PlacementController.State.IDLE,
		"deveria voltar para IDLE após colocar")
	_check(controller.selected_definition == null,
		"seleção deveria ser limpa após colocar")


func _test_place_on_invalid_cell_does_nothing() -> void:
	var grid := _make_single_cell_grid(CellType.PATH)
	var dinosaurs := _make_container()
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), dinosaurs, _make_container(), _make_economy())

	controller.select_dinosaur(_make_definition())
	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(dinosaurs.get_child_count() == 0, "nenhum Dinosaur deveria ser instanciado em célula inválida")
	_check(controller.state == PlacementController.State.PLACING,
		"deveria continuar em PLACING para permitir nova tentativa")


# ---- Integração com Economy (Phase 0.5) ----

func _test_place_deducts_cost() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var economy := _make_economy(50)
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), _make_container(), _make_container(), economy)

	controller.select_dinosaur(_make_definition(20))
	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(economy.coins == 30, "cost should be deducted on successful placement, got %d" % economy.coins)


func _test_place_fails_without_enough_coins() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var dinosaurs := _make_container()
	var economy := _make_economy(5)
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), dinosaurs, _make_container(), economy)

	var received := [""]
	controller.placement_failed.connect(func(reason: String) -> void: received[0] = reason)

	controller.select_dinosaur(_make_definition(20))
	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(dinosaurs.get_child_count() == 0,
		"placement should not happen without enough coins")
	_check(not grid.get_cell(Vector2i(0, 0)).occupied,
		"cell should not be marked occupied when placement fails for insufficient coins")
	_check(controller.state == PlacementController.State.PLACING,
		"should remain in PLACING to allow another attempt")
	_check(received[0] == "insufficient_coins",
		"placement_failed should be emitted with 'insufficient_coins', got '%s'" % received[0])


func _test_place_failed_does_not_deduct_coins() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var economy := _make_economy(5)
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), _make_container(), _make_container(), economy)

	controller.select_dinosaur(_make_definition(20))
	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(economy.coins == 5, "coins should be unchanged when placement fails, got %d" % economy.coins)


# ---- Phase 0.6 ----

func _test_place_emits_dinosaur_placed() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(), _make_container(), _make_container(), _make_economy())

	var received := [null, Vector2i(-9, -9)]
	controller.dinosaur_placed.connect(func(dinosaur: Dinosaur, coord: Vector2i) -> void:
		received[0] = dinosaur
		received[1] = coord
	)

	controller.select_dinosaur(_make_definition())
	controller.on_pointer_pressed(grid.cell_center_world(Vector2i(0, 0)))

	_check(received[0] != null, "dinosaur_placed deveria ser emitido com o Dinosaur colocado")
	_check(received[1] == Vector2i(0, 0), "dinosaur_placed deveria informar a coordenada correta")


func _test_can_afford_selected_reflects_economy() -> void:
	var grid := _make_single_cell_grid(CellType.BUILDABLE)
	var economy := _make_economy(15)
	var controller := _controller_for(grid, economy)

	controller.select_dinosaur(_make_definition(20))
	_check(not controller.can_afford_selected(), "20 de custo com 15 coins deveria ser 'não pode pagar'")

	controller.select_dinosaur(_make_definition(10))
	_check(controller.can_afford_selected(), "10 de custo com 15 coins deveria ser 'pode pagar'")
