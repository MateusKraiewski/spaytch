class_name WaveDefinition
extends Resource
## Definição estática e autoral de uma onda de inimigos (dado, não
## comportamento) — mesmo padrão de MapDefinition/DinosaurDefinition.
##
## V2 — uma wave agora é uma SEQUÊNCIA de grupos homogêneos ("5 Básico, depois 3 Rápido, depois 1
## Tanque"), cada um referenciando um `EnemyDefinition` — é isso que permite "waves intermediárias:
## combinação de inimigos" sem `WaveManager` conhecer nenhum tipo específico. Guardados como 3
## arrays PARALELOS de tipos primitivos (mesmo índice = mesmo grupo) em vez de um
## `Array[WaveEnemyGroup]` tipado de Resource aninhado — ver o doc comment de `WaveEnemyGroup`
## para o motivo (sintaxe de array-de-Resource só validável no editor de verdade).
## `reward_per_kill` mudou de "por wave" (Sprint 1) para "por `EnemyDefinition`" (Tanque morto vale
## mais que Enxame) — ver `enemy_definition.gd`.

@export var group_enemy_paths: Array[String] = []  ## res://data/enemies/*.tres, um por grupo
@export var group_counts: Array[int] = []
@export var group_spawn_intervals: Array[float] = []
@export var wave_completion_reward: int = 20  ## coins extra ao completar a wave inteira

## Permite injetar grupos já prontos EM MEMÓRIA — usado por testes que constroem um
## `EnemyDefinition` sintético via `.new()`, sem precisar de um `.tres` real em disco (mesmo
## espírito de `DinosaurDefinition.new()` em `fusion_tests.gd`). Quando não vazio, tem prioridade
## sobre os 3 arrays paralelos acima; produção real (waves carregadas de um `.tres`) nunca precisa
## disto, só os testes.
var groups_override: Array[WaveEnemyGroup] = []


## Resolve os 3 arrays paralelos acima em instâncias reais de `WaveEnemyGroup` (via `load()` dos
## paths), na ordem em que devem ser spawnados — a menos que `groups_override` já tenha sido
## preenchido (ver acima). Reconstrói a cada chamada em vez de cachear — o custo é irrelevante
## (poucos grupos por wave, `load()` de um path já carregado é barato/cacheado pelo próprio
## `ResourceLoader`) e evita guardar estado mutável derivado dentro de um `Resource` (armadilha já
## documentada em `map_definition.gd`: um `.tres` pode ser uma instância compartilhada).
func get_groups() -> Array[WaveEnemyGroup]:
	if not groups_override.is_empty():
		return groups_override
	var groups: Array[WaveEnemyGroup] = []
	for i in range(group_enemy_paths.size()):
		var enemy_definition := load(group_enemy_paths[i]) as EnemyDefinition
		groups.append(WaveEnemyGroup.new(enemy_definition, group_counts[i], group_spawn_intervals[i]))
	return groups
