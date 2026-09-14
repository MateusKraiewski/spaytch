extends SceneTree
## Testes de MapValidator (contra definições sintéticas, válidas e inválidas)
## e do mapa real "Vale dos Ovos" (contra o Resource autorado).
##
## Executar com:
##   godot --headless --path game --script res://tests/map_tests.gd
##
## Sem dependências externas (mesmo padrão de tests/grid_tests.gd).

var _failures: int = 0


func _initialize() -> void:
	_test_valid_map_has_no_errors()
	_test_rejects_invalid_dimensions()
	_test_rejects_wrong_cell_count()
	_test_rejects_missing_spawn()
	_test_rejects_missing_nest()
	_test_rejects_missing_egg()
	_test_rejects_missing_path()
	_test_rejects_disconnected_spawn()
	_test_rejects_disconnected_nest()
	_test_rejects_disconnected_path()

	_test_vale_dos_ovos_dimensions()
	_test_vale_dos_ovos_egg_count()
	_test_vale_dos_ovos_spawn_and_nest_count()
	_test_vale_dos_ovos_has_path_buildable_obstacles()
	_test_vale_dos_ovos_passes_validation()
	_test_every_playable_map_passes_validation_and_has_a_valid_path()

	if _failures == 0:
		print("[map_tests] ALL TESTS PASSED")
	else:
		print("[map_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[map_tests] FAIL: %s" % message)


func _errors_mention(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func _build(width: int, height: int, types: Array) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.width = width
	definition.height = height
	var cells := PackedInt32Array()
	cells.resize(types.size())
	for i in range(types.size()):
		cells[i] = types[i]
	definition.cells = cells
	return definition


# ---- MapValidator: mapa sintético válido ----

func _test_valid_map_has_no_errors() -> void:
	# SPAWN . PATH . NEST . EGG  (linha única 4x1, tudo conectado, 1 egg)
	var definition := _build(4, 1, [CellType.SPAWN, CellType.PATH, CellType.NEST, CellType.EGG])
	var errors := MapValidator.validate(definition)
	_check(errors.is_empty(), "mapa sintético válido não deveria gerar erros, gerou: %s" % [errors])


# ---- MapValidator: rejeições ----

func _test_rejects_invalid_dimensions() -> void:
	var definition := _build(0, 5, [])
	var errors := MapValidator.validate(definition)
	_check(not errors.is_empty(), "width=0 deveria ser rejeitado")
	_check(_errors_mention(errors, "Dimensões"), "erro deveria mencionar dimensões inválidas")


func _test_rejects_wrong_cell_count() -> void:
	var definition := MapDefinition.new()
	definition.width = 5
	definition.height = 5
	definition.cells = PackedInt32Array([CellType.EMPTY, CellType.EMPTY])  # 2 != 25
	var errors := MapValidator.validate(definition)
	_check(not errors.is_empty(), "cells.size() != width*height deveria ser rejeitado")
	_check(_errors_mention(errors, "células incorreta"), "erro deveria mencionar quantidade de células")


func _test_rejects_missing_spawn() -> void:
	var definition := _build(3, 1, [CellType.PATH, CellType.PATH, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "não possui nenhuma célula SPAWN"), "ausência de SPAWN deveria ser detectada")


func _test_rejects_missing_nest() -> void:
	var definition := _build(3, 1, [CellType.SPAWN, CellType.PATH, CellType.PATH])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "não possui nenhuma célula NEST"), "ausência de NEST deveria ser detectada")


func _test_rejects_missing_egg() -> void:
	var definition := _build(3, 1, [CellType.SPAWN, CellType.PATH, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "não possui nenhum EGG"), "ausência de EGG deveria ser detectada")


func _test_rejects_missing_path() -> void:
	var definition := _build(2, 1, [CellType.SPAWN, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "não possui nenhuma célula PATH"), "ausência de PATH deveria ser detectada")


func _test_rejects_disconnected_spawn() -> void:
	# SPAWN isolado (vizinho EMPTY, não PATH)
	var definition := _build(3, 1, [CellType.SPAWN, CellType.EMPTY, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "SPAWN em"), "SPAWN sem PATH adjacente deveria ser inválido")


