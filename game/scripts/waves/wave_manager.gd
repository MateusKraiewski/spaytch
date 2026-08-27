class_name WaveManager
extends Node
## Orquestra QUANDO e QUANTOS inimigos spawnar, com base em uma sequência de
## WaveDefinition — responsabilidade distinta de EnemySpawner (que só sabe
## criar UM inimigo por chamada e rastrear quem está vivo). Combinar as duas
## classes faria EnemySpawner acumular estado/timing de onda além de
## criação — candidato real a God Object. Mantidas separadas por
## composição: WaveManager USA EnemySpawner (spawn_enemy(),
## get_active_enemies()), não o substitui nem duplica sua lógica.
##
## Não permite iniciar duas waves simultaneamente (state machine mínima:
## IDLE / SPAWNING / WAITING_FOR_CLEAR). Não inicia a próxima wave
## automaticamente — quem decide isso é quem escuta `wave_completed`
## (Main.gd, via botão da HUD).
##
## `extends Node`: sem identidade espacial própria, mesmo raciocínio de
## EnemySpawner/PlacementController/Economy.
##
## step(delta) é lógica pura determinística, chamada por _process() em
## runtime e diretamente pelos testes (game/tests/wave_tests.gd) — mesmo
## padrão de BasicEnemy/Dinosaur/Projectile.

enum State { IDLE, SPAWNING, WAITING_FOR_CLEAR }

signal wave_started(wave_index: int, wave: WaveDefinition)
signal wave_completed(wave_index: int, wave: WaveDefinition)

@export var waves: Array[WaveDefinition] = []

var state: State = State.IDLE
var current_wave_index: int = -1  ## -1 = nenhuma wave iniciada ainda

var _enemy_spawner: EnemySpawner
var _economy: Economy
var _locked: bool = false  ## true após game over — impede spawn/wave novos
var _time_since_last_spawn: float = 0.0
var _spawned_count: int = 0


func setup(enemy_spawner: EnemySpawner, economy: Economy) -> void:
	_enemy_spawner = enemy_spawner
	_economy = economy
	_enemy_spawner.enemy_died.connect(_on_enemy_died)


func has_next_wave() -> bool:
	return current_wave_index + 1 < waves.size()


func is_wave_active() -> bool:
	return state != State.IDLE


## Trava permanentemente o WaveManager (chamado no game over, ver
## Main.gd) — nenhum spawn adicional acontece e nenhuma wave nova começa.
func lock() -> void:
	_locked = true


func start_next_wave() -> void:
	if _locked or is_wave_active() or not has_next_wave():
		return
	current_wave_index += 1
	state = State.SPAWNING
	_time_since_last_spawn = 0.0
	_spawned_count = 0
	wave_started.emit(current_wave_index, _current_wave())


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _locked or state == State.IDLE or _enemy_spawner == null:
		return

	var wave := _current_wave()

	if state == State.SPAWNING:
		_time_since_last_spawn += delta
		if _time_since_last_spawn >= wave.spawn_interval:
			_time_since_last_spawn = 0.0
			_enemy_spawner.spawn_enemy(wave.speed_override, wave.hp_override)
			_spawned_count += 1
			if _spawned_count >= wave.enemy_count:
				state = State.WAITING_FOR_CLEAR

	# Sem "elif": uma wave de 1 inimigo pode legitimamente já estar pronta
	# para completar no mesmo step() em que WAITING_FOR_CLEAR acabou de ser
	# setado (se por algum motivo o inimigo já não estivesse mais ativo —
	# não acontece na prática logo após spawnar, mas a checagem correndo
	# sempre que o estado permitir é mais simples que replicar a condição.
	if state == State.WAITING_FOR_CLEAR:
		if _enemy_spawner.get_active_enemies().is_empty():
			_complete_wave(wave)


func _complete_wave(wave: WaveDefinition) -> void:
	state = State.IDLE
	if _economy != null:
		_economy.add(wave.wave_completion_reward)
	wave_completed.emit(current_wave_index, wave)


func _current_wave() -> WaveDefinition:
	return waves[current_wave_index]


func _on_enemy_died(_enemy: BasicEnemy) -> void:
	if _economy == null or current_wave_index < 0 or current_wave_index >= waves.size():
		return
	_economy.add(_current_wave().reward_per_kill)
