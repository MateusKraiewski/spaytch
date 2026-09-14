extends Node2D
## Composition root da cena principal — liga todos os sistemas e controla o
## estado da partida (PREPARING/WAVE_ACTIVE/WAVE_COMPLETE/GAME_OVER),
## conforme pedido explicitamente pela Phase 0.5 ("o estado deve ser
## controlado pelo composition root"). Não é uma máquina de estados
## abstrata separada — é só um enum + reações a sinais dos sistemas reais
## (WaveManager, EggManager), que são quem de fato sabe quando uma wave
## termina ou quando os ovos acabam. Main nunca decide POR ELES, só reage.
##
## Pausa via mecanismo nativo do Godot (`get_tree().paused`): todo node de
## gameplay usa o `process_mode` padrão (PROCESS_MODE_INHERIT), então
## inimigos/dinossauros/projéteis/WaveManager param de avançar sozinhos
## quando pausado, sem nenhuma mudança de código neles. Só a HUD tem
## `process_mode = PROCESS_MODE_ALWAYS` (setado em HUD.tscn) para continuar
## respondendo ao próprio botão de pausa.
##
## Velocidade x1/x2 via `Engine.time_scale` (mecanismo nativo do Godot):
## escala uniformemente o delta de todo _process()/_physics_process() do
## projeto, sem exigir nenhuma mudança nos step() determinísticos já
## existentes (BasicEnemy/Dinosaur/Projectile/WaveManager).
##
## Não spawna mais um inimigo sozinho ao iniciar (diferente da Phase 0.3/0.4)
## — spawning agora é responsabilidade exclusiva de WaveManager, disparado
## pelo jogador via HUD.
##
## `WaveManager.waves` é montado aqui em código via load(), em vez de
## exportado/atribuído em Main.tscn: escrever manualmente o literal de
## Array[WaveDefinition] tipado no formato texto do .tscn é uma sintaxe que
## não há como validar sem abrir o projeto no editor de verdade — mesmo
## tipo de risco já evitado na Phase 0.1 (InputMap serializado à mão). Os
## VALORES de cada wave continuam inteiramente em dado (.tres), só a LISTA
## de quais arquivos compõem a campanha está aqui.
const _WAVE_PATHS := [
	"res://data/waves/wave_01.tres",
	"res://data/waves/wave_02.tres",
	"res://data/waves/wave_03.tres",
]

## Tipagem via script anônimo (não `class_name` — colidiria com o autoload "GameSession"; ver
## game_session.gd) só para poder chamar `.consume_selected_map_path()` com checagem estática.
const _GameSessionScript := preload("res://scripts/core/game_session.gd")

## Sprint 1, Etapa 4 — seleção mínima entre as 3 espécies: um único botão
## (já existente na HUD) cicla por esta lista a cada clique, em vez de criar
## um botão por espécie ou qualquer UI de escolha nova. Mesmo padrão de
## `_WAVE_PATHS` acima — a LISTA de quais .tres compõem a seleção fica aqui
## (código), os VALORES de cada um continuam inteiramente em dado (.tres da
## Etapa 2). Não usa `PlacementController.initial_definition` (que ainda
## aponta para o Velociraptor procedural antigo, intocado) — a pré-seleção
## automática do início agora vem do índice 0 desta lista.
const _DINOSAUR_DEFINITION_PATHS := [
	"res://data/dinosaurs/velociraptor_t1.tres",
	"res://data/dinosaurs/triceratops_t1.tres",
	"res://data/dinosaurs/trex_t1.tres",
]

enum GameState { PREPARING, WAVE_ACTIVE, WAVE_COMPLETE, GAME_OVER }

@onready var _grid_manager: GridManager = $GridManager
@onready var _input_manager: InputManager = $InputManager
@onready var _enemy_spawner: EnemySpawner = $EnemySpawner
@onready var _dinosaurs: Node = $Dinosaurs
@onready var _projectiles: Node = $Projectiles
@onready var _placement_controller: PlacementController = $PlacementController
@onready var _placement_preview: PlacementPreview = $PlacementPreview
@onready var _economy: Economy = $Economy
@onready var _egg_manager: EggManager = $EggManager
@onready var _wave_manager: WaveManager = $WaveManager
@onready var _hud: HUD = $HUD

## Wave automática — intervalo entre o banner "WAVE X COMPLETE" e a próxima wave iniciar sozinha.
## Vive em Main.gd (não em WaveManager) de propósito: WaveManager já documenta explicitamente que
## NÃO decide isto sozinho ("quem decide é quem escuta wave_completed") — mudar essa fronteira
## exigiria justificar uma mudança de arquitetura que este pedido não pede. Determinístico via
## `step(delta)` (mesmo padrão de WaveManager._time_since_last_spawn/Dinosaur.step()) em vez de
## `get_tree().create_timer()` — a suíte inteira testa tempo assim (chamando step() direto, sem
## depender de tempo real), um Timer do motor quebraria essa convenção e exigiria testes com
## espera real.
const _WAVE_COMPLETE_BANNER_DURATION := 2.0