func _test_rejects_disconnected_nest() -> void:
	# SPAWN conectado a PATH; NEST isolado (vizinho EMPTY)
	var definition := _build(5, 1, [CellType.SPAWN, CellType.PATH, CellType.PATH, CellType.EMPTY, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "NEST em"), "NEST sem PATH adjacente deveria ser inválido")


func _test_rejects_disconnected_path() -> void:
	# dois trechos de PATH que nunca se encontram (gap no meio)
	var definition := _build(5, 1, [CellType.SPAWN, CellType.PATH, CellType.EMPTY, CellType.PATH, CellType.NEST])
	var errors := MapValidator.validate(definition)
	_check(_errors_mention(errors, "caminho contínuo"), "PATH descontínuo entre SPAWN e NEST deveria ser rejeitado")


# ---- Mapa real: Vale dos Ovos ----

func _load_vale_dos_ovos() -> MapDefinition:
	return load("res://data/maps/vale_dos_ovos.tres") as MapDefinition


func _test_vale_dos_ovos_dimensions() -> void:
	var definition := _load_vale_dos_ovos()
	_check(definition.width == 20, "Vale dos Ovos deveria ter width 20")
	_check(definition.height == 12, "Vale dos Ovos deveria ter height 12")
	_check(definition.cells.size() == 240, "Vale dos Ovos deveria ter 240 células")


func _test_vale_dos_ovos_egg_count() -> void:
	var definition := _load_vale_dos_ovos()
	_check(definition.get_egg_positions().size() == 3, "Vale dos Ovos deveria ter exatamente 3 EGG")


func _test_vale_dos_ovos_spawn_and_nest_count() -> void:
	var definition := _load_vale_dos_ovos()
	_check(definition.get_spawn_points().size() == 1, "Vale dos Ovos deveria ter exatamente 1 SPAWN")
	_check(definition.get_nest_positions().size() == 1, "Vale dos Ovos deveria ter exatamente 1 NEST")


func _test_vale_dos_ovos_has_path_buildable_obstacles() -> void:
	var definition := _load_vale_dos_ovos()
	_check(not definition.get_positions_of_type(CellType.PATH).is_empty(), "Vale dos Ovos deveria ter PATH")
	_check(not definition.get_buildable_cells().is_empty(), "Vale dos Ovos deveria ter células BUILDABLE")
	_check(not definition.get_positions_of_type(CellType.OBSTACLE).is_empty(), "Vale dos Ovos deveria ter OBSTACLE")


func _test_vale_dos_ovos_passes_validation() -> void:
	var definition := _load_vale_dos_ovos()
	var errors := MapValidator.validate(definition)
	_check(errors.is_empty(), "Vale dos Ovos deveria passar em MapValidator sem erros, gerou: %s" % [errors])


## V2 — cada mapa novo (Trilha Sinuosa, Delta Verdejante, ...) passa pelas MESMAS 2 checagens
## genéricas que Vale dos Ovos já passava: `MapValidator` sem erros E `MapPath.build()` sem
## bifurcação/loop/célula solta (checagem mais estrita que `MapValidator` sozinho não cobre — ver
## `tools/map_builder.gd`, usado pra gerar estes `.tres`). Lista cresce conforme novos mapas
## entrarem (V2, meta de 10) sem precisar de uma função de teste nova por mapa.
const _ALL_PLAYABLE_MAP_PATHS := [
	"res://data/maps/vale_dos_ovos.tres",
	"res://data/maps/trilha_sinuosa.tres",
	"res://data/maps/delta_verdejante.tres",
]


func _test_every_playable_map_passes_validation_and_has_a_valid_path() -> void:
	for map_path in _ALL_PLAYABLE_MAP_PATHS:
		var definition := load(map_path) as MapDefinition
		_check(definition != null, "%s deveria carregar como MapDefinition" % map_path)
		if definition == null:
			continue
		var errors := MapValidator.validate(definition)
		_check(errors.is_empty(), "%s deveria passar em MapValidator sem erros, gerou: %s" % [map_path, errors])
		var map_path_result := MapPath.build(definition)
		_check(map_path_result != null,
			"%s deveria produzir um MapPath válido (sem bifurcação/loop/célula PATH solta)" % map_path)
