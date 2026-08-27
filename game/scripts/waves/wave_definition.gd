class_name WaveDefinition
extends Resource
## Definição estática e autoral de uma onda de inimigos (dado, não
## comportamento) — mesmo padrão de MapDefinition/DinosaurDefinition.
##
## Deliberadamente simples: não é um sistema genérico de "wave scripting"
## (múltiplos grupos de inimigos, timings compostos, eventos no meio da
## onda). Uma wave = N inimigos do mesmo tipo, a um intervalo fixo. Se
## variedade dentro de uma wave for necessária no futuro, isso é uma
## extensão natural deste Resource (ex: Array[WaveDefinition] menores), não
## uma razão para reescrever a base agora.

@export var enemy_count: int = 5
@export var spawn_interval: float = 1.0  ## s entre spawns consecutivos
@export var reward_per_kill: int = 5  ## coins por inimigo desta wave morto
@export var wave_completion_reward: int = 20  ## coins extra ao completar a wave inteira

## <= 0 significa "usar o default do BasicEnemy.tscn" — ver EnemySpawner.spawn_enemy().
@export var speed_override: float = -1.0
@export var hp_override: int = -1
