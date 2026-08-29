class_name PlacementController
extends Node
## Máquina de estados simples de placement: IDLE ↔ PLACING.
##
## IDLE          — nenhum dinossauro selecionado, input de placement ignorado.
## PLACING       — um DinosaurDefinition está selecionado; hover (PC) atualiza
##                 preview; um clique/toque em célula válida coloca o
##                 dinossauro e volta para IDLE.
##
## Nesta fase não existe UI de seleção de dinossauro — `initial_definition`
## permite pré-selecionar o Velociraptor automaticamente ao iniciar (ver
## Main.gd), simulando "o jogador já escolheu". `select_dinosaur()` é o
## único ponto de entrada para trocar a seleção — genérico o suficiente para
## uma UI futura chamar com qualquer DinosaurDefinition, sem exigir nenhuma
## mudança nesta classe.
##
## Só valida/instancia/marca ocupação — nenhuma lógica de combate aqui
## (cooldown, targeting e disparo vivem em Dinosaur/Targeting/Projectile).
##
## `extends Node`, não Node2D: sem identidade espacial própria, mesmo
## raciocínio de InputManager/EnemySpawner.

enum State { IDLE, PLACING }

## Estado público, somente leitura por convenção — consumido por
## PlacementPreview para saber o que desenhar.
signal preview_changed()

## Phase 0.5 — motivo pelo qual um placement confirmado não aconteceu (hoje
## só "insufficient_coins"); célula inválida não emite isto, só retorna
## silenciosamente (ver on_pointer_pressed).
signal placement_failed(reason: String)

## Phase 0.6 — gancho de feedback (visual/áudio) para um placement bem
## sucedido; emitido depois que o dinossauro já existe e a célula já está
## marcada como ocupada.
signal dinosaur_placed(dinosaur: Dinosaur, coord: Vector2i)

var state: State = State.IDLE
var hovered_coord: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var selected_definition: DinosaurDefinition = null

## Sprint 1, Etapa 7 (fusão jogável) — coordenada do primeiro dinossauro selecionado para fundir,
## aguardando o segundo clique. `Vector2i(-1, -1)` = nenhuma seleção pendente (mesmo sentinel de
## `hovered_coord`). Público, somente leitura por convenção (mesmo espírito de `hovered_coord`) —
## uma futura UI de destaque visual pode consumir isto sem exigir nenhuma mudança nesta classe.
var fusion_pending_coord: Vector2i = Vector2i(-1, -1)

@export var dinosaur_scene: PackedScene
@export var initial_definition: DinosaurDefinition  ## pré-seleção automática (sem UI ainda)

const _AURA_EFFECT_SCENE := preload("res://scenes/effects/AuraEffect.tscn")

var _grid: Grid
var _enemy_spawner: EnemySpawner
var _dinosaurs_container: Node
var _projectiles_container: Node
var _economy: Economy


func setup(grid: Grid, enemy_spawner: EnemySpawner, dinosaurs_container: Node, projectiles_container: Node, economy: Economy) -> void:
	_grid = grid
	_enemy_spawner = enemy_spawner
	_dinosaurs_container = dinosaurs_container
	_projectiles_container = projectiles_container
	_economy = economy


func select_dinosaur(definition: DinosaurDefinition) -> void:
	selected_definition = definition
	state = State.PLACING
	hovered_coord = Vector2i(-1, -1)
	is_hover_valid = false
	preview_changed.emit()


func on_pointer_moved(world_pos: Vector2) -> void:
	if state != State.PLACING:
		return
	var coord := _grid.world_to_cell(world_pos)
	if coord == hovered_coord:
		return
	hovered_coord = coord
	is_hover_valid = is_valid_placement(coord)
	preview_changed.emit()


