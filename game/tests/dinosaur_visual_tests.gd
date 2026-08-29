extends SceneTree
## Testes da integração visual (Sprint 1): confirma que Dinosaur.setup() aplica o
## `DinosaurDefinition.sprite_frames` certo ao AnimatedSprite2D — para as 3 espécies aprovadas,
## para as 3 tiers do Velociraptor (incluindo via fusão, não só placement direto), e que o
## Velociraptor procedural antigo (sprite_frames null) continua com a arte hardcoded de sempre.
##
## Mesmo raciocínio de dinosaur_aura_tests.gd: `dinosaurs_container` precisa estar de verdade
## dentro da SceneTree (root.add_child) para os `@onready` de Dinosaur/AnimatedVisual resolverem
## e `Dinosaur.setup()` realmente executar a troca — um Node solto (estilo placement_tests.gd)
## deixaria `_visual` null e o bloco inteiro seria pulado (comportamento seguro, mas não testa
## nada aqui).
##
## Executar com:
##   godot --headless --path game --script res://tests/dinosaur_visual_tests.gd

var _failures: int = 0
var _to_free: Array = []

const _COORD_A := Vector2i(0, 0)
const _COORD_B := Vector2i(1, 0)


func _initialize() -> void:
	await _test_legacy_velociraptor_keeps_hardcoded_art()
	await _test_velociraptor_t1_uses_own_sprite_frames()
	await _test_triceratops_t1_uses_own_sprite_frames()
	await _test_trex_t1_uses_own_sprite_frames()
	await _test_fusion_t1_plus_t1_result_uses_t2_sprite_frames()
	await _test_fusion_t2_plus_t2_result_uses_t3_sprite_frames_and_has_aura()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[dinosaur_visual_tests] ALL TESTS PASSED")
	else:
		print("[dinosaur_visual_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[dinosaur_visual_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


func _make_two_cell_grid() -> Grid:
	var definition := MapDefinition.new()
	definition.width = 2
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.BUILDABLE, CellType.BUILDABLE])
	return Grid.new(definition)


func _make_economy(starting: int = 1000) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	return _track(economy) as Economy


## `await process_frame` ANTES de qualquer placement — não depois. `root.add_child(dinosaurs)`
## não deixa `dinosaurs` "de verdade" dentro da árvore sincronamente neste harness headless
## (mesma observação já documentada em game_loop_integration_tests.gd/animated_visual_tests.gd);
## sem esperar um frame aqui, `Dinosaur.setup()` roda com `_visual` ainda null (o guard
## `if _visual != null` simplesmente pula o bloco inteiro, incluindo a troca de sprite_frames) —
## e um await DEPOIS do placement não conserta retroativamente uma chamada síncrona que já
## rodou com o valor errado. Bug real encontrado rodando estes testes a 1ª vez.
func _controller_with_real_tree(grid: Grid) -> PlacementController:
	var dinosaurs := Node.new()
	root.add_child(dinosaurs)
	_track(dinosaurs)
	await process_frame

	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	var enemy_spawner := _track(EnemySpawner.new()) as EnemySpawner
	var projectiles := _track(Node.new()) as Node
	controller.setup(grid, enemy_spawner, dinosaurs, projectiles, _make_economy())
	return controller


func _place(controller: PlacementController, grid: Grid, definition: DinosaurDefinition, coord: Vector2i) -> void:
	controller.select_dinosaur(definition)
	controller.on_pointer_pressed(grid.cell_center_world(coord))


func _sprite_frames_of(dinosaur: Dinosaur) -> SpriteFrames:
	var sprite := dinosaur.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	return sprite.sprite_frames if sprite != null else null


func _has_aura_child(dinosaur: Dinosaur) -> bool:
	for child in dinosaur.get_children():
		if child is AuraEffect:
			return true
	return false


func _load_frames(path: String) -> SpriteFrames:
	return load(path) as SpriteFrames


func _velociraptor_legacy() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor.tres") as DinosaurDefinition


func _velociraptor_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t1.tres") as DinosaurDefinition


func _velociraptor_t2() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t2.tres") as DinosaurDefinition


func _triceratops_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/triceratops_t1.tres") as DinosaurDefinition


func _trex_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/trex_t1.tres") as DinosaurDefinition


## O Velociraptor procedural antigo (Checkpoints A-F) nunca preencheu `sprite_frames` — este
## teste é a garantia explícita de que ele continua 100% intocado visualmente por esta
## integração: `AnimatedSprite2D.sprite_frames` depois do placement deve ser exatamente o mesmo
## recurso que já estava hardcoded em Dinosaur.tscn, não `null` nem qualquer outra coisa.
func _test_legacy_velociraptor_keeps_hardcoded_art() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_legacy(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur == null:
		return
	var expected := _load_frames("res://data/dinosaurs/velociraptor_sprite_frames.tres")
	_check(_sprite_frames_of(dinosaur) == expected,
		"Velociraptor procedural antigo deveria manter a arte hardcoded original, sem nenhuma troca")


func _test_velociraptor_t1_uses_own_sprite_frames() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur == null:
		return
	_check(_sprite_frames_of(dinosaur) == _load_frames("res://data/dinosaurs/velociraptor_t1_sprite_frames.tres"),
		"Velociraptor T1 deveria usar seu próprio SpriteFrames PixelLab aprovado")


func _test_triceratops_t1_uses_own_sprite_frames() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _triceratops_t1(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur == null:
		return
	_check(_sprite_frames_of(dinosaur) == _load_frames("res://data/dinosaurs/triceratops_t1_sprite_frames.tres"),
		"Triceratops T1 deveria usar seu próprio SpriteFrames aprovado")


func _test_trex_t1_uses_own_sprite_frames() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _trex_t1(), _COORD_A)

	var dinosaur := grid.get_cell(_COORD_A).occupant
	_check(dinosaur != null, "placement deveria ter acontecido")
	if dinosaur == null:
		return
	_check(_sprite_frames_of(dinosaur) == _load_frames("res://data/dinosaurs/trex_t1_sprite_frames.tres"),
		"T-Rex T1 deveria usar seu próprio SpriteFrames aprovado")


## A troca de arte precisa funcionar pelo MESMO ponto de instanciação usado pela fusão
## (PlacementController._instantiate_dinosaur(), Etapa 5/6) — não só pelo placement direto.
func _test_fusion_t1_plus_t1_result_uses_t2_sprite_frames() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T1 + T1 deveria fundir para este teste fazer sentido")
	if result == null:
		return
	_check(_sprite_frames_of(result) == _load_frames("res://data/dinosaurs/velociraptor_t2_sprite_frames.tres"),
		"resultado da fusão (T2) deveria usar o SpriteFrames do T2, não o do T1")
	_check(not _has_aura_child(result), "T2 não deveria ter AuraEffect")


func _test_fusion_t2_plus_t2_result_uses_t3_sprite_frames_and_has_aura() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_with_real_tree(grid)
	_place(controller, grid, _velociraptor_t2(), _COORD_A)
	_place(controller, grid, _velociraptor_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T2 + T2 deveria fundir para este teste fazer sentido")
	if result == null:
		return
	_check(_sprite_frames_of(result) == _load_frames("res://data/dinosaurs/velociraptor_t3_sprite_frames.tres"),
		"resultado da fusão (T3) deveria usar o SpriteFrames do T3")
	_check(_has_aura_child(result), "T3 deveria ter AuraEffect")
