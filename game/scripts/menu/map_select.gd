extends Control
## V2 — tela entre `MainMenu` e `Main`: escolhe qual `MapDefinition` a partida vai usar, gravando
## a escolha em `GameSession` (ver seu próprio doc comment sobre por que um autoload passou a ser
## necessário) antes de trocar de cena.
##
## Lista de mapas definida aqui em código (mesmo padrão de `Main._DINOSAUR_DEFINITION_PATHS`/
## `_WAVE_PATHS` — a LISTA de quais `.tres` existem fica em código, os VALORES de cada mapa
## continuam inteiramente em dado) — cresce conforme mapas novos forem adicionados (V2, meta de
## 10 mapas) sem tocar em nenhuma outra tela. Botões instanciados em runtime (não pré-criados no
## `.tscn`) — adicionar um mapa novo à lista não exige editar esta cena.

## Tipagem via script anônimo (não `class_name` — colidiria com o autoload "GameSession"; ver
## game_session.gd) só para poder chamar `.select_map()` com checagem estática.
const _GameSessionScript := preload("res://scripts/core/game_session.gd")

const _MAPS := [
	{"name": "Vale dos Ovos", "path": "res://data/maps/vale_dos_ovos.tres"},
	{"name": "Trilha Sinuosa", "path": "res://data/maps/trilha_sinuosa.tres"},
	{"name": "Delta Verdejante", "path": "res://data/maps/delta_verdejante.tres"},
]

@onready var _map_list: VBoxContainer = $MapList
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	for map_info in _MAPS:
		var button := Button.new()
		button.text = map_info["name"]
		button.custom_minimum_size = Vector2(240, 40)
		button.pressed.connect(_on_map_selected.bind(map_info["path"]))
		_map_list.add_child(button)
	_back_button.pressed.connect(_on_back_pressed)


func _on_map_selected(map_path: String) -> void:
	var game_session := get_node("/root/GameSession") as _GameSessionScript
	game_session.select_map(map_path)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