## Funciona igual para mouse click e touch tap (ambos chegam como
## pointer_pressed via InputManager) — placement não depende de hover para
## confirmar, só o pointer_pressed é necessário (requisito Android).
##
## Sprint 1, Etapa 7 (fusão jogável) — mesmo clique, dois comportamentos por estado: em PLACING,
## comportamento de sempre (inalterado, só extraído para _handle_placement_click). Fora de
## PLACING (IDLE — nada selecionado pra colocar), o clique vira seleção de fusão. Nenhum botão
## novo, nenhum modo novo na HUD: reaproveita o MESMO pointer_pressed que já chega aqui.
func on_pointer_pressed(world_pos: Vector2) -> void:
	if _grid == null:
		return
	var coord := _grid.world_to_cell(world_pos)
	if state == State.PLACING:
		_handle_placement_click(coord)
	else:
		_handle_fusion_click(_resolve_fusion_click_coord(world_pos, coord))


func _handle_placement_click(coord: Vector2i) -> void:
	if not is_valid_placement(coord):
		return
	if _economy != null and not _economy.can_afford(selected_definition.cost):
		print("[PlacementController] Coins insuficientes para %s (custo %d, disponível %d)." %
			[selected_definition.display_name, selected_definition.cost, _economy.coins])
		placement_failed.emit("insufficient_coins")
		return
	_place_dinosaur(coord)


## Correção do bug real confirmado por log de jogo real (Sprint 1): o sprite de um dinossauro
## pode ser bem maior que a célula 32x32 onde `occupant` está registrado (ex: Velociraptor
## T3 ~176px). Um clique visualmente "no dinossauro" caía fora da célula exata, resolvia pra uma
## célula vazia vizinha, e `_handle_fusion_click` cancelava a seleção silenciosamente — não é bug
## de `world_to_cell()` (já provado correto em toda a área da célula, ver
## fusion_tests.gd::_test_offset_click_position_resolves_to_correct_cell), é a célula exata sendo
## pequena demais pra área visual real.
##
## Resolve primeiro pela célula exata (cobre a maioria dos cliques, comportamento de sempre); só
## se ESSA célula estiver vazia, verifica se o clique caiu dentro da ÁREA VISUAL REAL de algum
## dinossauro já colocado (tamanho de verdade do frame atual do sprite dele — ver
## _visual_bounds_of()). Isto NÃO é busca cega em vizinhança: um dinossauro só é escolhido se o
## clique estiver genuinamente dentro do retângulo que o sprite DELE ocupa na tela: um clique fora
## de qualquer sprite continua resolvendo pra célula vazia normalmente (cancela a seleção, como
## sempre). Se por acaso dois sprites grandes se sobrepõem no ponto clicado, o de centro mais
## próximo do clique vence (ver _find_dinosaur_coord_by_visual_bounds()).
func _resolve_fusion_click_coord(world_pos: Vector2, grid_coord: Vector2i) -> Vector2i:
	if _grid.is_in_bounds(grid_coord) and _grid.get_cell(grid_coord).is_occupied():
		return grid_coord
	var by_sprite := _find_dinosaur_coord_by_visual_bounds(world_pos)
	if by_sprite != Vector2i(-1, -1):
		return by_sprite
	return grid_coord


## Varre os dinossauros já colocados e devolve a célula de quem tem `world_pos` genuinamente
## dentro do próprio retângulo visual (ver _visual_bounds_of()). `Vector2i(-1, -1)` se nenhum
## sprite contém o ponto — nunca "adivinha" um dinossauro vizinho.
func _find_dinosaur_coord_by_visual_bounds(world_pos: Vector2) -> Vector2i:
	if _dinosaurs_container == null or _grid == null:
		return Vector2i(-1, -1)
	var best_coord := Vector2i(-1, -1)
	var best_dist := INF
	for child in _dinosaurs_container.get_children():
		if not (child is Dinosaur):
			continue
		var dinosaur := child as Dinosaur
		var rect := _visual_bounds_of(dinosaur)
		if not rect.has_point(world_pos):
			continue
		var dist := dinosaur.global_position.distance_squared_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_coord = _grid.world_to_cell(dinosaur.global_position)
	return best_coord


