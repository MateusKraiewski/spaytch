class_name Cell
extends RefCounted
## Estado runtime de uma célula individual da grid.
##
## Deliberadamente mínimo: apenas o que já tem uso real nesta fase.
## `type` cobre path/buildable/egg/spawn/nest (categorias mutuamente exclusivas
## já representadas pelo enum CellType). `occupant` é estado mutável separado
## porque, diferente do tipo, ele muda em runtime (quando um dinossauro é
## posicionado na célula) e não é derivável do tipo.
##
## Sprint 1 (sistema de espécie/tier): era um `occupied: bool` simples até a
## Etapa 3 — trocado por uma referência real ao `Dinosaur` que ocupa a célula
## porque a regra de fusão (Etapa 5) precisa comparar `species_id`/`tier` do
## que já está na célula contra o que o jogador está tentando colocar; um
## bool não carrega essa informação. `is_occupied()` preserva a pergunta
## booleana de antes para quem só precisa saber "tem algo aqui?" (mesmo
## padrão de `is_buildable()`/`is_path()` abaixo — método, não campo direto).
## Novos campos (ex: metadata de gameplay) devem ser adicionados quando um
## sistema real precisar deles, não especulativamente.

var coord: Vector2i
var type: int
var occupant: Dinosaur = null


func _init(p_coord: Vector2i, p_type: int) -> void:
	coord = p_coord
	type = p_type


func is_buildable() -> bool:
	return type == CellType.BUILDABLE


func is_occupied() -> bool:
	return occupant != null


func is_path() -> bool:
	return type == CellType.PATH


func has_egg() -> bool:
	return type == CellType.EGG


func is_spawn() -> bool:
	return type == CellType.SPAWN


func is_nest() -> bool:
	return type == CellType.NEST
