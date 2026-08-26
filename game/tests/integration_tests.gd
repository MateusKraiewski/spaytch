extends SceneTree
## Teste de integração: carrega Main.tscn de verdade (o mesmo wiring de
## produção — GridManager, InputManager, EnemySpawner, BasicEnemy) e
## confirma que o pipeline completo funciona: mapa carrega, MapPath é
## construído, um BasicEnemy nasce no SPAWN, percorre o caminho e emite
## reached_nest.
##
## Diferente de path_tests.gd e enemy_tests.gd (lógica pura isolada), este
## teste instancia a cena real. Para avançar no tempo, chama
## BasicEnemy.step(delta) diretamente em vez de depender de frames reais de
## engine — testar tempo real de frame em modo headless seria frágil (o
## motor não gera frames de _process de forma confiável sem um loop de
## renderização real); step() já é a mesma API pública usada pelos testes
## de movimento em enemy_tests.gd, não é um hack criado só para este teste.
##
## Valores capturados por sinais usam Array de 1 elemento em vez de
## variáveis simples — lambdas do GDScript capturam variáveis locais
## simples POR VALOR (reatribuir dentro da lambda não é visto fora dela);
## um Array é capturado por referência ao mesmo objeto compartilhado, então
## mutar um elemento dele é visível fora da lambda. Confirmado
## empiricamente contra Godot 4.7.2 (mesma técnica em enemy_tests.gd).
##
## `await process_frame` logo após add_child(main): a notificação
## NOTIFICATION_READY de nodes recém-adicionados a uma SceneTree/Window não
## é entregue de forma síncrona dentro de add_child() quando rodando via um
## script customizado que estende SceneTree — confirmado empiricamente
## contra Godot 4.7.2 (fica pendente até o próximo flush de chamadas
## adiadas). Aguardar um único process_frame é o idiom padrão do Godot para
## isso (não é polling nem depende de quantos frames algo "eventualmente"
## leva — é uma sincronização determinística de um passo). O avanço no
## tempo de movimento continua 100% determinístico via step(delta) direto,
## sem depender de frames reais.
##
## Executar com:
##   godot --headless --path game --script res://tests/integration_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[integration_tests] FAIL: %s" % message)


func _initialize() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn should load")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	_check(spawner != null, "Main should have an EnemySpawner child")
	if spawner == null:
		main.free()
		_finish()
		return

	var spawned_enemy_holder := [null]
	spawner.enemy_spawned.connect(func(enemy: BasicEnemy) -> void: spawned_enemy_holder[0] = enemy)

	var reached_holder := [false]
	spawner.enemy_reached_nest.connect(func(_enemy: BasicEnemy) -> void: reached_holder[0] = true)

	root.add_child(main)  # dispara _ready() em cascata -> spawn real via Main.gd
	await process_frame  # garante que NOTIFICATION_READY já foi entregue (ver comentário acima)

	_check(spawned_enemy_holder[0] != null, "EnemySpawner should have spawned a BasicEnemy on Main._ready()")

	if spawned_enemy_holder[0] != null:
		var spawned_enemy: BasicEnemy = spawned_enemy_holder[0]
		var grid_manager := main.get_node("GridManager") as GridManager

		var expected_start: Vector2 = grid_manager.grid.cell_center_world(Vector2i(1, 9))
		_check(spawned_enemy.position.distance_to(expected_start) <= 0.5,
			"enemy should start at the SPAWN world position")

		var iterations := 0
		while not spawned_enemy.is_finished() and iterations < 2000:
			spawned_enemy.step(0.1)
			iterations += 1

		_check(spawned_enemy.is_finished(), "enemy should finish the path within a bounded number of steps")
		_check(reached_holder[0], "enemy_reached_nest should have been emitted through EnemySpawner")

		var expected_end: Vector2 = grid_manager.grid.cell_center_world(Vector2i(18, 2))
		_check(spawned_enemy.position.distance_to(expected_end) <= 0.5,
			"enemy should end at the NEST world position")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("[integration_tests] ALL TESTS PASSED")
	else:
		print("[integration_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
