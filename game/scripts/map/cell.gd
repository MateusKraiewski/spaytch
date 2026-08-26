class_name Cell
extends RefCounted
## Estado runtime de uma célula individual da grid.
##
## Deliberadamente mínimo: apenas o que já tem uso real nesta fase.
## `type` cobre path/buildable/egg/spawn/nest (categorias mutuamente exclusivas
## já representadas pelo enum CellType). `occupied` é estado mutável separado
## porque, diferente do tipo, ele muda em runtime (ex: quando algo for
## posicionado na célula em fases futuras) e não é derivável do tipo.
## Novos campos (ex: metadata de gameplay) devem ser adicionados quando um
## sistema real precisar deles, não especulativamente.

var coord: Vector2i
var type: int
var occupied: bool = false


func _init(p_coord: Vector2i, p_type: int) -> void:
	coord = p_coord
	type = p_type


func is_buildable() -> bool:
	return type == CellType.BUILDABLE


func is_path() -> bool:
	return type == CellType.PATH


func has_egg() -> bool:
	return type == CellType.EGG


func is_spawn() -> bool:
	return type == CellType.SPAWN


func is_nest() -> bool:
	return type == CellType.NEST
