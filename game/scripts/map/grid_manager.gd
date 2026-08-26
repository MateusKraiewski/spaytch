class_name GridManager
extends Node2D
## Dono da grid runtime; responsável por renderização de DEBUG e por resolver
## posições do mundo para células, a pedido de quem trata input (ver Main.gd).
##
## Não sabe nada sobre mouse/touch/InputManager — expõe apenas métodos públicos
## (on_pointer_moved / on_pointer_pressed) que o composition root (Main.gd) conecta
## aos sinais do InputManager. Isso mantém GridManager e InputManager desacoplados
## entre si (ver skill game-architecture).

@export var map_definition: MapDefinition
@export var debug_visible: bool = true

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


func _ready() -> void:
	assert(map_definition != null, "GridManager requires a MapDefinition assigned.")
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
	if not debug_visible or grid == null:
		return
	for y in range(grid.height):
		for x in range(grid.width):
			var coord := Vector2i(x, y)
			var cell := grid.get_cell(coord)
			var rect := Rect2(grid.cell_to_world(coord), Vector2(grid.cell_size, grid.cell_size))
			draw_rect(rect, DEBUG_COLORS.get(cell.type, Color.MAGENTA), true)
			draw_rect(rect, GRID_LINE_COLOR, false, 1.0)
	if grid.is_in_bounds(_hovered_coord):
		var hover_rect := Rect2(grid.cell_to_world(_hovered_coord), Vector2(grid.cell_size, grid.cell_size))
		draw_rect(hover_rect, HOVER_COLOR, false, 2.0)
