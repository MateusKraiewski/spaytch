extends SceneTree
## Testes determinísticos de movimento e combate de BasicEnemy. Chamam
## step(delta)/take_damage() diretamente (a mesma API pública usada em
## runtime), sem depender de timing real de frame do motor e sem adicionar
## o node a uma cena rodando — evita fragilidade de testar tempo real em
## modo headless.
##
## Comparações de posição/distância usam tolerância (_approx_equal /
## _approx_equal_float), não igualdade exata: `speed * delta` com delta
## fracionário envolve ponto flutuante que não é exatamente representável,
## então somas repetidas podem divergir por uma fração de pixel. Isso não
## afeta o resultado visual nem o comportamento real do jogo, só quebraria
## uma comparação `==` estrita nos testes.
##
## Flags setadas dentro de lambdas conectadas a signals usam Array[bool] de 1
## elemento, não `var flag := false` diretamente: uma lambda do GDScript
## captura variáveis locais simples POR VALOR (reatribuir `flag = true`
## dentro da lambda não é visto fora dela) — confirmado empiricamente contra
## Godot 4.7.2. Um Array é capturado por referência ao mesmo objeto
## compartilhado, então mutar um elemento dele é visível fora da lambda.
##
## Enemies mortos durante um teste (take_damage até 0 hp) já chamam
## queue_free() internamente — não chamamos .free() manualmente nesses
## casos, para não arriscar liberar o objeto duas vezes.
##
## Executar com:
##   godot --headless --path game --script res://tests/enemy_tests.gd

var _failures: int = 0


func _initialize() -> void:
	_test_starts_at_first_waypoint()
	_test_initial_waypoint_index()
	_test_advances_to_next_waypoint()
	_test_reaches_last_waypoint_and_finishes()
	_test_emits_reached_nest_signal()
	_test_movement_is_fps_independent()
	_test_no_movement_after_finished()

	_test_hp_initialized_to_max_hp()
	_test_take_damage_reduces_hp()
	_test_take_damage_kills_at_zero_hp()
	_test_died_signal_emitted()
	_test_take_damage_ignored_after_death()
	_test_no_movement_after_death()
	_test_is_active_true_when_alive()
	_test_is_active_false_when_finished()

	_test_distance_traveled_accumulates()
	_test_distance_traveled_stops_after_finish()

	_test_initialize_with_definition_applies_stats()
	_test_initialize_without_definition_keeps_manual_stats()
	_test_armor_reduces_damage()
	_test_armor_never_reduces_damage_below_one()
	_test_damaged_signal_reports_effective_post_armor_amount()

	if _failures == 0:
		print("[enemy_tests] ALL TESTS PASSED")
	else:
		print("[enemy_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[enemy_tests] FAIL: %s" % message)


func _approx_equal(a: Vector2, b: Vector2, epsilon: float = 0.5) -> bool:
	return a.distance_to(b) <= epsilon


func _approx_equal_float(a: float, b: float, epsilon: float = 0.5) -> bool:
	return absf(a - b) <= epsilon


func _make_enemy(waypoints: Array[Vector2], speed: float = 50.0, max_hp: int = 20) -> BasicEnemy:
	var enemy := BasicEnemy.new()
	enemy.speed = speed
	enemy.max_hp = max_hp
	enemy.initialize(waypoints)
	return enemy


# ---- Movimento (Phase 0.3, preservado) ----

func _test_starts_at_first_waypoint() -> void:
	var waypoints: Array[Vector2] = [Vector2(10, 20), Vector2(110, 20)]
	var enemy := _make_enemy(waypoints)
	_check(enemy.position == waypoints[0], "enemy should start exactly at the first waypoint")
	enemy.free()


func _test_initial_waypoint_index() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0)]
	var enemy := _make_enemy(waypoints)
	_check(enemy.current_waypoint_index() == 0, "initial waypoint index should be 0")
	enemy.free()


func _test_advances_to_next_waypoint() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]
	var enemy := _make_enemy(waypoints, 50.0)
	enemy.step(2.0)  # 50px/s * 2s = 100px = exatamente o primeiro segmento
	_check(enemy.current_waypoint_index() == 1, "enemy should have advanced to waypoint index 1")
	_check(_approx_equal(enemy.position, Vector2(100, 0)), "enemy should be at the second waypoint")
	enemy.free()


