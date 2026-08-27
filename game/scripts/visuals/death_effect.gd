class_name DeathEffect
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
##
## Checkpoint F: `z_index = 10` (ver DeathEffect.tscn) — sem isso, a ordem de
## desenho seguiria só a ordem dos nós-irmãos na árvore (`EnemySpawner`, que
## hospeda este efeito, vem ANTES de `Dinosaurs`/`Projectiles` em Main.tscn),
## deixando o efeito atrás de qualquer raptor/projétil que estivesse por
## cima na hora. `z_index` garante "efeito sempre visível por cima do alvo"
## sem depender de reordenar a árvore inteira.

const _LIFETIME := 0.4

@onready var _visual: AnimatedVisual = $Visual


func _ready() -> void:
	_visual.play_state(AnimatedVisual.State.DEATH)
	get_tree().create_timer(_LIFETIME).timeout.connect(queue_free)


## Opcional — chamado ANTES de `add_child()` (ver BasicEnemy._spawn_death_effect()) para o efeito
## mostrar os frames de morte da própria criatura em vez do burst de impacto genérico (arte padrão
## do `AnimatedSprite2D`, ver DeathEffect.tscn — Checkpoint D). Sem isto (uso padrão: impacto de
## projétil, chegada ao ninho), o efeito continua com o burst genérico — não é toda morte/impacto
## que precisa ser "a morte daquela criatura específica".
##
## Bug real encontrado por run_tests.ps1 na etapa em que isto foi criado: acessar via `_visual` (o
## próprio campo `@onready` de DeathEffect) falha aqui porque `_visual` só é resolvido no
## `_ready()` de DeathEffect — e este método roda ANTES de `add_child()`, ou seja, antes de
## qualquer `_ready()` da subárvore disparar. `self.get_node_or_null("Visual/...")` funciona
## porque navega a ESTRUTURA da cena já instanciada (existe assim que `instantiate()` roda), não
## um campo cacheado que ainda não foi preenchido.
func set_death_sprite_frames(frames: SpriteFrames) -> void:
	var sprite := get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or frames == null or not frames.has_animation("death"):
		return
	sprite.sprite_frames = frames
