extends SceneTree
## Testes determinísticos de DinosaurDefinition contra o Velociraptor real.
## Sem validador dedicado (ao contrário de MapValidator): campos escalares
## simples cabem em asserts diretos, uma classe separada seria
## over-engineering para isto — ver docs/ARCHITECTURE.md.
##
## Executar com:
##   godot --headless --path game --script res://tests/dinosaur_definition_tests.gd

var _failures: int = 0


func _initialize() -> void:
	_test_velociraptor_loads()
	_test_velociraptor_range_positive()
	_test_velociraptor_attack_interval_positive()
	_test_velociraptor_damage_positive()
	_test_velociraptor_projectile_speed_positive()
	_test_velociraptor_has_projectile_scene()
	_test_velociraptor_display_name_set()

	if _failures == 0:
		print("[dinosaur_definition_tests] ALL TESTS PASSED")
	else:
		print("[dinosaur_definition_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[dinosaur_definition_tests] FAIL: %s" % message)


func _load_velociraptor() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor.tres") as DinosaurDefinition


func _test_velociraptor_loads() -> void:
	_check(_load_velociraptor() != null, "velociraptor.tres should load as a DinosaurDefinition")


func _test_velociraptor_range_positive() -> void:
	_check(_load_velociraptor().range > 0.0, "range should be > 0")


func _test_velociraptor_attack_interval_positive() -> void:
	_check(_load_velociraptor().attack_interval > 0.0, "attack_interval should be > 0")


func _test_velociraptor_damage_positive() -> void:
	_check(_load_velociraptor().damage > 0, "damage should be > 0")


func _test_velociraptor_projectile_speed_positive() -> void:
	_check(_load_velociraptor().projectile_speed > 0.0, "projectile_speed should be > 0")


func _test_velociraptor_has_projectile_scene() -> void:
	var definition := _load_velociraptor()
	_check(definition.projectile_scene != null, "projectile_scene should be assigned")
	if definition.projectile_scene != null:
		var projectile := definition.projectile_scene.instantiate()
		_check(projectile is Projectile, "projectile_scene should instantiate a Projectile")
		projectile.free()


func _test_velociraptor_display_name_set() -> void:
	_check(_load_velociraptor().display_name == "Velociraptor",
		"display_name should be 'Velociraptor', got '%s'" % _load_velociraptor().display_name)
