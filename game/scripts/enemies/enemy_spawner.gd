class_name EnemySpawner
extends Node
## Cria um BasicEnemy no início do MapPath, com waypoints já convertidos
## para espaço de mundo, e o coloca em movimento.
##
## `extends Node`, não Node2D: o spawner não tem identidade espacial própria
## (mesmo raciocínio de InputManager) — quem tem posição é o BasicEnemy
## spawnado, não o spawner.
##
## Spawn parametrizado por chamador (Phase 0.5: WaveManager chama
## spawn_enemy() repetidamente, um por vez, com overrides opcionais de
## speed/hp vindos de um WaveDefinition) — EnemySpawner continua sem saber
## nada sobre waves, só cria UM inimigo por chamada com os parâmetros dados.
##
## Recebe Grid (para conversão célula→mundo via Grid.cell_center_world —
## conversão centralizada, não duplicada aqui) e MapPath (sequência já
## ordenada de waypoints em coordenadas de grid) através de setup(), chamado
## pelo composition root (Main.gd). Não sabe COMO o path é calculado nem
## COMO a grid é construída — só consome os dois resultados já prontos.
##
## Registro de inimigos ativos (Phase 0.4): mantém a lista de BasicEnemy
## ainda vivos/em jogo, consumida por Dinosaur/Targeting para escolher
## alvos. Deliberadamente NÃO extraído para uma classe EnemyRegistry/
## EnemyManager separada — EnemySpawner já vai precisar rastrear múltiplos
## inimigos quando existir um wave manager (fase futura já prevista), então
## isso não é escopo emprestado, é adiantar uma responsabilidade que já
## seria dele.
##
## Checkpoint E: spawn_enemy() também instancia um SpawnEffect (poeira subindo do chão) como
## irmão do BasicEnemy recém-criado — mesmo padrão autônomo de DeathEffect (nunca bloqueia o
## retorno de spawn_enemy(), se autodestrói sozinho). Puramente visual; não afeta HP/dano/path
## following/sinais/nenhuma regra de gameplay.

signal enemy_spawned(enemy: BasicEnemy)
signal enemy_reached_nest(enemy: BasicEnemy)
signal enemy_died(enemy: BasicEnemy)  ## Phase 0.5 — WaveManager/Economy escutam isto, não `BasicEnemy.died` diretamente

@export var enemy_scene: PackedScene

const _SPAWN_EFFECT_SCENE := preload("res://scenes/effects/SpawnEffect.tscn")

var _grid: Grid
var _map_path: MapPath
var _active_enemies: Array[BasicEnemy] = []


func setup(grid: Grid, map_path: MapPath) -> void:
	_grid = grid
	_map_path = map_path


## `speed_override`/`hp_override` <= 0 significam "usar o default do
## BasicEnemy.tscn" — permitem a um WaveDefinition ajustar dificuldade sem
## EnemySpawner precisar conhecer WaveDefinition/WaveManager.
func spawn_enemy(speed_override: float = -1.0, hp_override: int = -1) -> BasicEnemy:
	assert(_grid != null and _map_path != null, "EnemySpawner.setup() must be called before spawn_enemy().")
	assert(enemy_scene != null, "EnemySpawner.enemy_scene is not assigned.")

	var enemy := enemy_scene.instantiate() as BasicEnemy
	if speed_override > 0.0:
		enemy.speed = speed_override
	if hp_override > 0:
		enemy.max_hp = hp_override

	add_child(enemy)
	enemy.reached_nest.connect(_on_enemy_reached_nest)
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
	enemy.initialize(_world_waypoints())

	# Checkpoint E — feedback visual de que algo acabou de nascer no SPAWN (antes disso, o inimigo
	# só "aparecia" sem nenhum reconhecimento visual, diferente de impacto/morte/chegada ao ninho,
	# que já tinham DeathEffect desde o Checkpoint D). Mesmo padrão de `BasicEnemy`/`Projectile`:
	# autônomo, irmão da entidade (nunca filho — sobreviveria de qualquer forma, mas deixa claro
	# que não pertence à entidade), nunca bloqueia spawn_enemy() nem sua chamadora. `is_inside_tree()`
	# evita instanciar um node cujo `_ready()` nunca dispararia de qualquer forma (WaveManager/
	# testes que usam um EnemySpawner solto via `.new()`, nunca adicionado a uma SceneTree real —
	# ver wave_tests.gd) — mesmo raciocínio já usado por BasicEnemy/Projectile para DeathEffect.
	if is_inside_tree():
		var spawn_effect := _SPAWN_EFFECT_SCENE.instantiate() as SpawnEffect
		spawn_effect.global_position = enemy.global_position
		add_child(spawn_effect)

	_active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## Lista dos inimigos atualmente vivos e em jogo (nem mortos, nem chegaram
## ao ninho, nem foram removidos da cena). Consumida por Dinosaur/Targeting.
func get_active_enemies() -> Array[BasicEnemy]:
	return _active_enemies


func _world_waypoints() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for coord in _map_path.waypoints:
		points.append(_grid.cell_center_world(coord))
	return points


func _on_enemy_reached_nest(enemy: BasicEnemy) -> void:
	print("[EnemySpawner] Enemy reached the nest.")
	_remove_active_enemy(enemy)
	enemy_reached_nest.emit(enemy)


func _on_enemy_died(enemy: BasicEnemy) -> void:
	_remove_active_enemy(enemy)
	enemy_died.emit(enemy)


## Rede de segurança: garante que a lista nunca acumule referências a
## inimigos removidos por qualquer outro motivo (ex: liberados manualmente
## em um teste) que não `died`/`reached_nest`. `Array.erase()` não faz nada
## se o elemento já não estiver presente, então é seguro chamar mesmo
## quando a remoção já aconteceu por outro caminho.
func _on_enemy_tree_exited(enemy: BasicEnemy) -> void:
	_remove_active_enemy(enemy)


func _remove_active_enemy(enemy: BasicEnemy) -> void:
	_active_enemies.erase(enemy)
