class_name BasicEnemy
extends Node2D
## Inimigo básico: PATH FOLLOWING de uma lista de waypoints em espaço de
## mundo já pronta (não descobre caminho, não conhece Grid/MapDefinition/
## MapPath — só recebe posições prontas via initialize()).
##
## Node2D, não CharacterBody2D: não há física nem colisão nesta fase, só
## interpolação de posição — Node2D é suficiente e mais leve.
##
## Placeholder visual: Polygon2D (triângulo) dentro de `$Visual`
## (AnimatedVisual), ver scenes/enemies/BasicEnemy.tscn. TEMPORÁRIO —
## substituível por AnimatedSprite2D no futuro sem mudar este script (a
## lógica de movimento não sabe nada sobre a apresentação visual, só chama
## `_visual.play_state(...)`). `rotation` de direção (para onde o inimigo
## está virado) continua sendo desta classe (no node raiz); a animação de
## MOVE/HIT mexe só em `$Visual` (filho), então as duas nunca competem pela
## mesma propriedade.
##
## `speed`/`max_hp`/`egg_damage` são TBD/placeholder balance — valores só
## para visualização/teste nesta fase, não são balanceamento definitivo.
##
## Completamente independente de Dinosaur/Targeting/Projectile — não
## conhece nenhum deles. `take_damage()` é uma API pública genérica que
## qualquer coisa pode chamar (hoje só Projectile o faz).
##
## step(delta) é a lógica de movimento pura, chamada por _process() em
## runtime e diretamente pelos testes determinísticos
## (game/tests/enemy_tests.gd), sem precisar rodar dentro de uma SceneTree
## real — evita depender de timing real de frame em testes headless.

signal reached_nest(enemy: BasicEnemy)
signal died(enemy: BasicEnemy)
signal damaged(enemy: BasicEnemy, amount: int)  ## Phase 0.5 — gancho para feedback visual (flash etc.)

@export var speed: float = 60.0  ## px/s — TBD/placeholder balance
@export var max_hp: int = 20  ## TBD/placeholder balance
@export var egg_damage: int = 10  ## dano causado a um ovo ao alcançar o ninho — TBD/placeholder balance

const _ARRIVAL_EPSILON := 0.01
const _MAX_ITERATIONS_PER_STEP := 64  ## rede de segurança contra dados degenerados (não deveria disparar em uso normal)
const _DEATH_EFFECT_SCENE := preload("res://scenes/effects/DeathEffect.tscn")

@onready var _visual: AnimatedVisual = $Visual

var hp: int = 0
var _waypoints: Array[Vector2] = []
var _current_index: int = 0
var _finished: bool = false
var _dead: bool = false
var _distance_traveled: float = 0.0


## Reseta todo o estado runtime (posição, HP, progresso) — chamado tanto em
## runtime (EnemySpawner.spawn_enemy()) quanto em testes que instanciam
## BasicEnemy.new() diretamente sem passar pela árvore de cena. Deliberado:
## não inicializar `hp` em _ready(), porque _ready() só dispara quando o
## node entra numa SceneTree — testes que chamam .new() sem add_child()
## nunca disparariam _ready(), deixando hp incorretamente zerado. Como
## initialize() já é o ponto de entrada estabelecido de "preparar este
## inimigo para uma corrida", também é o lugar certo (e já testado) para
## isso, e funciona igual nos dois contextos.
func initialize(waypoints: Array[Vector2]) -> void:
	assert(waypoints.size() >= 2, "BasicEnemy requires at least 2 waypoints (start and end).")
	_waypoints = waypoints
	_current_index = 0
	_finished = false
	_dead = false
	_distance_traveled = 0.0
	hp = max_hp
	position = _waypoints[0]
	if _visual != null:
		_visual.play_state(AnimatedVisual.State.MOVE)


func is_finished() -> bool:
	return _finished


func is_dead() -> bool:
	return _dead


## Falso se o inimigo já morreu ou já chegou ao ninho — usado por
## Targeting/Projectile para ignorar inimigos que não são mais alvos
## válidos, sem cada um precisar conhecer os dois estados separadamente.
func is_active() -> bool:
	return not (_finished or _dead)


