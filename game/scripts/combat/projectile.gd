class_name Projectile
extends Node2D
## Entidade de combate separada do Dinosaur — não conhece cooldown nem
## targeting, só sabe perseguir um alvo e aplicar dano ao alcançá-lo.
##
## Movimento determinístico igual ao BasicEnemy: sem física, sem Area2D,
## "impacto" é só uma checagem de distância. Homing SIMPLES — persegue a
## posição ATUAL do alvo a cada passo, sem predição/lead (o alvo também está
## se movendo; calcular onde ele vai estar exigiria conhecer sua velocidade
## e trajetória futura, complexidade não necessária para este vertical
## slice).
##
## step(delta) é a lógica pura, chamada por _process() em runtime e
## diretamente pelos testes determinísticos (game/tests/projectile_tests.gd),
## mesmo padrão de BasicEnemy.step()/Dinosaur.step().

signal impacted(projectile: Projectile, target: BasicEnemy)  ## Phase 0.5 — gancho para feedback visual; só emitido em acerto real, não em "miss"

const _ARRIVAL_EPSILON := 4.0  ## px — maior que o de BasicEnemy: não há waypoints fixos, só um alvo em movimento
const _MAX_LIFETIME := 5.0  ## s — rede de segurança defensiva; não deveria ser atingida em uso normal
const _DEATH_EFFECT_SCENE := preload("res://scenes/effects/DeathEffect.tscn")

@onready var _visual: AnimatedVisual = $Visual

var _target: BasicEnemy
var _damage: int = 0
var _speed: float = 0.0
var _age: float = 0.0
var _spent: bool = false


## IDLE em voo (não é um objeto geométrico estático atravessando a tela —
## AnimatedVisual.State.IDLE já dá um leve "respiro" de rotação mesmo sem
## arte final). Projéteis não têm ATTACK/MOVE próprios (quem ataca é o
## Dinosaur que o disparou); o impacto usa o mesmo DeathEffect de
## BasicEnemy, não um estado de AnimatedVisual do próprio projétil (que já
## está prestes a desaparecer).
func initialize(target: BasicEnemy, damage: int, speed: float) -> void:
	_target = target
	_damage = damage
	_speed = speed
	_age = 0.0
	_spent = false
	if _visual != null:
		_visual.play_state(AnimatedVisual.State.IDLE)


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _spent:
		return

	_age += delta
	if _age > _MAX_LIFETIME:
		_spend()
		return

	# Alvo morreu, chegou ao ninho, ou foi liberado antes do impacto: o
	# projétil termina sem causar dano ("miss" silencioso), não deve
	# tentar acessar um Node inválido.
	if not is_instance_valid(_target) or not _target.is_active():
		_spend()
		return

	var to_target := _target.position - position
	var distance := to_target.length()
	var max_move := _speed * delta

	# Compara contra o quanto o projétil PODE se mover neste passo (não um
	# epsilon fixo pequeno) — senão um único step() com delta/velocidade
	# grandes o suficiente para cobrir toda a distância em um passo só
	# nunca detectaria a chegada nesse mesmo passo, empurrando o impacto
	# (e o dano) artificialmente para o próximo step().
	if distance <= max_move + _ARRIVAL_EPSILON:
		_target.take_damage(_damage)
		impacted.emit(self, _target)
		# Mesmo raciocínio de BasicEnemy._die(): o projétil se autodestrói
		# imediato (queue_free() logo abaixo, nunca adiado por animação); o
		# feedback visual de impacto é um DeathEffect independente, gerado
		# como irmão — sobrevive ao queue_free() do projétil e se
		# autodestrói sozinho depois.
		if is_inside_tree():
			_spawn_impact_effect()
		_spend()
		return

	rotation = to_target.angle()
	position += to_target.normalized() * max_move


func _spawn_impact_effect() -> void:
	var effect := _DEATH_EFFECT_SCENE.instantiate() as Node2D
	effect.global_position = global_position
	get_parent().add_child(effect)


func _spend() -> void:
	_spent = true
	queue_free()
