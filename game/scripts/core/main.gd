extends Node2D
## Composition root da cena principal: apenas conecta sinais entre nodes
## irmãos desacoplados (InputManager <-> GridManager). Não contém lógica de
## grid, input ou renderização — cada responsabilidade vive em seu próprio
## script (ver docs/ARCHITECTURE.md).

@onready var _grid_manager: GridManager = $GridManager
@onready var _input_manager: InputManager = $InputManager


func _ready() -> void:
	_input_manager.pointer_moved.connect(_grid_manager.on_pointer_moved)
	_input_manager.pointer_pressed.connect(_grid_manager.on_pointer_pressed)
