extends SceneTree
## Testes determinísticos de Projectile: movimento, impacto, dano, alvo
## removido/morto durante o voo. step(delta) chamado diretamente.
##
## Executar com:
##   godot --headless --path game --script res://tests/projectile_tests.gd

var _failures: int = 0
var _to_free: Array = []


func _initialize() -> void:
	_test_moves_toward_target()
	_test_impact_applies_damage()
	_test_damage_applied_only_once()
	_test_missing_target_causes_no_damage()
	_test_dead_target_causes_no_damage()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[projectile_tests] ALL TESTS PASSED")
	else:
		print("[projectile_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[projectile_tests] FAIL: %s" % message)


func _make_enemy_at(position: Vector2, max_hp: int = 20) -> BasicEnemy:
	var enemy := BasicEnemy.new()
	enemy.speed = 0.0  # parado de propósito: só o projétil se move nestes testes
	enemy.max_hp = max_hp
	enemy.initialize([position, position + Vector2(1, 0)])
	_to_free.append(enemy)
	return enemy


func _make_projectile(target: BasicEnemy, damage: int, speed: float, start_position: Vector2) -> Projectile:
	var projectile := Projectile.new()
	projectile.position = start_position
	projectile.initialize(target, damage, speed)
	_to_free.append(projectile)
	return projectile


func _test_moves_toward_target() -> void:
	var enemy := _make_enemy_at(Vector2(1000, 0))
	var projectile := _make_projectile(enemy, 5, 100.0, Vector2(0, 0))
	projectile.step(1.0)  # 100px/s * 1s = 100px; alvo está a 1000px, não deveria ter chegado
	_check(absf(projectile.position.x - 100.0) < 0.5,
		"projétil deveria ter avançado 100px em direção ao alvo, posição: %s" % projectile.position)


func _test_impact_applies_damage() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0), 20)
	var projectile := _make_projectile(enemy, 8, 200.0, Vector2(0, 0))
	projectile.step(1.0)  # tempo de sobra para alcançar (50px de distância, 200px/s)
	_check(enemy.hp == 12, "dano deveria ter sido aplicado ao alvo, hp: %d" % enemy.hp)


func _test_damage_applied_only_once() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0), 20)
	var projectile := _make_projectile(enemy, 8, 200.0, Vector2(0, 0))
	projectile.step(1.0)  # impacta
	projectile.step(1.0)  # já deveria estar "gasto" — não deveria fazer nada
	_check(enemy.hp == 12, "dano não deveria ser aplicado uma segunda vez, hp: %d" % enemy.hp)


func _test_missing_target_causes_no_damage() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0), 20)
	var projectile := _make_projectile(enemy, 8, 200.0, Vector2(0, 0))

	enemy.free()  # alvo liberado antes do impacto (removido por outro motivo)
	_to_free.erase(enemy)

	projectile.step(1.0)  # não deve gerar erro/crash ao acessar um alvo inválido
	_check(projectile.position == Vector2(0, 0),
		"projétil não deveria se mover quando o alvo é inválido")


func _test_dead_target_causes_no_damage() -> void:
	var enemy := _make_enemy_at(Vector2(50, 0), 10)
	var projectile := _make_projectile(enemy, 8, 200.0, Vector2(0, 0))
	enemy.take_damage(10)  # mata o alvo antes do projétil chegar
	_check(enemy.is_dead(), "sanity check: alvo deveria estar morto")

	projectile.step(1.0)
	_check(projectile.position == Vector2(0, 0),
		"projétil não deveria se mover quando o alvo já está morto/inativo")