func current_waypoint_index() -> int:
	return _current_index


## Distância acumulada (px de mundo) percorrida desde o SPAWN. Não é
## normalizada (0–1) de propósito: BasicEnemy não precisa conhecer o
## comprimento total do MapPath para isso ser útil — quem compara progresso
## entre inimigos (Targeting, modo FIRST) só precisa de valores comparáveis
## entre si, não de uma fração. Ver docs/ARCHITECTURE.md.
func get_distance_traveled() -> float:
	return _distance_traveled


## Dano genérico — quem causa dano (hoje só Projectile) não precisa saber
## nada sobre movimento/waypoints. Sem efeito se o inimigo já está morto ou
## já chegou ao ninho (evita, por exemplo, dois projéteis no mesmo frame
## matarem o mesmo inimigo duas vezes e dispararem `died` duas vezes).
func take_damage(amount: int) -> void:
	if not is_active():
		return
	hp -= amount
	damaged.emit(self, amount)
	if _visual != null:
		_visual.play_state(AnimatedVisual.State.HIT)
	if hp <= 0:
		_die()


## `queue_free()` continua imediato (nunca adiado por uma animação): ver
## docs/ARCHITECTURE.md "Phase 0.6" — atrasar a remoção real da entidade
## para "esperar a morte tocar" arriscaria travar testes headless que não
## bombeiam frames reais depois de matar um inimigo. O feedback visual de
## morte é um `DeathEffect` INDEPENDENTE, gerado como irmão deste node (não
## filho — ele sobreviveria ao `queue_free()` de qualquer forma, mas ser
## irmão deixa claro que o efeito não pertence à entidade que está sendo
## removida) e que se autodestrói sozinho depois de tocar sua própria
## animação, sem qualquer acompanhamento externo necessário.
func _die() -> void:
	_dead = true
	died.emit(self)
	if is_inside_tree():
		_spawn_death_effect()
	queue_free()


func _spawn_death_effect() -> void:
	var effect := _DEATH_EFFECT_SCENE.instantiate() as Node2D
	effect.global_position = global_position
	get_parent().add_child(effect)


func _process(delta: float) -> void:
	step(delta)


## Lógica de movimento pura — avança em direção ao próximo waypoint a
## `speed` px/s. Independente de FPS: a distância percorrida é sempre
## speed * delta, não importa em quantos passos o delta total é dividido.
## Se o delta cobrir mais de um waypoint (velocidade alta / delta grande),
## consome o restante no mesmo frame em vez de esperar o próximo _process,
## evitando lag perceptível. Sem overshoot: ao alcançar um waypoint, a
## posição é ajustada exatamente para ele, nunca ultrapassa.
func step(delta: float) -> void:
	if not is_active() or _waypoints.is_empty() or speed <= 0.0:
		return

	var remaining := delta
	var iterations := _MAX_ITERATIONS_PER_STEP
	while remaining > 0.0 and is_active() and iterations > 0:
		iterations -= 1
		var target: Vector2 = _waypoints[_current_index + 1]
		var to_target := target - position
		var distance := to_target.length()

		if distance <= _ARRIVAL_EPSILON:
			_distance_traveled += distance
			position = target
			_advance_waypoint()
			continue

		rotation = to_target.angle()
		var max_move := speed * remaining
		if distance <= max_move:
			position = target
			_distance_traveled += distance
			remaining -= distance / speed
			_advance_waypoint()
		else:
			position += to_target.normalized() * max_move
			_distance_traveled += max_move
			remaining = 0.0


## Feedback de chegada ao ninho (Phase 0.6): mesmo `DeathEffect` da morte,
## reaproveitado — a entidade em si NÃO se remove sozinha ao chegar (quem
## decide isso é EggManager, ver egg_manager.gd; BasicEnemy só reage
## visualmente ao próprio estado mudar para "chegou", sem tomar a decisão
## de remoção).
func _advance_waypoint() -> void:
	_current_index += 1
	if _current_index >= _waypoints.size() - 1:
		_finished = true
		if is_inside_tree():
			_spawn_death_effect()
		reached_nest.emit(self)
