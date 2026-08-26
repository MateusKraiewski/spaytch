extends SceneTree
## Testes determinísticos de MapPath: ordenação do PATH do Vale dos Ovos e
## rejeição de topologias impossíveis para path following (bifurcação, loop,
## células PATH soltas). Sem dependências externas — mesmo padrão de
## grid_tests.gd / map_tests.gd.
##
## Os testes de rejeição abaixo disparam MapPath.build() de propósito contra
## mapas inválidos, o que aciona push_error() em map_path.gd (comportamento
## de produção correto e intencional — não alterado aqui). Para não poluir
## o output como se fossem erros reais do harness, essas chamadas específicas
## são envolvidas por Engine.print_error_messages = false/true — mecanismo
## nativo do Godot 4 para suprimir a IMPRESSÃO de erros sem afetar em nada a
## lógica que os gera (push_error() continua rodando normalmente, `path`
## continua null, _check() continua validando o resultado real). Não é
## parsing de stdout nem stub da função push_error.
##
## Executar com:
##   godot --headless --path game --script res://tests/path_tests.gd

var _failures: int = 0


func _initialize() -> void:
	_test_vale_dos_ovos_builds()
	_test_vale_dos_ovos_start()
	_test_vale_dos_ovos_end()
	_test_vale_dos_ovos_waypoint_count()
	_test_vale_dos_ovos_contiguous_orthogonal()
	_test_vale_dos_ovos_no_duplicates()

	# As rejeições abaixo disparam push_error() de propósito (ver comentário
	# no topo do arquivo) — suprime só a impressão, não a validação em si.
	Engine.print_error_messages = false
	_test_rejects_forked_path()
	_test_rejects_map_with_loop()
	_test_rejects_leftover_path_cells()
	Engine.print_error_messages = true

	if _failures == 0:
		print("[path_tests] ALL TESTS PASSED")
	else:
		print("[path_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[path_tests] FAIL: %s" % message)


func _load_vale_dos_ovos() -> MapDefinition:
	return load("res://data/maps/vale_dos_ovos.tres") as MapDefinition


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


# ---- Vale dos Ovos (mapa real) ----

func _test_vale_dos_ovos_builds() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	_check(path != null, "MapPath.build() should succeed for Vale dos Ovos")


func _test_vale_dos_ovos_start() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	_check(path.start() == Vector2i(1, 9), "start() should be the SPAWN coord (1,9), got %s" % [path.start()])


func _test_vale_dos_ovos_end() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	_check(path.end() == Vector2i(18, 2), "end() should be the NEST coord (18,2), got %s" % [path.end()])


func _test_vale_dos_ovos_waypoint_count() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	# 23 células PATH + SPAWN + NEST = 25.
	_check(path.waypoint_count() == 25,
		"expected 25 waypoints (23 PATH + spawn + nest), got %d" % path.waypoint_count())


func _test_vale_dos_ovos_contiguous_orthogonal() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	for i in range(path.waypoints.size() - 1):
		var a: Vector2i = path.waypoints[i]
		var b: Vector2i = path.waypoints[i + 1]
		var dx := absi(b.x - a.x)
		var dy := absi(b.y - a.y)
		_check((dx == 1 and dy == 0) or (dx == 0 and dy == 1),
			"waypoints %d->%d (%s -> %s) should be orthogonally adjacent (no diagonals, no gaps)" %
				[i, i + 1, a, b])


func _test_vale_dos_ovos_no_duplicates() -> void:
	var path := MapPath.build(_load_vale_dos_ovos())
	var seen := {}
	var duplicates := 0
	for coord in path.waypoints:
		if seen.has(coord):
			duplicates += 1
		seen[coord] = true
	_check(duplicates == 0, "waypoints should have no duplicate cells, found %d" % duplicates)


# ---- Rejeição de topologias impossíveis ----

func _test_rejects_forked_path() -> void:
	# .P.
	# SPN   <- a partir de (1,1) [PATH], tanto (1,0) quanto (2,1) são
	#          candidatos válidos não visitados: bifurcação.
	var definition := _build(3, 2, [
		CellType.EMPTY, CellType.PATH, CellType.EMPTY,
		CellType.SPAWN, CellType.PATH, CellType.NEST,
	])
	var path := MapPath.build(definition)
	_check(path == null, "forked path should be rejected (build() should return null)")


func _test_rejects_map_with_loop() -> void:
	# Anel 3x3 com SPAWN e NEST em cantos opostos do anel:
	#   S P P
	#   P . P
	#   P P N
	# Ao entrar no anel a partir do SPAWN existem 2 direções válidas — um
	# loop sempre se manifesta como bifurcação no ponto em que é possível
	# entrar nele (ver comentário em map_path.gd).
	var definition := _build(3, 3, [
		CellType.SPAWN, CellType.PATH, CellType.PATH,
		CellType.PATH, CellType.EMPTY, CellType.PATH,
		CellType.PATH, CellType.PATH, CellType.NEST,
	])
	var path := MapPath.build(definition)
	_check(path == null, "looped/ringed path should be rejected (build() should return null)")


func _test_rejects_leftover_path_cells() -> void:
	# S P N .
	# . . . P   <- célula PATH isolada, nunca alcançada a partir do SPAWN.
	var definition := _build(4, 2, [
		CellType.SPAWN, CellType.PATH, CellType.NEST, CellType.EMPTY,
		CellType.EMPTY, CellType.EMPTY, CellType.EMPTY, CellType.PATH,
	])
	var path := MapPath.build(definition)
	_check(path == null, "map with an unreachable/leftover PATH cell should be rejected")
