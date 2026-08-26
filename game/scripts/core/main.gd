extends Node2D
## Composition root da cena principal: conecta sinais entre nodes irmãos
## desacoplados (InputManager <-> GridManager) e, nesta fase, constrói o
## MapPath a partir do MapDefinition já carregado pelo GridManager e o
## entrega ao EnemySpawner para o spawn inicial (Phase 0.3 — spawn manual
## simples, sem wave manager ainda). Não contém lógica de grid, input, path
## ou inimigo — cada responsabilidade vive em seu próprio script.

@onready var _grid_manager: GridManager = $GridManager
@onready var _input_manager: InputManager = $InputManager
@onready var _enemy_spawner: EnemySpawner = $EnemySpawner


func _ready() -> void:
	_input_manager.pointer_moved.connect(_grid_manager.on_pointer_moved)
	_input_manager.pointer_pressed.connect(_grid_manager.on_pointer_pressed)

	var map_path := MapPath.build(_grid_manager.map_definition)
	if map_path == null:
		push_error("[Main] Não foi possível construir o MapPath — spawn de inimigo cancelado.")
		return

	_enemy_spawner.setup(_grid_manager.grid, map_path)
	_enemy_spawner.spawn_enemy()
