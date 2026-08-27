class_name Egg
extends Node2D
## Runtime de um ovo — objeto real de gameplay (Phase 0.5), não mais dado
## abstrato do mapa. Posição/quantidade derivam de
## MapDefinition.get_egg_positions() (única fonte de verdade — ver
## EggManager, que não duplica essas posições em nenhum outro Resource).
##
## Node2D (mesmo raciocínio de BasicEnemy/Dinosaur): posição própria +
## `$Visual` (AnimatedVisual) que reage ao dano/destruição. O ovo não se
## move e não é removido da cena quando destruído (continua visível, só
## visualmente "morto" — cinza) — por isso usa só HIT (flash + tingimento
## permanente por fração de HP), nunca DEATH (que faz o node desaparecer,
## errado para um ovo que deve continuar visível).
##
## "Vivo" nunca fica estático: enquanto não destruído, mantém um loop
## contínuo em `$Visual` — IDLE (respiração lenta) acima de
## `_CRITICAL_HP_FRACTION`, MOVE (mesmo loop, só mais rápido/agitado —
## reaproveitado como "pulso de urgência", não literalmente "andando": o
## nome do estado é interno a AnimatedVisual, o jogador nunca vê "MOVE")
## abaixo dela. Ao ser destruído, o loop para (`stop_loop()`) — um ovo
## destruído fica estático de propósito, não "morre" com uma animação.

signal damaged(egg: Egg, amount: int)
signal destroyed(egg: Egg)

@export var max_hp: int = 30  ## TBD/placeholder balance

@onready var _visual: AnimatedVisual = $Visual

var hp: int = 0
var coord: Vector2i = Vector2i.ZERO

var _destroyed: bool = false

const _DESTROYED_COLOR := Color(0.35, 0.35, 0.35, 0.6)
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


## Além do tingimento permanente por fração de HP, um flash breve (estado
## HIT de AnimatedVisual) marca o instante do dano/destruição — a cor de
## repouso para onde HIT relaxa é sempre a tingida por HP (`set_base_modulate`
## já aplica na hora, então mesmo sem tocar a animação o tom fica correto).
## Também decide o loop de "vivo" (ver comentário de classe) e o desliga na
## destruição. `_visual == null` cobre os testes que instanciam
## Egg.new()/chamam initialize() sem add_child() — sem Visual, não há nada
## para animar.
func _update_visual() -> void:
	var fraction := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var target_color: Color = _DESTROYED_COLOR if _destroyed \
		else Color(1.0, lerpf(0.3, 1.0, fraction), lerpf(0.3, 1.0, fraction))

	if _visual == null:
		return
	_visual.set_base_modulate(target_color)
	if _destroyed:
		_visual.stop_loop()
	else:
		var loop_state := AnimatedVisual.State.MOVE if fraction <= _CRITICAL_HP_FRACTION else AnimatedVisual.State.IDLE
		_visual.play_state(loop_state)
	_visual.play_state(AnimatedVisual.State.HIT)
