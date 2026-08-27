extends SceneTree
## Testes determinísticos de Egg (hp/dano/destruição) e EggManager (deriva
## posições de MapDefinition, regra determinística de seleção, detecção de
## "todos destruídos", reação a EnemySpawner.enemy_reached_nest).
##
## Executar com:
##   godot --headless --path game --script res://tests/egg_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_egg_hp_after_initialize()
	_test_egg_take_damage_reduces_hp()
	_test_egg_is_destroyed_at_zero_hp()
	_test_egg_damaged_signal()
	_test_egg_destroyed_signal()
	_test_egg_no_damage_after_destroyed()

	_test_egg_manager_derives_positions_from_map()
	_test_egg_manager_all_destroyed_false_initially()
	_test_egg_manager_deterministic_selection()
	_test_egg_manager_all_destroyed_true_when_all_dead()
	_test_egg_manager_enemy_reached_nest_damages_next_egg()

	await _test_egg_visual_loop_state_healthy_vs_critical()
	await _test_egg_visual_loop_stops_when_destroyed()
	await _test_egg_visual_plays_death_once_destroyed_and_never_reverts()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[egg_tests] ALL TESTS PASSED")
	else:
		print("[egg_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[egg_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _make_egg(max_hp: int = 30) -> Egg:
	var egg := Egg.new()
	egg.max_hp = max_hp
	egg.initialize(Vector2i.ZERO)
	return _track(egg) as Egg


# ---- Egg ----

func _test_egg_hp_after_initialize() -> void:
	var egg := _make_egg(40)
	_check(egg.hp == 40, "hp should equal max_hp after initialize, got %d" % egg.hp)
	_check(not egg.is_destroyed(), "fresh egg should not be destroyed")


func _test_egg_take_damage_reduces_hp() -> void:
	var egg := _make_egg(40)
	egg.take_damage(15)
	_check(egg.hp == 25, "hp should decrease by damage amount, got %d" % egg.hp)


func _test_egg_is_destroyed_at_zero_hp() -> void:
	var egg := _make_egg(10)
	egg.take_damage(10)
	_check(egg.is_destroyed(), "egg should be destroyed at 0 hp")
	_check(egg.hp == 0, "hp should not go negative, got %d" % egg.hp)


func _test_egg_damaged_signal() -> void:
	var egg := _make_egg(30)
	var received := [false]
	egg.damaged.connect(func(_e: Egg, _amount: int) -> void: received[0] = true)
	egg.take_damage(5)
	_check(received[0], "damaged signal should be emitted")


func _test_egg_destroyed_signal() -> void:
	var egg := _make_egg(10)
	var received := [false]
	egg.destroyed.connect(func(_e: Egg) -> void: received[0] = true)
	egg.take_damage(10)
	_check(received[0], "destroyed signal should be emitted at 0 hp")


func _test_egg_no_damage_after_destroyed() -> void:
	var egg := _make_egg(10)
	egg.take_damage(10)
	var destroy_count := [0]
	egg.destroyed.connect(func(_e: Egg) -> void: destroy_count[0] += 1)
	egg.take_damage(5)  # já destruído — não deveria fazer nada
	_check(destroy_count[0] == 0, "destroyed should not fire again on an already-destroyed egg")
	_check(egg.hp == 0, "hp should remain 0")


# ---- EggManager ----

func _make_map_with_eggs(count: int) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.width = count
	definition.height = 1
	definition.tile_size = 32
	var cells := PackedInt32Array()
	cells.resize(count)
	cells.fill(CellType.EGG)
	definition.cells = cells
	return definition


func _make_egg_manager(definition: MapDefinition, enemy_spawner: EnemySpawner) -> EggManager:
	var manager := EggManager.new()
	manager.egg_scene = load("res://scenes/eggs/Egg.tscn") as PackedScene
	manager.setup(definition, Grid.new(definition), enemy_spawner)
	return _track(manager) as EggManager


func _test_egg_manager_derives_positions_from_map() -> void:
	var definition := _make_map_with_eggs(3)
	var spawner := _track(EnemySpawner.new()) as EnemySpawner
	var manager := _make_egg_manager(definition, spawner)
	_check(manager.get_eggs().size() == 3, "should create exactly 3 eggs, got %d" % manager.get_eggs().size())
	_check(manager.get_eggs()[0].coord == Vector2i(0, 0), "first egg should be at (0,0)")
	_check(manager.get_eggs()[2].coord == Vector2i(2, 0), "third egg should be at (2,0)")


func _test_egg_manager_all_destroyed_false_initially() -> void:
	var definition := _make_map_with_eggs(2)
	var spawner := _track(EnemySpawner.new()) as EnemySpawner
	var manager := _make_egg_manager(definition, spawner)
	_check(not manager.all_destroyed(), "should not be all destroyed right after creation")


## Chama _damage_next_egg() diretamente (método "privado" por convenção,
## não por imposição do GDScript) para isolar a regra de seleção do
## mecanismo de disparo (enemy_reached_nest) — esse mecanismo já é testado
## separadamente logo abaixo.
func _test_egg_manager_deterministic_selection() -> void:
	var definition := _make_map_with_eggs(2)
	var spawner := _track(EnemySpawner.new()) as EnemySpawner
	var manager := _make_egg_manager(definition, spawner)
	var eggs := manager.get_eggs()

	manager._damage_next_egg(30)  # hp default do Egg é 30 — destrói o primeiro
	_check(eggs[0].is_destroyed(), "first egg should be destroyed by the first damage batch")
	_check(not eggs[1].is_destroyed(), "second egg should still be alive")

	manager._damage_next_egg(30)
	_check(eggs[1].is_destroyed(), "second egg should be destroyed once the first is gone")


func _test_egg_manager_all_destroyed_true_when_all_dead() -> void:
	var definition := _make_map_with_eggs(1)
	var spawner := _track(EnemySpawner.new()) as EnemySpawner
	var manager := _make_egg_manager(definition, spawner)
	var received := [false]
	manager.all_eggs_destroyed.connect(func() -> void: received[0] = true)
	manager._damage_next_egg(9999)
	_check(manager.all_destroyed(), "all_destroyed() should be true when the only egg is destroyed")
	_check(received[0], "all_eggs_destroyed signal should be emitted")


func _test_egg_manager_enemy_reached_nest_damages_next_egg() -> void:
	var definition := _make_map_with_eggs(1)
	var spawner := _track(EnemySpawner.new()) as EnemySpawner
	var manager := _make_egg_manager(definition, spawner)
	var egg := manager.get_eggs()[0]
	var initial_hp := egg.hp

	var enemy := BasicEnemy.new()
	enemy.egg_damage = 7
	enemy.initialize([Vector2(0, 0), Vector2(1, 0)])

	# EggManager._on_enemy_reached_nest() já chama enemy.queue_free() —
	# não registramos `enemy` em _to_free (evita double-free: queue_free()
	# é diferido, então .free() manual depois poderia coincidir com ele).
	spawner.enemy_reached_nest.emit(enemy)

	_check(egg.hp == initial_hp - 7,
		"egg should take enemy.egg_damage when enemy reaches the nest, got %d" % egg.hp)


# ---- Visual: loop de "vivo" (saudável/crítico/destruído) ----
# Precisa de uma árvore de verdade (create_tween() de AnimatedVisual exige
# SceneTree válida) — diferente dos testes acima, que usam Egg.new() solto.

func _make_egg_in_tree(max_hp: int) -> Egg:
	var packed := load("res://scenes/eggs/Egg.tscn") as PackedScene
	var egg := packed.instantiate() as Egg
	egg.max_hp = max_hp
	root.add_child(egg)
	return _track(egg) as Egg


func _test_egg_visual_loop_state_healthy_vs_critical() -> void:
	var egg := _make_egg_in_tree(100)
	await process_frame
	egg.initialize(Vector2i.ZERO)

	_check(egg._visual.last_loop_state == AnimatedVisual.State.IDLE,
		"ovo saudável deveria manter o loop IDLE, got %s" % egg._visual.last_loop_state)

	egg.take_damage(75)  # 25/100 = 25%, abaixo do limiar crítico (30%)
	_check(egg._visual.last_loop_state == AnimatedVisual.State.MOVE,
		"ovo com HP crítico deveria trocar para o loop agitado (MOVE), got %s" % egg._visual.last_loop_state)

	root.remove_child(egg)


func _test_egg_visual_loop_stops_when_destroyed() -> void:
	var egg := _make_egg_in_tree(10)
	await process_frame
	egg.initialize(Vector2i.ZERO)

	egg.take_damage(10)  # destrói
	_check(egg.is_destroyed(), "sanity: ovo deveria estar destruído")
	var loop_tween: Tween = egg._visual._loop_tween
	_check(loop_tween == null or not loop_tween.is_valid(),
		"loop de 'vivo' deveria parar quando o ovo é destruído")

	root.remove_child(egg)


## Checkpoint D — regra de gameplay preservada ("o ovo continua visível quando destruído") agora
## realizada tocando DEATH uma vez (arte de casca quebrada) em vez de só parar o loop com
## `stop_loop()`. Crítico: DEATH não pode reverter sozinho para IDLE/MOVE ao terminar — diferente
## de ATTACK/HIT (que voltam ao loop de "vivo" via `_on_sprite_reaction_finished()`), a casca
## quebrada tem que ficar visível para sempre. Também confirma que o golpe letal NÃO passa por
## HIT (que reverteria) — só DEATH.
func _test_egg_visual_plays_death_once_destroyed_and_never_reverts() -> void:
	var egg := _make_egg_in_tree(10)
	await process_frame
	egg.initialize(Vector2i.ZERO)

	var sprite := egg.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death"),
		"SpriteFrames do ovo deveria ter a animação 'death'")

	egg.take_damage(10)  # golpe letal — destrói no mesmo take_damage()
	_check(egg.is_destroyed(), "sanity: ovo deveria estar destruído")
	_check(sprite.animation == "death",
		"golpe letal deveria tocar 'death' diretamente, got '%s'" % sprite.animation)

	# Simula o fim da animação (sem depender de tempo real) — diferente de ATTACK/HIT, nada deve
	# reconectar/reverter: a casca quebrada precisa continuar sendo o que está na tela.
	sprite.animation_finished.emit()
	_check(sprite.animation == "death",
		"depois de terminar, 'death' não deveria reverter para IDLE/MOVE, got '%s'" % sprite.animation)

	root.remove_child(egg)
