class_name DamageNumber
extends Node2D
## Número de dano flutuante — feedback de combate mínimo (Bloco 3): sobe e
## desaparece sozinho, sem exigir acompanhamento externo. Mesmo padrão de
## autonomia de `DeathEffect` (spawnado como irmão da entidade que sofreu
## dano, nunca no caminho crítico de nada, se autodestrói via timer).
##
## Desenhado direto via `draw_string()` (nativo de `CanvasItem`) em vez de
## um `Label`/`Control` — o número já nasce em espaço de MUNDO (mesma
## coordenada de quem sofreu o dano), então não precisa de nenhuma conversão
## câmera↔tela. `_draw()` só roda uma vez (o texto em si não muda depois de
## `initialize()`); subir e desaparecer são só `position`/`modulate`
## (propriedades nativas do `CanvasItem`, animadas pelo motor sem precisar
## chamar `queue_redraw()` de novo).

const _LIFETIME := 0.6
const _RISE_DISTANCE := 24.0
const _FONT_SIZE := 16
const _COLOR := Color(1.0, 0.85, 0.25)

var _text: String = ""


func initialize(amount: int) -> void:
	_text = str(amount)


func _ready() -> void:
	position.x += randf_range(-6.0, 6.0)  # evita empilhar vários números idênticos no mesmo ponto
	queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - _RISE_DISTANCE, _LIFETIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, _LIFETIME)

	get_tree().create_timer(_LIFETIME).timeout.connect(queue_free)


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-8, 0), _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, _FONT_SIZE, _COLOR)
