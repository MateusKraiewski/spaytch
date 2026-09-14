class_name WaveEnemyGroup
extends RefCounted
## V2 — estrutura de dado EM MEMÓRIA, nunca salva como `.tres` própria (ver
## `WaveDefinition.get_groups()`): representa "N inimigos do mesmo `EnemyDefinition`, a um
## intervalo fixo" dentro de uma wave.
##
## `RefCounted` (não `Resource`) de propósito: um `Array[WaveEnemyGroup]` tipado, com cada
## elemento um Resource ANINHADO dentro do `.tres` de `WaveDefinition`, é uma sintaxe que só é
## validável abrindo o editor Godot de verdade — exatamente o mesmo problema já documentado e
## evitado em `main.gd` para `WaveManager.waves` (`Array[WaveDefinition]` montado em código via
## `load()`, nunca escrito à mão no `.tscn`). `WaveDefinition` guarda os dados como 3 arrays
## PARALELOS de tipos primitivos (`String`/`int`/`float`, sintaxe `.tres` sem risco nenhum) e monta
## instâncias deste objeto sob demanda via `get_groups()`.

var enemy_definition: EnemyDefinition
var count: int
var spawn_interval: float


func _init(p_enemy_definition: EnemyDefinition, p_count: int, p_spawn_interval: float) -> void:
	enemy_definition = p_enemy_definition
	count = p_count
	spawn_interval = p_spawn_interval
