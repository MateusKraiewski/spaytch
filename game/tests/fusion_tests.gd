extends SceneTree
## Testes da fusão (Sprint 1, Etapa 5): a regra pura em Fusion (dados, sem árvore de cena) e o
## efeito real em PlacementController.try_fuse() (grid de 2 células, mesmo padrão de
## placement_tests.gd — MapDefinition sintética, PlacementController real, Dinosaur real
## instanciado por Dinosaur.tscn).
##
## V2: as 3 espécies (Velociraptor, Triceratops, T-Rex) têm T1/T2/T3 completos — os mesmos testes
## de fusão são repetidos para cada uma, confirmando que Fusion/try_fuse() continuam genéricos
## (nenhuma linha por espécie precisou ser escrita para isso funcionar).
##
## Executar com:
##   godot --headless --path game --script res://tests/fusion_tests.gd

var _failures: int = 0
var _to_free: Array = []

const _COORD_A := Vector2i(0, 0)
const _COORD_B := Vector2i(1, 0)


func _initialize() -> void:
	_test_can_fuse_same_species_same_tier()
	_test_can_fuse_false_for_different_species()
	_test_can_fuse_false_for_different_tier()
	_test_can_fuse_false_for_tier_3()
	_test_can_fuse_false_for_legacy_species()
	_test_resulting_definition_matches_evolves_to()

	_test_velociraptor_t1_plus_t1_fuses_to_t2()
	_test_velociraptor_t2_plus_t2_fuses_to_t3()
	_test_triceratops_t1_plus_t1_fuses_to_t2()
	_test_triceratops_t2_plus_t2_fuses_to_t3()
	_test_trex_t1_plus_t1_fuses_to_t2()
	_test_trex_t2_plus_t2_fuses_to_t3()
	_test_triceratops_and_trex_do_not_fuse_across_species_at_t2()
	_test_t3_plus_t3_is_rejected()
	_test_different_species_is_rejected()
	_test_different_tier_same_species_is_rejected()
	_test_target_cell_holds_new_dinosaur_and_other_cell_is_freed()
	_test_fused_dinosaur_keeps_species_id_and_correct_tier()
	await _test_old_dinosaurs_are_properly_removed()

	_test_click_click_fuses_via_input()
	_test_single_click_does_not_fuse_yet()
	_test_click_empty_cell_cancels_pending_selection()
	_test_click_same_cell_twice_cancels_instead_of_self_fusing()
	_test_click_incompatible_pair_via_input_does_not_fuse()
	_test_placement_click_unaffected_by_fusion_handling()

	_test_preview_changed_emitted_on_first_click_selection()
	_test_preview_changed_emitted_and_pending_cleared_on_cancel_empty_cell()
	_test_preview_changed_emitted_and_pending_cleared_on_cancel_same_cell()
	_test_preview_changed_emitted_and_pending_cleared_on_successful_fusion()
	_test_preview_changed_emitted_and_pending_cleared_on_rejected_fusion()
	_test_offset_click_position_resolves_to_correct_cell()

	await _test_click_outside_grid_but_within_dinosaur_sprite_selects_it()
	await _test_click_between_two_dinosaurs_resolves_to_the_one_actually_under_the_click()
	await _test_click_in_genuinely_empty_area_does_not_select_any_dinosaur()
	await _test_fusion_completes_via_off_center_clicks_within_sprite_bounds()

	for obj in _to_free:
		if is_instance_valid(obj):
			obj.free()

	if _failures == 0:
		print("[fusion_tests] ALL TESTS PASSED")
	else:
		print("[fusion_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[fusion_tests] FAIL: %s" % message)


func _track(obj: Object) -> Object:
	_to_free.append(obj)
	return obj


# ---- Fusion (regra pura, sem grid/cena) ------------------------------------------------------

func _def(species: StringName, tier: int, next: DinosaurDefinition = null) -> DinosaurDefinition:
	var definition := DinosaurDefinition.new()
	definition.species_id = species
	definition.tier = tier
	definition.evolves_to = next
	return definition


