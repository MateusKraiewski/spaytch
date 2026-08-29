class_name AnimatedVisual
extends Node2D
## Camada de apresentação desacoplada do gameplay. Todo entity visual
## (Dinosaur, BasicEnemy, Egg, Projectile) tem um node `Visual` filho com
## este script — gameplay NUNCA manipula Tween/Polygon2D/AnimatedSprite2D
## diretamente, só chama `play_state(state)` com um dos 5 estados padrão
## (IDLE/MOVE/ATTACK/HIT/DEATH). Regra do projeto: nenhuma entidade fica
## visualmente estática como solução definitiva — mesmo sem arte final, todo
## estado produz alguma reação visível.
##
## COMO É REALIZADO HOJE (sem pixel art final): primeiro tenta uma animação
## de mesmo nome (`"idle"`/`"move"`/`"attack"`/`"hit"`/`"death"`) num
## `AnimatedSprite2D` filho, se existir e tiver essa animação em
## `sprite_frames`. Sem isso, cai num fallback **procedural** — `Tween`
## simples sobre `rotation`/`scale`/`modulate` do próprio node — usando só a
## engine, sem precisar de nenhum asset. Isso é a "camada equivalente
## adequada" ao `AnimatedSprite2D` pedida para esta fase: no dia em que
## houver arte final, basta adicionar um `AnimatedSprite2D` com
## `SpriteFrames` contendo animações chamadas "idle"/"move"/etc. como filho
## de `Visual` — o fallback procedural para de ser usado automaticamente
## (porque a checagem `sprite_frames.has_animation(name)` passa a ser
## verdadeira), sem mudar UMA linha de código de gameplay.
##
## Duas "trilhas" de Tween independentes evitam que animações concorrentes
## brigem pela mesma propriedade: IDLE/MOVE (`_loop_tween`, looping,
## `rotation`) e ATTACK/HIT/DEATH (`_reaction_tween`, um tiro só, `scale`/
## `modulate`). Cada uma só mexe nas suas próprias propriedades, então as
## duas podem tocar ao mesmo tempo sem produzir jitter.
##
## `is_inside_tree()` guarda toda reação: `create_tween()` exige uma
## `SceneTree` válida, e várias suítes de teste (dinosaur_tests.gd,
## enemy_tests.gd, egg_tests.gd) instanciam entidades via `.new()` sem
## `add_child()`, sem nenhum `Visual` sequer existindo nesses casos — o
## chamador já checa `if _visual != null` antes de usar isto (ver
## BasicEnemy/Dinosaur/Egg/Projectile).
##
## Quando existe arte (Primeiro Protótipo Visual): ATTACK/HIT são animações
## de UM tiro só no `AnimatedSprite2D` (`loop = false` no `SpriteFrames`) —
## diferente do fallback procedural (onde IDLE/MOVE continuam rodando por
## baixo, em trilha de Tween separada), aqui é uma única animação por vez.
## Por isso `_on_sprite_reaction_finished()` volta sozinho para
## `last_loop_state` ao final de uma reação — sem isso o sprite ficaria
## congelado no último frame do ataque/hit para sempre.

enum State { IDLE, MOVE, ATTACK, HIT, DEATH }

const _STATE_NAMES := {
	State.IDLE: "idle",
	State.MOVE: "move",
	State.ATTACK: "attack",
	State.HIT: "hit",
	State.DEATH: "death",
}

## Cor de "repouso" para onde HIT sempre relaxa de volta — Egg a atualiza a
## cada mudança de HP (tingimento permanente por fração de vida); as demais
## entidades deixam no branco padrão.
var base_modulate: Color = Color.WHITE

## Último estado pedido via play_state() (qualquer um dos 5) e último
## especificamente da trilha de loop (só IDLE/MOVE) — introspecção pura
## para testes (mesmo espírito de Dinosaur.current_target()); nada além
## disso lê estes campos, e eles não influenciam nenhuma decisão de
## gameplay. Separados porque uma entidade comum chama IDLE/MOVE e depois
## HIT no mesmo instante (ex: Egg — loop de vida + flash de dano) —
## `last_state` sozinho não bastaria para inspecionar qual variante de loop
## está tocando.
var last_state: State = State.IDLE
var last_loop_state: State = State.IDLE

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var _loop_tween: Tween = null
var _reaction_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE
var _base_position: Vector2 = Vector2.ZERO
var _has_spawned: bool = false


