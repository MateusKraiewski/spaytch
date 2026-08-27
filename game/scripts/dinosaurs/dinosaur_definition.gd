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
