# ROADMAP — SPAYTCH

Roadmap de desenvolvimento em fases. Cada fase lista objetivos gerais e um espaço para tarefas
concretas, que serão adicionadas conforme o projeto avança. Nenhuma tarefa de gameplay foi
definida ainda — este é o esqueleto do roadmap.

---

## Phase 0 — Foundation

**Objetivo:** estabelecer a fundação documental, arquitetural e de ferramentas do projeto antes
de qualquer gameplay.

- [x] Documentação inicial (`CLAUDE.md`, `docs/`, skills em `.claude/skills/`)
- [x] Identidade inicial de design registrada (nome, conceito, core loop, papéis de
      dinossauros/inimigos/ovos, filosofia de design) — ver [GAME_BIBLE.md](GAME_BIBLE.md)
- [x] Configuração do projeto Godot 4.x (estrutura de diretórios, configurações de projeto) —
      ver Phase 0.1 abaixo
- [x] Configuração de controle de versão (`.gitignore` apropriado para Godot)
- [ ] *(tarefas adicionais TBD)*

### Phase 0.1 — Godot Foundation + Grid

- [x] Projeto Godot 4.x criado em `game/` (GDScript, resolução interna 640×384, 20×12 tiles de
      32×32px, renderer `gl_compatibility`, configuração pixel-perfect)
- [x] Estrutura de diretórios inicial (`scenes/`, `scripts/{core,map,input}/`, `data/maps/`,
      `assets/`, `ui/`, `tests/`)
- [x] Cena principal (`Main.tscn`) modular (composition root + `GridManager` + `InputManager`)
- [x] Sistema de grid lógica 20×12 (`Grid`/`Cell`, `RefCounted`, testável isoladamente)
- [x] Tipos de célula (`CellType`: EMPTY, PATH, BUILDABLE, EGG, OBSTACLE, SPAWN, NEST)
- [x] `MapDefinition` (`Resource`) + mapa de teste 20×12 (`test_map.tres`, movido para
      `data/test/` na Phase 0.2.1 — na época desta fase estava em `data/maps/`)
- [x] Visualização de debug da grid, com toggle (tecla F3)
- [x] Input de mouse (hover + clique identificam célula) e touch (toque identifica célula),
      normalizados por uma camada de `InputManager` comum