## Retângulo visual REAL de um Dinosaur, em coordenadas de mundo — do tamanho de verdade do frame
## ATUAL do AnimatedSprite2D dele (`sprite.animation`/`sprite.frame`, o que estiver tocando nesse
## instante), não um tamanho fixo hardcoded. `AnimatedSprite2D` é `centered = true` (mesma
## convenção usada no projeto inteiro) — a posição do Dinosaur é o CENTRO do sprite, não o canto.
## `Rect2()` (vazio, `has_point()` sempre falso) se não houver textura válida — nunca finge um
## tamanho.
## `* sprite.global_scale` (Godot 4, calculado do transform global) — bug report do jogador levou a
## reduzir a escala de exibição dos dinossauros com arte (ver Dinosaur._DISPLAY_SCALE); sem
## multiplicar aqui, esta função voltaria a reportar o tamanho do TEXTURE cru (maior que o
## desenhado de verdade na tela), reabrindo exatamente o bug que esta função foi criada pra
## corrigir. O algoritmo em si (retângulo = tamanho real centrado na posição) não muda.
func _visual_bounds_of(dinosaur: Dinosaur) -> Rect2:
	var sprite := dinosaur.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return Rect2()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2()
	var size := Vector2(texture.get_size()) * sprite.global_scale
	return Rect2(dinosaur.global_position - size / 2.0, size)


## Primeiro clique numa célula ocupada marca `fusion_pending_coord`; segundo clique numa célula
## ocupada DIFERENTE chama try_fuse() (já existente, Etapa 5) — só decide QUANDO chamar, nunca
## reimplementa a regra de espécie/tier/aura (isso mora inteiramente em Fusion/try_fuse(), zero
## duplicação aqui). Clique numa célula vazia, fora dos limites, ou na MESMA célula já
## selecionada cancela a seleção pendente — dá pro jogador desistir sem precisar de um botão de
## "cancelar" dedicado. Se try_fuse() rejeitar (espécie/tier diferente, tier 3), nada acontece —
## o mesmo contrato "sem efeito colateral em caso de rejeição" que já valia para try_fuse().
##
## Correção de UX (não mudou a mecânica): `preview_changed` — sinal já existente, usado por
## PlacementPreview — agora também dispara aqui a cada mudança de `fusion_pending_coord`, pra a
## célula que o CLIQUE de verdade identificou (não um hover) ficar visualmente destacada
## enquanto pendente, e sumir ao cancelar/concluir/rejeitar. Nenhuma chamada nova a try_fuse()
## nem a Fusion — só o gancho de UI que já existia sendo emitido nos pontos certos.
func _handle_fusion_click(coord: Vector2i) -> void:
	if not _grid.is_in_bounds(coord) or not _grid.get_cell(coord).is_occupied():
		fusion_pending_coord = Vector2i(-1, -1)
		preview_changed.emit()
		return
	if fusion_pending_coord == Vector2i(-1, -1):
		fusion_pending_coord = coord
		preview_changed.emit()
		return
	if fusion_pending_coord == coord:
		fusion_pending_coord = Vector2i(-1, -1)
		preview_changed.emit()
		return
	var first := fusion_pending_coord
	fusion_pending_coord = Vector2i(-1, -1)
	preview_changed.emit()
	try_fuse(first, coord)


## Público (não só uso interno) porque é uma consulta legítima e sem efeito
## colateral sobre o estado do mundo — mesmo espírito de Grid.is_in_bounds()/
## Cell.is_buildable(). Célula válida somente se BUILDABLE e livre; PATH,
## SPAWN, NEST, EGG e OBSTACLE já são excluídos por is_buildable().
func is_valid_placement(coord: Vector2i) -> bool:
	if _grid == null or not _grid.is_in_bounds(coord):
		return false
	var cell := _grid.get_cell(coord)
	return cell.is_buildable() and not cell.is_occupied()


## Consulta pura para a UI (Phase 0.6 — feedback de coins insuficientes
## durante o hover, antes mesmo do jogador tentar confirmar). Mesmo espírito
## de is_valid_placement(): sem efeito colateral, só leitura.
func can_afford_selected() -> bool:
	if _economy == null or selected_definition == null:
		return true
	return _economy.can_afford(selected_definition.cost)


func _place_dinosaur(coord: Vector2i) -> void:
	if _economy != null:
		_economy.spend(selected_definition.cost)

	var dinosaur := _instantiate_dinosaur(selected_definition, coord)
	_grid.get_cell(coord).occupant = dinosaur

	state = State.IDLE
	selected_definition = null
	hovered_coord = Vector2i(-1, -1)
	is_hover_valid = false
	preview_changed.emit()
	dinosaur_placed.emit(dinosaur, coord)