func _test_can_fuse_same_species_same_tier() -> void:
	var t2 := _def(&"velociraptor", 2)
	var a := _def(&"velociraptor", 1, t2)
	var b := _def(&"velociraptor", 1, t2)
	_check(Fusion.can_fuse(a, b), "mesma espécie + mesmo tier + evolves_to definido deveria poder fundir")


func _test_can_fuse_false_for_different_species() -> void:
	var t2 := _def(&"velociraptor", 2)
	var a := _def(&"velociraptor", 1, t2)
	var b := _def(&"triceratops", 1, _def(&"triceratops", 2))
	_check(not Fusion.can_fuse(a, b), "espécies diferentes nunca deveriam fundir")


func _test_can_fuse_false_for_different_tier() -> void:
	var a := _def(&"velociraptor", 1, _def(&"velociraptor", 2))
	var b := _def(&"velociraptor", 2, _def(&"velociraptor", 3))
	_check(not Fusion.can_fuse(a, b), "tiers diferentes nunca deveriam fundir")


func _test_can_fuse_false_for_tier_3() -> void:
	var a := _def(&"velociraptor", 3)  # sem evolves_to — tier máximo
	var b := _def(&"velociraptor", 3)
	_check(not Fusion.can_fuse(a, b), "tier 3 não pode fundir de novo")


func _test_can_fuse_false_for_legacy_species() -> void:
	# species_id vazio (&"") é a marca da espécie legada (Velociraptor procedural) — mesmo que
	# ambas as definições sejam "iguais" (tier 1, sem species_id), não devem fundir.
	var a := DinosaurDefinition.new()
	var b := DinosaurDefinition.new()
	_check(not Fusion.can_fuse(a, b), "espécie legada (species_id vazio) nunca deveria fundir")


func _test_resulting_definition_matches_evolves_to() -> void:
	var t2 := _def(&"velociraptor", 2)
	var a := _def(&"velociraptor", 1, t2)
	var b := _def(&"velociraptor", 1, t2)
	_check(Fusion.resulting_definition(a, b) == t2,
		"resulting_definition deveria ser exatamente o evolves_to de 'a'")
	_check(Fusion.resulting_definition(_def(&"velociraptor", 3), _def(&"velociraptor", 3)) == null,
		"resulting_definition deveria ser null quando can_fuse é falso")


# ---- PlacementController.try_fuse() (grid + Dinosaur reais) ----------------------------------

func _make_two_cell_grid() -> Grid:
	var definition := MapDefinition.new()
	definition.width = 2
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.BUILDABLE, CellType.BUILDABLE])
	return Grid.new(definition)


func _make_enemy_spawner() -> EnemySpawner:
	return _track(EnemySpawner.new()) as EnemySpawner


func _make_container() -> Node:
	return _track(Node.new()) as Node


func _make_economy(starting: int = 1000) -> Economy:
	var economy := Economy.new()
	economy.starting_coins = starting
	economy.reset()
	return _track(economy) as Economy


func _controller_for_fusion(grid: Grid, dinosaurs_container: Node = null) -> PlacementController:
	var controller := _track(PlacementController.new()) as PlacementController
	controller.dinosaur_scene = load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	controller.setup(grid, _make_enemy_spawner(),
		dinosaurs_container if dinosaurs_container != null else _make_container(),
		_make_container(), _make_economy())
	return controller


func _place(controller: PlacementController, grid: Grid, definition: DinosaurDefinition, coord: Vector2i) -> void:
	controller.select_dinosaur(definition)
	controller.on_pointer_pressed(grid.cell_center_world(coord))


func _velociraptor_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t1.tres") as DinosaurDefinition


func _velociraptor_t2() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t2.tres") as DinosaurDefinition


func _velociraptor_t3() -> DinosaurDefinition:
	return load("res://data/dinosaurs/velociraptor_t3.tres") as DinosaurDefinition


func _triceratops_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/triceratops_t1.tres") as DinosaurDefinition


