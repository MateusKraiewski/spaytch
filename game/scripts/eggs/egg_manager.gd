class_name EggManager
extends Node
## Cria um Egg por posição EGG do mapa e aplica a regra de "qual ovo recebe
## dano quando um inimigo chega ao ninho".
##
## Posições vêm de MapDefinition.get_egg_positions() — não duplicadas aqui
## nem em nenhum outro Resource (requisito explícito da Phase 0.5; a mesma
## regra já valia para spawn/nest/buildable desde a Phase 0.2).
##
## `extends Node`: sem identidade espacial própria — cada Egg tem a sua.
##
## Escuta EnemySpawner.enemy_reached_nest diretamente (Main.gd não
## intermedia essa interação) — mesmo padrão já usado por WaveManager: quem
## precisa da informação se inscreve na fonte via setup(), em vez do
## composition root fazer a ponte manualmente para cada evento.

signal egg_damaged(egg: Egg)
signal all_eggs_destroyed()

@export var egg_scene: PackedScene

var _eggs: Array[Egg] = []
var _all_destroyed_emitted: bool = false


func setup(definition: MapDefinition, grid: Grid, enemy_spawner: EnemySpawner) -> void:
	for coord in definition.get_egg_positions():
		var egg := egg_scene.instantiate() as Egg
		add_child(egg)
		egg.initialize(coord)
		egg.global_position = grid.cell_center_world(coord)
		egg.destroyed.connect(_on_egg_destroyed)
		_eggs.append(egg)

	enemy_spawner.enemy_reached_nest.connect(_on_enemy_reached_nest)


func get_eggs() -> Array[Egg]:
	return _eggs


func get_alive_eggs() -> Array[Egg]:
	return _eggs.filter(func(egg: Egg) -> bool: return not egg.is_destroyed())


func all_destroyed() -> bool:
	return not _eggs.is_empty() and get_alive_eggs().is_empty()


## Regra determinística simples: o primeiro ovo ainda vivo, na mesma ordem
## derivada de MapDefinition.get_egg_positions() (row-major) — não é "o mais
## próximo" nem aleatório, propositalmente simples (requisito 5).
func _damage_next_egg(amount: int) -> void:
	var alive := get_alive_eggs()
	if alive.is_empty():
		return
	var egg := alive[0]
	egg.take_damage(amount)
	egg_damaged.emit(egg)


func _on_enemy_reached_nest(enemy: BasicEnemy) -> void:
	_damage_next_egg(enemy.egg_damage)
	enemy.queue_free()


func _on_egg_destroyed(_egg: Egg) -> void:
	if _all_destroyed_emitted:
		return
	if all_destroyed():
		_all_destroyed_emitted = true
		all_eggs_destroyed.emit()