## Countdown "3, 2, 1, GO!" antes de cada wave (exceto a primeira, que começa por ação direta do
## jogador) — cada item é [texto, duração em segundos], consumido em ordem por step() depois do
## banner "WAVE X COMPLETE" já ter ficado visível por _WAVE_COMPLETE_BANNER_DURATION. Mesmo Label
## de sempre (`HUD.show_banner`), sem elemento de UI novo — só mais uma sequência de textos.
const _WAVE_COUNTDOWN_STEPS: Array = [
	["3", 1.0],
	["2", 1.0],
	["1", 1.0],
	["GO!", 0.6],
]

var _state: GameState = GameState.PREPARING
var _speed_multiplier: float = 1.0
var _available_definitions: Array[DinosaurDefinition] = []
var _selected_definition_index: int = 0

## Fila de passos do countdown ainda não exibidos (ver _WAVE_COUNTDOWN_STEPS) — vazia quando não
## há countdown em andamento. `_wave_intermission_timer < 0.0` é o sentinel de "nada pendente"
## (mesmo espírito de `PlacementController.fusion_pending_coord = Vector2i(-1,-1)`); o 1º valor
## setado em _on_wave_completed() é o tempo restante do banner "COMPLETE" (fila ainda intacta,
## step() só começa a consumi-la quando esse tempo zerar).
var _wave_intermission_queue: Array = []
var _wave_intermission_timer: float = -1.0


func _ready() -> void:
	Engine.time_scale = 1.0  # evita herdar time_scale de uma instância anterior (ex: em testes)

	# V2 — seleção de mapa (ver GameSession/map_select.gd): PRECISA ser a primeiríssima coisa,
	# antes de qualquer leitura de _grid_manager.grid/map_definition — GridManager já construiu o
	# grid a partir do default do .tscn no próprio _ready() dele (roda antes deste, propagação
	# bottom-up do Godot); trocar depois disso já seria tarde demais. String vazia (nenhuma
	# seleção pendente — ex: Main.tscn aberto direto no editor, ou fluxo de teste que não passou
	# pela tela de seleção) preserva o comportamento de sempre (mapa default do .tscn, Vale dos
	# Ovos).
	var game_session := get_node("/root/GameSession") as _GameSessionScript
	var selected_map_path := game_session.consume_selected_map_path()
	if not selected_map_path.is_empty():
		var selected_map := load(selected_map_path) as MapDefinition
		if selected_map != null:
			_grid_manager.set_map_definition(selected_map)

	_input_manager.pointer_moved.connect(_grid_manager.on_pointer_moved)
	_input_manager.pointer_pressed.connect(_grid_manager.on_pointer_pressed)
	_input_manager.pointer_moved.connect(_placement_controller.on_pointer_moved)
	_input_manager.pointer_pressed.connect(_placement_controller.on_pointer_pressed)

	var map_path := MapPath.build(_grid_manager.map_definition)
	if map_path == null:
		push_error("[Main] Não foi possível construir o MapPath — jogo não pode iniciar.")
		return

	_enemy_spawner.setup(_grid_manager.grid, map_path)

	_egg_manager.setup(_grid_manager.map_definition, _grid_manager.grid, _enemy_spawner)
	_egg_manager.all_eggs_destroyed.connect(_on_all_eggs_destroyed)
	_egg_manager.egg_damaged.connect(_on_egg_damaged)

	var waves: Array[WaveDefinition] = []
	for path in _WAVE_PATHS:
		waves.append(load(path) as WaveDefinition)
	_wave_manager.waves = waves
	_wave_manager.setup(_enemy_spawner, _economy)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_completed.connect(_on_wave_completed)

	_placement_controller.setup(_grid_manager.grid, _enemy_spawner, _dinosaurs, _projectiles, _economy)
	_placement_controller.placement_failed.connect(_on_placement_failed)
	_placement_controller.dinosaur_placed.connect(_on_dinosaur_placed)
	_placement_preview.setup(_placement_controller, _grid_manager.grid)

	for path in _DINOSAUR_DEFINITION_PATHS:
		_available_definitions.append(load(path) as DinosaurDefinition)
	if not _available_definitions.is_empty():
		var option_labels: Array[String] = []
		for definition in _available_definitions:
			option_labels.append("🦖 %s (%d)" % [definition.display_name, definition.cost])
		_hud.set_dinosaur_options(option_labels)
		_select_dinosaur_definition(0)

	_hud.start_wave_pressed.connect(_on_start_wave_pressed)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.resume_pressed.connect(_on_resume_pressed)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.speed_pressed.connect(_on_speed_pressed)
	_hud.dinosaur_option_selected.connect(_on_dinosaur_option_selected)
	_economy.coins_changed.connect(_on_coins_changed)

	_hud.set_coins(_economy.coins)
	_hud.set_pause_label(get_tree().paused)
	_hud.set_speed_label(_speed_multiplier)
	_update_wave_hud()
	_update_eggs_hud()
	_set_state(GameState.PREPARING)


