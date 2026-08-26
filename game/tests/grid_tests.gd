extends SceneTree
## Testes simples e sem dependências externas para a lógica pura de Grid/MapDefinition.
##
## Não usa nenhum addon de testing (GUT etc.) — apenas o SceneTree do próprio Godot
## em modo headless, para evitar dependências externas desnecessárias nesta fase
## (ver skill testing). Executar com:
##   godot --headless --script res://tests/grid_tests.gd
## (a partir da pasta game/, ou apontando --path game/ para o projeto)

var _failures: int = 0


func _initialize() -> void:
	var grid := _build_empty_grid()

	_test_world_to_cell(grid)
	_test_cell_to_world(grid)
	_test_bounds(grid)
	_test_out_of_bounds_cell(grid)

	if _failures == 0:
		print("[grid_tests] ALL TESTS PASSED")
	else:
		print("[grid_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _build_empty_grid() -> Grid:
	var definition := MapDefinition.new()
	definition.width = 20
	definition.height = 12
	definition.tile_size = 32
	var cells := PackedInt32Array()
	cells.resize(definition.width * definition.height)
	cells.fill(CellType.EMPTY)
	definition.cells = cells
	return Grid.new(definition)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[grid_tests] FAIL: %s" % message)


func _test_world_to_cell(grid: Grid) -> void:
	_check(grid.world_to_cell(Vector2(0, 0)) == Vector2i(0, 0),
		"world_to_cell(0,0) should be cell (0,0)")
	_check(grid.world_to_cell(Vector2(33, 65)) == Vector2i(1, 2),
		"world_to_cell(33,65) should be cell (1,2)")
	_check(grid.world_to_cell(Vector2(639, 383)) == Vector2i(19, 11),
		"world_to_cell(639,383) should be the last cell (19,11)")


func _test_cell_to_world(grid: Grid) -> void:
	_check(grid.cell_to_world(Vector2i(0, 0)) == Vector2(0, 0),
		"cell_to_world(0,0) should be (0,0)")
	_check(grid.cell_to_world(Vector2i(19, 11)) == Vector2(608, 352),
		"cell_to_world(19,11) should be (608,352)")


func _test_bounds(grid: Grid) -> void:
	_check(grid.is_in_bounds(Vector2i(0, 0)), "cell (0,0) should be in bounds")
	_check(grid.is_in_bounds(Vector2i(19, 11)), "cell (19,11) should be in bounds")
	_check(not grid.is_in_bounds(Vector2i(20, 0)), "cell (20,0) should be out of bounds (width edge)")
	_check(not grid.is_in_bounds(Vector2i(0, 12)), "cell (0,12) should be out of bounds (height edge)")
	_check(not grid.is_in_bounds(Vector2i(-1, 0)), "cell (-1,0) should be out of bounds (negative)")


func _test_out_of_bounds_cell(grid: Grid) -> void:
	_check(grid.get_cell(Vector2i(-1, -1)) == null,
		"get_cell(-1,-1) should return null")
	_check(grid.get_cell(Vector2i(20, 0)) == null,
		"get_cell(20,0) should return null")
