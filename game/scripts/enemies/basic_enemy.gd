class_name BasicEnemy
extends Node2D
## Inimigo básico: PATH FOLLOWING de uma lista de waypoints em espaço de
## mundo já pronta (não descobre caminho, não conhece Grid/MapDefinition/
## MapPath — só recebe posições prontas via initialize()).
##
## Node2D, não CharacterBody2D: não há física nem colisão nesta fase, só
## interpolação de posição — Node2D é suficiente e mais leve.
##
## Visual: `AnimatedSprite2D` (pixel art, Primeiro Protótipo Visual) dentro
## de `$Visual` (AnimatedVisual), ver scenes/enemies/BasicEnemy.tscn — este
## script não sabe disso, só chama `_visual.play_state(...)`; se a arte for
## trocada de novo no futuro (ou removida, voltando ao fallback procedural)
## nenhuma linha aqui muda. `rotation` de direção (para onde o inimigo está
## virado) continua sendo desta classe (no node raiz); a animação de
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

## V2 — qual EnemyDefinition originou este inimigo (null = spawnado sem um, ver initialize()) —
## mesmo espírito de Dinosaur.definition: consultado por quem precisa saber O TIPO (hoje só
## WaveManager, pra recompensa por kill; ver _on_enemy_died()).
@export var definition: EnemyDefinition

@export var speed: float = 60.0  ## px/s — TBD/placeholder balance; sobrescrito por definition.speed se houver
@export var max_hp: int = 20  ## TBD/placeholder balance; sobrescrito por definition.max_hp se houver
@export var egg_damage: int = 10  ## dano ao ninho; sobrescrito por definition.egg_damage se houver

const _ARRIVAL_EPSILON := 0.01
const _MAX_ITERATIONS_PER_STEP := 64  ## rede de segurança contra dados degenerados (não deveria disparar em uso normal)
const _DEATH_EFFECT_SCENE := preload("res://scenes/effects/DeathEffect.tscn")
const _DAMAGE_NUMBER_SCENE := preload("res://scenes/effects/DamageNumber.tscn")

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
## `p_definition` opcional (V2) — quando fornecido, sobrescreve speed/max_hp/egg_damage a partir
## dele ANTES de aplicar o resto do reset (mesma ordem de Dinosaur.setup() lendo
## DinosaurDefinition). `null` preserva o comportamento de sempre (Sprint 0-1): quem chama
## initialize() sem definition continua controlando speed/max_hp/egg_damage diretamente via
## @export, como todo teste existente já faz.
func initialize(waypoints: Array[Vector2], p_definition: EnemyDefinition = null) -> void:
	assert(waypoints.size() >= 2, "BasicEnemy requires at least 2 waypoints (start and end).")
	definition = p_definition
	if definition != null:
		speed = definition.speed
		max_hp = definition.max_hp
		egg_damage = definition.egg_damage
	_waypoints = waypoints
	_current_index = 0
	_finished = false
	_dead = false
	_distance_traveled = 0.0
	hp = max_hp
	position = _waypoints[0]
	if _visual != null:
		# Mesmo contrato de Dinosaur.setup(): sprite_frames nulo (todo o roster V2 atual, ainda sem
		# arte própria por tipo) não troca nada — a cena mantém a arte procedural já hardcoded.
		if definition != null and definition.sprite_frames != null:
			_visual.set_sprite_frames(definition.sprite_frames)
			_visual.set_base_modulate(definition.placeholder_color)
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
## V2 — `definition.armor` (0 se não houver definition) reduz o dano ANTES de aplicar, mas nunca
## deixa passar menos que 1 — um "Blindado" fica ineficiente contra ataques fracos, não invencível
## contra qualquer atacante (evitaria uma composição de dinossauros ficar matematicamente
## impossível). `damaged`/DamageNumber mostram o dano EFETIVO (pós-armor), não o bruto — é o que
## realmente aconteceu ao hp, e é o número que o jogador precisa ver pra entender que a armadura
## está funcionando.
func take_damage(amount: int) -> void:
	if not is_active():
		return
	var armor := definition.armor if definition != null else 0
	var effective_amount := maxi(amount - armor, 1)
	hp -= effective_amount
	damaged.emit(self, effective_amount)
	if _visual != null:
		_visual.play_state(AnimatedVisual.State.HIT)
	if is_inside_tree():
		_spawn_damage_number(effective_amount)
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
		_spawn_death_effect(true)
	queue_free()


## `with_creature_sprite`: quando true (só na morte de verdade, não na chegada ao ninho — ver
## _advance_waypoint() abaixo), repassa o próprio SpriteFrames (se houver "death" nele) para o
## DeathEffect mostrar a animação de morte desta criatura específica em vez do losango neutro
## genérico. Lido direto do próprio $Visual/AnimatedSprite2D — não duplica a referência em
## nenhum outro lugar.
func _spawn_death_effect(with_creature_sprite: bool = false) -> void:
	var effect := _DEATH_EFFECT_SCENE.instantiate() as DeathEffect
	effect.global_position = global_position
	if with_creature_sprite and _visual != null:
		var sprite := _visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null and sprite.sprite_frames != null:
			effect.set_death_sprite_frames(sprite.sprite_frames)
	get_parent().add_child(effect)


func _spawn_damage_number(amount: int) -> void:
	var number := _DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	number.global_position = global_position + Vector2(0, -8)
	number.initialize(amount)
	get_parent().add_child(number)


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