func _triceratops_t2() -> DinosaurDefinition:
	return load("res://data/dinosaurs/triceratops_t2.tres") as DinosaurDefinition


func _triceratops_t3() -> DinosaurDefinition:
	return load("res://data/dinosaurs/triceratops_t3.tres") as DinosaurDefinition


func _trex_t1() -> DinosaurDefinition:
	return load("res://data/dinosaurs/trex_t1.tres") as DinosaurDefinition


func _trex_t2() -> DinosaurDefinition:
	return load("res://data/dinosaurs/trex_t2.tres") as DinosaurDefinition


func _trex_t3() -> DinosaurDefinition:
	return load("res://data/dinosaurs/trex_t3.tres") as DinosaurDefinition


## V2 — Triceratops e T-Rex ganharam T2/T3 (recolor procedural, ver tools/tier_recolor_generator.gd
## e a decisão registrada em GAME_BIBLE.md#future-ideas). Mesmos testes que já existem para
## Velociraptor, agora cobrindo as outras 2 espécies — confirma que Fusion/try_fuse() continuam
## 100% genéricos (nenhuma linha nova em fusion.gd foi necessária para isto funcionar).
func _test_triceratops_t1_plus_t1_fuses_to_t2() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _triceratops_t1(), _COORD_A)
	_place(controller, grid, _triceratops_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "Triceratops T1 + T1 deveria fundir")
	if result != null:
		_check(result.definition.species_id == &"triceratops", "resultado deveria manter species_id 'triceratops'")
		_check(result.definition.tier == 2, "resultado deveria ser tier 2")


func _test_triceratops_t2_plus_t2_fuses_to_t3() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _triceratops_t2(), _COORD_A)
	_place(controller, grid, _triceratops_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "Triceratops T2 + T2 deveria fundir")
	if result != null:
		_check(result.definition.tier == 3, "resultado deveria ser tier 3")
		_check(result.definition.has_aura(), "Triceratops T3 deveria ter aura")


func _test_trex_t1_plus_t1_fuses_to_t2() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _trex_t1(), _COORD_A)
	_place(controller, grid, _trex_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T-Rex T1 + T1 deveria fundir")
	if result != null:
		_check(result.definition.species_id == &"trex", "resultado deveria manter species_id 'trex'")
		_check(result.definition.tier == 2, "resultado deveria ser tier 2")


func _test_trex_t2_plus_t2_fuses_to_t3() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _trex_t2(), _COORD_A)
	_place(controller, grid, _trex_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "T-Rex T2 + T2 deveria fundir")
	if result != null:
		_check(result.definition.tier == 3, "resultado deveria ser tier 3")
		_check(result.definition.has_aura(), "T-Rex T3 deveria ter aura")


## Confirma que espécies diferentes de tier alto continuam bloqueadas pela mesma regra de sempre
## (Fusion.can_fuse() já testa isso para T1 — aqui é só a confirmação de que nada mudou pras
## definições novas especificamente).
func _test_triceratops_and_trex_do_not_fuse_across_species_at_t2() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _triceratops_t2(), _COORD_A)
	_place(controller, grid, _trex_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result == null, "Triceratops T2 + T-Rex T2 nunca deveria fundir (espécies diferentes)")


func _test_velociraptor_t1_plus_t1_fuses_to_t2() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "Velociraptor T1 + T1 deveria fundir")
	if result != null:
		_check(result.definition.species_id == &"velociraptor", "resultado deveria manter species_id 'velociraptor'")
		_check(result.definition.tier == 2, "resultado deveria ser tier 2")


func _test_velociraptor_t2_plus_t2_fuses_to_t3() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t2(), _COORD_A)
	_place(controller, grid, _velociraptor_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "Velociraptor T2 + T2 deveria fundir")
	if result != null:
		_check(result.definition.tier == 3, "resultado deveria ser tier 3")


