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
- [x] `MapDefinition` (`Resource`) + mapa de teste 20×12 (`data/maps/test_map.tres`)
- [x] Visualização de debug da grid, com toggle (tecla F3)
- [x] Input de mouse (hover + clique identificam célula) e touch (toque identifica célula),
      normalizados por uma camada de `InputManager` comum
- [x] Testes headless da lógica pura da grid (`game/tests/grid_tests.gd`)
- [x] `docs/ARCHITECTURE.md` atualizado com as decisões técnicas reais desta fase
- [x] Validado com Godot **4.7.2** instalado localmente: projeto abre sem erros, testes headless
      passam (`ALL TESTS PASSED`), cena principal roda sem erro/warning, e uma sessão jogada
      manualmente confirma mouse hover/clique identificando células corretamente — ver
      [ARCHITECTURE.md](ARCHITECTURE.md#versão-do-godot)

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