func _ready() -> void:
	_base_scale = scale
	_base_position = position
	modulate = base_modulate


## Define a cor de repouso E aplica imediatamente a `modulate` — só setar
## `base_modulate` não muda o que está na tela até a próxima reação (HIT);
## para tingimento permanente (ex: cor do dinossauro, tom de HP do ovo) o
## efeito precisa ser visível na hora.
func set_base_modulate(color: Color) -> void:
	base_modulate = color
	modulate = color


## Bug report do jogador (sobreposição visual de dinossauros vizinhos) — reduz o tamanho de
## exibição. Atualiza `_base_scale` (não só `scale`) porque toda reação (ATTACK/HIT/DEATH/
## spawn-pop, ver _play_reaction()/_spawn_pop_if_first()) sempre tween de volta pra `_base_scale`
## ao final — se só `scale` fosse setado aqui, a 1ª reação depois disso desfaria a redução assim
## que `_base_scale` capturasse `Vector2.ONE` em _ready(). Seguro chamar antes OU depois de
## _ready() desta classe (mesmo espírito de set_sprite_frames()/set_base_modulate(), chamados por
## Dinosaur.setup() logo após add_child() — quando o `Visual` filho, por já ter sido adicionado
## primeiro, JÁ teve seu próprio _ready() executado nesse ponto).
func set_display_scale(factor: float) -> void:
	_base_scale = Vector2(factor, factor)
	scale = _base_scale


## Sprint 1 (integração visual) — troca o SpriteFrames do AnimatedSprite2D em runtime.
## Dinosaur.setup() chama isto com DinosaurDefinition.sprite_frames (Etapa 2) para aplicar a arte
## PixelLab aprovada da espécie/tier certa, sem duplicar nenhuma lógica por espécie aqui — só
## troca o recurso, quem decide QUAL é o chamador (dado, não código).
##
## Usa get_node_or_null() (não o campo `_sprite` cacheado via @onready) pelo mesmo motivo já
## documentado em DeathEffect.set_death_sprite_frames(): isto é chamado por Dinosaur.setup(),
## que roda logo após add_child() — ANTES do `_ready()` desta própria classe, então `_sprite`
## ainda não foi resolvido nesse momento. get_node_or_null() navega a estrutura da cena já
## instanciada, funciona independente de `_ready()` já ter rodado. Sem efeito se não houver
## AnimatedSprite2D (fallback procedural continua funcionando do mesmo jeito) ou se `frames` for
## null (mantém a arte já configurada na cena — é assim que o Velociraptor procedural antigo,
## cujo DinosaurDefinition.sprite_frames é sempre null, continua com a arte hardcoded de sempre).
func set_sprite_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.sprite_frames = frames


## Também para a trilha de loop (IDLE/MOVE) — usado quando uma entidade
## precisa silenciar a animação de repouso sem tocar nenhuma reação (ex:
## Egg quando destruído: fica estático, cinza, sem pulso de "vivo").
func stop_loop() -> void:
	if _loop_tween != null and _loop_tween.is_valid():
		_loop_tween.kill()
	rotation = 0.0


func play_state(state: State) -> void:
	last_state = state
	if not is_inside_tree():
		return

	var anim_name: String = _STATE_NAMES[state]
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim_name):
		_play_sprite(state, anim_name)
		return

	match state:
		State.IDLE, State.MOVE:
			_play_loop(state)
		State.ATTACK, State.HIT, State.DEATH:
			_play_reaction(state)


