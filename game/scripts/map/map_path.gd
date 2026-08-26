class_name MapPath
extends RefCounted
## Sequência ordenada e determinística de waypoints (coordenadas de grid) que
## liga o SPAWN ao NEST de um MapDefinition, seguindo as células PATH entre eles.
##
## Isto é PATH FOLLOWING, não pathfinding: o mapa já define um único caminho
## contínuo desenhado pelo level designer; este algoritmo apenas converte a
## representação "conjunto de células" (sem ordem) do MapDefinition em uma
## sequência ordenada consumível por quem precisa percorrê-la (EnemySpawner/
## BasicEnemy). Não descobre caminhos alternativos e não faz busca (A*/BFS)
## em runtime por inimigo — é calculado uma única vez por mapa, aqui.
##
## Assume um MapDefinition já aprovado por MapValidator (não repete a
## validação geral: dimensões, presença de SPAWN/NEST/PATH, conectividade).
## Ainda assim falha de forma clara diante de dados impossíveis PARA
## ORDENAÇÃO especificamente — bifurcação, loop, células PATH não visitadas —
## que MapValidator não verifica, pois não são necessárias para conectividade
## genérica, só para produzir uma única sequência determinística.
##
## Trabalha inteiramente em coordenadas de grid (Vector2i). Conversão para
## posição de mundo é responsabilidade de Grid.cell_center_world() — não
## duplicada aqui (ver docs/ARCHITECTURE.md).
##
## Loop e bifurcação são detectados pelo MESMO mecanismo (mais de 1 candidato
## válido em um passo): qualquer loop alcançável a partir do SPAWN
## necessariamente cria um ponto de decisão em algum lugar do trajeto, então
## uma implementação correta de "siga o único vizinho não visitado" já
## rejeita os dois casos sem precisar de lógica extra dedicada a loops.

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var waypoints: Array[Vector2i] = []


static func build(definition: MapDefinition) -> MapPath:
	var spawn_positions := definition.get_positions_of_type(CellType.SPAWN)
	var nest_positions := definition.get_positions_of_type(CellType.NEST)
	if spawn_positions.size() != 1:
		push_error("[MapPath] Esperava exatamente 1 SPAWN, encontrou %d." % spawn_positions.size())
		return null
	if nest_positions.size() != 1:
		push_error("[MapPath] Esperava exatamente 1 NEST, encontrou %d." % nest_positions.size())
		return null

	var spawn: Vector2i = spawn_positions[0]
	var nest: Vector2i = nest_positions[0]
	var total_path_cells := definition.get_positions_of_type(CellType.PATH).size()

	var ordered: Array[Vector2i] = [spawn]
	var visited := {spawn: true}
	var current := spawn
	var max_steps := definition.width * definition.height + 1

	while current != nest:
		var next_candidates: Array[Vector2i] = []
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor := current + offset
			if visited.has(neighbor) or not definition.is_in_bounds(neighbor):
				continue
			var type := definition.get_cell_type(neighbor)
			if type == CellType.PATH or type == CellType.NEST:
				next_candidates.append(neighbor)

		if next_candidates.is_empty():
			push_error("[MapPath] Caminho interrompido em %s antes de alcançar NEST %s." % [current, nest])
			return null
		if next_candidates.size() > 1:
			push_error("[MapPath] Bifurcação detectada em %s: %d próximas células válidas (%s)." %
				[current, next_candidates.size(), next_candidates])
			return null

		current = next_candidates[0]
		visited[current] = true
		ordered.append(current)

		if ordered.size() > max_steps:
			push_error("[MapPath] Caminho excedeu %d passos sem alcançar NEST (loop?)." % max_steps)
			return null

	# ordered inclui spawn e nest; células PATH "usadas" = ordered.size() - 2.
	var used_path_cells := ordered.size() - 2
	if used_path_cells != total_path_cells:
		push_error("[MapPath] %d célula(s) PATH não fazem parte do caminho de SPAWN a NEST (total %d, usado %d)." %
			[total_path_cells - used_path_cells, total_path_cells, used_path_cells])
		return null

	var path := MapPath.new()
	path.waypoints = ordered
	return path


func start() -> Vector2i:
	return waypoints[0]


func end() -> Vector2i:
	return waypoints[waypoints.size() - 1]


func waypoint_count() -> int:
	return waypoints.size()
