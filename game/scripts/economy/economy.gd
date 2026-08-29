class_name Economy
extends Node
## Recurso de partida (`coins`) — estado runtime mutável, não `Resource`
## (mesmo raciocínio já aplicado a `Cell.occupant`: dado que muda durante o
## jogo não deve viver num Resource potencialmente compartilhado). Só
## `starting_coins` é configuração (`@export`, mesmo padrão de
## `GridManager.map_definition`).
##
## `extends Node`, não Node2D: sem identidade espacial própria, mesmo
## raciocínio de InputManager/EnemySpawner/PlacementController.
##
## Regras centralizadas aqui (não espalhadas): `can_afford()`/`spend()`/
## `add()` são os únicos pontos que tocam `coins` — quem quer gastar ou
## conceder moedas chama estes métodos, nunca lê/escreve `coins` diretamente
## de fora sem passar por eles (por convenção; GDScript não impõe
## privacidade real).
##
## Sem loja, sem moeda premium, sem persistência — fora de escopo desta
## fase.

signal coins_changed(new_amount: int)

@export var starting_coins: int = 150  ## TBD/placeholder balance

var coins: int = 0


func _ready() -> void:
	reset()


## Público e separado de _ready() pelo mesmo motivo de BasicEnemy.initialize():
## _ready() só dispara quando o node entra numa SceneTree — testes que
## instanciam Economy.new() diretamente (sem add_child) precisam de um jeito
## de (re)inicializar `coins` que funcione nos dois contextos.
func reset() -> void:
	coins = starting_coins


func can_afford(amount: int) -> bool:
	return coins >= amount


## Retorna false (e não desconta nada) se não houver coins suficientes —
## quem chama decide o que fazer nesse caso (ex: PlacementController cancela
## o placement).
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)