func _test_t3_plus_t3_is_rejected() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t3(), _COORD_A)
	_place(controller, grid, _velociraptor_t3(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result == null, "T3 + T3 não deveria fundir (tier máximo)")
	_check(grid.get_cell(_COORD_A).is_occupied() and grid.get_cell(_COORD_B).is_occupied(),
		"ambas as células deveriam continuar ocupadas quando a fusão é rejeitada")


func _test_different_species_is_rejected() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _triceratops_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result == null, "Velociraptor + Triceratops nunca deveria fundir")


func _test_different_tier_same_species_is_rejected() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result == null, "T1 + T2 da mesma espécie nunca deveria fundir")


func _test_target_cell_holds_new_dinosaur_and_other_cell_is_freed() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "fusão deveria ter acontecido para este teste fazer sentido")
	if result == null:
		return
	_check(grid.get_cell(_COORD_A).occupant == result,
		"a célula onde a fusão aconteceu (COORD_A) deveria ficar ocupada pelo NOVO dinossauro")
	_check(grid.get_cell(_COORD_B).occupant == null,
		"a outra célula (COORD_B) deveria ficar livre depois da fusão")


func _test_fused_dinosaur_keeps_species_id_and_correct_tier() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t2(), _COORD_A)
	_place(controller, grid, _velociraptor_t2(), _COORD_B)

	var result := controller.try_fuse(_COORD_A, _COORD_B)

	_check(result != null, "fusão deveria ter acontecido para este teste fazer sentido")
	if result == null:
		return
	_check(result.definition.species_id == &"velociraptor",
		"dinossauro fundido deveria manter species_id da espécie original")
	_check(result.definition.tier == 3,
		"dinossauro fundido a partir de T2 deveria ter tier 3, got %d" % result.definition.tier)


## `queue_free()` é deferido (mesmo padrão de BasicEnemy/DeathEffect no resto do projeto) — só
## depois de um `process_frame` os dois dinossauros antigos realmente saem da árvore. Captura as
## referências ANTES da fusão (via cell.occupant, já setado pelo placement real) para confirmar
## que são exatamente esses dois nodes que desaparecem, não qualquer coisa parecida.
func _test_old_dinosaurs_are_properly_removed() -> void:
	var grid := _make_two_cell_grid()
	var dinosaurs := _make_container()
	var controller := _controller_for_fusion(grid, dinosaurs)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var old_a := grid.get_cell(_COORD_A).occupant
	var old_b := grid.get_cell(_COORD_B).occupant
	_check(old_a != null and old_b != null, "os dois placements iniciais deveriam ter ocorrido")

	var result := controller.try_fuse(_COORD_A, _COORD_B)
	_check(result != null, "fusão deveria ter acontecido para este teste fazer sentido")

	await process_frame  # deixa o queue_free() dos dois antigos ser processado

	_check(not is_instance_valid(old_a), "o primeiro dinossauro antigo deveria ter sido removido (queue_free)")
	_check(not is_instance_valid(old_b), "o segundo dinossauro antigo deveria ter sido removido (queue_free)")
	_check(dinosaurs.get_child_count() == 1,
		"o container deveria ter só o novo Dinosaur fundido, got %d filhos" % dinosaurs.get_child_count())


# ---- Fusão via clique (Sprint 1, Etapa 7) — on_pointer_pressed() simulando o clique real do
# jogador, não try_fuse() chamado diretamente. Depois de colocar os dois dinossauros (modo
# PLACING, comportamento de sempre), o controller volta pra IDLE — é nesse estado que
# on_pointer_pressed() passa a tratar cliques em células ocupadas como seleção de fusão. ----

func _click(controller: PlacementController, grid: Grid, coord: Vector2i) -> void:
	controller.on_pointer_pressed(grid.cell_center_world(coord))


func _test_click_click_fuses_via_input() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)
	_check(controller.state == PlacementController.State.IDLE,
		"deveria estar IDLE depois dos 2 placements, sem nada selecionado pra colocar")

	_click(controller, grid, _COORD_A)
	_click(controller, grid, _COORD_B)

	_check(grid.get_cell(_COORD_A).occupant != null, "célula A deveria ter o dinossauro fundido")
	_check(grid.get_cell(_COORD_A).occupant.definition.tier == 2,
		"clicar nos dois T1 deveria produzir um T2 na célula A")
	_check(grid.get_cell(_COORD_B).occupant == null, "célula B deveria ficar livre depois da fusão via clique")
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"seleção de fusão deveria estar limpa depois da fusão acontecer")