func _test_reaches_last_waypoint_and_finishes() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]
	var enemy := _make_enemy(waypoints, 50.0)
	enemy.step(10.0)  # tempo de sobra para cobrir o caminho inteiro (200px / 50px/s = 4s)
	_check(enemy.is_finished(), "enemy should be finished after enough time")
	_check(_approx_equal(enemy.position, waypoints[waypoints.size() - 1]),
		"enemy should end at the last waypoint")
	enemy.free()


func _test_emits_reached_nest_signal() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(50, 0)]
	var enemy := _make_enemy(waypoints, 50.0)
	var received := [false]
	enemy.reached_nest.connect(func(_e: BasicEnemy) -> void: received[0] = true)
	enemy.step(5.0)
	_check(received[0], "reached_nest signal should be emitted when the enemy finishes")
	enemy.free()


func _test_movement_is_fps_independent() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0)]

	var enemy_one_step := _make_enemy(waypoints, 50.0)
	enemy_one_step.step(2.0)

	var enemy_many_steps := _make_enemy(waypoints, 50.0)
	var iterations := 0
	while not enemy_many_steps.is_finished() and iterations < 40:
		enemy_many_steps.step(0.1)
		iterations += 1

	_check(enemy_many_steps.is_finished(), "many-small-steps enemy should have finished within 40 iterations")
	_check(_approx_equal(enemy_one_step.position, enemy_many_steps.position),
		"final position should match regardless of step granularity (%s vs %s)" %
			[enemy_one_step.position, enemy_many_steps.position])
	enemy_one_step.free()
	enemy_many_steps.free()


func _test_no_movement_after_finished() -> void:
	var waypoints: Array[Vector2] = [Vector2(0, 0), Vector2(50, 0)]
	var enemy := _make_enemy(waypoints, 50.0)
	enemy.step(5.0)
	var position_after_finish := enemy.position
	enemy.step(1.0)
	_check(enemy.position == position_after_finish, "enemy should not move after finishing")
	enemy.free()


# ---- HP / dano / morte (Phase 0.4) ----

func _test_hp_initialized_to_max_hp() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 30)
	_check(enemy.hp == 30, "hp should be initialized to max_hp, got %d" % enemy.hp)
	enemy.free()


func _test_take_damage_reduces_hp() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 30)
	enemy.take_damage(10)
	_check(enemy.hp == 20, "hp should decrease by the damage amount, got %d" % enemy.hp)
	_check(not enemy.is_dead(), "enemy should still be alive above 0 hp")
	enemy.free()


func _test_take_damage_kills_at_zero_hp() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 10)
	enemy.take_damage(10)
	_check(enemy.is_dead(), "enemy should be dead when hp reaches 0")
	_check(not enemy.is_active(), "dead enemy should not be active")


func _test_died_signal_emitted() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 10)
	var received := [false]
	enemy.died.connect(func(_e: BasicEnemy) -> void: received[0] = true)
	enemy.take_damage(10)
	_check(received[0], "died signal should be emitted when hp reaches 0")


func _test_take_damage_ignored_after_death() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 10)
	var death_count := [0]
	enemy.died.connect(func(_e: BasicEnemy) -> void: death_count[0] += 1)
	enemy.take_damage(10)
	enemy.take_damage(10)  # excedente: não deveria matar de novo nem reemitir died
	_check(death_count[0] == 1, "died should only be emitted once, got %d" % death_count[0])


func _test_no_movement_after_death() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0, 10)
	enemy.take_damage(10)
	var position_after_death := enemy.position
	enemy.step(1.0)
	_check(enemy.position == position_after_death, "dead enemy should not move")


# ---- V2 — EnemyDefinition (roster data-driven) ----

func _make_definition(speed: float = 90.0, max_hp: int = 15, egg_damage: int = 7, armor: int = 0) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.speed = speed
	definition.max_hp = max_hp
	definition.egg_damage = egg_damage
	definition.armor = armor
	return definition


func _test_initialize_with_definition_applies_stats() -> void:
	var enemy := BasicEnemy.new()
	enemy.speed = 999.0  # valores que initialize() com definition deveria SOBRESCREVER
	enemy.max_hp = 999
	enemy.egg_damage = 999
	var definition := _make_definition(90.0, 15, 7)
	enemy.initialize([Vector2(0, 0), Vector2(100, 0)], definition)
	_check(enemy.speed == 90.0, "speed deveria vir do EnemyDefinition, got %f" % enemy.speed)
	_check(enemy.max_hp == 15, "max_hp deveria vir do EnemyDefinition, got %d" % enemy.max_hp)
	_check(enemy.hp == 15, "hp deveria ser inicializado com o max_hp do EnemyDefinition, got %d" % enemy.hp)
	_check(enemy.egg_damage == 7, "egg_damage deveria vir do EnemyDefinition, got %d" % enemy.egg_damage)
	_check(enemy.definition == definition, "enemy.definition deveria ser exatamente o objeto passado")
	enemy.free()