- [x] Testes headless da lógica pura da grid (`game/tests/grid_tests.gd`)
- [x] `docs/ARCHITECTURE.md` atualizado com as decisões técnicas reais desta fase
- [x] Validado com Godot **4.7.2** instalado localmente: projeto abre sem erros, testes headless
      passam (`ALL TESTS PASSED`), cena principal roda sem erro/warning, e uma sessão jogada
      manualmente confirma mouse hover/clique identificando células corretamente — ver
      [ARCHITECTURE.md](ARCHITECTURE.md#versão-do-godot)

### Phase 0.2 — Map Foundation + Primeiro Mapa (Vale dos Ovos)

- [x] Layout do mapa proposto como decisão de game design, analisado e **aprovado** (com ajustes:
      ovos em arranjo triangular, obstáculos sem encostar no PATH) antes de qualquer implementação
- [x] Princípio de level design registrado em
      [GAME_BIBLE.md](GAME_BIBLE.md#princípio-de-level-design): "o mapa deve criar decisões
      interessantes antes de o jogador possuir upgrades"
- [x] Primeiro mapa real do jogo — `data/maps/vale_dos_ovos.tres` (20×12, 1 SPAWN, 1 NEST, 3 EGG,
      caminho em S com 4 curvas, 3 zonas buildable com identidade estratégica + 2 áreas buildable
      extras, 8 obstáculos sem adjacência confusa ao PATH) — carregado por `Main.tscn`
- [x] `test_map.tres` (Phase 0.1) mantido intacto nesta fase, sem ser mais o mapa padrão da cena
      (movido de pasta na Phase 0.2.1, ver abaixo)
- [x] `MapValidator` (`scripts/map/map_validator.gd`): valida dimensões, contagem de células,
      presença/unicidade de SPAWN e NEST, presença de PATH, presença de EGG, SPAWN/NEST
      conectados a PATH, e conectividade SPAWN→NEST (BFS simples, não é pathfinding genérico)
- [x] `GridManager` chama `MapValidator` no `_ready()` e reporta erros sem travar a execução
- [x] Grid, resolução (640×384, 20×12, 32px), visualização de debug, mouse (hover/clique) e
      touch mantidos sem alteração de comportamento
- [x] Testes expandidos — `game/tests/map_tests.gd`: `MapValidator` contra mapas sintéticos
      válidos/inválidos (todas as categorias pedidas) + asserções específicas do Vale dos Ovos
      (20×12, 240 células, 3 ovos, 1 spawn, 1 nest, path/buildable/obstacle presentes, validação
      limpa)
- [x] Bug real de tipagem GDScript (Godot 4.7) encontrado e corrigido durante os testes — ver
      [ARCHITECTURE.md](ARCHITECTURE.md#decisões-técnicas-phase-02)
- [x] `docs/ARCHITECTURE.md` e `docs/GAME_BIBLE.md` atualizados com as decisões reais desta fase
- [x] Validado com Godot **4.7.2**: testes de grid e de mapa passam limpos (sem `SCRIPT ERROR`),
      cena principal roda 30 frames sem erro/warning, escaneamento completo do editor sem erros
- [ ] Nenhum sistema de gameplay (torres, inimigos, waves, economia, combate) foi implementado —
      fora de escopo desta fase, conforme planejado

### Phase 0.2.1 — Test Harness Hardening

- [x] Falso positivo confirmado: `map_tests.gd` reportava `ALL TESTS PASSED` (exit 0) mesmo com
      `SCRIPT ERROR` de compilação em `map_validator.gd` no output
- [x] Mecanismo correto do Godot 4.7.2 investigado empiricamente (bug reintroduzido e revertido
      de forma controlada) — `--check-only` só retorna exit code confiável quando aponta
      diretamente para o arquivo com o erro; checar um arquivo dependente, ou escanear o projeto
      inteiro (`--editor --quit`), retorna exit 0 mesmo com erro real — limitação do próprio
      Godot, documentada em [ARCHITECTURE.md](ARCHITECTURE.md#phase-021--test-harness-hardening)
- [x] `game/tests/run_tests.ps1` criado: roda `--check-only` em cada um dos 10 `.gd` do projeto
      individualmente antes de rodar qualquer teste; aborta com exit 1 se qualquer arquivo falhar
      ao compilar — mecanismo baseado em exit code real do Godot, não em busca de string no stdout
- [x] Mecanismo verificado nos dois sentidos: com o bug reintroduzido, abortou corretamente
      apontando o arquivo exato, sem rodar nenhum teste; com o bug revertido, os 10 scripts
      compilaram limpo e os dois test suites passaram — nenhum artefato temporário deixado no
      projeto
- [x] `grid_tests.gd` e `map_tests.gd` auditados — mesmo padrão de sucesso/falha em ambos
      (`_failures` + `quit()`), nenhuma mudança necessária nesses arquivos
- [x] `test_map.tres` movido de `data/maps/` para `data/test/` (nenhuma referência ao caminho
      antigo existia — confirmado por busca antes da mudança); `data/maps/` agora contém só o
      mapa jogável (`vale_dos_ovos.tres`)
- [x] Nenhuma alteração de gameplay (dinos, inimigos, waves, combate, economia, targeting)
- [x] `docs/ARCHITECTURE.md` atualizado com o mecanismo, a limitação do Godot descoberta, e a
      nova localização de `test_map.tres`

### Phase 0.3 — Path System + Primeiro Inimigo + Movimento

- [x] `MapPath` (`scripts/map/map_path.gd`): converte as células PATH de um `MapDefinition` em
      uma sequência ordenada e determinística de waypoints (SPAWN → ... → NEST), seguindo só
      vizinhos ortogonais; rejeita bifurcação, "loop" (mesmo mecanismo da bifurcação), célula
      PATH solta — path following, sem A*/BFS por inimigo
- [x] `BasicEnemy` (`scripts/enemies/basic_enemy.gd` + `scenes/enemies/BasicEnemy.tscn`):
      placeholder visual (Polygon2D triângulo, claramente temporário), percorre waypoints em
      espaço de mundo com `speed` configurável (TBD/placeholder balance), movimento
      independente de FPS via `step(delta)` público (sem overshoot, sem jitter), orientação
      aproximada para o próximo waypoint, emite `reached_nest` ao terminar sem se autodestruir
- [x] `EnemySpawner` (`scripts/enemies/enemy_spawner.gd`): spawn manual único ao iniciar `Main`,
      converte waypoints de grid para mundo via `Grid.cell_center_world()` (conversão
      centralizada, não duplicada), reemite `enemy_reached_nest` e loga a chegada
- [x] `Main.gd` (composition root) constrói o `MapPath` e liga `Grid`+`MapPath` ao
      `EnemySpawner` — nenhuma lógica de path/inimigo dentro de `GridManager`
- [x] Testes determinísticos — `game/tests/path_tests.gd` (mapa real + 3 topologias sintéticas
      inválidas rejeitadas) e `game/tests/enemy_tests.gd` (posição/índice inicial, avanço,
      chegada, sinal, independência de FPS, sem movimento após terminar)
- [x] Teste de integração — `game/tests/integration_tests.gd`: `Main.tscn` real ponta a ponta
      (mapa → path → spawn → percurso completo → `enemy_reached_nest`), separado dos testes de
      lógica pura
- [x] Duas limitações reais de Godot 4.7.2 descobertas rodando os testes de verdade (não só
      inspecionando código) e corrigidas em `run_tests.ps1`/`integration_tests.gd`: cache de
      `class_name` global não atualiza sem scan do editor; `_ready()` não é síncrono ao
      `add_child()` num script `SceneTree` customizado — ver
      [ARCHITECTURE.md](ARCHITECTURE.md#phase-03--path-system--primeiro-inimigo--movimento)
- [x] `run_tests.ps1` atualizado (refresh de cache como nova Fase 1/3 + 3 novos testes) e
      validado limpo: compile-check, todos os testes, `--quit-after 30`, `--editor --quit` —
      sem `SCRIPT ERROR`, sem `Parse Error`, exit codes corretos
- [x] `docs/ARCHITECTURE.md` atualizado com a arquitetura, decisões e limitações reais desta fase
- [ ] Nenhum sistema de combate, dano, HP de ovos, economia, waves, targeting, torres ou dano foi
      implementado — fora de escopo desta fase, conforme planejado

## Phase 1 — Core Prototype

**Objetivo:** protótipo jogável mínimo validando o core loop (uma torre, um inimigo, um
caminho, sem arte final).

- [ ] *TBD*

## Phase 2 — Vertical Slice

**Objetivo:** fatia vertical representativa do produto final — um mapa completo, poucas torres
e inimigos, com arte e áudio de qualidade representativa.

- [ ] *TBD*

## Phase 3 — Content

**Objetivo:** expansão de conteúdo — mais torres, inimigos, mapas e waves conforme definido em
[GAME_BIBLE.md](GAME_BIBLE.md).

- [ ] *TBD*

## Phase 4 — Progression

**Objetivo:** sistemas de progressão e economia completos (meta-progressão, desbloqueios,
balanceamento).

- [ ] *TBD*

## Phase 5 — Polish

**Objetivo:** refinamento de UX, VFX, áudio, feedback de jogo e correção de bugs.

- [ ] *TBD*

## Phase 6 — Mobile Optimization

**Objetivo:** otimização dedicada para Android (performance em dispositivos de baixo/médio
desempenho, controles touch, adaptação de UI — ver skill `mobile-performance`).

- [ ] *TBD*

## Phase 7 — Release

**Objetivo:** preparação de builds finais para PC e Android, submissão a lojas, materiais de
lançamento.

- [ ] *TBD*