func _test_single_click_does_not_fuse_yet() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)

	var before_a := grid.get_cell(_COORD_A).occupant
	var before_b := grid.get_cell(_COORD_B).occupant

	_click(controller, grid, _COORD_A)

	_check(controller.fusion_pending_coord == _COORD_A,
		"1 clique deveria só marcar a seleção pendente, não fundir ainda")
	_check(grid.get_cell(_COORD_A).occupant == before_a and grid.get_cell(_COORD_B).occupant == before_b,
		"nenhum dinossauro deveria ter mudado depois de só 1 clique")


func _test_click_empty_cell_cancels_pending_selection() -> void:
	var grid := _make_three_cell_grid()  # célula C extra (2,0), vazia, só pra este teste
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	_click(controller, grid, _COORD_A)
	_check(controller.fusion_pending_coord == _COORD_A, "1º clique deveria marcar a seleção pendente")

	_click(controller, grid, Vector2i(2, 0))  # célula C, vazia
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"clicar numa célula vazia deveria cancelar a seleção pendente, não tentar fundir com o vazio")


func _test_click_same_cell_twice_cancels_instead_of_self_fusing() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	_click(controller, grid, _COORD_A)
	_click(controller, grid, _COORD_A)

	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"clicar 2x na mesma célula deveria cancelar a seleção, não fundir um dinossauro consigo mesmo")
	_check(grid.get_cell(_COORD_A).occupant != null,
		"o dinossauro original deveria continuar lá (não fundiu consigo mesmo)")


func _test_click_incompatible_pair_via_input_does_not_fuse() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _triceratops_t1(), _COORD_B)

	var dino_a := grid.get_cell(_COORD_A).occupant
	var dino_b := grid.get_cell(_COORD_B).occupant

	_click(controller, grid, _COORD_A)
	_click(controller, grid, _COORD_B)

	_check(grid.get_cell(_COORD_A).occupant == dino_a and grid.get_cell(_COORD_B).occupant == dino_b,
		"Velociraptor + Triceratops clicados não deveriam fundir, os dois originais continuam")
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"seleção pendente deveria ser limpa mesmo quando a fusão é rejeitada (evita ficar travada)")


## Confirma que a extração de on_pointer_pressed() (Etapa 7) não alterou NADA do comportamento
## de placement normal em modo PLACING — mesma checagem que combat_integration_tests.gd/
## game_loop_integration_tests.gd/placement_tests.gd já fazem, repetida aqui isolada porque é
## exatamente este arquivo que mexeu na função.
func _test_placement_click_unaffected_by_fusion_handling() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)

	controller.select_dinosaur(_velociraptor_t1())
	_check(controller.state == PlacementController.State.PLACING, "select_dinosaur deveria deixar em PLACING")
	_click(controller, grid, _COORD_A)

	_check(grid.get_cell(_COORD_A).is_occupied(), "clique em modo PLACING deveria colocar o dinossauro normalmente")
	_check(controller.state == PlacementController.State.IDLE, "deveria voltar pra IDLE depois de colocar")


func _make_three_cell_grid() -> Grid:
	var definition := MapDefinition.new()
	definition.width = 3
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.BUILDABLE, CellType.BUILDABLE, CellType.BUILDABLE])
	return Grid.new(definition)


# ---- Correção de UX da fusão: preview_changed + fusion_pending_coord (não mexe em Fusion/
# try_fuse — só confirma que o sinal já existente dispara nos pontos certos, pra PlacementPreview
# conseguir destacar/limpar a célula que o CLIQUE de verdade identificou). ----

