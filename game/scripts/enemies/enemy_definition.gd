class_name EnemyDefinition
extends Resource
## V2 — dado estático e autoral de um TIPO de inimigo (mesmo padrão de `DinosaurDefinition`):
## `BasicEnemy` continua sendo a única cena/script genérico que qualquer tipo consome (nenhuma
## subclasse por arquétipo), a diferenciação vem inteiramente daqui.
##
## Os 6 arquétipos da V2 (ver `data/enemies/*.tres`) são funcionalmente distintos, não só HP
## diferente:
## - Básico: referência neutra, sem pressão específica.
## - Rápido: HP baixo, velocidade alta — exige dinossauros de ataque rápido (Velociraptor);
##   um dinossauro de cooldown longo deixa passar.
## - Tanque: HP muito alto, lento, dano alto ao ninho se atravessar — exige DPS total sustentado.
## - Enxame: HP muito baixo, spawna em GRANDE quantidade (`WaveEnemyGroup.count` alto, intervalo
##   curto) — pressão de volume/DPS-por-segundo, não de HP individual.
## - Blindado: `armor` reduz cada hit — ataques fracos/rápidos (Velociraptor T1) ficam ineficientes,
##   força dano por hit mais alto (Triceratops/T-Rex, ou tiers evoluídos).
## - Elite: HP alto E velocidade acima da média ao mesmo tempo — pressão em duas frentes
##   simultâneas (nem só "aguentar dano" nem só "reagir rápido" resolve sozinho).
##
## `armor` é a única mecânica nova introduzida (ver `BasicEnemy.take_damage()`) — deliberadamente
## não foi criada uma aura de suporte/buff entre inimigos: exigiria um novo laço de atualização
## cruzando todos os inimigos ativos a cada frame (acoplamento que `BasicEnemy` hoje não tem com
## `EnemySpawner`/outros inimigos), custo arquitetural real para um 6º arquétipo quando a
## combinação de stats já basta pra criar 6 funções distintas.

@export var display_name: String = "Inimigo"
@export var speed: float = 60.0  ## px/s
@export var max_hp: int = 20
@export var egg_damage: int = 10  ## dano causado a um ovo ao alcançar o ninho
@export var reward_per_kill: int = 5  ## coins ao morrer — por TIPO agora, não por wave (permite waves mistas)

## Redução plana de dano por hit. 0 = sem armadura (todo o roster antigo/Básico). `BasicEnemy.
## take_damage()` nunca deixa passar menos que 1 de dano efetivo, mesmo contra armor alto — evita
## invulnerabilidade total contra qualquer atacante.
@export var armor: int = 0

## `null` = usa a arte procedural já hardcoded em BasicEnemy.tscn (comportamento de sempre) —
## mesmo contrato de `DinosaurDefinition.sprite_frames`.
@export var sprite_frames: SpriteFrames
@export var placeholder_color: Color = Color.WHITE