func _set_state(new_state: GameState) -> void:
	_state = new_state
	_hud.set_wave_state(GameState.keys()[_state])
	var can_start := (_state == GameState.PREPARING or _state == GameState.WAVE_COMPLETE) \
		and _wave_manager.has_next_wave()
	_hud.set_start_wave_enabled(can_start)


func _on_start_wave_pressed() -> void:
	if _state == GameState.GAME_OVER:
		return
	_wave_manager.start_next_wave()


## Único `_process` de Main — o resto do gameplay já tem seu próprio `step(delta)` chamado por
## subsistema (WaveManager/Dinosaur/BasicEnemy/Projectile); a contagem do intervalo/countdown entre
## waves é uma decisão de FLUXO de jogo (mesma responsabilidade das transições de GameState), não
## pertence a nenhum deles. `PROCESS_MODE_INHERIT` padrão (Main não sobrescreve) já garante que
## isto para sozinho quando o jogo está pausado, sem nenhum código extra — mesmo comportamento de
## WaveManager/Dinosaur durante a pausa (ver doc comment no topo do arquivo).
func _process(delta: float) -> void:
	step(delta)


## Público (não `_step`) de propósito — testável chamando direto, mesma convenção de
## WaveManager.step()/Dinosaur.step() (ver seus próprios doc comments). Consome
## `_wave_intermission_timer`/`_wave_intermission_queue`: enquanto o timer não chega a zero, só
## decrementa; ao chegar a zero, mostra o PRÓXIMO texto da fila (e rearma o timer com a duração
## dele) ou, se a fila já estiver vazia, inicia a próxima wave de verdade.
func step(delta: float) -> void:
	if _wave_intermission_timer < 0.0:
		return
	_wave_intermission_timer -= delta
	if _wave_intermission_timer > 0.0:
		return
	if not _wave_intermission_queue.is_empty():
		var countdown_step: Array = _wave_intermission_queue.pop_front()
		_hud.show_banner(countdown_step[0], 0.0)
		_wave_intermission_timer = countdown_step[1]
		return
	_wave_intermission_timer = -1.0
	if _state != GameState.GAME_OVER:
		_wave_manager.start_next_wave()


func _on_wave_started(wave_index: int, _wave: WaveDefinition) -> void:
	## Cobre tanto o início manual (botão, pula o resto do countdown) quanto o automático.
	_wave_intermission_timer = -1.0
	_wave_intermission_queue.clear()
	_set_state(GameState.WAVE_ACTIVE)
	_hud.show_banner("WAVE %d" % (wave_index + 1), 1.0)
	_update_wave_hud()


func _on_wave_completed(wave_index: int, wave: WaveDefinition) -> void:
	if _state == GameState.GAME_OVER:
		return
	_set_state(GameState.WAVE_COMPLETE)
	if _wave_manager.has_next_wave():
		# Sem auto-hide próprio (`show_banner(..., 0.0)`): quem substitui este texto é sempre o
		# próximo passo do countdown (ou "WAVE X" ao iniciar de verdade) — um 2º timer de auto-hide
		# correria em paralelo por tempo real (get_tree().create_timer(), não pausável do mesmo
		# jeito que este step()), podendo dessincronizar sob pausa.
		_hud.show_banner("WAVE %d COMPLETE! +%d coins" % [wave_index + 1, wave.wave_completion_reward], 0.0)
		_wave_intermission_queue = _WAVE_COUNTDOWN_STEPS.duplicate(true)
		_wave_intermission_timer = _WAVE_COMPLETE_BANNER_DURATION
	else:
		# Última wave da campanha: feedback distinto de "acabou" em vez do
		# banner genérico de wave-complete — sem isso o jogador só via o
		# botão "Iniciar Onda" ficar desabilitado para sempre, sem
		# explicação nenhuma de que tinha vencido. Sem próxima wave, não há
		# nada pra agendar (_wave_intermission_timer/_queue ficam vazios).
		_hud.show_banner("🏆 VITÓRIA! Todas as ondas superadas! +%d coins" % wave.wave_completion_reward)
	_update_wave_hud()


