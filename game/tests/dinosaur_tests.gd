extends SceneTree
## Testes determinísticos de Dinosaur: seleção de alvo, cooldown, disparo.
## Chama Dinosaur.step(delta) diretamente — mesma API pública usada por
## _process() em runtime.
##
## Popula EnemySpawner._active_enemies diretamente em vez de rodar um ciclo
## completo de spawn com Grid/MapPath reais — conveniência de teste
## deliberada: o pipeline real spawn→registro já é coberto por
## combat_integration_tests.gd; aqui só precisamos de um EnemySpawner com
## alguns BasicEnemy conhecidos para isolar o comportamento de Dinosaur.
##
## Todo objeto criado (enemy, spawner, dinosaur, container de projéteis, e
## qualquer Projectile.tscn real instanciado por um disparo) é registrado em
## `_to_free` e liberado no final — Dinosaur dispara projéteis reais
## (Projectile.tscn, com nodes Polygon2D de verdade) mesmo nestes testes
## "unitários", e deixá-los sem dono causava vazamento de RID/CanvasItem no
## motor (detectado rodando de verdade contra Godot 4.7.2, não hipotético).
##
## Executar com:
##   godot --headless --path game --script res://tests/dinosaur_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_selects_target_in_range()
	_test_no_target_when_no_enemies()
	_test_fires_projectile_when_target_in_range()
	_test_does_not_fire_before_cooldown_elapses()
	_test_fires_again_after_cooldown_elapses()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[dinosaur_tests] ALL TESTS PASSED")
	else:
		print("[dinosaur_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[dinosaur_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _make_enemy_at(position: Vector2, max_hp: int = 20) -> BasicEnemy:
	var enemy := BasicEnemy.new()
	enemy.speed = 0.0  # parado de propósito: não precisamos que se mova nestes testes
	enemy.max_hp = max_hp
	enemy.initialize([position, position + Vector2(1, 0)])
	return _track(enemy)


func _make_spawner_with_enemies(enemies: Array[BasicEnemy]) -> EnemySpawner:
	var spawner := EnemySpawner.new()
	spawner._active_enemies = enemies
	return _track(spawner)


func _make_definition(p_range: float = 100.0, attack_interval: float = 1.0, damage: int = 5, projectile_speed: float = 200.0) -> DinosaurDefinition:
	var definition := DinosaurDefinition.new()
	definition.range = p_range
	definition.attack_interval = attack_interval
	definition.damage = damage
	definition.projectile_speed = projectile_speed
	definition.projectile_scene = load("res://scenes/combat/Projectile.tscn") as PackedScene
	return definition


func _make_dinosaur(definition: DinosaurDefinition, spawner: EnemySpawner, projectiles_container: Node, position: Vector2) -> Dinosaur:
	var dinosaur := Dinosaur.new()
	dinosaur.global_position = position
	dinosaur.setup(definition, spawner, projectiles_container)
	return _track(dinosaur)


func _make_projectiles_container() -> Node:
	var container := Node.new()
	return _track(container)


func _test_selects_target_in_range() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0))
	var spawner := _make_spawner_with_enemies([enemy])
	var definition := _make_definition(100.0)
	var dinosaur := _make_dinosaur(definition, spawner, _make_projectiles_container(), Vector2(0, 0))
	dinosaur.step(0.001)
	_check(dinosaur.current_target() == enemy, "dinossauro deveria selecionar o inimigo dentro do alcance")


func _test_no_target_when_no_enemies() -> void:
	var enemies: Array[BasicEnemy] = []
	var spawner := _make_spawner_with_enemies(enemies)
	var definition := _make_definition(100.0)
	var dinosaur := _make_dinosaur(definition, spawner, _make_projectiles_container(), Vector2(0, 0))
	dinosaur.step(0.001)
	_check(dinosaur.current_target() == null, "sem inimigos, dinossauro não deveria ter alvo")


func _test_fires_projectile_when_target_in_range() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0))
	var spawner := _make_spawner_with_enemies([enemy])
	var definition := _make_definition(100.0, 1.0, 5, 200.0)
	var projectiles := _make_projectiles_container()
	var dinosaur := _make_dinosaur(definition, spawner, projectiles, Vector2(0, 0))

	dinosaur.step(0.016)  # cooldown inicial é 0 — deveria disparar imediatamente

	_check(projectiles.get_child_count() == 1, "deveria ter instanciado exatamente 1 Projectile")


func _test_does_not_fire_before_cooldown_elapses() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0))
	var spawner := _make_spawner_with_enemies([enemy])
	var definition := _make_definition(100.0, 1.0, 5, 200.0)
	var projectiles := _make_projectiles_container()
	var dinosaur := _make_dinosaur(definition, spawner, projectiles, Vector2(0, 0))

	dinosaur.step(0.016)
	_check(projectiles.get_child_count() == 1, "sanity: primeiro tiro deveria ter acontecido")

	dinosaur.step(0.1)  # bem dentro do cooldown de 1.0s
	_check(projectiles.get_child_count() == 1, "não deveria disparar de novo antes do cooldown terminar")


func _test_fires_again_after_cooldown_elapses() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0))
	var spawner := _make_spawner_with_enemies([enemy])
	var definition := _make_definition(100.0, 1.0, 5, 200.0)
	var projectiles := _make_projectiles_container()
	var dinosaur := _make_dinosaur(definition, spawner, projectiles, Vector2(0, 0))

	dinosaur.step(0.016)
	_check(projectiles.get_child_count() == 1, "sanity: primeiro tiro deveria ter acontecido")

	dinosaur.step(1.1)  # tempo suficiente para o cooldown de 1.0s terminar
	_check(projectiles.get_child_count() == 2, "deveria disparar de novo após o cooldown terminar")
