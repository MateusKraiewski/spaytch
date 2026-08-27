class_name PlacementController
extends Node
## Máquina de estados simples de placement: IDLE ↔ PLACING.
##
## IDLE          — nenhum dinossauro selecionado, input de placement ignorado.
## PLACING       — um DinosaurDefinition está selecionado; hover (PC) atualiza
##                 preview; um clique/toque em célula válida coloca o
##                 dinossauro e volta para IDLE.
##
## Nesta fase não existe UI de seleção de dinossauro — `initial_definition`
## permite pré-selecionar o Velociraptor automaticamente ao iniciar (ver
## Main.gd), simulando "o jogador já escolheu". `select_dinosaur()` é o
## único ponto de entrada para trocar a seleção — genérico o suficiente para
## uma UI futura chamar com qualquer DinosaurDefinition, sem exigir nenhuma
## mudança nesta classe.
##
## Só valida/instancia/marca ocupação — nenhuma lógica de combate aqui
## (cooldown, targeting e disparo vivem em Dinosaur/Targeting/Projectile).
##
## `extends Node`, não Node2D: sem identidade espacial própria, mesmo
## raciocínio de InputManager/EnemySpawner.

enum State { IDLE, PLACING }

## Estado público, somente leitura por convenção — consumido por
## PlacementPreview para saber o que desenhar.
signal preview_changed()

## Phase 0.5 — motivo pelo qual um placement confirmado não aconteceu (hoje
## só "insufficient_coins"); célula inválida não emite isto, só retorna
## silenciosamente (ver on_pointer_pressed).
signal placement_failed(reason: String)

## Phase 0.6 — gancho de feedback (visual/áudio) para um placement bem
## sucedido; emitido depois que o dinossauro já existe e a célula já está
## marcada como ocupada.
signal dinosaur_placed(dinosaur: Dinosaur, coord: Vector2i)

var state: State = State.IDLE
var hovered_coord: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var selected_definition: DinosaurDefinition = null

@export var dinosaur_scene: PackedScene
@export var initial_definition: DinosaurDefinition  ## pré-seleção automática (sem UI ainda)

var _grid: Grid
var _enemy_spawner: EnemySpawner
var _dinosaurs_container: Node
var _projectiles_container: Node
var _economy: Economy


func setup(grid: Grid, enemy_spawner: EnemySpawner, dinosaurs_container: Node, projectiles_container: Node, economy: Economy) -> void:
	_grid = grid
	_enemy_spawner = enemy_spawner
	_dinosaurs_container = dinosaurs_container
	_projectiles_container = projectiles_container
	_economy = economy


func select_dinosaur(definition: DinosaurDefinition) -> void:
	selected_definition = definition
	state = State.PLACING
	hovered_coord = Vector2i(-1, -1)
	is_hover_valid = false
	preview_changed.emit()


func on_pointer_moved(world_pos: Vector2) -> void:
	if state != State.PLACING:
		return
	var coord := _grid.world_to_cell(world_pos)
	if coord == hovered_coord:
		return
	hovered_coord = coord
	is_hover_valid = is_valid_placement(coord)
	preview_changed.emit()


## Funciona igual para mouse click e touch tap (ambos chegam como
## pointer_pressed via InputManager) — placement não depende de hover para
## confirmar, só o pointer_pressed é necessário (requisito Android).
func on_pointer_pressed(world_pos: Vector2) -> void:
	if state != State.PLACING:
		return
	var coord := _grid.world_to_cell(world_pos)
	if not is_valid_placement(coord):
		return
	if _economy != null and not _economy.can_afford(selected_definition.cost):
		print("[PlacementController] Coins insuficientes para %s (custo %d, disponível %d)." %
			[selected_definition.display_name, selected_definition.cost, _economy.coins])
		placement_failed.emit("insufficient_coins")
		return
	_place_dinosaur(coord)


## Público (não só uso interno) porque é uma consulta legítima e sem efeito
## colateral sobre o estado do mundo — mesmo espírito de Grid.is_in_bounds()/
## Cell.is_buildable(). Célula válida somente se BUILDABLE e livre; PATH,
## SPAWN, NEST, EGG e OBSTACLE já são excluídos por is_buildable().
func is_valid_placement(coord: Vector2i) -> bool:
	if _grid == null or not _grid.is_in_bounds(coord):
		return false
	var cell := _grid.get_cell(coord)
	return cell.is_buildable() and not cell.occupied


## Consulta pura para a UI (Phase 0.6 — feedback de coins insuficientes
## durante o hover, antes mesmo do jogador tentar confirmar). Mesmo espírito
## de is_valid_placement(): sem efeito colateral, só leitura.
func can_afford_selected() -> bool:
	if _economy == null or selected_definition == null:
		return true
	return _economy.can_afford(selected_definition.cost)


func _place_dinosaur(coord: Vector2i) -> void:
	if _economy != null:
		_economy.spend(selected_definition.cost)

	var dinosaur := dinosaur_scene.instantiate() as Dinosaur
	_dinosaurs_container.add_child(dinosaur)
	dinosaur.setup(selected_definition, _enemy_spawner, _projectiles_container)
	dinosaur.global_position = _grid.cell_center_world(coord)
	_grid.get_cell(coord).occupied = true

	state = State.IDLE
	selected_definition = null
	hovered_coord = Vector2i(-1, -1)
	is_hover_valid = false
	preview_changed.emit()
	dinosaur_placed.emit(dinosaur, coord)
