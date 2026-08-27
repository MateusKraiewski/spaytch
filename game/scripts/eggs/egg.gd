class_name Egg
extends Node2D
## Runtime de um ovo — objeto real de gameplay (Phase 0.5), não mais dado
## abstrato do mapa. Posição/quantidade derivam de
## MapDefinition.get_egg_positions() (única fonte de verdade — ver
## EggManager, que não duplica essas posições em nenhum outro Resource).
##
## Node2D (mesmo raciocínio de BasicEnemy/Dinosaur): posição própria +
## `$Visual` (AnimatedVisual) que reage ao dano/destruição. O ovo não se
## move e não é removido da cena quando destruído (continua visível, agora
## com a casca quebrada de verdade — ver Checkpoint D em ARCHITECTURE.md).
##
## "Vivo" nunca fica estático: enquanto não destruído, mantém um loop
## contínuo em `$Visual` — IDLE (respiração lenta, saudável) acima de
## `_CRITICAL_HP_FRACTION`, MOVE (mesmo loop, só mais rápido/agitado —
## reaproveitado como "pulso de urgência"/ferido, não literalmente
## "andando": o nome do estado é interno a AnimatedVisual, o jogador nunca
## vê "MOVE") abaixo dela.
##
## Ao ser destruído, toca DEATH uma vez (`loop = false` no SpriteFrames) —
## diferente de BasicEnemy/Dinosaur (onde DEATH acompanha uma entidade que
## está prestes a sumir/ser liberada), aqui a arte de "death" é desenhada
## para ficar bem em pé, quebrada, PARA SEMPRE (a animação simplesmente
## congela no último frame ao terminar — `AnimatedVisual` não reconecta
## `animation_finished` para o estado DEATH, então nada a traz de volta ao
## loop de "vivo"). Isso preserva a regra de gameplay de o ovo continuar
## visível quando destruído sem precisar de nenhum mecanismo novo.

signal damaged(egg: Egg, amount: int)
signal destroyed(egg: Egg)

@export var max_hp: int = 30  ## TBD/placeholder balance

@onready var _visual: AnimatedVisual = $Visual

var hp: int = 0
var coord: Vector2i = Vector2i.ZERO

var _destroyed: bool = false

const _CRITICAL_HP_FRACTION := 0.3
const _DAMAGE_NUMBER_SCENE := preload("res://scenes/effects/DamageNumber.tscn")


## Mesmo padrão de BasicEnemy.initialize()/Economy.reset(): callable direto
## em testes sem depender de _ready()/SceneTree.
func initialize(p_coord: Vector2i) -> void:
	coord = p_coord
	hp = max_hp
	_destroyed = false
	_update_visual()


func is_destroyed() -> bool:
	return _destroyed


func take_damage(amount: int) -> void:
	if _destroyed:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(self, amount)
	if is_inside_tree():
		_spawn_damage_number(amount)
	if hp <= 0:
		_destroyed = true
		destroyed.emit(self)
	_update_visual()


func _spawn_damage_number(amount: int) -> void:
	var number := _DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	number.global_position = global_position + Vector2(0, -10)
	number.initialize(amount)
	get_parent().add_child(number)


## Decide QUAL animação toca: IDLE/MOVE enquanto vivo (por fração de HP, ver comentário de
## classe), HIT como reação a um dano não-letal, DEATH uma vez só quando é o golpe que destrói
## (nunca as duas coisas no mesmo golpe — HIT reverteria sozinho para o loop de "vivo" ao
## terminar, desfazendo a casca quebrada). `_visual == null` cobre os testes que instanciam
## Egg.new()/chamam initialize() sem add_child() — sem Visual, não há nada para animar.
##
## Não aplica mais tingimento por fração de HP (`set_base_modulate`, era como o protótipo
## placeholder comunicava saudável/ferido/destruído só com cor, antes de existir arte real).
## `modulate` MULTIPLICA a cor do sprite — um tom não-branco por cima da arte cuidadosamente
## desenhada aqui (Checkpoint D) desbotaria/distorceria as cores reais em vez de só "tingir um
## polígono monocromático" como antes (mesma categoria de decisão já tomada para
## `Dinosaur.setup()`/`placeholder_color` no Checkpoint B). A diferença saudável/ferido/destruído
## agora vem inteiramente da animação escolhida (idle/move/death), que já é bem mais expressiva
## do que um gradiente de cor.
func _update_visual() -> void:
	if _visual == null:
		return
	if _destroyed:
		_visual.play_state(AnimatedVisual.State.DEATH)
	else:
		var fraction := float(hp) / float(max_hp) if max_hp > 0 else 0.0
		var loop_state := AnimatedVisual.State.MOVE if fraction <= _CRITICAL_HP_FRACTION else AnimatedVisual.State.IDLE
		_visual.play_state(loop_state)
		_visual.play_state(AnimatedVisual.State.HIT)