## Caminho de arte final: delega a animação para o AnimatedSprite2D em vez do fallback
## procedural. IDLE/MOVE tocam em loop natural do próprio SpriteFrames (configurado como
## `loop = true` no `.tres`) e não precisam de mais nada. ATTACK/HIT são configurados como
## `loop = false` — tocam uma vez e, sem isto, ficariam congelados no último frame para sempre
## (diferente do fallback procedural, onde IDLE/MOVE continuam rodando por baixo da reação em
## trilhas de Tween independentes — aqui é UMA única animação por vez, não trilhas separadas).
## Por isso: ao terminar uma animação de reação, volta sozinho para `last_loop_state`.
func _play_sprite(state: State, anim_name: String) -> void:
	if _sprite.animation_finished.is_connected(_on_sprite_reaction_finished):
		_sprite.animation_finished.disconnect(_on_sprite_reaction_finished)

	match state:
		State.IDLE, State.MOVE:
			last_loop_state = state
			_sprite.play(anim_name)
		State.ATTACK, State.HIT:
			_sprite.play(anim_name)
			_sprite.animation_finished.connect(_on_sprite_reaction_finished, CONNECT_ONE_SHOT)
		State.DEATH:
			_sprite.play(anim_name)


func _on_sprite_reaction_finished() -> void:
	play_state(last_loop_state)


func _play_loop(state: State) -> void:
	last_loop_state = state
	_spawn_pop_if_first()

	if _loop_tween != null and _loop_tween.is_valid():
		_loop_tween.kill()

	# MOVE balança mais rápido/perceptível que IDLE ("andando" vs "parado") —
	# só `rotation`, nunca `scale`/`modulate` (trilha da reação).
	var amount := 0.03 if state == State.IDLE else 0.09
	var half_duration := 0.7 if state == State.IDLE else 0.13

	_loop_tween = create_tween().set_loops()
	_loop_tween.tween_property(self, "rotation", amount, half_duration).set_trans(Tween.TRANS_SINE)
	_loop_tween.tween_property(self, "rotation", -amount, half_duration * 2.0).set_trans(Tween.TRANS_SINE)
	_loop_tween.tween_property(self, "rotation", 0.0, half_duration)


func _play_reaction(state: State) -> void:
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	scale = _base_scale
	position = _base_position

	match state:
		State.ATTACK:
			# Pulso de escala + um pequeno "recoil" (recuo) no eixo local -X —
			# aproximação simples, não mira de verdade no alvo (AnimatedVisual
			# não conhece gameplay/alvo, só reage ao próprio estado); efeito
			# puramente estilístico de "empurrão do disparo".
			scale = _base_scale * 1.2
			position = _base_position + Vector2(-4, 0)
			_reaction_tween = create_tween()
			_reaction_tween.set_parallel(true)
			_reaction_tween.tween_property(self, "scale", _base_scale, 0.14)
			_reaction_tween.tween_property(self, "position", _base_position, 0.14).set_trans(Tween.TRANS_SINE)
		State.HIT:
			# Flash de cor + um "squash" curto (achata e alarga) — mais
			# perceptível que só mudar `modulate`, sem sair do orçamento de
			# efeito barato para mobile (um Tween paralelo curto).
			modulate = Color(2.0, 2.0, 2.0, base_modulate.a)
			scale = _base_scale * Vector2(1.25, 0.75)
			_reaction_tween = create_tween()
			_reaction_tween.set_parallel(true)
			_reaction_tween.tween_property(self, "modulate", base_modulate, 0.15)
			_reaction_tween.tween_property(self, "scale", _base_scale, 0.15).set_trans(Tween.TRANS_BACK)
		State.DEATH:
			_reaction_tween = create_tween()
			_reaction_tween.set_parallel(true)
			_reaction_tween.tween_property(self, "scale", _base_scale * 1.6, 0.3).set_trans(Tween.TRANS_CUBIC)
			_reaction_tween.tween_property(self, "modulate:a", 0.0, 0.3)


## "Feedback de spawn": a primeira vez que qualquer estado de loop toca
## (IDLE ou MOVE), a entidade nasce pequena e cresce até o tamanho normal,
## em vez de simplesmente aparecer estática. Usa a trilha de reação (mesma
## propriedade `scale` de ATTACK/DEATH) — loop nunca toca `scale`, então não
## há conflito mesmo que um HIT chegue durante o pop-in.
func _spawn_pop_if_first() -> void:
	if _has_spawned:
		return
	_has_spawned = true
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	scale = _base_scale * 0.3
	_reaction_tween = create_tween()
	_reaction_tween.tween_property(self, "scale", _base_scale, 0.15).set_trans(Tween.TRANS_BACK)
