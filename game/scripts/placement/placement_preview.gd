class_name PlacementPreview
extends Node2D
## Visual placeholder de placement: destaca a célula sob o cursor (verde =
## válida, vermelho = inválida) e um círculo aproximado do alcance do
## dinossauro selecionado. Só desenha — nunca decide validade nem altera
## estado; lê tudo de PlacementController (somente leitura).
##
## Redesenha só quando PlacementController.preview_changed dispara (mudança
## real de estado), não a cada frame — mesmo padrão de GridManager.
##
## No touch não há hover, então esta preview normalmente só aparece
## enquanto o dedo se move sobre a tela (se o dispositivo gerar
## eventos de movimento) ou não aparece antes do toque de confirmação —
## isso é aceitável nesta fase (requisito: não depender de hover para
## FUNCIONAR, só como reforço visual quando disponível).

const VALID_COLOR := Color(0.2, 1.0, 0.3, 0.85)
const INVALID_COLOR := Color(1.0, 0.2, 0.2, 0.85)
const INSUFFICIENT_FUNDS_COLOR := Color(1.0, 0.65, 0.1, 0.85)  ## célula válida, mas sem coins suficientes
const RANGE_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const FUSION_SELECTED_COLOR := Color(1.0, 0.85, 0.2, 0.95)  ## dourado — distinto do verde/vermelho do placement

## Mesmo silhueta de scenes/dinosaurs/Dinosaur.tscn (Placeholder), reduzida
## aqui só para o preview — ambas são placeholder e serão substituídas pela
## arte final juntas, então essa duplicação pontual é aceitável (evitar uma
## Resource compartilhada só para isso seria overengineering nesta fase).
## `Array[Vector2]` tipado, não `PackedVector2Array([...])` — mesmo motivo já
## documentado em map_validator.gd (Phase 0.1): um array-literal-dentro-de-
## PackedXArray() não é reconhecido como expressão constante pelo GDScript,
## só um Array tipado com anotação explícita é.
const _DINOSAUR_SHAPE: Array[Vector2] = [
	Vector2(12, -6), Vector2(-2, -9), Vector2(-16, 0),
	Vector2(-2, 8), Vector2(10, 6), Vector2(14, 0),
]

var _controller: PlacementController
var _grid: Grid


func setup(controller: PlacementController, grid: Grid) -> void:
	_controller = controller
	_grid = grid
	_controller.preview_changed.connect(_on_preview_changed)


func _on_preview_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if _controller == null or _grid == null:
		return
	if _controller.state != PlacementController.State.PLACING:
		_draw_fusion_selection()
		return
	if not _grid.is_in_bounds(_controller.hovered_coord):
		return

	var color: Color
	if not _controller.is_hover_valid:
		color = INVALID_COLOR
	elif not _controller.can_afford_selected():
		color = INSUFFICIENT_FUNDS_COLOR
	else:
		color = VALID_COLOR

	var cell_rect := Rect2(_grid.cell_to_world(_controller.hovered_coord), Vector2(_grid.cell_size, _grid.cell_size))
	draw_rect(cell_rect, color, false, 2.0)

	if _controller.selected_definition != null:
		var center := _grid.cell_center_world(_controller.hovered_coord)
		draw_circle(center, _controller.selected_definition.range, RANGE_COLOR)
		var shape := PackedVector2Array()
		for point in _DINOSAUR_SHAPE:
			shape.append(center + point)
		draw_colored_polygon(shape, Color(color.r, color.g, color.b, 0.5))


## Correção de UX da fusão (não mexe na mecânica, só o desenho): destaca a célula que o
## PRIMEIRO CLIQUE já confirmou como pendente de fusão — `_controller.fusion_pending_coord`,
## preenchido por PlacementController._handle_fusion_click() com a coordenada REAL que
## `Grid.world_to_cell()` resolveu para aquele clique, não uma posição de hover em tempo real
## (fusão não usa hover, só o resultado do clique — diferente do placement acima). Isso é
## exatamente "qual célula o jogo identificou" — se o destaque aparecer numa célula diferente da
## que o jogador visualmente mirou, o problema é o tamanho do sprite vs a célula, não a lógica de
## fusão (que já está coberta por fusion_tests.gd). Some sozinho quando `fusion_pending_coord`
## volta a `(-1,-1)` (cancelado, fundido, ou rejeitado — ver _handle_fusion_click()).
func _draw_fusion_selection() -> void:
	if not _grid.is_in_bounds(_controller.fusion_pending_coord):
		return
	var cell_rect := Rect2(_grid.cell_to_world(_controller.fusion_pending_coord), Vector2(_grid.cell_size, _grid.cell_size))
	draw_rect(cell_rect, FUSION_SELECTED_COLOR, false, 3.0)
