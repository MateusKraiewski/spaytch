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
## (Main.gd, via botão da HUD/countdown automático — ver main.gd).
##
## V2 — `WaveDefinition.groups` (Array[WaveEnemyGroup]) substitui o antigo `enemy_count`/
## `spawn_interval` flat: SPAWNING agora percorre os grupos em ordem (`_current_group_index`/
## `_spawned_in_group`), só avançando pro próximo grupo quando o atual termina de spawnar, e só
## indo para WAITING_FOR_CLEAR quando o ÚLTIMO grupo terminar. WaveManager continua sem saber
## nada sobre QUAL tipo de inimigo está spawnando — só repassa `group.enemy_definition` pronto
## pra EnemySpawner.spawn_enemy(), a mesma relação de sempre com WaveDefinition.
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
var _current_group_index: int = 0  ## índice do grupo (WaveEnemyGroup) sendo spawnado agora
var _spawned_in_group: int = 0  ## quantos já foram spawnados do grupo atual


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
	_current_group_index = 0
	_spawned_in_group = 0
	if _current_wave().get_groups().is_empty():
		state = State.WAITING_FOR_CLEAR  # wave sem grupo nenhum (dado degenerado) — nada a spawnar
	wave_started.emit(current_wave_index, _current_wave())


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _locked or state == State.IDLE or _enemy_spawner == null:
		return

	var wave := _current_wave()
	var groups := wave.get_groups()

	if state == State.SPAWNING:
		_time_since_last_spawn += delta
		var group := groups[_current_group_index]
		if _time_since_last_spawn >= group.spawn_interval:
			_time_since_last_spawn = 0.0
			_enemy_spawner.spawn_enemy(group.enemy_definition)
			_spawned_in_group += 1
			if _spawned_in_group >= group.count:
				_current_group_index += 1
				_spawned_in_group = 0
				if _current_group_index >= groups.size():
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


func _on_enemy_died(enemy: BasicEnemy) -> void:
	if _economy == null or enemy.definition == null:
		return
	_economy.add(enemy.definition.reward_per_kill)