## Sprint 1, Etapa 6 (aura T3) — único ponto de instanciação de Dinosaur, usado tanto pelo
## placement normal quanto pela fusão (try_fuse() abaixo): decidir aqui garante que um T3 ganha
## aura pelos DOIS caminhos, sem duplicar a checagem. `AuraEffect` entra como FILHO do Dinosaur
## (não irmão, diferente de DeathEffect/SpawnEffect — aqui a diferença é proposital: aura é uma
## companheira PERSISTENTE, não um burst de um instante, então precisa ser removida junto do
## Dinosaur automaticamente quando ele for removido; um filho é liberado sozinho pela árvore de
## cena, um irmão exigiria código extra de limpeza). Também herda a posição do Dinosaur de graça
## (Node2D filho segue o pai), sem precisar copiar `global_position` manualmente. `z_index = -1`
## já vem definido em AuraEffect.tscn — relativo aos outros filhos do Dinosaur, garante que a
## aura desenha atrás do próprio sprite da criatura.
##
## Sem guarda de `is_inside_tree()` — bug real encontrado por dinosaur_aura_tests.gd: a 1ª versão
## copiava o raciocínio de EnemySpawner.spawn_enemy() (só cria o efeito se já estiver numa
## SceneTree real), mas `root.is_inside_tree()` é `false` mesmo dentro de um script
## `extends SceneTree` rodado headless — a checagem nunca passava, a aura nunca era anexada em
## nenhum teste. `Dinosaur` em si já é instanciado incondicionalmente (sem essa guarda) em
## `_place_dinosaur()`; `AuraEffect._ready()` já lida com segurança o caso de nunca entrar numa
## árvore de verdade (mesmo padrão de AnimatedVisual.play_state(), que já checa isso sozinho).
func _instantiate_dinosaur(definition: DinosaurDefinition, coord: Vector2i) -> Dinosaur:
	var dinosaur := dinosaur_scene.instantiate() as Dinosaur
	_dinosaurs_container.add_child(dinosaur)
	dinosaur.setup(definition, _enemy_spawner, _projectiles_container)
	dinosaur.global_position = _grid.cell_center_world(coord)
	if definition.has_aura():
		dinosaur.add_child(_AURA_EFFECT_SCENE.instantiate())
	return dinosaur


## Sprint 1, Etapa 5 (fusão) — funde os dinossauros que já ocupam `coord_a` e `coord_b` (mesma
## espécie + mesmo tier + tier < 3, ver Fusion.can_fuse()). O resultado aparece em `coord_a`
## (célula "onde a fusão aconteceu"); `coord_b` fica livre. Retorna o novo Dinosaur, ou `null`
## sem nenhum efeito colateral se a fusão não for permitida — chamador não precisa checar
## Fusion.can_fuse() antes, só tratar `null`.
##
## Deliberadamente sem custo em coins nem gancho de feedback visual ainda — balanceamento e
## efeito de "evolução" são decisões de uma etapa futura. Chamado hoje por
## _handle_fusion_click() (Etapa 7 — clicar em 2 dinossauros já colocados), mas continua
## utilizável diretamente (testável sem passar por input nenhum, ver fusion_tests.gd).
func try_fuse(coord_a: Vector2i, coord_b: Vector2i) -> Dinosaur:
	if _grid == null:
		return null
	var cell_a := _grid.get_cell(coord_a)
	var cell_b := _grid.get_cell(coord_b)
	if cell_a == null or cell_b == null:
		return null
	var dino_a := cell_a.occupant
	var dino_b := cell_b.occupant
	if dino_a == null or dino_b == null:
		return null

	var result_definition := Fusion.resulting_definition(dino_a.definition, dino_b.definition)
	if result_definition == null:
		return null

	dino_a.queue_free()
	dino_b.queue_free()
	cell_b.occupant = null

	var evolved := _instantiate_dinosaur(result_definition, coord_a)
	cell_a.occupant = evolved
	return evolved
