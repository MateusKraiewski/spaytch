# ARCHITECTURE — SPAYTCH

Documento técnico vivo. Descreve a arquitetura do projeto conforme ela existe e evolui.
Este documento é **descritivo do estado real do código**, não um plano aspiracional — atualize-o
quando a arquitetura mudar de fato.

> Status: **Phase 0.3 — Path System + primeiro inimigo + movimento, concluída e validada em
> Godot 4.7.2.** Além da fundação (Phase 0.1) e do primeiro mapa (Phase 0.2), o projeto agora
> converte o PATH do mapa em uma sequência ordenada de waypoints (`MapPath`, path following, não
> pathfinding), spawna um `BasicEnemy` placeholder que percorre esse caminho de SPAWN a NEST de
> forma independente de FPS, e emite um sinal ao chegar. Nenhum sistema de combate, economia,
> waves, targeting, torres ou dano existe ainda. Seções abaixo descrevem o que existe de fato; o
> que ainda não existe permanece `TBD`.

---

## Versão do Godot

**Godot 4.7 é a versão de desenvolvimento alvo do projeto SPAYTCH.**

O projeto foi originalmente escrito tendo Godot 4.3+ como referência (sem editor disponível para
validação). Com Godot **4.7.2 stable** instalado no ambiente de desenvolvimento, o projeto foi
aberto, escaneado e executado nessa versão sem nenhum erro — não houve necessidade de correção
de código ou de configuração; apenas metadados que o próprio editor gerencia automaticamente
mudaram (ver abaixo).

Não há, até o momento, nenhuma razão técnica conhecida para restringir o projeto a uma versão 4.x
mais antiga que 4.7 — nenhuma API usada é específica de uma versão anterior, e nenhum recurso do
projeto depende de comportamento removido/alterado em 4.7. Se isso mudar (ex: dependência de uma
API introduzida ou removida em uma versão específica), deve ser registrado aqui com justificativa.

O que o editor 4.7.2 alterou automaticamente ao abrir o projeto (não foi uma correção manual):

- `config/features` em `project.godot` passou de `"4.3"` para `"4.7"` — apenas metadado
  informativo da versão, sem efeito funcional.
- Uma seção `[animation]` com
  `compatibility/default_parent_skeleton_in_mesh_instance_3d=true` foi adicionada — configuração
  de compatibilidade de esqueleto 3D que o editor passou a escrever por padrão; irrelevante para
  este projeto 2D, não requer ação.
- `window/stretch/aspect="keep"` deixou de aparecer explicitamente em `project.godot` — o valor
  não mudou, o editor apenas parou de escrever valores iguais ao padrão (`"keep"` já é o default
  do motor). Comportamento de stretch permanece o mesmo.
- Um arquivo `.uid` sidecar foi gerado para cada script (`res://scripts/**/*.gd.uid`,
  `res://tests/grid_tests.gd.uid`) — sistema de identificação estável de recursos do Godot
  4.4+. **Devem ser versionados no Git** (não são cache; são referências estáveis usadas pelo
  motor), diferente de `.godot/` (cache local, já ignorado em `.gitignore`).

## Validação executada (Godot 4.7.2)

- `godot --headless --path game --script res://tests/grid_tests.gd` → `[grid_tests] ALL TESTS
  PASSED`, exit code `0`.
- `godot --headless --path game --quit-after 30` (roda a cena principal por 30 frames) → nenhum
  erro ou warning, exit code `0`.
- `godot --headless --editor --quit --path game` (escaneamento completo do projeto pelo editor)
  → nenhum erro de parsing em nenhum script/cena/resource, exit code `0`.
- Log real de uma sessão jogada manualmente (`%APPDATA%/Godot/app_userdata/SPAYTCH/logs/godot.log`)
  confirma que mouse hover/clique identificam células corretamente (`BUILDABLE`, `PATH`,
  `EMPTY`, `OBSTACLE` reportados corretamente para as coordenadas clicadas), usando o renderer
  `Compatibility` (OpenGL 3.3) conforme configurado.

A Phase 0.1 continua válida sob Godot 4.7 — nenhuma regressão encontrada.

---

## Arquitetura Geral

O projeto Godot vive na pasta **`game/`** (raiz `res://`), separada da raiz do repositório, que
também guarda `docs/` e `.claude/`. Isso mantém a documentação/tooling fora do projeto Godot
propriamente dito. Esta é uma adaptação da estrutura sugerida originalmente (que tratava `game/`
como topo já contendo `assets/`, `scripts/`, etc. diretamente) — mantida como está, apenas
esclarecendo que `game/project.godot` é a raiz `res://`.

Padrão adotado nesta fase:

