# ART DIRECTION — SPAYTCH

Documento vivo com a direção visual do jogo. Valores técnicos marcados como **TBD** ainda não
foram decididos — não assuma nem invente números definitivos antes de decisão explícita.

---

## Direção Provisória (Identidade)

Pixel art colorida, com dinossauros carismáticos, em um mundo visualmente atraente para
crianças, mas com acabamento sofisticado o suficiente para também agradar jogadores adultos.

O objetivo é combinar pixel art com **VFX modernos** para manter o jogo visualmente vivo sem
perder a identidade pixel art:

- partículas;
- impactos;
- flashes;
- pequenos efeitos de iluminação;
- screen shake quando apropriado;
- efeitos de habilidades.

Esta é uma diretriz de tom e identidade — valores técnicos concretos (resolução, paleta, tile
size etc.) permanecem TBD nas seções abaixo e devem ser definidos separadamente, respeitando o
orçamento de performance mobile (ver skill `mobile-performance`).

## Pixel Art

**Decidido (Primeiro Protótipo Visual):** pixel art estilo **16-bit nostálgico** (referência de
*sensação*, não de cópia — ver [Direção Provisória](#direção-provisória-identidade)), clean/
hard-edge (sem dithering) — bordas sólidas, sem gradientes de ruído. Identidade original do
SPAYTCH: nenhuma silhueta, paleta, proporção ou composição de outro jogo é reaproduzida.

- **Contorno:** 1px, cor escura derivada do próprio tom do elemento (não preto puro universal) —
  separa a silhueta do fundo sem parecer um adesivo genérico.
- **Sombras:** sombra de contato simples (elipse escura semitransparente sob a base), não sombra
  projetada direcional — mais barato e mais legível num tabuleiro visto de cima/¾.
- **Iluminação:** *flat shading* com no máximo 2 tons por elemento (base + sombra/highlight), sem
  gradiente suave — reforça a identidade 16-bit e é o mais barato para mobile.
- **Nível de detalhe:** silhueta lê à distância de jogo (tile 32px) sem precisar de zoom — detalhe
  interno mínimo, forma é o que carrega a leitura.

## Resolução Interna

**Decidido (Phase 0.1, confirmado aqui):** 640×384px (`project.godot`,
`window/size/viewport_width`/`height`), `stretch/mode="viewport"`. Proporção 5:3, landscape.

## Tamanho de Tiles

**Decidido (Phase 0.1, confirmado aqui):** 32×32px (`MapDefinition.tile_size`, único valor usado
em todo o jogo — grid, torres, inimigos, projéteis). Todo sprite novo (ambiente ou personagem)
usa canvas de 32×32px por frame, alinhado exatamente à célula da grid — nenhuma escala adicional
é aplicada em runtime além da que a própria cena já usa hoje.

## Escala

**Decidido:** escala 1:1 entre pixel de asset e pixel de canvas interno (640×384) — sem
reamostragem. `textures/canvas_textures/default_texture_filter` já é `Nearest` (`project.godot`,
confirmado nesta auditoria) — todo import de textura nova deve manter esse filtro. Escalonamento
inteiro da JANELA (viewport→tela do dispositivo) continua **TBD** (ver skill `pixel-art`) — não é
bloqueante para esta etapa.

## Câmera

*TBD — comportamento de câmera (fixa vs. com pan/zoom), limites do mapa, adaptação a diferentes
aspect ratios (importante para variedade de telas Android).*

## Sprites

**Decidido:** canvas 32×32px por frame, formato PNG (transparência real, sem matte color),
orientação ¾/perfil simples (mesma convenção já usada pelos placeholders geométricos — "nariz"
apontando para +X local antes de qualquer rotação de gameplay). Organização em disco (ver também
[ARCHITECTURE.md](ARCHITECTURE.md) para o pipeline técnico completo):

```
game/assets/environment/
├── grass_01.png … grass_04.png       # tile de chão 32×32, 4 variações (mesma linguagem visual)
├── path_01.png … path_03.png         # idem, trilha — 3 variações (base/pedregosa/com raízes)
├── path_edge_n/s/e/w.png             # tiras de transição grama↔trilha, uma por direção
├── bush_small/large.png, tree_small/large.png, rock_small/large.png, rock_cluster.png, stump.png
│                                       # decoração — só em células OBSTACLE, nunca BUILDABLE
└── flower_yellow/pink.png, mushroom.png, leaf.png, twig.png, root_detail.png, grass_tuft.png
                                        # detalhes pequenos — assets prontos, uso futuro além do
                                        # que já está embutido nas variantes de grass_0x

game/assets/
├── dinosaurs/
│   └── <nome>/     # um subdiretório por dinossauro — frames soltos, um PNG por frame
├── enemies/
│   └── <nome>/     # idem, por tipo de inimigo
├── eggs/           # Checkpoint D — idle_0-3/move_0-3/hit_0-2/death_0-4 (16 frames, 32×32)
├── projectiles/     # Checkpoint D — idle_0-3 (4 frames, 20×16 — único estado usado)
├── effects/        # Checkpoint D+E — impact_0-3 (DeathEffect) e spawn_0-3 (SpawnEffect);
│                   # DamageNumber continua procedural
└── ui/             # reservado — HUD/MainMenu continuam Label/Button padrão do Godot
```

Cada personagem/inimigo com sprite próprio tem um `SpriteFrames` (`.tres`) em
`game/data/<categoria>/<nome>_sprite_frames.tres`, com animações nomeadas exatamente como os
estados de `AnimatedVisual.State` (minúsculo: `"idle"`, `"move"`, `"attack"`, `"hit"`,
`"death"`) — ver seção [Animações](#animações) abaixo. Pastas "reservadas" acima **não têm**
conteúdo ainda; existem só para deixar a estrutura de destino óbvia quando a arte chegar.

## Animações

**Decidido (Phase 0.6):** nenhuma entidade do jogo (dinossauro, inimigo, ovo, projétil) fica
visualmente estática como solução definitiva — toda entidade visual tem 5 estados de animação
padronizados: **IDLE, MOVE, ATTACK, HIT, DEATH**. A superfície que gameplay usa é
`AnimatedVisual.play_state(state)` (`scripts/visuals/animated_visual.gd`), que nunca expõe COMO a
animação é realizada por baixo — ver [ARCHITECTURE.md](ARCHITECTURE.md#animatedvisual-e-deatheffect-phase-06)
para o detalhamento técnico completo.

Convenção de nomenclatura fixada para quando a arte final chegar: um `AnimatedSprite2D` filho do
node `Visual` de cada entidade, com um `SpriteFrames` contendo animações nomeadas exatamente
`"idle"`, `"move"`, `"attack"`, `"hit"`, `"death"` (minúsculas). Assim que essas animações
existirem, elas substituem automaticamente o fallback procedural atual (`Tween` sobre
`rotation`/`scale`/`modulate`, usado hoje por não haver pixel art final) — nenhuma linha de código
de gameplay precisa mudar.

**Regras de animação (Primeiro Protótipo Visual):**

- Mínimo **2 frames** por estado ativo (`MOVE`/`ATTACK`/`HIT`/`DEATH`) — nunca um frame só
  fingindo animação por cima de um `Tween` de escala. Mudança de pose real: corpo, cabeça, cauda
  ou pernas, não só recolorir o mesmo desenho.
- `IDLE` pode ser sutil (respiração/balanço), mas ainda assim 2 frames — consistente com a regra
  geral do projeto de "nenhuma entidade estática" (ver `ARCHITECTURE.md`, Phase 0.6).
- Animações de reação (`ATTACK`/`HIT`) **não fazem loop** — tocam uma vez e a entidade volta
  sozinha ao loop anterior (`IDLE`/`MOVE`); isso é responsabilidade de `AnimatedVisual`, não de
  cada script de entidade (ver `ARCHITECTURE.md`, seção do reforço desta etapa).
- Nada de animação exagerada — tower defense precisa continuar legível com várias unidades na
  tela ao mesmo tempo; poses de 2–3 frames bastam, sem interpolação suave entre elas.

*Ainda TBD: frame rate final de animação para a arte definitiva (o protótipo usa um intervalo
fixo por frame, ver `SpriteFrames`), se `AnimationPlayer` faz mais sentido para algum caso
específico (ex: animações compostas com mais de um sprite).*

## Paleta

**Decidido (Primeiro Protótipo Visual):** paleta por elemento, não uma paleta global única ainda
— cada asset usa 4–6 cores (base, sombra, highlight, contorno, +1–2 de detalhe). Regra de
identidade: tons **terrosos/naturais** para cenário (verdes de grama, marrons de terra/trilha,
cinzas de pedra) — saturação e contraste **mais baixos** que os elementos de gameplay, de
propósito (ver [Contraste Gameplay/Decorativo](#contraste-gameplaydecorativo) abaixo). Cores dos
dinossauros continuam as já estabelecidas desde a Phase 0.4 (Velociraptor: laranja `#F28D26`;
BasicEnemy: vermelho-terroso `#F35A1A`) — o protótipo visual não muda a identidade cromática já
aprovada, só a converte de silhueta geométrica para pixel art de verdade.

**Decidido (Checkpoint D):** Ovo em creme/palha (`#E2D2A2` base) com pintas — tom natural,
temático pré-histórico, nunca branco genérico; vermelho-terroso só aparece nas marcas de
"ferido"/rachaduras, nunca como cor dominante. Projétil reaproveita a paleta do Velociraptor (é o
que a torre dispara — coerência visual entre quem atira e o que é disparado), não uma cor nova.

*TBD: paleta global consolidada (hex fixos por categoria), variação por bioma/mapa futuro.*

## Iluminação

**Decidido:** sem iluminação dinâmica (`Light2D`/shaders) nesta etapa — *flat shading* pintado
direto no sprite (ver [Pixel Art](#pixel-art) acima). Custo zero em runtime, consistente com o
orçamento de performance mobile (skill `mobile-performance`). Reavaliar só se uma direção de arte
futura exigir de verdade.

## Contraste Gameplay/Decorativo

**Decidido:** elementos que carregam informação de jogo (trilha, área construível, ovos, ninho,
dinossauros, inimigos, projéteis) têm saturação/contraste **mais altos** que elementos puramente
decorativos (grama, arbustos, árvores, pedras de obstáculo). Vegetação nunca compete visualmente
com o que o jogador precisa ler para jogar — ver regras específicas abaixo.

### Regras para vegetação

- Puramente decorativa — nunca é a única pista de que uma célula é `OBSTACLE`/`BUILDABLE` (a cor
  de base do tile continua sendo essa pista).
- Usada com moderação: árvore/pedra/arbusto aparecem só em células `OBSTACLE` (reforça "não dá
  pra construir aqui"); células `BUILDABLE` ficam com o tile de grama limpo, sem objetos grandes
  por cima, para continuar claramente identificável como construível.
- Nunca ultrapassa os limites da própria célula (32×32px) — evita sobrepor trilha ou células
  vizinhas (verificado por teste automatizado, ver `environment_assets_tests.gd`).
- **Variação sem virar bioma diferente (Checkpoint A):** tiles de chão têm 3–4 variantes (mesma
  paleta/estilo, só desloca o padrão de detalhe e acrescenta no máximo um elemento pontual por
  variante — ex: uma flor) e decorações têm variação de tamanho (pequeno/grande) — escolhidas
  deterministicamente por coordenada em `GridManager` (nunca aleatório: o mesmo mapa sempre
  desenha igual). Evita repetição visual idêntica entre células vizinhas sem o jogador perceber
  "isto é outro cenário".
- **Transição grama↔trilha nas 4 direções** (norte/sul/leste/oeste) — sem tratamento de canto
  dedicado (2 tiras sobrepostas quando necessário, ver `GridManager._draw_path_edges()`).

### Regras para personagens

- Silhueta própria e reconhecível à distância de jogo — nunca um "dinossauro genérico"
  redesenhado de outra obra (ver diretriz explícita desta etapa).
- Contorno + no mínimo 2 frames por estado ativo (ver [Animações](#animações) acima).
- Personagens de papéis diferentes (defensor vs. inimigo) devem ser diferenciáveis por silhueta
  E cor, não só por cor — importante para leitura rápida em combate.

### Regras para efeitos

- **`DeathEffect` ganhou arte real no Checkpoint D** (`assets/effects/impact_0-3.png`) — um burst
  de impacto pequeno e rápido (núcleo + raios que se espalham e recolhem em 4 frames, 0.4s),
  usado como arte PADRÃO sempre que o passthrough de sprite de uma criatura específica não é
  chamado (impacto de projétil, chegada de inimigo ao ninho). O passthrough (morte real do
  BasicEnemy) continua sobrescrevendo normalmente. `DamageNumber` continua procedural (texto
  flutuante, fora do escopo de pixel art) — ver
  [ARCHITECTURE.md](ARCHITECTURE.md#animatedvisual-e-deatheffect-phase-06).
- **`SpawnEffect` (Checkpoint E)** — arte real desde a criação (`assets/effects/spawn_0-3.png`),
  poeira/terra levantando do chão no instante em que um `BasicEnemy` nasce no SPAWN. Mesmo padrão
  autônomo de `DeathEffect` (nova cena/script, mesma arquitetura); paleta terrosa, visualmente
  distinta do burst de impacto (evita "o mesmo efeito reaproveitado" para dois eventos diferentes).
- Efeitos pequenos e rápidos, nunca explosões grandes ou detalhes ilegíveis no tamanho real —
  mesma régua de legibilidade que personagens e cenário.

## VFX

Direção provisória: ver [Direção Provisória (Identidade)](#direção-provisória-identidade) acima
— partículas, impactos, flashes, iluminação leve, screen shake e efeitos de habilidade.

**Implementado (reforço pós Phase 0.6):** números de dano flutuantes (`DamageNumber`) e um
pequeno recoil/squash nas reações de ataque/dano de `AnimatedVisual` — feedback de combate barato
(sem partículas, sem shader), pensado para não sobrecarregar leitura do mapa nem custo em mobile.

*TBD — linguagem visual detalhada, orçamento concreto de VFX simultâneos, legibilidade em meio
a combate intenso.*

## UI

*TBD — estilo visual de UI, fontes, iconografia, consistência com a pixel art do jogo.*

## Legibilidade em Telas Pequenas

*TBD — regras para garantir que elementos de gameplay e UI permaneçam legíveis em telas de
celular (tamanho mínimo de elementos interativos, contraste, espessura de contorno em sprites
importantes). Crítico para a plataforma Android.*
