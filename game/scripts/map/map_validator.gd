class_name MapValidator
extends RefCounted
## Validação de invariantes mínimas de um MapDefinition autorado.
##
## Opera apenas sobre o dado estático (MapDefinition), sem depender de Grid/Cell
## em runtime — pode validar um mapa antes mesmo dele ser carregado em cena.
## A checagem de conectividade é um BFS único disparado sob demanda para
## validação de autoria/teste; NÃO é um sistema de pathfinding consultado em
## runtime por inimigos (isso é uma responsabilidade futura e separada).
##
## Regra deliberada sobre EGG: exige apenas "ao menos 1 ovo", não um número
## fixo. docs/GAME_BIBLE.md registra que a quantidade de ovos varia por mapa,
## então travar um número exato aqui contradiria essa decisão de design. O
## mapa "Vale dos Ovos" ter exatamente 3 ovos é verificado como um teste
## específico desse mapa (game/tests/map_tests.gd), não como regra genérica.

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func validate(definition: MapDefinition) -> Array[String]:
	var errors: Array[String] = []

	if definition.width <= 0 or definition.height <= 0:
		errors.append("Dimensões inválidas: width=%d, height=%d (ambos devem ser > 0)." %
			[definition.width, definition.height])
		return errors

	var expected_cell_count := definition.width * definition.height
	if definition.cells.size() != expected_cell_count:
		errors.append("Quantidade de células incorreta: %d (esperado %d para %dx%d)." %
			[definition.cells.size(), expected_cell_count, definition.width, definition.height])
		return errors

	var spawn_positions := definition.get_positions_of_type(CellType.SPAWN)
	var nest_positions := definition.get_positions_of_type(CellType.NEST)
	var egg_positions := definition.get_positions_of_type(CellType.EGG)
	var path_positions := definition.get_positions_of_type(CellType.PATH)

	if spawn_positions.is_empty():
		errors.append("Mapa não possui nenhuma célula SPAWN.")
	elif spawn_positions.size() > 1:
		errors.append("Mapa possui %d células SPAWN (esperado exatamente 1)." % spawn_positions.size())

	if nest_positions.is_empty():
		errors.append("Mapa não possui nenhuma célula NEST.")
	elif nest_positions.size() > 1:
		errors.append("Mapa possui %d células NEST (esperado exatamente 1)." % nest_positions.size())

	if path_positions.is_empty():
		errors.append("Mapa não possui nenhuma célula PATH.")

	if egg_positions.is_empty():
		errors.append("Mapa não possui nenhum EGG (um mapa precisa de ao menos 1 ovo para defender).")

	if spawn_positions.size() == 1 and not _has_adjacent_path(definition, spawn_positions[0]):
		errors.append("SPAWN em %s não está conectado a nenhuma célula PATH adjacente." % spawn_positions[0])

	if nest_positions.size() == 1 and not _has_adjacent_path(definition, nest_positions[0]):
		errors.append("NEST em %s não está conectado a nenhuma célula PATH adjacente." % nest_positions[0])

	if spawn_positions.size() == 1 and nest_positions.size() == 1:
		if not _is_connected(definition, spawn_positions[0], nest_positions[0]):
			errors.append("Não existe caminho contínuo de PATH entre SPAWN %s e NEST %s." %
				[spawn_positions[0], nest_positions[0]])

	return errors


static func _has_adjacent_path(definition: MapDefinition, coord: Vector2i) -> bool:
	for offset in _NEIGHBOR_OFFSETS:
		var neighbor := coord + offset
		if definition.is_in_bounds(neighbor) and definition.get_cell_type(neighbor) == CellType.PATH:
			return true
	return false


static func _is_connected(definition: MapDefinition, from: Vector2i, to: Vector2i) -> bool:
	var visited := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			return true
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor := current + offset
			if visited.has(neighbor) or not definition.is_in_bounds(neighbor):
				continue
			var type := definition.get_cell_type(neighbor)
			if type == CellType.PATH or type == CellType.SPAWN or type == CellType.NEST:
				visited[neighbor] = true
				queue.push_back(neighbor)
	return false