- **Dados vs. comportamento:** dados de mapa estáticos e autorais vivem em `Resource`
  (`MapDefinition`); estado runtime mutável vive em objetos simples (`Grid`, `Cell`), nunca no
  próprio `Resource`. Ver [Resources](#resources) e [Sistemas](#sistemas).
- **Lógica pura desacoplada da árvore de cena:** `Grid` e `Cell` são `RefCounted`, não `Node`.
  Podem ser instanciados e testados sem depender de uma cena rodando (ver [Testes](#testes)).
- **Composição + signals em vez de referências cruzadas:** nodes irmãos (`GridManager`,
  `InputManager`) não se conhecem diretamente; o nó pai (`Main`) é o *composition root* que
  conecta os sinais de um aos métodos públicos do outro.
- **Nenhum autoload foi criado.** Não havia necessidade real de estado/serviço global nesta fase;
  se surgir, deve ser justificado aqui antes de ser adicionado.

## Estrutura de Diretórios

```
game/
├── project.godot
├── scenes/
│   └── Main.tscn
├── scripts/
│   ├── core/
│   │   └── main.gd            # composition root da cena principal
│   ├── map/
│   │   ├── cell_type.gd        # enum CellType (class_name global)
│   │   ├── cell.gd             # estado runtime de uma célula
│   │   ├── grid.gd             # lógica pura da grid (RefCounted, testável)
│   │   ├── grid_manager.gd     # node: render de debug + resolução de posição→célula
│   │   ├── map_definition.gd   # Resource: dado estático de mapa
│   │   ├── map_validator.gd    # validação de invariantes de um MapDefinition (RefCounted, estático)
│   │   └── map_path.gd         # PATH -> sequência ordenada de waypoints (RefCounted, testável)
│   ├── input/
│   │   └── input_manager.gd    # normalização mouse/touch → sinais de ponteiro
│   └── enemies/
│       ├── basic_enemy.gd      # movimento (path following) de um inimigo, Node2D
│       └── enemy_spawner.gd    # cria BasicEnemy a partir de Grid+MapPath, Node
├── data/
│   ├── maps/
│   │   └── vale_dos_ovos.tres  # único mapa JOGÁVEL (Phase 0.2), carregado por Main.tscn
│   └── test/
│       └── test_map.tres       # fixture de teste (Phase 0.1) — não é mais mapa jogável
├── assets/                     # vazio nesta fase (sem arte final ainda)
├── ui/                         # vazio nesta fase (sem UI ainda)
└── tests/
    ├── grid_tests.gd           # testes headless da lógica pura de Grid/MapDefinition
    ├── map_tests.gd            # testes headless de MapValidator + do mapa Vale dos Ovos
    ├── path_tests.gd           # testes headless de MapPath (ordenação, rejeição de dados impossíveis)
    ├── enemy_tests.gd          # testes headless de movimento de BasicEnemy (step() puro)
    ├── integration_tests.gd    # teste de integração: Main.tscn real, ponta a ponta
    └── run_tests.ps1           # orquestra refresh de cache + compile-check + testes (ver Phase 0.2.1/0.3)
```

`data/maps/` guarda mapas jogáveis; `data/test/` guarda fixtures de dado usadas só por testes —
essa separação de pastas (feita na Phase 0.2.1) deixa a distinção explícita no próprio caminho
do arquivo, não apenas em comentário.

Desvio documentado em relação à sugestão original: a pasta `tests/` foi adicionada (não estava
na sugestão original de estrutura) para manter o código de teste separado do código de produção
em `scripts/`, seguindo convenção comum e atendendo ao requisito de testes da Phase 0.1.

## Cenas (Scenes)

Duas cenas existem: `scenes/Main.tscn` e `scenes/enemies/BasicEnemy.tscn`. Hierarquia de `Main`:

```
Main (Node2D, main.gd)
├── GridManager (Node2D, grid_manager.gd)
├── InputManager (Node, input_manager.gd)
└── EnemySpawner (Node, enemy_spawner.gd)
        └── (BasicEnemy instanciado em runtime por spawn_enemy())
```

`Main` não contém lógica de grid/input/path/inimigo própria além de: conectar sinais no
`_ready()`, construir o `MapPath` a partir do `MapDefinition` já carregado por `GridManager`, e
entregar `Grid` + `MapPath` ao `EnemySpawner` para o spawn inicial (Phase 0.3 — spawn manual
único, sem wave manager ainda). `GridManager`, `InputManager` e `EnemySpawner` são desacoplados
entre si; nenhum referencia os outros diretamente — `Main` é o único ponto de wiring
(*composition root*). Convenção mantida: cenas pequenas, cada responsabilidade em seu próprio
script.

`scenes/enemies/BasicEnemy.tscn`:

```
BasicEnemy (Node2D, basic_enemy.gd)
└── Placeholder (Polygon2D)   # visual TEMPORÁRIO — triângulo laranja, ver Enemies abaixo
```

## Scripts

- Linguagem: **GDScript** (decisão do escopo desta fase; C# não foi avaliado).
- Convenção de nomenclatura: `snake_case.gd` para arquivos, `PascalCase` para `class_name`.
- Classes com `class_name` (`CellType`, `Cell`, `Grid`, `MapDefinition`, `GridManager`,
  `InputManager`, `MapValidator`, `MapPath`, `BasicEnemy`, `EnemySpawner`) são registradas
  globalmente pelo Godot e não exigem `preload`/`load` manual — **mas o registro depende de um
  scan de projeto já ter rodado** (ver limitação documentada na [Phase 0.3](#phase-03--path-system--primeiro-inimigo--movimento) abaixo).
- Regra aplicada: dado configurável/estático → `Resource` (`MapDefinition`); comportamento e
  estado runtime → script comum (`Grid`, `Cell`, `GridManager`, `InputManager`, `MapPath`,
  `BasicEnemy`, `EnemySpawner`).

## Resources

### MapDefinition (`scripts/map/map_definition.gd`)

`Resource` customizado representando a definição **estática e autoral** de um mapa:

- `width`, `height`, `tile_size` (`@export`)
- `cells: PackedInt32Array` — array plano *row-major* (`index = y * width + x`) com o `CellType`
  de cada célula. É a **única fonte de verdade** dos dados do mapa.

`spawn_points`, `egg_positions`, `buildable_cells` e `nest_positions` **não são armazenados**
como listas separadas — são derivados sob demanda via `get_positions_of_type()` a partir de
`cells`. Decisão deliberada: armazenar essas listas separadamente do array de tipos criaria duas
fontes de verdade que poderiam dessincronizar (ex: editar uma célula para `EGG` sem lembrar de
atualizar `egg_positions`). Isso é uma interpretação/adaptação do pedido original (que sugeria
campos explícitos) em favor do princípio de "evitar duplicação" do `CLAUDE.md`. Se o custo de
recalcular sob demanda se tornar um problema real de performance (mapas muito grandes,
recálculo frequente), cache pode ser adicionado depois — não implementado agora por não haver
necessidade demonstrada.

**Importante:** `MapDefinition` não guarda nenhum estado mutável de runtime (ex: "ocupada"). Um
`Resource` carregado do disco pode ser uma instância compartilhada; mutá-lo em runtime é uma
armadilha comum no Godot. Estado mutável vive em `Cell`/`Grid` (ver abaixo).

### Fixture de teste (`data/test/test_map.tres`)

Instância de `MapDefinition` 20×12 usada apenas para validar a Phase 0.1 (contém todos os 7
tipos de célula). Não é um mapa de design final. **Movida de `data/maps/` para `data/test/` na
Phase 0.2.1** (nenhum script ou cena referenciava o caminho antigo — confirmado por busca antes
da mudança) para deixar explícito, pelo próprio caminho do arquivo, que `data/maps/` contém
apenas mapas jogáveis e `data/test/` guarda dado usado só por testes. Conteúdo do arquivo não
foi alterado, só o caminho.

### Vale dos Ovos (primeiro mapa, `data/maps/vale_dos_ovos.tres`)

Primeiro mapa real do jogo (20×12), carregado por `GridManager.map_definition` em `Main.tscn`.
Layout (proposto, aprovado com ajustes, e implementado nesta fase):

```
..................E.
.O...............E.E
..O..........PPPPPN.
.............P.BB...
.............P.BB...
.............P.B....
...BB.PPPPPPPP..O...
..BBB.P.BBBB........
...BB.P.BBBB....O...
.SPPPPP......OO..O..
.........BBB........
..O......BBB........
```

Legenda: `.`=EMPTY `B`=BUILDABLE `P`=PATH `E`=EGG `O`=OBSTACLE `S`=SPAWN `N`=NEST.

Decisões de design (não técnicas) por trás deste layout — nome, motivação de cada zona
buildable, escolha das curvas do caminho — estão registradas em
[GAME_BIBLE.md](GAME_BIBLE.md#vale-dos-ovos-primeiro-mapa) e no princípio de
[level design](GAME_BIBLE.md#princípio-de-level-design) que o guiou. Resumo técnico:

- SPAWN em `(1,9)`, NEST em `(18,2)`, caminho em S com 4 curvas (23 células PATH).
- 3 EGG em arranjo triangular ao redor do ninho: `(18,0)`, `(17,1)`, `(19,1)`.
- 3 zonas BUILDABLE com identidade estratégica (DPS, Controle, potencial Long Range) + 2 áreas
  buildable adicionais (perto do spawn, perto da aproximação final) — o jogador não fica
  limitado às 3 zonas nomeadas.
- 8 OBSTACLE decorativos, posicionados e verificados (ver `MapValidator`/testes) para não serem
  ortogonalmente adjacentes a nenhuma célula PATH/SPAWN/NEST — evita a leitura visual de que um
  obstáculo "bloqueia" o caminho, já que não existe colisão física nesta fase.
- Nenhuma cobertura de alcance é garantida pela geometria — a zona de long range é descrita como
  **posição potencialmente favorável a unidades de longo alcance**, não como zona com alcance
  garantido sobre trechos específicos do caminho, já que alcance/targeting/footprint de
  dinossauros ainda não existem.

## Sistemas

Nesta fase existem o **sistema de grid**, a **validação de mapa**, o **sistema de path** e o
**primeiro inimigo**:

| Camada | Arquivo | Tipo | Responsabilidade |
|---|---|---|---|
| Dado estático | `map_definition.gd` | `Resource` | Definição autoral do mapa (tipos de célula) |
| Validação | `map_validator.gd` | `RefCounted` (métodos estáticos) | Verifica invariantes de um `MapDefinition` (ver [MapValidator](#mapvalidator)) |
| Lógica runtime | `grid.gd`, `cell.gd` | `RefCounted` | Conversões coordenada↔célula, limites, estado runtime por célula (`occupied`) |
| Apresentação/Node | `grid_manager.gd` | `Node2D` | Constrói o `Grid` a partir do `MapDefinition` (após validar), desenha visual de debug, resolve posição de ponteiro → célula |
| Input | `input_manager.gd` | `Node` | Normaliza mouse/touch em sinais `pointer_moved` / `pointer_pressed` |
| Path | `map_path.gd` | `RefCounted` (fábrica estática) | Converte as células PATH de um `MapDefinition` em uma sequência ordenada de waypoints (ver [MapPath](#mappath--path-following)) |
| Inimigo | `basic_enemy.gd` | `Node2D` | Percorre uma lista de waypoints em espaço de mundo, independente de FPS (ver [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner)) |
| Spawn | `enemy_spawner.gd` | `Node` | Cria um `BasicEnemy`, converte waypoints de grid para mundo via `Grid`, inicia o movimento |

Nenhum sistema de combate, economia, waves, upgrades ou targeting existe ainda.

### MapValidator

`scripts/map/map_validator.gd` — funções estáticas que verificam um `MapDefinition` e retornam
`Array[String]` de erros (vazio = válido). Verifica: dimensões válidas (`width`/`height` > 0),
`cells.size() == width*height`, presença de exatamente 1 SPAWN e 1 NEST, presença de PATH,
presença de ao menos 1 EGG, SPAWN/NEST cada um com ao menos uma célula PATH adjacente, e
conectividade SPAWN→NEST (BFS sobre células PATH/SPAWN/NEST).

**Decisão deliberada sobre quantidade de EGG:** o validador exige apenas **"ao menos 1 ovo"**,
não um número fixo. `docs/GAME_BIBLE.md` (seção Ovos) já registra que a quantidade de ovos pode
variar por mapa; travar "exatamente 3" nessa validação genérica contradiria essa decisão de
design para mapas futuros. A exigência de **exatamente 3 ovos** é verificada como teste
específico do mapa `vale_dos_ovos.tres` (`game/tests/map_tests.gd`), não como regra genérica do
`MapValidator`.

**Não é pathfinding:** a checagem de conectividade é um BFS único disparado sob demanda para
validar dados de mapa em tempo de autoria/teste — não é um sistema consultado em runtime por
inimigos (isso permanece uma responsabilidade futura e separada, fora do escopo desta fase).

`GridManager._ready()` chama `MapValidator.validate()` e reporta cada erro via `push_warning()`
antes de construir o `Grid` — não interrompe a execução (`assert` continua reservado para o caso
mais grave de `map_definition` nulo). Erro em runtime é visível no log, mas não trava o jogo,
para não impedir carregar mapas intencionalmente incompletos durante desenvolvimento/debug.

### MapPath — Path Following

`scripts/map/map_path.gd` — converte o conjunto (sem ordem) de células `PATH` de um
`MapDefinition` em uma sequência **ordenada e determinística** de waypoints (`Array[Vector2i]`,
em coordenadas de grid, do SPAWN ao NEST — ambos incluídos como primeiro/último elemento).

**Path following, não pathfinding:** o level designer já desenha o único caminho no mapa; não há
descoberta de rota, não há A*, não há BFS por inimigo. O algoritmo roda **uma única vez por
mapa** (em `Main._ready()`), e o resultado é reutilizado por qualquer inimigo que precise dele —
inimigos apenas consomem a lista pronta, nunca recalculam nada.

**Algoritmo** (`MapPath.build(definition) -> MapPath`): a partir do SPAWN, segue repetidamente o
único vizinho ortogonal (cima/baixo/esquerda/direita — sem diagonais) do tipo PATH/NEST ainda não
visitado, até alcançar o NEST. Falha (retorna `null`, com `push_error()` explicando o motivo) se:

- SPAWN ou NEST não existem em quantidade exatamente 1 (checagem mínima e barata — não repete a
  validação completa de `MapValidator`, que já deveria ter rodado antes);
- o caminho é interrompido antes do NEST (nenhum vizinho válido);
- existe **bifurcação** (mais de um vizinho válido não visitado em algum ponto);
- sobra alguma célula PATH do mapa que nunca foi visitada pelo caminho de SPAWN a NEST
  (segmento desconexo).

**Loop e bifurcação são detectados pelo mesmo mecanismo.** Não existe um caminho separado de
código para "loop": qualquer loop alcançável a partir do SPAWN necessariamente cria um ponto com
mais de um vizinho válido em algum passo do trajeto (o ponto onde seria possível entrar no loop),
então a checagem de bifurcação já rejeita os dois casos. Um contador de segurança
(`max_steps = width*height + 1`) existe como rede adicional, mas não é o mecanismo primário —
com a checagem de vizinho-único-não-visitado, o algoritmo não consegue de fato entrar em loop
infinito (cada célula só pode ser visitada uma vez).

**Por que não duplicar a validação geral do `MapValidator`:** `MapValidator` já garante
dimensões, presença de SPAWN/NEST/PATH/EGG e conectividade genérica (BFS simples). Isso não
garante que o PATH seja uma linha única sem ramificações — um mapa pode passar em
`MapValidator` e ainda assim ser topologicamente inválido para produzir uma sequência
determinística única (ex: um "Y" no caminho). `MapPath` assume que `MapValidator` já rodou, e
adiciona só as checagens específicas de ordenação que `MapValidator` não faz.

**Conversão para mundo não é feita aqui.** `MapPath` só conhece coordenadas de grid.
`Grid.cell_center_world()` (já existente desde a Phase 0.1) é reutilizado por quem consome o
path (`EnemySpawner`) para converter para posições de mundo — conversão centralizada num único
lugar, não duplicada.

### BasicEnemy e EnemySpawner

**`BasicEnemy`** (`scripts/enemies/basic_enemy.gd`, `Node2D`) — inimigo placeholder mínimo:
recebe uma lista de waypoints **em espaço de mundo** (não sabe nada sobre grid, `MapDefinition`
ou `MapPath`) via `initialize(waypoints)`, e os percorre em ordem. `Node2D`, não
`CharacterBody2D`: não há física nem colisão nesta fase, só interpolação de posição — física
seria peso desnecessário para o que o inimigo faz hoje.

- `speed: float` (`@export`, px/s) — **TBD/placeholder balance**, valor só para
  visualização/teste (`60.0`), não é número de design final.
- Movimento independente de FPS: `step(delta)` avança `speed * delta` px em direção ao próximo
  waypoint; se `delta` cobrir mais de um waypoint no mesmo frame (velocidade alta), consome o
  restante no mesmo `step()` em vez de esperar o próximo frame; ao alcançar um waypoint, a
  posição é ajustada exatamente para ele (sem overshoot).
- `step(delta)` é **lógica pura, pública, chamável fora de `_process`** — `_process(delta)` só
  chama `step(delta)`. Isso existe especificamente para permitir testes determinísticos
  (`game/tests/enemy_tests.gd`) sem depender de timing real de frame do motor.
- Ao alcançar o último waypoint, emite `reached_nest(self)` e marca-se como terminado
  (`is_finished()`). **Não se autodestrói** — outros sistemas futuros (dano ao ninho, contagem de
  wave) podem precisar inspecionar o inimigo após a chegada; destruir preemptivamente removeria
  essa informação sem necessidade.
- Direção: `rotation` é ajustada para apontar para o waypoint atual a cada passo de movimento —
  sem sistema de animação, só orientação básica, preparando para sprites direcionais futuros.

Visual: `scenes/enemies/BasicEnemy.tscn` = `BasicEnemy` (script) + `Polygon2D` filho (triângulo
laranja simples). **Placeholder explicitamente temporário** — substituível por
`Sprite2D`/`AnimatedSprite2D` sem tocar em `basic_enemy.gd` (a lógica de movimento não sabe nada
sobre a apresentação visual).

**`EnemySpawner`** (`scripts/enemies/enemy_spawner.gd`, `Node`, não `Node2D` — sem identidade
espacial própria, mesmo raciocínio de `InputManager`) — recebe `Grid` e `MapPath` já prontos via
`setup()` (chamado por `Main`), e em `spawn_enemy()`: instancia `BasicEnemy` a partir de
`enemy_scene` (`@export PackedScene`), converte os waypoints do `MapPath` (grid) para mundo via
`Grid.cell_center_world()`, chama `initialize()`, e conecta ao próprio `reached_nest` do
inimigo. Reemite como `enemy_reached_nest(enemy)` (sinal do próprio spawner) e loga — quem
escuta esse evento hoje é só um `print()`; nenhum sistema (dano ao ninho, wave) existe ainda para
consumi-lo de verdade.

**Spawn desta fase é manual e único**, disparado por `Main._ready()` (`_enemy_spawner.setup(...)`
seguido de `_enemy_spawner.spawn_enemy()`). Não existe wave manager, timer de spawn, nem múltiplos
inimigos — fora de escopo da Phase 0.3.

### CellType: enum vs. Resource

Decisão: `CellType` é um **enum** (em script com `class_name` global), não um `Resource` por
tipo. Motivo: os 7 tipos de célula formam um conjunto pequeno e fechado, usado para comparações
e branches frequentes em vários sistemas; como `int`, cabe naturalmente em um
`PackedInt32Array` (leve, rápido de serializar — 240 inteiros para o mapa de teste). Um
`Resource` por tipo só se justificaria se cada tipo precisasse de dados ricos e configuráveis
próprios (textura, nome, parâmetros de gameplay) — não é o caso agora. Se isso mudar, um
`CellTypeInfo` (Resource) complementar pode ser adicionado depois sem quebrar esta base.

## Comunicação entre Sistemas

### Signals

`InputManager` expõe `pointer_moved(world_pos)` e `pointer_pressed(world_pos)`. `GridManager`
expõe métodos públicos (`on_pointer_moved`, `on_pointer_pressed`), sem conhecer quem os chama.
`Main.gd` (composition root) faz a conexão entre os dois no `_ready()`. Nenhum dos dois nodes
tem referência direta ao outro — convenção a seguir para futuras adições de sistemas irmãos.

### Event Bus

Não introduzido. Com apenas dois sistemas se comunicando, signals diretos conectados pelo nó pai
são suficientes e mais simples de rastrear. Reavaliar apenas se/quando o número de sistemas que
precisam se comunicar entre si crescer a ponto de conexões diretas ficarem impraticáveis.

## Gerenciamento de Estado

Não implementado ainda (sem wave atual, economia, vida da base — esses conceitos não existem no
código). O único estado runtime existente é por-célula (`Cell.occupied`, ainda não consumido por
nenhum sistema) e a célula atualmente sob o cursor (`GridManager._hovered_coord`, privado).

## Persistência

*TBD — não implementado.*

## Testes

**Abordagem:** sem dependências externas (nenhum addon como GUT foi adicionado). Testes usam
apenas o `SceneTree` do próprio Godot em modo headless.

**Arquivos:**

- `game/tests/grid_tests.gd` — lógica pura de `Grid`: conversão coordenada→célula,
  célula→coordenada, limites da grid (dentro e fora), e `get_cell()` para coordenadas fora dos
  limites.
- `game/tests/map_tests.gd` (Phase 0.2) — `MapValidator` contra definições sintéticas (mapa
  válido; dimensões inválidas; contagem de células incorreta; ausência de SPAWN/NEST/PATH/EGG;
  SPAWN/NEST sem PATH adjacente; PATH descontínuo) e o mapa real `vale_dos_ovos.tres` (20×12,
  240 células, exatamente 3 EGG, 1 SPAWN, 1 NEST, presença de PATH/BUILDABLE/OBSTACLE, e
  `MapValidator.validate()` retornando zero erros).
- `game/tests/path_tests.gd` (Phase 0.3) — `MapPath` contra o Vale dos Ovos real (constrói com
  sucesso; início/fim corretos; 25 waypoints = 23 PATH + spawn + nest; todos os pares
  consecutivos ortogonalmente adjacentes — sem diagonal, sem gap; sem duplicatas) e contra mapas
  sintéticos inválidos (bifurcação; "loop"/anel; célula PATH solta) — todos devem ser rejeitados
  (`build()` retorna `null`).
- `game/tests/enemy_tests.gd` (Phase 0.3) — movimento puro de `BasicEnemy` via `step(delta)`
  chamado diretamente (sem `_process`, sem depender de frame real): posição inicial correta,
  índice de waypoint inicial, avanço para o próximo waypoint, chegada ao último waypoint com
  `is_finished()`, emissão do sinal `reached_nest`, independência de FPS (mesmo resultado final
  com um `step()` grande ou vários pequenos somando o mesmo tempo), e ausência de movimento após
  terminado.
- `game/tests/integration_tests.gd` (Phase 0.3) — instancia `Main.tscn` de verdade (o wiring de
  produção completo) e confirma ponta a ponta: mapa carrega, `EnemySpawner` cria um `BasicEnemy`
  real na posição de mundo do SPAWN, o inimigo consegue percorrer o caminho todo (avançado via
  `step(delta)` determinístico, não frames reais) e chega à posição de mundo do NEST emitindo
  `enemy_reached_nest` através do `EnemySpawner`.

**Como executar (recomendado — inclui verificação de compilação, ver Phase 0.2.1):**

```powershell
game/tests/run_tests.ps1
```

**Como executar manualmente (sem a verificação de compilação prévia):**

```
godot --headless --path game --script res://tests/grid_tests.gd
godot --headless --path game --script res://tests/map_tests.gd
godot --headless --path game --script res://tests/path_tests.gd
godot --headless --path game --script res://tests/enemy_tests.gd
godot --headless --path game --script res://tests/integration_tests.gd
```

Saída esperada em cada um: `ALL TESTS PASSED` e código de saída `0`; em caso de falha, cada
asserção que falhar é impressa e o código de saída é `1`. **Rodar os dois comandos manualmente,
sem o `run_tests.ps1`, reintroduz o risco documentado no Phase 0.2.1 abaixo** — prefira sempre
`run_tests.ps1` quando possível.

> **Problema descoberto na Phase 0.2, corrigido na Phase 0.2.1** (ver
> [Phase 0.2.1 — Test Harness Hardening](#phase-021--test-harness-hardening) abaixo): um bug
> real de tipagem em `map_validator.gd` fez o script falhar ao compilar em Godot 4.7.2, mas
> `map_tests.gd` mesmo assim imprimiu `ALL TESTS PASSED` com exit code `0`. Isso não pode mais
> acontecer sem ser detectado — `game/tests/run_tests.ps1` agora verifica a compilação de todo
> script antes de rodar qualquer teste.

> **Atualização (Phase 0.1):** com Godot 4.7.2 instalado no ambiente, os testes de grid foram
> executados e confirmados (`ALL TESTS PASSED`, exit code `0`), assim como a abertura/escaneamento
> completo do projeto no editor, sem erros. Ver
> [Validação executada (Godot 4.7.2)](#validação-executada-godot-472). A limitação original
> (Godot não instalado) não se aplica mais.

## Phase 0.2.1 — Test Harness Hardening

**Problema:** durante a Phase 0.2, `godot --headless --path game --script res://tests/map_tests.gd`
imprimiu `[map_tests] ALL TESTS PASSED` com exit code `0`, mesmo com um bug real de compilação em
`map_validator.gd` (constante de offsets sem tipo explícito) e várias linhas `SCRIPT ERROR` no
output. Um falso positivo: os testes "passaram" sem nunca terem de fato rodado a lógica que
deveriam validar.

**Causa raiz:** `MapValidator` é referenciado em `map_tests.gd` através do sistema de
`class_name` global do Godot (não `preload`/`load` explícito). Quando `map_validator.gd` falha
ao compilar, essa referência não vira um erro fatal de carregamento do script chamador — a
chamada `MapValidator.validate(...)` falha em runtime (`Invalid call. Nonexistent function`),
imprime um `SCRIPT ERROR`, e a execução **continua** normalmente para a linha seguinte (GDScript
não tem exceções). Como o retorno da chamada quebrada acabou não incrementando o contador de
falhas do harness (`_failures`), o teste terminou achando que nada deu errado.

**Investigação do mecanismo correto (empírica, contra Godot 4.7.2 real, bug reintroduzido
temporariamente e depois revertido):**

| Comando | Resultado com `map_validator.gd` quebrado |
|---|---|
| `--script map_tests.gd` (execução normal) | `SCRIPT ERROR` no output, mas **exit code 0** — não confiável |
| `--check-only --script map_tests.gd` (o arquivo que *depende* do quebrado) | `SCRIPT ERROR` no output, mas **exit code 0** — não confiável |
| `--check-only --script grid_manager.gd` (outro arquivo que depende do quebrado) | mesmo padrão — **exit code 0** — não confiável |
| `--editor --quit` (scan completo do projeto) | `SCRIPT ERROR` no output, mas **exit code 0** — não confiável |
| `--check-only --script map_validator.gd` (**o arquivo que contém o erro**) | **exit code 1** — confiável |
| `--check-only --script grid.gd` (arquivo saudável, não relacionado) | exit code `0`, sem output de erro — sem falso negativo |

**Limitação real do Godot 4.7.2 (headless), documentada aqui pois não há como contornar sem
rodar contra o binário real:** o exit code de `--check-only` só reflete um erro de
compilação quando o **arquivo apontado diretamente** é o que contém o problema. Um erro em uma
dependência (via `class_name` global) não se propaga para o exit code de quem depende dela — nem
mesmo o escaneamento completo do projeto (`--editor --quit`) propaga esse tipo de erro para seu
próprio exit code. Isso não é um problema do projeto SPAYTCH; é um comportamento do Godot 4.7.2
em si.

**Solução implementada — `game/tests/run_tests.ps1`:** já que não é possível saber de antemão
qual arquivo tem o problema, o script roda `--check-only --script <arquivo>` **individualmente
em cada um dos `.gd` do projeto** (10 arquivos nesta fase). Como a tabela acima mostra, checar o
arquivo problemático diretamente sempre retorna exit code correto — então essa varredura
completa garante que o arquivo com erro (seja ele qual for) será apontado diretamente em algum
momento e vai falhar. Só se **todos** os arquivos compilarem limpo é que os testes
(`grid_tests.gd`, `map_tests.gd`) são executados; qualquer falha de compilação aborta antes
disso, sem rodar teste nenhum. Não usa nenhuma busca de string arbitrária no stdout — só exit
codes reais retornados pelo próprio Godot via `--check-only`, e nenhuma dependência externa além
do binário do Godot já usado no projeto.

**Verificação do próprio mecanismo:** o bug de `map_validator.gd` foi reintroduzido
temporariamente (mesma mudança: remover a anotação `Array[Vector2i]`) e `run_tests.ps1` rodado
contra ele — abortou corretamente na Fase 1 (compile-check), identificando exatamente
`res://scripts/map/map_validator.gd` como o arquivo com problema, com exit code `1`, **sem**
rodar nenhum teste. O bug foi então revertido (arquivo restaurado ao estado correto) e
`run_tests.ps1` rodado novamente, confirmando os 10 scripts compilando limpo e os dois test
suites passando (exit code `0` no final). Nenhum artefato temporário de teste ficou no projeto —
a mudança foi feita e revertida na mesma linha do arquivo já existente, nada novo foi criado só
para esse experimento.

**Harnesses auditados (`grid_tests.gd`, `map_tests.gd`):** ambos usam o mesmo padrão —
`_failures: int`, helper `_check(condition, message)` que incrementa `_failures` e imprime a
falha, e `quit(1 if _failures > 0 else 0)` no fim de `_initialize()`. Comportamento consistente
entre os dois; nenhuma mudança foi necessária nesses dois arquivos — o problema era inteiramente
externo a eles (uma dependência falhando ao compilar), o que nenhuma lógica interna a um desses
scripts poderia detectar sozinha. A correção tinha que vir de fora (`run_tests.ps1`).

## Phase 0.3 — Path System + primeiro inimigo + movimento

Duas novas limitações reais de Godot 4.7.2 foram descobertas ao rodar (não apenas inspecionar)
os novos scripts/testes desta fase — ambas fizeram o `run_tests.ps1` do Phase 0.2.1 reportar
falhas falsas ou testes travados até serem entendidas e corrigidas. Documentadas aqui porque não
há como contornar sem rodar contra o binário real, e para não serem redescobertas do zero numa
fase futura.

### 1) O cache de `class_name` global não é atualizado por execução normal

**Sintoma:** ao adicionar `MapPath`, `BasicEnemy` e `EnemySpawner` (três `class_name` novos),
tanto `--check-only` quanto uma execução normal (`--quit-after 30`) passaram a reportar
`Identifier not found: MapPath` / `Could not find type "BasicEnemy"` em scripts que referenciam
essas classes — mesmo com o código sintaticamente correto (confirmado depois, sem nenhuma
mudança de código).

**Causa:** o Godot mantém um cache de classes `class_name` registradas globalmente
(`.godot/global_script_class_cache.cfg`), populado por um **scan de projeto do editor**. Rodar
`godot --headless --script X.gd` ou `--quit-after N` **não** dispara esse scan — só usa o cache
que já existir. Um `class_name` recém-criado fica invisível para qualquer OUTRO script (mesmo em
execução normal do jogo, não só em `--check-only`) até `--editor --quit` (ou abrir o projeto no
editor de verdade) rodar pelo menos uma vez depois de o arquivo existir.

**Confirmado empiricamente:** rodando `--editor --quit --path game`, a saída mostra
explicitamente `update_scripts_classes | BasicEnemy`, `| EnemySpawner`, `| MapPath` sendo
registrados; depois disso, a mesma execução normal que falhava passou a rodar sem nenhum erro.

**Correção:** `game/tests/run_tests.ps1` agora roda `--editor --quit` como sua **Fase 1/3**,
incondicionalmente, antes de qualquer compile-check ou teste — refresh de cache, não uma
verificação (o exit code de `--editor --quit` não é usado para decidir sucesso/falha, só o
efeito colateral de popular o cache importa). Isso significa: **sempre que um `class_name` novo
for adicionado ao projeto, rodar `run_tests.ps1` (ou abrir o editor) pelo menos uma vez antes de
rodar testes/builds isolados** — um `--check-only` isolado, sem esse refresh prévio, pode
reportar um falso erro de "classe não encontrada" para uma classe perfeitamente válida.

### 2) `_ready()` não é síncrono ao fazer `add_child()` em um script `SceneTree` customizado

**Sintoma:** `game/tests/integration_tests.gd` instancia `Main.tscn` e faz `root.add_child(main)`
esperando que isso dispare `_ready()` em cascata (GridManager constrói `grid`, Main constrói
`MapPath` e spawna o inimigo) de forma síncrona, igual aconteceria numa cena normal. O teste
verificava o resultado imediatamente após `add_child()` e sempre falhava: `GridManager.grid`
continuava `null`, nenhum `BasicEnemy` era criado.

**Causa, confirmada empiricamente com um script mínimo isolado:** ao rodar via um script que
`extends SceneTree` (o modo `--script` que todos os testes deste projeto usam), a notificação
`NOTIFICATION_READY` de nodes recém-adicionados a `root` **não é entregue de forma síncrona**
dentro da chamada a `add_child()` — fica pendente até o próximo flush de chamadas adiadas do
motor. Um `print()` logo após `add_child()` mostra `is_node_ready() == false`; o `_ready()` do
node só de fato executa depois (impresso só ao final do script, após até `quit()` já ter sido
chamado). Isso é diferente de como a cena principal (`run/main_scene`) é carregada pelo próprio
bootstrapping do Godot, que já garante isso antes do primeiro frame real.

**Correção:** `await process_frame` (sinal do próprio `SceneTree`) logo após `root.add_child(main)`
em `integration_tests.gd` — esse é o idiom padrão do Godot para "aguarde o próximo flush de
notificações/chamadas adiadas", não um hack: é uma sincronização de **um único passo
determinístico**, não polling nem dependência de quantos frames algo "eventualmente" leva. O
avanço de tempo do movimento em si continua 100% determinístico via `BasicEnemy.step(delta)`
chamado diretamente pelo teste — nenhuma dependência de timing real de frame foi introduzida.

## Decisões técnicas adicionais desta fase

- **Renderer:** `gl_compatibility` (Compatibility renderer), tanto para desktop quanto mobile
  (`renderer/rendering_method` e `.mobile`). Escolhido por ser o backend com maior compatibilidade
  em dispositivos Android de baixo/médio desempenho (ver skill `mobile-performance`), em vez de
  Forward+ (essencialmente desktop/alto desempenho).
- **Input unificado sem `InputMap`:** mouse e touch são normalizados em código
  (`InputManager._unhandled_input`), checando o tipo do evento diretamente, em vez de usar uma
  ação de `InputMap` compartilhada. Uma ação de `InputMap` ligada a múltiplos dispositivos seria
  mais idiomática e é uma melhoria futura razoável, mas exigiria escrever manualmente um bloco
  serializado complexo em `project.godot` sem poder validar no editor — optou-se pela abordagem
  mais simples e de menor risco de erro de sintaxe nesta fase.
- **Pixel-perfect:** `window/stretch/mode="viewport"` com `aspect="keep"` (resolução interna fixa
  640×384, escalada preservando proporção, sem distorção), filtro de textura padrão `Nearest`
  (`textures/canvas_textures/default_texture_filter=0`), e snapping de transforms/vértices 2D
  para pixel ativado. Escalonamento estritamente inteiro (integer scaling) **não** foi
  implementado — ficaria a cargo de um `Viewport`/`SubViewportContainer` dedicado; marcado como
  refinamento futuro (TBD), não necessário para esta fase.
- **Orientação:** `window/handheld/orientation="landscape"`, inferido diretamente da resolução
  interna 640×384 (mais larga que alta), não de uma decisão de design documentada em
  `GAME_BIBLE.md`. Sinalizar se isso não corresponder à intenção real do projeto.

## Decisões técnicas — Phase 0.2

- **`MapDefinition` continua sendo a única fonte de verdade.** Nenhum array duplicado foi
  adicionado para spawn/nest/egg/buildable do Vale dos Ovos — tudo deriva de `cells` via
  `get_positions_of_type()`, já existente desde a Phase 0.1.
- **`MapValidator` como classe separada, não método em `MapDefinition`.** A validação envolve um
  algoritmo (BFS de conectividade, várias checagens) — comportamento, não dado. Mantê-la fora do
  `Resource` segue o princípio de separar dados de comportamento do `CLAUDE.md` e evita que
  `MapDefinition` cresça além de ser um contêiner de dados simples.
- **Gotcha de tipagem estática do GDScript em Godot 4.7:** um array literal atribuído a uma
  `const` sem anotação de tipo explícita (`const X := [Vector2i(...), ...]`) é inferido como
  `Array` genérico, não `Array[Vector2i]`. Iterar esse array e usar o item em uma expressão com
  `:=` (ex: `var neighbor := coord + offset`) falha ao compilar com "Cannot infer the type...".
  Correção: anotar o tipo explicitamente (`const X: Array[Vector2i] = [...]`). Isso foi
  descoberto rodando os testes de verdade contra Godot 4.7.2 — reforça o valor de validar com o
  motor real em vez de apenas inspecionar o código (ver também o cuidado operacional registrado
  em [Testes](#testes)).
- **`GridManager` não cresceu para além do razoável.** A única adição desta fase em
  `grid_manager.gd` foi chamar `MapValidator.validate()` no `_ready()` e logar os erros — 4
  linhas. Se validação de mapa ganhar mais responsabilidade (ex: validação assíncrona, UI de
  erro), deve ser extraída para um componente próprio antes de crescer mais dentro de
  `GridManager`.

## Decisões técnicas — Phase 0.3

- **`MapPath` (não `PathDefinition`):** nomeado por analogia direta com `Grid` — ambos são dados
  runtime **derivados** de um `MapDefinition` (não autorados diretamente), então usar o sufixo
  `Definition` (reservado no projeto para dado estático/autoral, ver `MapDefinition`) induziria o
  leitor a erro. `MapPath` deixa claro: "o [caminho] deste [mapa]", já calculado.
- **`MapPath` é `RefCounted` com fábrica estática (`build()`), igual a `Grid`.** Não depende da
  árvore de cena — testável isoladamente (`game/tests/path_tests.gd`). `build()` retorna `null` +
  `push_error()` em vez de lançar exceção (GDScript não tem exceções) ou usar `assert()` — assim
  quem consome (`Main.gd`) pode decidir o que fazer com um mapa mal formado sem derrubar o
  processo.
- **`BasicEnemy` é `Node2D`, não `CharacterBody2D`.** Não há física nem colisão nesta fase, só
  interpolação de posição — `CharacterBody2D` adicionaria complexidade e custo (integração de
  física) sem nenhum benefício ainda. Reavaliar quando/se colisão real for necessária.
- **`EnemySpawner` é `Node`, não `Node2D`.** Mesmo raciocínio já aplicado a `InputManager`: o
  spawner não tem posição/rotação próprias que importem — quem tem identidade espacial é o
  `BasicEnemy` spawnado.
- **`step(delta)` público e separado de `_process(delta)` em `BasicEnemy`.** `_process` só chama
  `step()`. Isso existe especificamente para permitir avançar o movimento de forma determinística
  em testes (chamando `step()` diretamente, com deltas controlados) sem depender de o node estar
  numa `SceneTree` rodando nem de timing real de frame — usado tanto pelos testes de movimento
  puro (`enemy_tests.gd`) quanto pelo teste de integração (`integration_tests.gd`).
- **Detecção de bifurcação e de loop no `MapPath` usam o mesmo mecanismo** (ver seção
  [MapPath](#mappath--path-following) acima) — não foi implementada lógica dedicada a "loop"
  porque, dada a checagem de "siga o único vizinho válido não visitado", um loop alcançável a
  partir do SPAWN sempre se manifesta como uma bifurcação em algum ponto do trajeto.
- **Gotcha de closures do GDScript, descoberto escrevendo os testes:** uma função anônima
  (`func(...): ...`) que reatribui uma variável local simples do escopo externo (ex:
  `var received := false; sinal.connect(func(): received = true)`) **não** propaga essa mudança
  para fora da lambda — GDScript captura variáveis locais simples por valor. `Array`/`Dictionary`
  são capturados por referência ao mesmo objeto, então mutar um **elemento** deles (ex:
  `var received := [false]; ... func(): received[0] = true`) funciona corretamente. Confirmado
  com um script isolado contra Godot 4.7.2 antes de aplicar a correção nos testes afetados
  (`enemy_tests.gd`, `integration_tests.gd`).
- **`speed` em `BasicEnemy` é TBD/placeholder balance** (`60.0` px/s) — só para
  visualização/teste nesta fase; não é um valor de design final, e não há sistema de
  balanceamento ainda.
