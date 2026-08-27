extends Node2D
## Efeito visual autônomo, desacoplado do gameplay: instanciado no momento
## da morte de um inimigo, da chegada ao ninho, ou do impacto de um
## projétil (ver BasicEnemy/Projectile) — NUNCA no caminho crítico de
## remoção da entidade. A entidade que gerou o efeito já se autodestrói
## (`queue_free()`) de forma imediata e independente deste efeito existir,
## tocar, ou terminar.
##
## Por quê: adiar o `queue_free()` da própria entidade para "esperar a
## animação" arriscaria travar testes headless que não bombeiam frames
## reais depois da morte/impacto (vários testes chamam `take_damage()` e
## seguem para a próxima asserção no mesmo frame lógico — ver
## docs/ARCHITECTURE.md, Phase 0.6). Este node se autodestrói sozinho via
## timer, sem exigir nenhum acompanhamento externo — seguro mesmo que
## ninguém nunca "olhe" para ele rodar de verdade (testes automatizados).
## Fica dentro da árvore de cena (adicionado como irmão da entidade que o
## gerou) então é limpo normalmente pelo shutdown do motor/`main.free()`
## mesmo se o timer nunca disparar.

const _LIFETIME := 0.4

@onready var _visual: AnimatedVisual = $Visual


func _ready() -> void:
	_visual.play_state(AnimatedVisual.State.DEATH)
	get_tree().create_timer(_LIFETIME).timeout.connect(queue_free)
