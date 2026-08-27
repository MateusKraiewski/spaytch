extends SceneTree
## Testes determinísticos de Economy: coins inicial, can_afford, spend
## (sucesso/falha), add, sinal coins_changed. Mesmo padrão dos demais
## testes: chamadas diretas, sem depender de _ready()/SceneTree real.
##
## Executar com:
##   godot --headless --path game --script res://tests/economy_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_starts_with_starting_coins()
	_test_can_afford_true_when_enough()
	_test_can_afford_false_when_not_enough()
	_test_spend_success_deducts_coins()
	_test_spend_failure_does_not_deduct()
	_test_add_increases_coins()
	_test_add_ignores_non_positive_amounts()
	_test_coins_changed_signal_on_spend()
	_test_coins_changed_signal_on_add()
	_test_coins_changed_not_emitted_on_failed_spend()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[economy_tests] ALL TESTS PASSED")
	else:
		print("[economy_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[economy_tests] FAIL: %s" % message)


func _make_economy(starting: int = 100) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	_to_free.append(economy)
	return economy


func _test_starts_with_starting_coins() -> void:
	var economy := _make_economy(50)
	_check(economy.coins == 50, "coins should start at starting_coins, got %d" % economy.coins)


func _test_can_afford_true_when_enough() -> void:
	var economy := _make_economy(50)
	_check(economy.can_afford(50), "should afford exactly the amount available")
	_check(economy.can_afford(10), "should afford less than available")


func _test_can_afford_false_when_not_enough() -> void:
	var economy := _make_economy(10)
	_check(not economy.can_afford(11), "should not afford more than available")


func _test_spend_success_deducts_coins() -> void:
	var economy := _make_economy(50)
	var result := economy.spend(20)
	_check(result, "spend should succeed when affordable")
	_check(economy.coins == 30, "coins should be deducted, got %d" % economy.coins)


func _test_spend_failure_does_not_deduct() -> void:
	var economy := _make_economy(10)
	var result := economy.spend(20)
	_check(not result, "spend should fail when not affordable")
	_check(economy.coins == 10, "coins should be unchanged on failed spend, got %d" % economy.coins)


func _test_add_increases_coins() -> void:
	var economy := _make_economy(10)
	economy.add(15)
	_check(economy.coins == 25, "coins should increase by amount added, got %d" % economy.coins)


func _test_add_ignores_non_positive_amounts() -> void:
	var economy := _make_economy(10)
	economy.add(0)
	economy.add(-5)
	_check(economy.coins == 10, "add() with amount <= 0 should be a no-op, got %d" % economy.coins)


func _test_coins_changed_signal_on_spend() -> void:
	var economy := _make_economy(50)
	var received := [false]
	economy.coins_changed.connect(func(_n: int) -> void: received[0] = true)
	economy.spend(10)
	_check(received[0], "coins_changed should be emitted on successful spend")


func _test_coins_changed_signal_on_add() -> void:
	var economy := _make_economy(50)
	var received := [false]
	economy.coins_changed.connect(func(_n: int) -> void: received[0] = true)
	economy.add(10)
	_check(received[0], "coins_changed should be emitted on add")


func _test_coins_changed_not_emitted_on_failed_spend() -> void:
	var economy := _make_economy(5)
	var received := [false]
	economy.coins_changed.connect(func(_n: int) -> void: received[0] = true)
	economy.spend(50)
	_check(not received[0], "coins_changed should not be emitted when spend fails")
