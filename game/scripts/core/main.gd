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

var _state: GameState = GameState.PREPARING
var _speed_multiplier: float = 1.0


func _ready() -> void:
	Engine.time_scale = 1.0  # evita herdar time_scale de uma instância anterior (ex: em testes)

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
	_placement_preview.setup(_placement_controller, _grid_manager.grid)
	if _placement_controller.initial_definition != null:
		_placement_controller.select_dinosaur(_placement_controller.initial_definition)
		var definition := _placement_controller.initial_definition
		_hud.set_dinosaur_button_label("🦖 %s (%d)" % [definition.display_name, definition.cost])

	_hud.start_wave_pressed.connect(_on_start_wave_pressed)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.resume_pressed.connect(_on_resume_pressed)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.speed_pressed.connect(_on_speed_pressed)
	_hud.dinosaur_button_pressed.connect(_on_dinosaur_button_pressed)
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


func _on_wave_started(wave_index: int, _wave: WaveDefinition) -> void:
	_set_state(GameState.WAVE_ACTIVE)
	_hud.show_banner("WAVE %d" % (wave_index + 1), 1.0)
	_update_wave_hud()


func _on_wave_completed(wave_index: int, wave: WaveDefinition) -> void:
	if _state == GameState.GAME_OVER:
		return
	_set_state(GameState.WAVE_COMPLETE)
	if _wave_manager.has_next_wave():
		_hud.show_banner("WAVE %d COMPLETE! +%d coins" % [wave_index + 1, wave.wave_completion_reward])
	else:
		# Última wave da campanha: feedback distinto de "acabou" em vez do
		# banner genérico de wave-complete — sem isso o jogador só via o
		# botão "Iniciar Onda" ficar desabilitado para sempre, sem
		# explicação nenhuma de que tinha vencido.
		_hud.show_banner("🏆 VITÓRIA! Todas as ondas superadas! +%d coins" % wave.wave_completion_reward)
	_update_wave_hud()


func _on_placement_failed(reason: String) -> void:
	if reason == "insufficient_coins":
		_hud.show_banner("Coins insuficientes!", 1.5)


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


## Permite colocar mais de um Velociraptor por partida — sem isto, o
## jogador só conseguiria posicionar exatamente 1 dinossauro (a pré-seleção
## automática do início), já que PlacementController nunca voltava sozinho
## para PLACING depois do primeiro placement. Não adiciona profundidade de
## jogo nova, só torna utilizável a capacidade que já existia (Phase 0.4/0.5
## permitiam isso via API; não havia jeito de acionar de novo pela UI).
func _on_dinosaur_button_pressed() -> void:
	if _placement_controller.state == PlacementController.State.IDLE \
			and _placement_controller.initial_definition != null:
		_placement_controller.select_dinosaur(_placement_controller.initial_definition)


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
