class_name Targeting
extends RefCounted
## Seleção de alvo para dinossauros. Só o modo FIRST está implementado agora
## (maior distância percorrida no MapPath) — modos futuros (LAST, CLOSEST,
## STRONGEST, WEAKEST) entram como novos casos no `match` abaixo, sem exigir
## uma hierarquia de classes por modo (Strategy Pattern), deliberadamente
## evitada por ser abstração prematura com um único modo implementado.
##
## Puramente funcional: não conhece Dinosaur, não dispara nada, não sabe de
## projétil. Só recebe candidatos + origem + alcance e devolve um alvo (ou
## null).

enum Mode { FIRST }


static func select_target(candidates: Array[BasicEnemy], origin: Vector2, range: float, mode: int = Mode.FIRST) -> BasicEnemy:
	var in_range := _filter_in_range(candidates, origin, range)
	if in_range.is_empty():
		return null
	match mode:
		Mode.FIRST:
			return _select_first(in_range)
		_:
			push_error("[Targeting] Modo não implementado: %d" % mode)
			return null


static func _filter_in_range(candidates: Array[BasicEnemy], origin: Vector2, range: float) -> Array[BasicEnemy]:
	var result: Array[BasicEnemy] = []
	for enemy in candidates:
		if not is_instance_valid(enemy) or not enemy.is_active():
			continue
		if origin.distance_to(enemy.position) <= range:
			result.append(enemy)
	return result


## FIRST = inimigo com maior progresso no caminho (BasicEnemy.get_distance_traveled()),
## não o mais próximo fisicamente do dinossauro — ver docs/ARCHITECTURE.md.
static func _select_first(candidates: Array[BasicEnemy]) -> BasicEnemy:
	var best: BasicEnemy = candidates[0]
	for enemy in candidates:
		if enemy.get_distance_traveled() > best.get_distance_traveled():
			best = enemy
	return best
