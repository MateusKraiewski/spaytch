class_name EnemySpawner
extends Node
## Cria um BasicEnemy no início do MapPath, com waypoints já convertidos
## para espaço de mundo, e o coloca em movimento.
##
## `extends Node`, não Node2D: o spawner não tem identidade espacial própria
## (mesmo raciocínio de InputManager) — quem tem posição é o BasicEnemy
## spawnado, não o spawner.
##
## Spawn manual simples desta fase (Phase 0.3) — sem wave manager, sem
## múltiplos inimigos/tipos, sem economia. Ver docs/ROADMAP.md.
##
## Recebe Grid (para conversão célula→mundo via Grid.cell_center_world —
## conversão centralizada, não duplicada aqui) e MapPath (sequência já
## ordenada de waypoints em coordenadas de grid) através de setup(), chamado
## pelo composition root (Main.gd). Não sabe COMO o path é calculado nem
## COMO a grid é construída — só consome os dois resultados já prontos.

signal enemy_spawned(enemy: BasicEnemy)
signal enemy_reached_nest(enemy: BasicEnemy)

@export var enemy_scene: PackedScene

var _grid: Grid
var _map_path: MapPath


func setup(grid: Grid, map_path: MapPath) -> void:
	_grid = grid
	_map_path = map_path


func spawn_enemy() -> BasicEnemy:
	assert(_grid != null and _map_path != null, "EnemySpawner.setup() must be called before spawn_enemy().")
	assert(enemy_scene != null, "EnemySpawner.enemy_scene is not assigned.")

	var enemy := enemy_scene.instantiate() as BasicEnemy
	add_child(enemy)
	enemy.reached_nest.connect(_on_enemy_reached_nest)
	enemy.initialize(_world_waypoints())
	enemy_spawned.emit(enemy)
	return enemy


func _world_waypoints() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for coord in _map_path.waypoints:
		points.append(_grid.cell_center_world(coord))
	return points


func _on_enemy_reached_nest(enemy: BasicEnemy) -> void:
	print("[EnemySpawner] Enemy reached the nest.")
	enemy_reached_nest.emit(enemy)
