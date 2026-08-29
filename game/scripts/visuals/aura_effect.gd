class_name AuraEffect
extends Node2D
## Camada de energia visual independente do sprite da criatura — usada pela forma T3 (evolução
## máxima) dos dinossauros. `AuraEffect.tscn` fica com `z_index = -1`: por trás de qualquer entidade
## no mesmo z_index padrão (0), sem precisar reordenar a árvore de cena. Nunca desenha nem modifica
## o sprite da criatura — é um node próprio, pensado para ser instanciado como irmão dela (mesmo
## princípio de composição de DeathEffect/SpawnEffect).
##
## Diferente de DeathEffect/SpawnEffect (efeitos de UM instante — nascem, tocam uma vez, se
## autodestroem via timer), este efeito é pensado para durar enquanto a criatura T3 existir: não
## tem timer nem `queue_free()` próprio. Quem instanciar (futuro sistema de tier — ver
## docs/ROADMAP.md, Sprint 1 Parte 5, ainda não implementado) é responsável por `add_child()`
## junto da criatura T3 e por remover este node quando ela for removida/evoluir/fundir.
##
## Reaproveita AnimatedVisual.State.IDLE — não porque isto seja "parado", mas porque IDLE já é o
## único estado com o contrato exato que uma aura contínua precisa: toca em loop pra sempre, sem
## nenhuma lógica de reação de um-tiro-só (mesma reutilização de contrato que DeathEffect/
## SpawnEffect já fazem com State.DEATH, só que para o oposto — eles querem UM tiro só).
##
## Ainda não instanciado por nenhum sistema de gameplay — existe pronto para quando o campo `tier`
## em DinosaurDefinition e a integração T3 acontecerem.

@onready var _visual: AnimatedVisual = $Visual


func _ready() -> void:
	_visual.play_state(AnimatedVisual.State.IDLE)
