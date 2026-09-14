class_name GridManager
extends Node2D
## Dono da grid runtime; responsável por renderização (arte + DEBUG) e por resolver
## posições do mundo para células, a pedido de quem trata input (ver Main.gd).
##
## Não sabe nada sobre mouse/touch/InputManager — expõe apenas métodos públicos
## (on_pointer_moved / on_pointer_pressed) que o composition root (Main.gd) conecta
## aos sinais do InputManager. Isso mantém GridManager e InputManager desacoplados
## entre si (ver skill game-architecture).
##
## Primeiro Protótipo Visual: `debug_visible` (F3) inverteu de sentido — antes era a ÚNICA forma
## de ver a grid (não havia arte), agora é o oposto: por padrão (`false`) desenha os tiles de
## `assets/environment/` (grama/trilha/decoração); `true` troca para o preenchimento plano de
## `DEBUG_COLORS` de sempre (auxílio de desenvolvimento, útil para depurar tipo de célula sem
## ambiguidade visual). Nenhuma lógica de grid mudou — `Grid`/`Cell`/`MapDefinition` continuam
## exatamente como eram; isto é só uma segunda forma de DESENHAR o mesmo dado.

@export var map_definition: MapDefinition
@export var debug_visible: bool = false

var grid: Grid
var _hovered_coord: Vector2i = Vector2i(-1, -1)

const DEBUG_COLORS := {
	CellType.EMPTY: Color(0.14, 0.14, 0.16),
	CellType.PATH: Color(0.55, 0.42, 0.24),
	CellType.BUILDABLE: Color(0.20, 0.45, 0.22),
	CellType.EGG: Color(0.92, 0.85, 0.35),
	CellType.OBSTACLE: Color(0.55, 0.12, 0.12),
	CellType.SPAWN: Color(0.20, 0.42, 0.85),
	CellType.NEST: Color(0.60, 0.22, 0.68),
}
const GRID_LINE_COLOR := Color(0, 0, 0, 0.35)
const HOVER_COLOR := Color(1, 1, 1, 0.9)

## `Array[Texture2D]` explícito em todas as listas abaixo: um array literal sem anotação de tipo
## não é reconhecido como expressão constante pelo GDScript (mesmo gotcha já documentado em
## map_validator.gd/placement_preview.gd).
const _GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/grass_01.png"),
	preload("res://assets/environment/grass_02.png"),
	preload("res://assets/environment/grass_03.png"),
	preload("res://assets/environment/grass_04.png"),
]
const _PATH_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/path_01.png"),
	preload("res://assets/environment/path_02.png"),
	preload("res://assets/environment/path_03.png"),
]
const _PATH_EDGE_N := preload("res://assets/environment/path_edge_n.png")
const _PATH_EDGE_S := preload("res://assets/environment/path_edge_s.png")
const _PATH_EDGE_E := preload("res://assets/environment/path_edge_e.png")
const _PATH_EDGE_W := preload("res://assets/environment/path_edge_w.png")
const _EDGE_STRIP_SIZE := 10.0

## Decorações em células OBSTACLE (determinístico por coordenada — nunca aleatório, o mesmo mapa
## sempre desenha igual). Só os tamanhos "grande" entram aqui por padrão (preenchem melhor uma
## célula 32×32 sozinhos); `rock_cluster`/`stump`/`tree_small` entram como variação extra para não
## repetir sempre os 3 mesmos elementos.
const _OBSTACLE_DECORATIONS: Array[Texture2D] = [
	preload("res://assets/environment/rock_large.png"),
	preload("res://assets/environment/tree_large.png"),
	preload("res://assets/environment/bush_large.png"),
	preload("res://assets/environment/rock_cluster.png"),
	preload("res://assets/environment/tree_small.png"),
	preload("res://assets/environment/stump.png"),
]


func _ready() -> void:
	_build_grid()


## V2 — permite trocar o mapa ANTES da partida realmente usá-lo (seleção de mapa, ver
## GameSession/map_select.gd). Precisa ser chamado bem no topo de `Main._ready()`, antes de
## qualquer outro sistema (EnemySpawner/EggManager/PlacementController) consumir `grid`/
## `map_definition`: como `GridManager` é filho de `Main`, o próprio `_ready()` dele já roda
## ANTES do `_ready()` do pai (propagação bottom-up do Godot) e já constrói `grid` a partir do
## `map_definition` default do `.tscn` — sem chamar isto de novo depois, a troca chegaria tarde
## demais (grid já construído com o mapa errado).
func set_map_definition(new_definition: MapDefinition) -> void:
	map_definition = new_definition
	_build_grid()


func _build_grid() -> void:
	assert(map_definition != null, "GridManager requires a MapDefinition assigned.")
	var errors := MapValidator.validate(map_definition)
	for error in errors:
		push_warning("[GridManager] MapDefinition inválido: %s" % error)
	grid = Grid.new(map_definition)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_visible = not debug_visible
			queue_redraw()


func on_pointer_moved(world_pos: Vector2) -> void:
	var coord := grid.world_to_cell(world_pos)
	if grid.is_in_bounds(coord):
		if coord != _hovered_coord:
			_hovered_coord = coord
			queue_redraw()
	elif _hovered_coord != Vector2i(-1, -1):
		_hovered_coord = Vector2i(-1, -1)
		queue_redraw()


