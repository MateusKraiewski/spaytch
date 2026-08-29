class_name DinosaurDefinition
extends Resource
## Definição estática e autoral de um dinossauro defensor (dado, não
## comportamento) — mesmo padrão de MapDefinition. Um único `Dinosaur.tscn` +
## `dinosaur.gd` genérico consome qualquer instância deste Resource; novos
## dinossauros (Triceratops.tres, T-Rex.tres, ...) não exigem cena nem
## classe novas — só um novo `.tres` — enquanto não precisarem de
## comportamento realmente especial.
##
## Deliberadamente sem: upgrades, habilidade especial, ícone de UI. Nenhum
## sistema existe ainda para consumir esses campos; adicioná-los agora seria
## especulativo. `cost` foi adicionado na Phase 0.5 junto com a economia —
## antes disso não fazia sentido existir sem nada para consumi-lo.

@export var display_name: String = ""
@export var range: float = 100.0  ## px, distância no mundo (requisito 8)
@export var attack_interval: float = 1.0  ## s, cooldown entre disparos — TBD/placeholder balance
@export var damage: int = 1  ## por acerto — TBD/placeholder balance
@export var projectile_speed: float = 200.0  ## px/s
@export var projectile_scene: PackedScene
@export var placeholder_color: Color = Color.WHITE  ## reservado para uso futuro; ver Dinosaur.tscn
@export var cost: int = 10  ## coins — TBD/placeholder balance

## Sprint 1 (sistema de espécie/tier) — vazio (`&""`) = espécie legada (Velociraptor procedural
## das Checkpoints A-F, cuja arte continua fixa em Dinosaur.tscn, sem passar por este campo).
## Um `.tres` novo (Sprint 1) preenche com um id estável e minúsculo ("velociraptor",
## "triceratops", "trex") — é o que a futura regra de fusão vai comparar (mesma espécie + mesmo
## tier), não `display_name` (que é texto de UI, pode mudar por localização).
@export var species_id: StringName = &""

## 1 = forma base, 2 = evoluída, 3 = máxima (com aura). Default 1 mantém qualquer `.tres`
## existente (como velociraptor.tres, que não tem tier definido) válido sem precisar editá-lo.
@export_range(1, 3, 1) var tier: int = 1

## Arte desta tier específica (Sprint 1). `null` = usa a arte fixa já hardcoded em
## Dinosaur.tscn (comportamento de sempre, Velociraptor procedural). Nenhum sistema ainda lê este
## campo — a integração visual (Dinosaur.gd escolher isto sobre o AnimatedSprite2D) é uma etapa
## futura; por enquanto isto só é o dado que os `.tres` da Sprint 1 já carregam pronto.
@export var sprite_frames: SpriteFrames

## Sprint 1, Etapa 6 (aura) — regra pura, sem qualquer conhecimento de Node/Scene/AuraEffect:
## só T3 tem aura própria. Método (não campo direto) pelo mesmo motivo de
## `Cell.is_occupied()`/`is_buildable()` — a REGRA fica num único lugar testável isoladamente
## (`dinosaur_definition_tests.gd`), sem precisar de árvore de cena; quem decide COMO mostrar a
## aura (instanciar AuraEffect) é PlacementController, que só chama isto.
func has_aura() -> bool:
	return tier == 3


## Sprint 1, Etapa 5 (fusão) — aponta direto para o `.tres` do próximo tier da MESMA espécie
## (T1→T2, T2→T3). `null` = não evolui (tier 3, ou qualquer tier sem próximo definido ainda,
## como Triceratops/T-Rex T2/T3 — arte não gerada, ver Etapas 1-2). `Fusion` (fusion.gd) só lê
## este campo — nenhuma espécie é hardcoded na regra de fusão, uma espécie nova só precisa
## preencher isto no próprio `.tres` para participar.
@export var evolves_to: DinosaurDefinition
