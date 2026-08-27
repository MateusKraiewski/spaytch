class_name HUD
extends CanvasLayer
## HUD do jogo — placeholders de UI (tema padrão do Godot), sem polimento
## visual definitivo. Só EXIBE estado e ENCAMINHA a intenção do jogador via
## sinais; não decide nada sozinha (Main.gd decide o que fazer com
## start_wave_pressed etc.) — mesmo princípio de PlacementPreview (visual,
## não lógica de jogo).
##
## `process_mode = PROCESS_MODE_ALWAYS` (setado na cena, HUD.tscn): continua
## funcionando mesmo com a árvore pausada (get_tree().paused = true) — é o
## único jeito do jogador conseguir despausar pela própria UI (overlay de
## pausa incluso).
##
## Estrutura pensada para arte final substituir os placeholders depois: cada
## elemento tem um caminho estável dentro de `Root`, e os métodos públicos
## (set_coins, set_wave, show_banner, ...) são a única superfície que o
## resto do jogo toca — trocar Label/Panel por algo mais elaborado não exige
## mudar quem chama esses métodos.
##
## Phase 0.6 — banner único reutilizável (show_banner/hide_banner) substitui
## os antigos show_wave_complete/hide_wave_complete: "WAVE N" (auto-some em
## ~1s), "WAVE N COMPLETE" (fica até a próxima wave começar) e "Coins
## insuficientes!" (auto-some) usam o mesmo Label, evitando três elementos
## de UI ad-hoc para a mesma ideia ("mensagem temporária no centro da
## tela"). `_banner_token` invalida um auto-hide agendado se outra chamada a
## show_banner() sobrescrever o texto antes do timer disparar.

signal start_wave_pressed()
signal pause_pressed()
signal resume_pressed()
signal menu_pressed()
signal speed_pressed()
signal dinosaur_button_pressed()

@onready var _coins_label: Label = $Root/CoinsLabel
@onready var _wave_label: Label = $Root/WaveLabel
@onready var _wave_state_label: Label = $Root/WaveStateLabel
@onready var _eggs_label: Label = $Root/EggsLabel
@onready var _start_wave_button: Button = $Root/StartWaveButton
@onready var _pause_button: Button = $Root/PauseButton
@onready var _speed_button: Button = $Root/SpeedButton
@onready var _dinosaur_button: Button = $Root/DinosaurButton
@onready var _banner_label: Label = $Root/BannerLabel
@onready var _pause_overlay: Control = $Root/PauseOverlay
@onready var _resume_button: Button = $Root/PauseOverlay/ResumeButton
@onready var _pause_menu_button: Button = $Root/PauseOverlay/PauseMenuButton
@onready var _game_over_overlay: Control = $Root/GameOverOverlay
@onready var _game_over_menu_button: Button = $Root/GameOverOverlay/GameOverMenuButton

var _banner_token: int = 0


func _ready() -> void:
	_start_wave_button.pressed.connect(func() -> void: start_wave_pressed.emit())
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_pause_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_game_over_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	_dinosaur_button.pressed.connect(func() -> void: dinosaur_button_pressed.emit())
	_banner_label.visible = false
	_pause_overlay.visible = false
	_game_over_overlay.visible = false


func set_coins(amount: int) -> void:
	_coins_label.text = "💰 Coins: %d" % amount


func set_wave(wave_number: int, total_waves: int) -> void:
	_wave_label.text = "Wave: %d/%d" % [wave_number, total_waves]


func set_wave_state(text: String) -> void:
	_wave_state_label.text = "Status: %s" % text


func set_eggs(alive: int, total: int, hp_values: Array[int]) -> void:
	var parts: Array[String] = []
	for hp in hp_values:
		parts.append(str(hp))
	_eggs_label.text = "🥚 Eggs: %d/%d (HP: %s)" % [alive, total, ", ".join(parts)]


func set_start_wave_enabled(enabled: bool) -> void:
	_start_wave_button.disabled = not enabled


## Texto do botão de seleção do dinossauro (ex: "🦖 Velociraptor (20)") —
## setado uma vez pelo Main.gd a partir de DinosaurDefinition; o custo é
## estático nesta fase (sem upgrades), então não precisa ser recalculado.
func set_dinosaur_button_label(text: String) -> void:
	_dinosaur_button.text = text


## Mensagem central temporária. `auto_hide_after <= 0.0` deixa visível até
## hide_banner() (ou outro show_banner()) ser chamado explicitamente.
func show_banner(text: String, auto_hide_after: float = 0.0) -> void:
	_banner_label.text = text
	_banner_label.visible = true
	_banner_token += 1
	if auto_hide_after > 0.0:
		var token := _banner_token
		var timer := get_tree().create_timer(auto_hide_after)
		timer.timeout.connect(func() -> void:
			if token == _banner_token:
				hide_banner()
		)


func hide_banner() -> void:
	_banner_label.visible = false


func show_pause_overlay() -> void:
	_pause_overlay.visible = true


func hide_pause_overlay() -> void:
	_pause_overlay.visible = false


func show_game_over() -> void:
	_game_over_overlay.visible = true


func set_pause_label(paused: bool) -> void:
	_pause_button.text = "▶ Resume" if paused else "⏸ Pause"


func set_speed_label(speed_multiplier: float) -> void:
	_speed_button.text = "x%d" % int(speed_multiplier)
