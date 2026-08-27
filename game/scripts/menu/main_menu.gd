extends Control
## Cena de entrada do jogo (BOOT -> MAIN MENU), separada da cena de jogo
## (Main.tscn) — só navega, nenhuma lógica de gameplay aqui. Nenhum estado é
## compartilhado entre esta cena e o jogo (ver docs/ARCHITECTURE.md, "Phase
## 0.6"): `get_tree().change_scene_to_file()` é suficiente, sem precisar de
## nenhum GameSession/autoload — o jogo reconstrói tudo do zero em Main.tscn
## a cada "JOGAR".
##
## "Opções" ainda não existe como tela (fora de escopo desta fase) — o botão
## já existe na navegação para que uma tela de opções (e, no futuro, login/
## conta) possa ser adicionada depois sem reestruturar este menu ou o resto
## do projeto.

@onready var _play_button: Button = $PlayButton
@onready var _options_button: Button = $OptionsButton
@onready var _quit_button: Button = $QuitButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_options_pressed() -> void:
	print("[MainMenu] Opções ainda não implementadas nesta fase.")


func _on_quit_pressed() -> void:
	get_tree().quit()
