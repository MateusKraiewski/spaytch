extends SceneTree
## Testes da conexão AuraEffect <-> Tier 3 (Sprint 1, Etapa 6): confirma que só dinossauros T3
## ganham uma AuraEffect (como filho do Dinosaur), tanto via placement direto quanto via fusão —
## os dois caminhos passam pelo mesmo PlacementController._instantiate_dinosaur() (ver
## placement_controller.gd). A REGRA em si ("só tier 3 tem aura") é testada isoladamente, sem
## nenhuma cena/nó, em dinosaur_definition_tests.gd (DinosaurDefinition.has_aura()) — aqui só a
## CONEXÃO real (lógica de decisão continua desacoplada da camada visual: quem decide é a regra
## pura, quem só executa é PlacementController).
##
## `dinosaurs_container` precisa estar de verdade dentro da SceneTree (root.add_child) para
## Dinosaur.is_inside_tree() ser true depois do add_child() e a AuraEffect realmente ser anexada
## — diferente de placement_tests.gd/fusion_tests.gd, que usam um Node solto porque não
## precisam testar a parte visual.
##
## Executar com:
##   godot --headless --path game --script res://tests/dinosaur_aura_tests.gd

var _failures: int = 0
var _to_free: Array = []

const _COORD_A := Vector2i(0, 0)
const _COORD_B := Vector2i(1, 0)


func _initialize() -> void:
	_test_tier_1_placement_has_no_aura()
	_test_tier_3_placement_has_aura()
	_test_fusion_result_tier_3_has_aura()
	_test_fusion_result_tier_2_has_no_aura()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[dinosaur_aura_tests] ALL TESTS PASSED")
	else:
		print("[dinosaur_aura_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[dinosaur_aura_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _make_two_cell_grid() -> Grid:
	var definition := MapDefinition.new()
	definition.width = 2
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.BUILDABLE, CellType.BUILDABLE])
	return Grid.new(definition)


func _make_economy(starting: int = 1000) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	return _track(economy) as Economy


func _controller_with_real_tree(grid: Grid) -> PlacementController:
	var dinosaurs := Node.new()
	root.add_child(dinosaurs)
	_track(dinosaurs)

	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	var enemy_spawner := _track(EnemySpawner.new()) as EnemySpawner
	var projectiles := _track(Node.new()) as Node
	controller.setup(grid, enemy_spawner, dinosaurs, projectiles, _make_economy())
	return controller


func _place(controller: PlacementController, grid: Grid, definition: DinosaurDefinition, coord: Vector2i) -> void:
	controller.select_dinosaur(definition)
	controller.on_pointer_pressed(grid.cell_center_world(coord))


func _has_aura_child(dinosaur: Dinosaur) -> bool:
	for child in dinosaur.get_children():
		if child is AuraEffect:
			return true
	return false


func _velociraptor_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t1.tres") as DinosaurDefinition


func _velociraptor_t2() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t2.tres") as DinosaurDefinition


func _velociraptor_t3() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t3.tres") as DinosaurDefinition


func _test_tier_1_placement_has_no_aura() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur != null:
		_check(not _has_aura_child(dinosaur), "Velociraptor T1 não deveria ganhar AuraEffect")


func _test_tier_3_placement_has_aura() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t3(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur != null:
		_check(_has_aura_child(dinosaur), "Velociraptor T3 deveria ganhar AuraEffect")


func _test_fusion_result_tier_3_has_aura() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t2(), _COORD_A)
	_place(controller, grid, _velociraptor_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T2 + T2 deveria fundir para este teste fazer sentido")
	if result != null:
		_check(_has_aura_child(result),
			"resultado da fusão (T3) deveria ganhar AuraEffect também pelo caminho da fusão, não só placement direto")


func _test_fusion_result_tier_2_has_no_aura() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T1 + T1 deveria fundir para este teste fazer sentido")
	if result != null:
		_check(not _has_aura_child(result), "resultado da fusão (T2) não deveria ganhar AuraEffect")