func _test_preview_changed_emitted_on_first_click_selection() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	var emit_count := [0]
	controller.preview_changed.connect(func() -> void: emit_count[0] += 1)

	_click(controller, grid, _COORD_A)

	_check(emit_count[0] == 1, "preview_changed deveria disparar 1x no 1º clique que marca a seleção, got %d" % emit_count[0])
	_check(controller.fusion_pending_coord == _COORD_A, "fusion_pending_coord deveria ser a célula clicada")


func _test_preview_changed_emitted_and_pending_cleared_on_cancel_empty_cell() -> void:
	var grid := _make_three_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_click(controller, grid, _COORD_A)

	var emit_count := [0]
	controller.preview_changed.connect(func() -> void: emit_count[0] += 1)

	_click(controller, grid, Vector2i(2, 0))  # célula vazia

	_check(emit_count[0] == 1, "preview_changed deveria disparar 1x ao cancelar clicando em célula vazia, got %d" % emit_count[0])
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"fusion_pending_coord deveria voltar a (-1,-1) — destaque deveria sumir")


func _test_preview_changed_emitted_and_pending_cleared_on_cancel_same_cell() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_click(controller, grid, _COORD_A)

	var emit_count := [0]
	controller.preview_changed.connect(func() -> void: emit_count[0] += 1)

	_click(controller, grid, _COORD_A)  # mesma célula de novo

	_check(emit_count[0] == 1, "preview_changed deveria disparar 1x ao cancelar clicando na mesma célula, got %d" % emit_count[0])
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"fusion_pending_coord deveria voltar a (-1,-1) — destaque deveria sumir")


func _test_preview_changed_emitted_and_pending_cleared_on_successful_fusion() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _velociraptor_t1(), _COORD_B)
	_click(controller, grid, _COORD_A)

	var emit_count := [0]
	controller.preview_changed.connect(func() -> void: emit_count[0] += 1)

	_click(controller, grid, _COORD_B)  # completa a fusão

	_check(emit_count[0] == 1, "preview_changed deveria disparar 1x ao completar a fusão, got %d" % emit_count[0])
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"fusion_pending_coord deveria voltar a (-1,-1) depois da fusão — destaque deveria sumir")


func _test_preview_changed_emitted_and_pending_cleared_on_rejected_fusion() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)
	_place(controller, grid, _triceratops_t1(), _COORD_B)
	_click(controller, grid, _COORD_A)

	var emit_count := [0]
	controller.preview_changed.connect(func() -> void: emit_count[0] += 1)

	_click(controller, grid, _COORD_B)  # espécie diferente — try_fuse() rejeita

	_check(emit_count[0] == 1,
		"preview_changed deveria disparar 1x mesmo quando a fusão é rejeitada, got %d" % emit_count[0])
	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"fusion_pending_coord deveria voltar a (-1,-1) mesmo quando a fusão é rejeitada — destaque não deveria ficar preso")


## Diagnóstico pedido explicitamente: confirma que um clique DESLOCADO do centro da célula (mas
## ainda dentro dos 32x32 dela) resolve pra MESMA célula que cell_center_world() resolveria — ou
## seja, Grid.world_to_cell() (matemática já existente, não tocada) está correta em toda a área
## da célula, não só no centro exato. Se isto passa mas o jogo real ainda "erra a célula", o
## problema está no tamanho do sprite ultrapassando a célula (jogador mirando fora da área de
## 32x32), não em world_to_cell()/fusion_pending_coord — exatamente a pergunta que este teste foi
## pedido pra responder.
func _test_offset_click_position_resolves_to_correct_cell() -> void:
	var grid := _make_two_cell_grid()
	var controller := _controller_for_fusion(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)

	# canto superior-esquerdo da célula A, deslocado só 3px pra dentro — bem longe do centro,
	# mas ainda dentro dos 32x32 da célula.
	var offset_pos: Vector2 = grid.cell_to_world(_COORD_A) + Vector2(3, 3)
	controller.on_pointer_pressed(offset_pos)

	_check(controller.fusion_pending_coord == _COORD_A,
		"clique deslocado do centro (canto superior-esquerdo da célula) deveria resolver pra %s, got %s" %
			[_COORD_A, controller.fusion_pending_coord])


