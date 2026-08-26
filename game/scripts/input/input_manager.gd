class_name InputManager
extends Node
## Normaliza eventos de ponteiro (mouse hoje; touch e, futuramente, gamepad)
## em um único par de sinais que o resto do jogo consome, sem precisar saber
## qual dispositivo originou o evento.
##
## Posições emitidas já estão no espaço lógico do jogo (640x384): com
## window/stretch/mode = "viewport", o Godot converte automaticamente as
## coordenadas de input do dispositivo real para o espaço do viewport base,
## então nenhuma conversão manual é necessária aqui.

signal pointer_moved(world_pos: Vector2)
signal pointer_pressed(world_pos: Vector2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_moved.emit(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pointer_pressed.emit(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			pointer_pressed.emit(event.position)
