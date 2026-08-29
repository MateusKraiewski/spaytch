class_name Dinosaur
extends Node2D
## Runtime genérico de um dinossauro defensor. Uma única cena/script serve
## qualquer tipo de dinossauro — a diferenciação vem inteiramente de
## `DinosaurDefinition` (dado), não de subclasses (Velociraptor, Triceratops
## etc. serão só `.tres` diferentes).
##
## Não implementa lógica de projétil (delega a Projectile) nem de escolha de
## alvo (delega a Targeting) — só orquestra cooldown + disparo. Não conhece
## os detalhes de COMO Targeting escolhe o alvo, só chama
## Targeting.select_target() e usa o resultado.
##
## step(delta) é a lógica pura, chamada por _process() em runtime e
## diretamente pelos testes determinísticos (game/tests/dinosaur_tests.gd).

signal fired(dinosaur: Dinosaur, projectile: Projectile)  ## Phase 0.5 — gancho para feedback visual

## Bug report do jogador — sprites de T2/T3 (arte PixelLab) são bem maiores que a célula 32x32
## onde o dinossauro é registrado (T3 ~176px, quase 6x a célula); colocar vários lado a lado ficava
## visualmente uma bagunça de sprites empilhados. Reduz só a EXIBIÇÃO (AnimatedVisual.scale), não a
## célula/hitbox lógica nem `DinosaurDefinition` — Fusion/Targeting/custo continuam inteiramente
## inalterados. Só se aplica a espécies com `sprite_frames` de verdade (ver setup() abaixo); o
## Velociraptor procedural antigo (sprite_frames sempre null) continua no tamanho de sempre.
const _DISPLAY_SCALE := 0.65

@export var definition: DinosaurDefinition

@onready var _visual: AnimatedVisual = $Visual

var _enemy_spawner: EnemySpawner
var _projectiles_container: Node
var _target: BasicEnemy = null
var _cooldown_remaining: float = 0.0


## `_visual.base_modulate` (não `modulate` direto) com definition.placeholder_color
## — `AnimatedVisual` é quem decide como aplicar isso (hoje: tingimento
## direto; no dia em que Visual ganhar um AnimatedSprite2D, o mesmo campo
## continua fazendo sentido). Dinossauros nunca se movem nesta fase — só
## IDLE (com o "pop" de spawn embutido em AnimatedVisual) e ATTACK ao
## disparar, nunca MOVE.
##
## Sprint 1 (integração visual) — `definition.sprite_frames` (Etapa 2) troca a arte do
## AnimatedSprite2D ANTES do play_state(IDLE), pra "idle" já resolver pra dentro do
## SpriteFrames certo. `null` (Velociraptor procedural antigo, e qualquer .tres futuro sem arte
## ainda) simplesmente não troca nada — a cena mantém a arte que já tinha hardcoded, mesmo
## comportamento de sempre. Nenhum `if species_id == ...` aqui: uma espécie nova só precisa
## preencher `sprite_frames` no próprio `.tres` (Etapa 1-2) pra aparecer certa, sem tocar neste
## arquivo.
func setup(p_definition: DinosaurDefinition, enemy_spawner: EnemySpawner, projectiles_container: Node) -> void:
	definition = p_definition
	_enemy_spawner = enemy_spawner
	_projectiles_container = projectiles_container
	if _visual != null and definition != null:
		if definition.sprite_frames != null:
			_visual.set_sprite_frames(definition.sprite_frames)
			_visual.set_display_scale(_DISPLAY_SCALE)
		_visual.set_base_modulate(definition.placeholder_color)
		_visual.play_state(AnimatedVisual.State.IDLE)


func current_target() -> BasicEnemy:
	return _target


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if definition == null or _enemy_spawner == null:
		return

	_cooldown_remaining -= delta

	if not _has_valid_target():
		_target = Targeting.select_target(_enemy_spawner.get_active_enemies(), global_position, definition.range)

	if _target != null and _cooldown_remaining <= 0.0:
		_fire()


func _has_valid_target() -> bool:
	if _target == null or not is_instance_valid(_target) or not _target.is_active():
		return false
	return global_position.distance_to(_target.position) <= definition.range


func _fire() -> void:
	var projectile := definition.projectile_scene.instantiate() as Projectile
	_projectiles_container.add_child(projectile)
	projectile.global_position = global_position
	projectile.initialize(_target, definition.damage, definition.projectile_speed)
	_cooldown_remaining = definition.attack_interval
	fired.emit(self, projectile)
	if _visual != null:
		_visual.play_state(AnimatedVisual.State.ATTACK)