func on_pointer_pressed(world_pos: Vector2) -> void:
	var coord := grid.world_to_cell(world_pos)
	if not grid.is_in_bounds(coord):
		print("[GridManager] Clique fora da grid: %s" % coord)
		return
	var cell := grid.get_cell(coord)
	print("[GridManager] Célula selecionada: %s | tipo: %s" % [coord, CellType.name_of(cell.type)])


func _draw() -> void:
	if grid == null:
		return
	for y in range(grid.height):
		for x in range(grid.width):
			var coord := Vector2i(x, y)
			var cell := grid.get_cell(coord)
			var rect := Rect2(grid.cell_to_world(coord), Vector2(grid.cell_size, grid.cell_size))
			if debug_visible:
				draw_rect(rect, DEBUG_COLORS.get(cell.type, Color.MAGENTA), true)
				draw_rect(rect, GRID_LINE_COLOR, false, 1.0)
			else:
				_draw_cell_art(coord, cell, rect)
	if grid.is_in_bounds(_hovered_coord):
		var hover_rect := Rect2(grid.cell_to_world(_hovered_coord), Vector2(grid.cell_size, grid.cell_size))
		draw_rect(hover_rect, HOVER_COLOR, false, 2.0)


## PATH/SPAWN/NEST desenham a base de trilha (mesmo "chão andável"); todo o resto desenha grama.
## Decoração/tingimento por cima conforme o tipo específico — nunca decide BUILDABLE/OBSTACLE por
## conta própria, só lê `cell.type` (já validado por MapValidator antes de qualquer desenho
## acontecer, ver _ready()). Escolhe entre as variações de grama/trilha deterministicamente por
## coordenada (nunca aleatório) — evita repetição visual idêntica entre células vizinhas sem
## deixar de desenhar sempre igual para o mesmo mapa.
func _draw_cell_art(coord: Vector2i, cell: Cell, rect: Rect2) -> void:
	var is_path_like := _is_path_like_type(cell.type)
	if is_path_like:
		draw_texture_rect(_pick(_PATH_TEXTURES, coord), rect, false)
		_draw_path_edges(coord, rect)
	else:
		draw_texture_rect(_pick(_GRASS_TEXTURES, coord), rect, false)

	match cell.type:
		CellType.OBSTACLE:
			# Só em OBSTACLE, nunca em BUILDABLE: vegetação decorativa não pode competir com a
			# leitura de "aqui dá para construir" (ver docs/ART_DIRECTION.md).
			draw_texture_rect(_pick(_OBSTACLE_DECORATIONS, coord), rect, false)
		CellType.SPAWN:
			draw_rect(rect, Color(DEBUG_COLORS[CellType.SPAWN], 0.35), true)
		CellType.NEST:
			draw_rect(rect, Color(DEBUG_COLORS[CellType.NEST], 0.35), true)
		CellType.EGG:
			draw_rect(rect, Color(DEBUG_COLORS[CellType.EGG], 0.22), true)


## Hash simples e determinístico só para escolher entre variações visuais equivalentes — não tem
## nenhuma relação com gameplay/RNG. Multiplicadores diferentes por lista (ver chamadores) evitam
## que grama/trilha/decoração caiam sempre no mesmo índice relativo umas às outras.
func _pick(textures: Array[Texture2D], coord: Vector2i, mult_x: int = 7, mult_y: int = 13) -> Texture2D:
	return textures[absi(coord.x * mult_x + coord.y * mult_y) % textures.size()]


func _is_path_like_type(type: int) -> bool:
	return type == CellType.PATH or type == CellType.SPAWN or type == CellType.NEST


## Transição grama→trilha nas 4 bordas da célula — cada direção usa um asset já pré-orientado
## (`path_edge_n/s/e/w.png`, derivados por flip/transpose no próprio gerador, ver
## pixel_art_generator.gd), então não precisa de nenhuma rotação em runtime (`draw_set_transform`)
## — decisão deliberada desde a rodada anterior: essa matemática não dava para validar
## visualmente, e os 4 assets prontos são simples de conferir individualmente. Sem tratamento de
## canto dedicado dentro do orçamento desta etapa — quando 2 lados adjacentes precisam de
## transição, as duas tiras são desenhadas sobrepostas, o que já cobre a leitura sem exigir um
## quarto conjunto de assets diagonais.
func _draw_path_edges(coord: Vector2i, rect: Rect2) -> void:
	var s := _EDGE_STRIP_SIZE
	if not _is_path_like_type(_cell_type_at(coord + Vector2i(0, -1))):
		draw_texture_rect(_PATH_EDGE_N, Rect2(rect.position, Vector2(rect.size.x, s)), false)
	if not _is_path_like_type(_cell_type_at(coord + Vector2i(0, 1))):
		draw_texture_rect(_PATH_EDGE_S, Rect2(rect.position + Vector2(0, rect.size.y - s), Vector2(rect.size.x, s)), false)
	if not _is_path_like_type(_cell_type_at(coord + Vector2i(-1, 0))):
		draw_texture_rect(_PATH_EDGE_W, Rect2(rect.position, Vector2(s, rect.size.y)), false)
	if not _is_path_like_type(_cell_type_at(coord + Vector2i(1, 0))):
		draw_texture_rect(_PATH_EDGE_E, Rect2(rect.position + Vector2(rect.size.x - s, 0), Vector2(s, rect.size.y)), false)


## Fora dos limites conta como "não é trilha" — desenha a transição também na borda do mapa.
func _cell_type_at(coord: Vector2i) -> int:
	if not grid.is_in_bounds(coord):
		return CellType.EMPTY
	return grid.get_cell(coord).type