## Sem definition (todo o roster Phase 0.3-0.6, e qualquer teste que não passe uma) continua
## controlando speed/max_hp/egg_damage diretamente via @export, exatamente como sempre — initialize()
## opcional não pode quebrar esse caminho antigo.
func _test_initialize_without_definition_keeps_manual_stats() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 42.0, 33)
	_check(enemy.speed == 42.0, "sem definition, speed deveria continuar o valor setado manualmente")
	_check(enemy.max_hp == 33, "sem definition, max_hp deveria continuar o valor setado manualmente")
	_check(enemy.definition == null, "sem definition, enemy.definition deveria continuar null")
	enemy.free()


## "Blindado" — a única mecânica nova do roster V2: armor reduz cada hit, forçando dano por hit
## mais alto em vez de spam de ataques fracos.
func _test_armor_reduces_damage() -> void:
	var enemy := BasicEnemy.new()
	enemy.initialize([Vector2(0, 0), Vector2(100, 0)], _make_definition(60.0, 30, 10, 5))
	enemy.take_damage(8)  # 8 - 5 armor = 3 efetivo
	_check(enemy.hp == 27, "armor deveria reduzir o dano em 5 (30 - 3 = 27), got %d" % enemy.hp)
	enemy.free()


## Mesmo um atacante muito mais fraco que a armadura sempre causa PELO MENOS 1 de dano —
## armadura reduz, nunca torna o inimigo matematicamente invencível.
func _test_armor_never_reduces_damage_below_one() -> void:
	var enemy := BasicEnemy.new()
	enemy.initialize([Vector2(0, 0), Vector2(100, 0)], _make_definition(60.0, 30, 10, 999))
	enemy.take_damage(1)
	_check(enemy.hp == 29, "mesmo com armor absurdamente alto, pelo menos 1 de dano deveria passar, got hp=%d" % enemy.hp)
	enemy.free()


func _test_damaged_signal_reports_effective_post_armor_amount() -> void:
	var enemy := BasicEnemy.new()
	enemy.initialize([Vector2(0, 0), Vector2(100, 0)], _make_definition(60.0, 30, 10, 5))
	var reported := [-1]
	enemy.damaged.connect(func(_e: BasicEnemy, amount: int) -> void: reported[0] = amount)
	enemy.take_damage(8)
	_check(reported[0] == 3, "sinal damaged deveria reportar o dano EFETIVO pós-armor (8-5=3), got %d" % reported[0])
	enemy.free()


func _test_is_active_true_when_alive() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0)
	_check(enemy.is_active(), "freshly initialized enemy should be active")
	enemy.free()


func _test_is_active_false_when_finished() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(50, 0)], 50.0)
	enemy.step(5.0)
	_check(enemy.is_finished(), "sanity check: enemy should have finished")
	_check(not enemy.is_active(), "finished enemy should not be active")
	enemy.free()


# ---- Progresso no caminho (Phase 0.4, requisito 7) ----

func _test_distance_traveled_accumulates() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0)
	_check(enemy.get_distance_traveled() == 0.0, "distance traveled should start at 0")
	enemy.step(1.0)  # 50px/s * 1s = 50px
	_check(_approx_equal_float(enemy.get_distance_traveled(), 50.0),
		"distance traveled should reflect actual movement, got %f" % enemy.get_distance_traveled())
	enemy.free()


func _test_distance_traveled_stops_after_finish() -> void:
	var enemy := _make_enemy([Vector2(0, 0), Vector2(100, 0)], 50.0)
	enemy.step(10.0)  # tempo de sobra, termina em 100px
	var distance_at_finish := enemy.get_distance_traveled()
	_check(_approx_equal_float(distance_at_finish, 100.0),
		"distance traveled should equal total path length at finish, got %f" % distance_at_finish)
	enemy.step(1.0)
	_check(enemy.get_distance_traveled() == distance_at_finish,
		"distance traveled should not change after finishing")
	enemy.free()
