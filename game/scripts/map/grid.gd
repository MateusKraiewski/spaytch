class_name Grid
extends RefCounted
## Representação runtime da grid, construída a partir de um MapDefinition.
##
## Objeto puro (RefCounted, não Node): não depende da árvore de cena, então pode
## ser instanciado e testado isoladamente (ver game/tests/grid_tests.gd).
## Mantém um Cell por célula (estado runtime mutável), copiado a partir dos tipos
## estáticos do MapDefinition no momento da construção — o MapDefinition original
## nunca é mutado por esta classe.

var width: int
var height: int
var cell_size: int
var _cells: Array[Cell] = []


func _init(definition: MapDefinition) -> void:
	width = definition.width
	height = definition.height
	cell_size = definition.tile_size
	_cells.resize(width * height)
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			_cells[y * width + x] = Cell.new(coord, definition.get_cell_type(coord))


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < width and coord.y < height


func get_cell(coord: Vector2i) -> Cell:
	if not is_in_bounds(coord):
		return null
	return _cells[coord.y * width + coord.x]


func get_cells_of_type(type: int) -> Array[Cell]:
	return _cells.filter(func(cell: Cell) -> bool: return cell.type == type)


## Converte uma posição no mundo (px) para a coordenada de célula correspondente.
## Não garante que a coordenada resultante esteja dentro dos limites da grid —
## use is_in_bounds() para validar antes de consumir o resultado.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))


## Retorna o canto superior-esquerdo (em px) da célula, na origem do mundo.
func cell_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * cell_size, coord.y * cell_size)


func cell_center_world(coord: Vector2i) -> Vector2:
	return cell_to_world(coord) + Vector2(cell_size, cell_size) / 2.0