# ---- Correção do bug real de jogo (sprite maior que a célula 32x32) — reproduz exatamente o
# caso confirmado em log de jogo real: clique fora da célula exata, mas dentro da área visual do
# sprite. Precisa do sprite_frames REAL (PixelLab) aplicado — só acontece com o container numa
# árvore viva (mesma lição da Etapa 6), por isso usa root.add_child()+await, não
# _controller_for_fusion(). ----

func _controller_for_fusion_real_tree(grid: Grid) -> PlacementController:
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


## Reproduz o bug real relatado: clique BEM fora da célula exata (até fora dos limites da grid),
## mas dentro da área visual do sprite do Velociraptor T1 (célula é 32x32; o sprite raw é 64x64,
## mas é EXIBIDO a 65% — Dinosaur._DISPLAY_SCALE, correção separada pra sobreposição visual — então
## a área visual real é 64*0.65=41.6px, ultrapassando a célula em só ~4.8px pra cada lado). Antes
## da correção original desta função, isto resolvia pra uma célula vazia/fora dos limites e
## cancelava a seleção silenciosamente — exatamente o sintoma dos logs.
func _test_click_outside_grid_but_within_dinosaur_sprite_selects_it() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_for_fusion_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)  # centro em (16,16), sprite exibido 41.6x41.6

	# 3px pra fora do canto superior-esquerdo da célula A (world x=-3,y=6) — fora da grid
	# (world_to_cell dá (-1,0), out of bounds), mas dentro do retângulo visual do sprite EXIBIDO
	# ((16-20.8,16-20.8) a (16+20.8,16+20.8) = (-4.8,-4.8) a (36.8,36.8)).
	controller.on_pointer_pressed(Vector2(-3, 6))

	_check(controller.fusion_pending_coord == _COORD_A,
		"clique fora da grid mas dentro do sprite do dinossauro deveria selecioná-lo, got fusion_pending_coord=%s" %
			controller.fusion_pending_coord)


## Dois dinossauros T1 (sprite raw 64px, exibido a 65% = 41.6px, ver Dinosaur._DISPLAY_SCALE) em
## células a 2 de distância (0,0) e (2,0) — os sprites exibidos alcançam a célula vazia do meio
## (1,0) só uma fatia perto de cada borda, sem overlap entre si. Confirma que um clique nessa
## célula vazia, mas dentro do alcance visual de um dos dois, seleciona o dinossauro CORRETO (o que
## realmente está sob o clique) — nunca o outro, arbitrariamente.
func _test_click_between_two_dinosaurs_resolves_to_the_one_actually_under_the_click() -> void:
	var grid := _make_three_cell_grid()
	var controller := await _controller_for_fusion_real_tree(grid)
	var coord_a := Vector2i(0, 0)  # centro (16,16), sprite exibido alcança até x=36.8
	var coord_c := Vector2i(2, 0)  # centro (80,16), sprite exibido alcança a partir de x=59.2
	_place(controller, grid, _velociraptor_t1(), coord_a)
	_place(controller, grid, _velociraptor_t1(), coord_c)

	# x=34: dentro da célula do meio (1,0) (x=32-64), vazia; dentro do sprite exibido de A (até
	# x=36.8); fora do sprite exibido de C (só a partir de x=59.2).
	controller.on_pointer_pressed(Vector2(34, 16))
	_check(controller.fusion_pending_coord == coord_a,
		"clique em x=34 (dentro só do sprite de A) deveria selecionar A, got %s" % controller.fusion_pending_coord)

	# cancela a seleção antes do 2º sub-caso (clicando na mesma célula de novo)
	controller.on_pointer_pressed(grid.cell_center_world(coord_a))
	_check(controller.fusion_pending_coord == Vector2i(-1, -1), "seleção deveria estar limpa antes do 2º sub-caso")

	# x=62: dentro da célula do meio (1,0), vazia; dentro do sprite exibido de C (a partir de
	# x=59.2); fora do sprite exibido de A (só até x=36.8).
	controller.on_pointer_pressed(Vector2(62, 16))
	_check(controller.fusion_pending_coord == coord_c,
		"clique em x=62 (dentro só do sprite de C) deveria selecionar C, got %s" % controller.fusion_pending_coord)


