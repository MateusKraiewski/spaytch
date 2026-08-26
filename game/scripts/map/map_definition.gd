class_name MapDefinition
extends Resource
## Definição estática e autoral de um mapa (dado, não comportamento).
##
## Fonte única de verdade: `cells`, um array plano row-major (index = y * width + x)
## com o tipo (CellType) de cada célula. Spawn points, posições de ovo, células
## buildable e o ninho NÃO são armazenados como listas separadas — são derivados
## de `cells` sob demanda via `get_positions_of_type()`. Isso evita duas fontes de
## verdade que poderiam dessincronizar (ex: uma lista de spawn_points desatualizada
## em relação ao cell type real). Ver docs/ARCHITECTURE.md para o racional completo.
##
## MapDefinition é um Resource: dados autorais/serializáveis. Estado runtime mutável
## (ex: célula ocupada) NÃO deve viver aqui — Resources podem ser instâncias
## compartilhadas, e mutar um Resource carregado do disco em runtime é uma armadilha
## comum no Godot. Esse estado mutável vive em Cell/Grid (ver grid.gd).

@export var width: int = 20
@export var height: int = 12
@export var tile_size: int = 32
@export var cells: PackedInt32Array = PackedInt32Array()


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < width and coord.y < height


func get_cell_type(coord: Vector2i) -> int:
	if not is_in_bounds(coord):
		return CellType.EMPTY
	return cells[coord.y * width + coord.x]


func get_positions_of_type(type: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if cells[y * width + x] == type:
				result.append(Vector2i(x, y))
	return result


func get_spawn_points() -> Array[Vector2i]:
	return get_positions_of_type(CellType.SPAWN)


func get_egg_positions() -> Array[Vector2i]:
	return get_positions_of_type(CellType.EGG)


func get_buildable_cells() -> Array[Vector2i]:
	return get_positions_of_type(CellType.BUILDABLE)


func get_nest_positions() -> Array[Vector2i]:
	return get_positions_of_type(CellType.NEST)
