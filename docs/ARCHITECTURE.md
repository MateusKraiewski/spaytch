# ARCHITECTURE — SPAYTCH

Documento técnico vivo. Descreve a arquitetura do projeto conforme ela existe e evolui.
Este documento é **descritivo do estado real do código**, não um plano aspiracional — atualize-o
quando a arquitetura mudar de fato.

> Status: **Phase 0.2 — Map Foundation + primeiro mapa (Vale dos Ovos) concluída e validada em
> Godot 4.7.2.** Além da fundação da Phase 0.1, o projeto agora tem um mapa real de 20×12
> (`data/maps/vale_dos_ovos.tres`) e uma validação de integridade de `MapDefinition`
> (`MapValidator`). Nenhum sistema de gameplay (torres, inimigos, waves, economia, combate) foi
> implementado. Seções abaixo descrevem o que existe de fato; o que ainda não existe permanece
> `TBD`.

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
│   │   └── map_validator.gd    # validação de invariantes de um MapDefinition (RefCounted, estático)
│   └── input/
│       └── input_manager.gd    # normalização mouse/touch → sinais de ponteiro
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
    └── run_tests.ps1           # orquestra compile-check + testes (ver Phase 0.2.1)
```

`data/maps/` guarda mapas jogáveis; `data/test/` guarda fixtures de dado usadas só por testes —
essa separação de pastas (feita na Phase 0.2.1) deixa a distinção explícita no próprio caminho
do arquivo, não apenas em comentário.

Desvio documentado em relação à sugestão original: a pasta `tests/` foi adicionada (não estava
na sugestão original de estrutura) para manter o código de teste separado do código de produção
em `scripts/`, seguindo convenção comum e atendendo ao requisito de testes da Phase 0.1.

## Cenas (Scenes)

Uma única cena existe: `scenes/Main.tscn`. Hierarquia:

```
Main (Node2D, main.gd)
├── GridManager (Node2D, grid_manager.gd)
└── InputManager (Node, input_manager.gd)
```

`Main` não contém lógica própria além de conectar sinais no `_ready()` — é o composition root.
`GridManager` e `InputManager` são desacoplados entre si; nenhum dos dois referencia o outro
diretamente. Convenção adotada: cenas devem permanecer pequenas e cada responsabilidade
(dados/lógica de grid, renderização de debug, input) deve ter seu próprio script.

## Scripts

- Linguagem: **GDScript** (decisão do escopo desta fase; C# não foi avaliado).
- Convenção de nomenclatura: `snake_case.gd` para arquivos, `PascalCase` para `class_name`.
- Classes com `class_name` (`CellType`, `Cell`, `Grid`, `MapDefinition`, `GridManager`,
  `InputManager`) são registradas globalmente pelo Godot e não exigem `preload`/`load` manual.
- Regra aplicada: dado configurável/estático → `Resource` (`MapDefinition`); comportamento e
  estado runtime → script comum (`Grid`, `Cell`, `GridManager`, `InputManager`).

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

Nesta fase existem o **sistema de grid** e a **validação de mapa**:

| Camada | Arquivo | Tipo | Responsabilidade |
|---|---|---|---|
| Dado estático | `map_definition.gd` | `Resource` | Definição autoral do mapa (tipos de célula) |
| Validação | `map_validator.gd` | `RefCounted` (métodos estáticos) | Verifica invariantes de um `MapDefinition` (ver [MapValidator](#mapvalidator)) |
| Lógica runtime | `grid.gd`, `cell.gd` | `RefCounted` | Conversões coordenada↔célula, limites, estado runtime por célula (`occupied`) |
| Apresentação/Node | `grid_manager.gd` | `Node2D` | Constrói o `Grid` a partir do `MapDefinition` (após validar), desenha visual de debug, resolve posição de ponteiro → célula |
| Input | `input_manager.gd` | `Node` | Normaliza mouse/touch em sinais `pointer_moved` / `pointer_pressed` |

Nenhum sistema de gameplay (economia, combate, waves, upgrades) existe ainda.

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

**Como executar (recomendado — inclui verificação de compilação, ver Phase 0.2.1):**

```powershell
game/tests/run_tests.ps1
```

**Como executar manualmente (sem a verificação de compilação prévia):**

```
godot --headless --path game --script res://tests/grid_tests.gd
godot --headless --path game --script res://tests/map_tests.gd
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