## Dois dinossauros T1 longe o bastante (0,0) e (3,0) pra os sprites exibidos (65% de 64px =
## 41.6px, ver Dinosaur._DISPLAY_SCALE) NUNCA se aproximarem — clique numa célula vazia entre os
## dois, fora do alcance visual de ambos, não deveria selecionar nenhum (continua cancelando a
## seleção, mesmo comportamento de sempre pra clique genuinamente vazio).
func _test_click_in_genuinely_empty_area_does_not_select_any_dinosaur() -> void:
	var definition := MapDefinition.new()
	definition.width = 4
	definition.height = 1
	definition.tile_size = 32
	definition.cells = PackedInt32Array([CellType.BUILDABLE, CellType.BUILDABLE, CellType.BUILDABLE, CellType.BUILDABLE])
	var grid := Grid.new(definition)

	var controller := await _controller_for_fusion_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), Vector2i(0, 0))  # centro (16,16), alcança até x=36.8
	_place(controller, grid, _velociraptor_t1(), Vector2i(3, 0))  # centro (112,16), alcança a partir de x=91.2

	# célula (2,0) é BUILDABLE e vazia; seu centro (80,16) está bem fora do alcance de ambos os
	# sprites exibidos (A vai só até x=36.8, D só a partir de x=91.2) — folga ampla de sobra.
	controller.on_pointer_pressed(Vector2(70, 16))

	_check(controller.fusion_pending_coord == Vector2i(-1, -1),
		"clique genuinamente fora de qualquer sprite não deveria selecionar nenhum dinossauro, got %s" %
			controller.fusion_pending_coord)


## Ponta a ponta: reproduz o cenário completo dos logs reais — coloca 2 Velociraptor T1 e
## completa a fusão inteira usando cliques deslocados do centro (dentro da área visual, fora da
## célula exata) nos dois passos. Se isto passar, o caso real relatado ("clico no dinossauro e a
## fusão às vezes não acontece") está coberto de ponta a ponta, não só a resolução de coordenada
## isolada.
func _test_fusion_completes_via_off_center_clicks_within_sprite_bounds() -> void:
	var grid := _make_two_cell_grid()
	var controller := await _controller_for_fusion_real_tree(grid)
	_place(controller, grid, _velociraptor_t1(), _COORD_A)  # centro (16,16), sprite exibido x:[-4.8,36.8]
	_place(controller, grid, _velociraptor_t1(), _COORD_B)  # centro (48,16), sprite exibido x:[27.2,68.8]

	# 1º clique: fora da célula exata de A (que vai só até x=32) e fora do alcance do sprite
	# EXIBIDO de B (que começa em x=27.2) — ponto exclusivo da área visual de A.
	controller.on_pointer_pressed(Vector2(-3, 20))
	_check(controller.fusion_pending_coord == _COORD_A,
		"1º clique deslocado deveria selecionar A, got %s" % controller.fusion_pending_coord)

	# 2º clique: fora da célula exata de B (x=32-64, y=0-32 — grid tem só 1 linha, y=34 já é fora
	# da grid) e fora do alcance do sprite EXIBIDO de A (que só vai até x=36.8) — ponto exclusivo
	# da área visual de B (sprite exibido de B vai de x=27.2 a 68.8).
	controller.on_pointer_pressed(Vector2(66, 34))

	var fused := grid.get_cell(_COORD_A).occupant
	_check(fused != null and fused.definition.tier == 2,
		"fusão via 2 cliques deslocados (dentro do sprite, fora da célula exata) deveria produzir um T2 em A")
	_check(grid.get_cell(_COORD_B).occupant == null, "célula B deveria ficar livre depois da fusão")
