# ARCHITECTURE — SPAYTCH

Documento técnico vivo. Descreve a arquitetura do projeto conforme ela existe e evolui.
Este documento é **descritivo do estado real do código**, não um plano aspiracional — atualize-o
quando a arquitetura mudar de fato.

> Status: **Phase 0.1 — Godot Foundation + Grid concluída.** Existe um projeto Godot 4.x
> funcional com uma cena principal, um sistema de grid lógica desacoplado de renderização, e uma
> camada de input normalizada para mouse/touch. Nenhum sistema de gameplay (torres, inimigos,
> waves, economia, combate) foi implementado. Seções abaixo descrevem o que existe de fato; o que
> ainda não existe permanece `TBD`.

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
│   │   └── map_definition.gd   # Resource: dado estático de mapa
│   └── input/
│       └── input_manager.gd    # normalização mouse/touch → sinais de ponteiro
├── data/
│   └── maps/
│       └── test_map.tres       # instância de MapDefinition usada como mapa de teste
├── assets/                     # vazio nesta fase (sem arte final ainda)
├── ui/                         # vazio nesta fase (sem UI ainda)
└── tests/
    └── grid_tests.gd           # testes headless da lógica pura de Grid/MapDefinition
```

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

### Mapa de teste

`data/maps/test_map.tres` é uma instância de `MapDefinition` 20×12 usada apenas para validar a
Phase 0.1 (contém todos os 7 tipos de célula). Não é um mapa de design final — layout puramente
funcional para debug.

## Sistemas

Nesta fase existe apenas o **sistema de grid**, dividido em três camadas:

| Camada | Arquivo | Tipo | Responsabilidade |
|---|---|---|---|
| Dado estático | `map_definition.gd` | `Resource` | Definição autoral do mapa (tipos de célula) |
| Lógica runtime | `grid.gd`, `cell.gd` | `RefCounted` | Conversões coordenada↔célula, limites, estado runtime por célula (`occupied`) |
| Apresentação/Node | `grid_manager.gd` | `Node2D` | Constrói o `Grid` a partir do `MapDefinition`, desenha visual de debug, resolve posição de ponteiro → célula |
| Input | `input_manager.gd` | `Node` | Normaliza mouse/touch em sinais `pointer_moved` / `pointer_pressed` |

Nenhum sistema de gameplay (economia, combate, waves, upgrades) existe ainda.

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

**Arquivo:** `game/tests/grid_tests.gd` — cobre lógica pura de `Grid`:
conversão coordenada→célula, célula→coordenada, limites da grid (dentro e fora), e
`get_cell()` para coordenadas fora dos limites.

**Como executar:**

```
godot --headless --path game --script res://tests/grid_tests.gd
```

Saída esperada: `[grid_tests] ALL TESTS PASSED` e código de saída `0`; em caso de falha, cada
asserção que falhar é impressa e o código de saída é `1`.

> **Limitação conhecida:** o Godot 4.x não está instalado no ambiente onde esta fase foi
> implementada, então os testes acima e a abertura do projeto no editor **não puderam ser
> executados/verificados localmente**. O código foi escrito e revisado com atenção à sintaxe e
> ao formato de arquivo do Godot 4.3+, mas deve ser aberto no editor e validado antes de ser
> considerado definitivamente livre de erros.

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
