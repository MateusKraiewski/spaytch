extends SceneTree
## Testes determinísticos de Targeting (modo FIRST). Enemies sintéticos são
## avançados por step() sobre um segmento reto para controlar exatamente
## get_distance_traveled() (e, junto, sua posição, já que ambos avançam
## 1:1 num segmento reto — suficiente para isolar a lógica de seleção sem
## precisar do Vale dos Ovos real).
##
## Executar com:
##   godot --headless --path game --script res://tests/targeting_tests.gd

var _failures: int = 0
var _to_free: Array[BasicEnemy] = []


func _initialize() -> void:
	_test_no_candidates_returns_null()
	_test_single_enemy_in_range_selected()
	_test_enemy_out_of_range_returns_null()
	_test_dead_enemy_ignored()
	_test_finished_enemy_ignored()
	_test_first_selects_most_progress()
	_test_first_ignores_out_of_range_when_choosing()

	for enemy in _to_free:
		if is_instance_valid(enemy):
			enemy.free()

	if _failures == 0:
		print("[targeting_tests] ALL TESTS PASSED")
	else:
		print("[targeting_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[targeting_tests] FAIL: %s" % message)


## Cria um inimigo num segmento reto de comprimento grande e avança
## `distance_traveled` px (a 1 px por unidade de delta), deixando tanto a
## posição quanto o progresso previsíveis para o teste.
func _make_enemy_at_progress(distance_traveled: float, max_hp: int = 20) -> BasicEnemy:
	var enemy := BasicEnemy.new()
	enemy.speed = 1.0
	enemy.max_hp = max_hp
	enemy.initialize([Vector2(0, 0), Vector2(1000000, 0)])
	if distance_traveled > 0.0:
		enemy.step(distance_traveled)
	_to_free.append(enemy)
	return enemy


func _test_no_candidates_returns_null() -> void:
	var result := Targeting.select_target([], Vector2(0, 0), 100.0)
	_check(result == null, "sem candidatos, select_target deveria retornar null")


func _test_single_enemy_in_range_selected() -> void:
	var enemy := _make_enemy_at_progress(50.0)
	var result := Targeting.select_target([enemy], Vector2(0, 0), 100.0)
	_check(result == enemy, "único inimigo dentro do alcance deveria ser selecionado")


func _test_enemy_out_of_range_returns_null() -> void:
	var enemy := _make_enemy_at_progress(500.0)
	var result := Targeting.select_target([enemy], Vector2(0, 0), 100.0)
	_check(result == null, "inimigo fora do alcance não deveria ser selecionado")


func _test_dead_enemy_ignored() -> void:
	var enemy := _make_enemy_at_progress(50.0)
	enemy.take_damage(enemy.max_hp)
	_check(enemy.is_dead(), "sanity check: inimigo deveria estar morto")
	var result := Targeting.select_target([enemy], Vector2(0, 0), 100.0)
	_check(result == null, "inimigo morto não deveria ser selecionável")


func _test_finished_enemy_ignored() -> void:
	var enemy := BasicEnemy.new()
	enemy.speed = 50.0
	enemy.initialize([Vector2(0, 0), Vector2(10, 0)])
	enemy.step(5.0)  # tempo de sobra para terminar um trajeto curto
	_check(enemy.is_finished(), "sanity check: inimigo deveria ter terminado o caminho")
	_to_free.append(enemy)
	var result := Targeting.select_target([enemy], Vector2(0, 0), 1000.0)
	_check(result == null, "inimigo que já chegou ao ninho não deveria ser selecionável")


func _test_first_selects_most_progress() -> void:
	var low := _make_enemy_at_progress(20.0)
	var high := _make_enemy_at_progress(80.0)
	var mid := _make_enemy_at_progress(50.0)
	var result := Targeting.select_target([low, high, mid], Vector2(0, 0), 1000.0)
	_check(result == high, "FIRST deveria selecionar o inimigo com maior distância percorrida")


func _test_first_ignores_out_of_range_when_choosing() -> void:
	var in_range_low_progress := _make_enemy_at_progress(10.0)
	var out_of_range_high_progress := _make_enemy_at_progress(500.0)
	var result := Targeting.select_target(
		[in_range_low_progress, out_of_range_high_progress], Vector2(0, 0), 100.0)
	_check(result == in_range_low_progress,
		"o inimigo fora de alcance não deveria vencer mesmo tendo mais progresso")