func _on_placement_failed(reason: String) -> void:
	if reason == "insufficient_coins":
		_hud.show_banner("Coins insuficientes!", 1.5)


## Bug report do jogador — o botão continuava mostrando o nome/custo da última espécie mesmo
## depois dela já ter sido colocada: `_place_dinosaur()` zera `selected_definition` e volta pra
## IDLE (nada armado), mas nada avisava a HUD disso, então o texto ficava "mentindo" (mostrava uma
## espécie que já não tinha mais nenhuma relação com o que um clique seguinte faria — em IDLE, o
## mesmo clique vira seleção de fusão, não um novo placement). `PlacementController.dinosaur_placed`
## já existia pronto exatamente pra este tipo de gancho (Phase 0.6, nunca conectado até agora) —
## só reseta o texto pra um estado neutro; não rearma seleção nem muda a máquina de estados de
## PlacementController (continua IDLE até o jogador clicar o botão de novo, comportamento da
## Etapa 4 inalterado).
func _on_dinosaur_placed(_dinosaur: Dinosaur, _coord: Vector2i) -> void:
	_hud.set_dinosaur_button_label("🦖 Escolher dinossauro")


func _on_all_eggs_destroyed() -> void:
	_set_state(GameState.GAME_OVER)
	_wave_manager.lock()
	_hud.show_game_over()


func _on_egg_damaged(_egg: Egg) -> void:
	_update_eggs_hud()


func _on_coins_changed(new_amount: int) -> void:
	_hud.set_coins(new_amount)


func _on_pause_pressed() -> void:
	if get_tree().paused:
		_unpause()
	else:
		get_tree().paused = true
		_hud.set_pause_label(true)
		_hud.show_pause_overlay()


func _on_resume_pressed() -> void:
	_unpause()


## Volta ao Main Menu — descarta a partida atual (permitido explicitamente
## nesta fase, ver docs/ARCHITECTURE.md "Phase 0.6"). Despausa ANTES de
## trocar de cena: `get_tree().paused` é uma propriedade global da árvore,
## não local a esta cena — se não for resetado aqui, o Main Menu também
## nasceria pausado.
func _on_menu_pressed() -> void:
	_unpause()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _unpause() -> void:
	get_tree().paused = false
	_hud.set_pause_label(false)
	_hud.hide_pause_overlay()


## Permite colocar mais de um dinossauro por partida — sem isto, o jogador só
## conseguiria posicionar exatamente 1 (a pré-seleção automática do início),
## já que PlacementController nunca voltava sozinho para PLACING depois do
## primeiro placement. Não adiciona profundidade de jogo nova, só torna
## utilizável a capacidade que já existia (Phase 0.4/0.5 permitiam isso via
## API; não havia jeito de acionar de novo pela UI).
##
## Bug report do jogador — a versão anterior (Etapa 4) CICLAVA pra próxima
## espécie a cada clique no botão único; a reclamação foi que isso "não
## deixa escolher, só traz a próxima". Agora o botão (ver hud.gd) abre um
## popup com as 3 espécies e este handler reage à escolha DIRETA do jogador
## (`index` já é a posição exata em `_available_definitions`/
## `_DINOSAUR_DEFINITION_PATHS`, sem aritmética de ciclo nenhuma).
## `select_dinosaur()` continua seguro de chamar em qualquer estado (ver seu
## próprio doc comment em PlacementController), então escolher de novo
## depois de já ter colocado um funciona sem tratamento especial.
func _on_dinosaur_option_selected(index: int) -> void:
	if index < 0 or index >= _available_definitions.size():
		return
	_select_dinosaur_definition(index)


func _select_dinosaur_definition(index: int) -> void:
	_selected_definition_index = index
	var definition := _available_definitions[index]
	_placement_controller.select_dinosaur(definition)
	_hud.set_dinosaur_button_label("🦖 %s (%d)" % [definition.display_name, definition.cost])


func _on_speed_pressed() -> void:
	_speed_multiplier = 2.0 if _speed_multiplier == 1.0 else 1.0
	Engine.time_scale = _speed_multiplier
	_hud.set_speed_label(_speed_multiplier)


func _update_wave_hud() -> void:
	_hud.set_wave(_wave_manager.current_wave_index + 1, _wave_manager.waves.size())


func _update_eggs_hud() -> void:
	var eggs := _egg_manager.get_eggs()
	var hp_values: Array[int] = []
	for egg in eggs:
		hp_values.append(egg.hp)
	_hud.set_eggs(_egg_manager.get_alive_eggs().size(), eggs.size(), hp_values)
