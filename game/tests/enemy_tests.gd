extends SceneTree
## Testes determinísticos de movimento de BasicEnemy. Chamam step(delta)
## diretamente (a mesma API pura usada em runtime por _process), sem
## depender de timing real de frame do motor e sem adicionar o node a uma
## cena rodando — evita fragilidade de testar tempo real em modo headless.
##
## Comparações de posição usam tolerância (_approx_equal), não igualdade
## exata: `speed * delta` com delta como 0.1 envolve ponto flutuante que não
## é exatamente representável, então somas repetidas podem divergir por uma
## fração de pixel. Isso não afeta o resultado visual nem o comportamento
## real do jogo, só quebraria uma comparação `==` estrita nos testes.
##
## Flags setadas dentro de lambdas conectadas a signals usam Array[bool] de 1
## elemento, não `var flag := false` diretamente: uma lambda do GDScript
## captura variáveis locais simples POR VALOR (reatribuir `flag = true`
## dentro da lambda não é visto fora dela) — confirmado empiricamente contra
## Godot 4.7.2. Um Array é capturado por referência ao mesmo objeto
## compartilhado, então mutar um elemento dele é visível fora da lambda.
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


func _make_enemy(waypoints: Array[Vector2], speed: float = 50.0) -> BasicEnemy:
	var enemy := BasicEnemy.new()
	enemy.speed = speed
	enemy.initialize(waypoints)
	return enemy


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
