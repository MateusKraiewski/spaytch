class_name SpawnEffect
extends Node2D
## Efeito visual autônomo de spawn — mesmo padrão de `DeathEffect` (Phase 0.6): instanciado como
## irmão da entidade no instante em que ela aparece, NUNCA no caminho crítico de
## `EnemySpawner.spawn_enemy()` (que continua retornando o `BasicEnemy` imediatamente,
## independente deste efeito existir/tocar/terminar). Este node se autodestrói sozinho via timer.
##
## Reaproveita `AnimatedVisual.State.DEATH` — não porque isto seja uma morte, mas porque DEATH já
## é o único estado com o contrato exato que um efeito de um-tiro-só precisa (toca uma vez,
## `loop = false` no SpriteFrames, nunca reconecta `animation_finished` para reverter a outro
## estado). Mesma reutilização de contrato que `DeathEffect` já faz para o burst de impacto
## genérico (Checkpoint D) — não é "morte" ali também, é só o mecanismo certo. Criar um 6º estado
## em `AnimatedVisual` só para "SPAWN" adicionaria uma classe de estado nova para um contrato que
## já existe.
##
## Checkpoint F: `z_index = 10` (ver SpawnEffect.tscn), mesmo raciocínio de `DeathEffect` — garante
## que a poeira de spawn apareça por cima do inimigo recém-nascido em vez de atrás dele, sem
## depender da ordem dos nós-irmãos em `EnemySpawner`.

const _LIFETIME := 0.35

@onready var _visual: AnimatedVisual = $Visual


func _ready() -> void:
	_visual.play_state(AnimatedVisual.State.DEATH)
	get_tree().create_timer(_LIFETIME).timeout.connect(queue_free)
