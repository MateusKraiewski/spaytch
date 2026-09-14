extends Node
## V2 — ÚNICO autoload do projeto. Justificativa (CLAUDE.md exige justificar todo autoload):
## `MainMenu`/`MapSelect` e `Main` são cenas INDEPENDENTES, trocadas via
## `get_tree().change_scene_to_file()` — nenhuma delas recebe argumentos do chamador (é assim que
## `change_scene_to_file()` funciona). A escolha de qual mapa jogar precisa atravessar essa
## fronteira de cena; sem autoload, isso exigiria um framework de cena novo (ou instanciar `Main`
## manualmente em vez de trocar de cena) só para passar UM valor. `ARCHITECTURE.md` já registrava
## esse tipo de necessidade como esperada ("estrutura pronta para... sem GameSession... nenhum
## estado atravessa menu↔jogo" — Phase 0.6) — isto é exatamente essa extensão, só quando ficou
## realmente necessária (seleção de mapa, V2), não antes.
##
## Deliberadamente mínimo: um único campo, resetado pra vazio sempre que lido por `Main.gd` (ver
## `consume_selected_map_path()`) — nenhum outro estado de partida (coins, wave, HUD) atravessa
## cenas, e não é intenção que atravesse. Se mais estado precisar cruzar cenas no futuro, isso
## deve ser avaliado e justificado aqui de novo, não assumido.
##
## SEM `class_name` de propósito (Godot recusa compilar um `class_name` com o MESMO nome do
## autoload — "hides an autoload singleton", confirmado empiricamente). E sem usar o identificador
## global mágico `GameSession` (que o motor injeta em runtime) também de propósito: `--check-only`
## (usado por run_tests.ps1) faz compile-check de cada script INDIVIDUALMENTE, sem carregar o
## projeto inteiro — esse identificador não existe nesse modo isolado e quebra o compile-check com
## "Identifier not found" (comportamento real confirmado, não suposição). Quem consome este
## autoload (main.gd, map_select.gd) usa `const GameSession := preload("res://scripts/core/
## game_session.gd")` + `get_node("/root/GameSession") as GameSession` — tipagem via script
## anônimo (preload), que compila isoladamente sem depender de autoload nenhum, em vez do
## identificador global ou de um `class_name`.

## Vazio = "usa o mapa default do próprio Main.tscn" (Vale dos Ovos) — mesmo comportamento de
## sempre quando ninguém passou por uma tela de seleção (ex: abrir Main.tscn direto no editor).
var _selected_map_path: String = ""


func select_map(map_path: String) -> void:
	_selected_map_path = map_path


## "Consome" (lê e limpa) a seleção — evita que uma segunda partida iniciada sem passar pela
## seleção de novo (ex: MENU -> JOGAR de novo depois de uma derrota) herde silenciosamente o mapa
## de uma partida anterior por engano.
func consume_selected_map_path() -> String:
	var path := _selected_map_path
	_selected_map_path = ""
	return path
