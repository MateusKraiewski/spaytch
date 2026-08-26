class_name BasicEnemy
extends Node2D
## Inimigo básico: PATH FOLLOWING de uma lista de waypoints em espaço de
## mundo já pronta (não descobre caminho, não conhece Grid/MapDefinition/
## MapPath — só recebe posições prontas via initialize()).
##
## Node2D, não CharacterBody2D: não há física nem colisão nesta fase, só
## interpolação de posição — Node2D é suficiente e mais leve.
##
## Placeholder visual: Polygon2D (triângulo), ver scenes/enemies/BasicEnemy.tscn.
## TEMPORÁRIO — substituível por Sprite2D/AnimatedSprite2D no futuro sem
## mudar este script (a lógica de movimento não sabe nada sobre a
## apresentação visual).
##
## `speed` é TBD/placeholder balance — valor só para visualização/teste
## nesta fase, não é balanceamento definitivo.
##
## step(delta) é a lógica de movimento pura, chamada por _process() em
## runtime e diretamente pelos testes determinísticos
## (game/tests/enemy_tests.gd), sem precisar rodar dentro de uma SceneTree
## real — evita depender de timing real de frame em testes headless.

signal reached_nest(enemy: BasicEnemy)

@export var speed: float = 60.0  ## px/s — TBD/placeholder balance

const _ARRIVAL_EPSILON := 0.01
const _MAX_ITERATIONS_PER_STEP := 64  ## rede de segurança contra dados degenerados (não deveria disparar em uso normal)

var _waypoints: Array[Vector2] = []
var _current_index: int = 0
var _finished: bool = false


func initialize(waypoints: Array[Vector2]) -> void:
	assert(waypoints.size() >= 2, "BasicEnemy requires at least 2 waypoints (start and end).")
	_waypoints = waypoints
	_current_index = 0
	_finished = false
	position = _waypoints[0]


func is_finished() -> bool:
	return _finished


func current_waypoint_index() -> int:
	return _current_index


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
	if _finished or _waypoints.is_empty() or speed <= 0.0:
		return

	var remaining := delta
	var iterations := _MAX_ITERATIONS_PER_STEP
	while remaining > 0.0 and not _finished and iterations > 0:
		iterations -= 1
		var target: Vector2 = _waypoints[_current_index + 1]
		var to_target := target - position
		var distance := to_target.length()

		if distance <= _ARRIVAL_EPSILON:
			position = target
			_advance_waypoint()
			continue

		rotation = to_target.angle()
		var max_move := speed * remaining
		if distance <= max_move:
			position = target
			remaining -= distance / speed
			_advance_waypoint()
		else:
			position += to_target.normalized() * max_move
			remaining = 0.0


func _advance_waypoint() -> void:
	_current_index += 1
	if _current_index >= _waypoints.size() - 1:
		_finished = true
		reached_nest.emit(self)
