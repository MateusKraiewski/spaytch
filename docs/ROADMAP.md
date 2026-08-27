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

### Phase 0.4 — Dinosaur/Tower System

- [x] `DinosaurDefinition` (`scripts/dinosaurs/dinosaur_definition.gd`): Resource com
      display_name, range, attack_interval, damage, projectile_speed, projectile_scene,
      placeholder_color; sem custo/economia/upgrade/habilidade especial (fora de escopo)
- [x] `velociraptor.tres`: primeiro (e único) DinosaurDefinition — DPS, alcance médio, ataque
      rápido, dano baixo/médio, targeting FIRST, sem upgrades/habilidades
- [x] `Dinosaur` (`scripts/dinosaurs/dinosaur.gd` + `scenes/dinosaurs/Dinosaur.tscn`): runtime
      genérico (uma cena para qualquer dinossauro futuro), cooldown, pede alvo a `Targeting`,
      dispara `Projectile`, node `Visual` separado do gameplay para arte futura
- [x] `Targeting` (`scripts/dinosaurs/targeting.gd`): modo FIRST (maior progresso no MapPath),
      filtra por alcance no mundo, ignora inimigos mortos/inativos; enum+match, sem Strategy
      Pattern (explicitamente não criado)
- [x] `Projectile` (`scripts/combat/projectile.gd` + `scenes/combat/Projectile.tscn`): movimento
      determinístico via `step(delta)`, homing simples sem predição, sem física/Area2D, aplica
      dano exatamente uma vez ao impactar, termina sem dano se o alvo sumir/morrer em voo
- [x] `PlacementController` (`scripts/placement/placement_controller.gd`): máquina de estados
      IDLE/PLACING, Velociraptor pré-selecionado automaticamente (sem UI de loja/seleção),
      valida célula (BUILDABLE + livre), instancia Dinosaur, marca `Cell.occupied` (runtime,
      não MapDefinition); mesmo fluxo para mouse click e touch tap, sem depender de hover
- [x] `PlacementPreview` (`scripts/placement/placement_preview.gd`): highlight válido/inválido +
      círculo de alcance aproximado, placeholder simples, só leitura do estado do controller
- [x] `EnemySpawner` expandido: registro de inimigos ativos (`get_active_enemies()`), sem
      EnemyRegistry/EnemyManager separado (explicitamente não criado)
- [x] `BasicEnemy` expandido: `max_hp`/`hp`, `take_damage()`, `is_dead()`, `is_active()`, signal
      `died`, `get_distance_traveled()` (progresso no caminho, requisito de targeting FIRST) —
      continua independente de Dinosaur/Targeting
- [x] `Main.tscn`/`main.gd`: containers neutros `Dinosaurs`/`Projectiles`, wiring de
      `PlacementController`/`PlacementPreview`, pré-seleção do Velociraptor
- [x] Dois problemas reais encontrados e corrigidos rodando os testes de verdade: `Projectile`
      só detectava impacto no `step()` seguinte (não no mesmo, com delta grande); cenas reais
      instanciadas em testes vazavam RID/CanvasItem sem liberação explícita — ver
      [ARCHITECTURE.md](ARCHITECTURE.md#phase-04--dinosaurtower-system)
- [x] Testes determinísticos novos: `dinosaur_definition_tests.gd`, `placement_tests.gd`,
      `targeting_tests.gd`, `dinosaur_tests.gd`, `projectile_tests.gd`,
      `combat_integration_tests.gd` (vertical slice completo: placement → targeting → disparo →
      dano → morte, antes do inimigo alcançar o ninho)
- [x] `run_tests.ps1` atualizado (11 test suites) e validado limpo: compile-check (28 scripts),
      todos os testes, `--quit-after 30`, `--editor --quit` — sem SCRIPT ERROR, sem Parse Error,
      sem warning/erro de vazamento de recurso
- [x] `docs/ARCHITECTURE.md` atualizado com arquitetura, decisões e limitações reais desta fase
- [x] `docs/GAME_BIBLE.md` atualizado apenas para registrar que o Velociraptor é o primeiro
      dinossauro concreto (papel DPS) — sem números de balanceamento (técnicos, ficam em
      ARCHITECTURE.md)
- [ ] Nenhuma economia, waves, upgrades, habilidades especiais, UI de seleção/loja, animações
      finais ou arte final foi implementada — fora de escopo desta fase, conforme planejado

### Phase 0.5 — Primeiro Game Loop Jogável Completo

- [x] `WaveDefinition` (`Resource`) + `WaveManager`: 3 waves (`wave_01/02/03.tres`, 5/8/10
      inimigos, intervalo 1.0/0.9/0.8s); máquina de estados IDLE/SPAWNING/WAITING_FOR_CLEAR;
      não permite duas waves simultâneas; conclusão só quando nenhum inimigo spawnado por ela
      continua ativo; `wave_started`/`wave_completed`; `lock()` para GAME_OVER
- [x] `EnemySpawner` estendido: `spawn_enemy(speed_override, hp_override)` parametrizado por
      wave; sinal `enemy_died` (re-emissão); não spawna mais sozinho ao iniciar (spawning agora
      é exclusivo de `WaveManager`)
- [x] `Economy` (`Node`): `coins` runtime, `starting_coins` configurável, `can_afford`/`spend`/
      `add` centralizados, sinal `coins_changed`; sem loja, sem moeda premium, sem persistência
- [x] `DinosaurDefinition.cost` adicionado; `PlacementController` verifica/desconta coins na
      confirmação do placement (não durante hover/preview); sem coins suficientes: nada é
      descontado, nenhum dinossauro é criado, `placement_failed("insufficient_coins")` +
      log
- [x] `Egg` (`Node2D`, hp/dano/destruição) + `EggManager`: posições derivadas de
      `MapDefinition.get_egg_positions()` (não duplicadas); regra determinística de seleção
      (primeiro ovo vivo, ordem do mapa); inimigo que alcança o ninho causa `egg_damage` e é
      removido (`queue_free()`, decisão do `EggManager`, não do `BasicEnemy`); sinal
      `all_eggs_destroyed`
- [x] `BasicEnemy` estendido: `egg_damage` (dano a ovos), sinal `damaged` — continua
      independente de `Dinosaur`/`Targeting`/`GameState`/`Economy`
- [x] Estado da partida (`GameState`: PREPARING/WAVE_ACTIVE/WAVE_COMPLETE/GAME_OVER) controlado
      por `Main.gd` (composition root), reagindo a sinais reais de `WaveManager`/`EggManager` —
      sem máquina de estados abstrata separada
- [x] GAME_OVER quando todos os ovos são destruídos: `WaveManager.lock()` impede spawn/wave
      novos, `HUD` mostra overlay simples
- [x] `HUD` (`CanvasLayer`, `scenes/ui/HUD.tscn`): coins, wave atual, status, ovos vivos + HP,
      botão "Iniciar Onda", feedback de wave complete e game over — placeholders de UI, métodos
      públicos estáveis para arte final substituir depois; só exibe/encaminha, não decide
- [x] Pausa via mecanismo nativo do Godot (`get_tree().paused` + `process_mode`): inimigos,
      projéteis, cooldowns e spawning param sozinhos; só a HUD (`process_mode = ALWAYS`)
      continua respondendo
- [x] Velocidade x1/x2 via `Engine.time_scale` (mecanismo nativo do Godot), resetado
      explicitamente a cada `Main._ready()`
- [x] Sinais de feedback estabelecidos (não VFX complexos): `BasicEnemy.damaged`,
      `Dinosaur.fired`, `Projectile.impacted`, `Egg.damaged`/`destroyed`,
      `WaveManager.wave_started`/`wave_completed` — `Egg`/`BasicEnemy` já reagem com um
      `modulate` simples; `Dinosaur.fired`/`Projectile.impacted` só o sinal existe ainda
- [x] Continua PC (mouse) e Android (touch) pelo mesmo `InputManager`, sem sistema de input
      separado
- [x] Nenhum autoload/EventBus/Manager global novo; `GridManager`/`InputManager` não sofreram
      nenhuma alteração nesta fase
- [x] Testes novos: `economy_tests.gd`, `egg_tests.gd`, `wave_tests.gd`,
      `game_loop_integration_tests.gd` (loop completo + cenário de dano ao ovo); `placement_tests.gd`
      expandido (custo); `enemy_tests.gd` expandido; `integration_tests.gd`/`combat_integration_tests.gd`
      ajustados para o novo modelo de spawn (não automático)
- [x] `run_tests.ps1` (15 test suites, 38 scripts) e validação completa: sem SCRIPT ERROR, sem
      Parse Error, sem warning/erro de vazamento de recurso, `--quit-after 30` e `--editor --quit`
      limpos
- [x] `docs/ARCHITECTURE.md` e `docs/GAME_BIBLE.md` atualizados com as decisões reais desta fase
- [ ] Nenhuma economia premium, loja real, gacha, energia, login/backend, persistência entre
      sessões, novos dinossauros, ou arte/áudio final foi implementada — fora de escopo desta
      fase, conforme planejado

### Phase 0.6 — First Playable / UX Pass

- [x] `MainMenu.tscn` (`Control`, `main_menu.gd`) como cena de boot (`project.godot`
      `run/main_scene`, era `Main.tscn`): título, subtítulo, JOGAR/OPÇÕES/SAIR; JOGAR navega via
      `get_tree().change_scene_to_file()` nativo, sem framework de cena; sem `GameSession`/
      autoload (nenhum estado atravessa menu↔jogo); estrutura pronta para uma tela de LOGIN/
      PERFIL futura sem reestruturar
- [x] HUD: banner único reutilizável (`show_banner`/`hide_banner`) para "WAVE N" (~1s),
      "WAVE N COMPLETE! +recompensa" e "Coins insuficientes!"; overlay de pausa (PAUSADO/
      CONTINUAR/MENU) além do botão compacto existente; `GameOverOverlay` ganhou botão MENU;
      botão de dinossauro permite recolocar o Velociraptor (mais de um por partida); rótulos com
      emoji + texto (🥚/💰/🦖), fallback textual caso o glyph não renderize; botões maiores para
      toque
- [x] Placement UX: `PlacementController.can_afford_selected()` + terceira cor (âmbar) na preview
      para "válido mas sem coins" durante o hover, não só no clique; silhueta translúcida do
      dinossauro desenhada na preview (não só um retângulo); sinal `dinosaur_placed`
- [x] **Arquitetura de animação (`AnimatedVisual`, `class_name`, `scripts/visuals/`):** todo
      `Dinosaur`/`BasicEnemy`/`Egg`/`Projectile` ganhou um node `Visual` com este componente
      compartilhado — gameplay só chama `play_state(IDLE/MOVE/ATTACK/HIT/DEATH)`, nunca manipula
      `Tween`/`AnimatedSprite2D` diretamente. Hoje realizado via `Tween` procedural (sem arte
      final); pronto para um `AnimatedSprite2D`+`SpriteFrames` real substituir o fallback sem
      mudar código de gameplay. `DeathEffect` (efeito visual autônomo, nunca atrasa o
      `queue_free()` real da entidade) cobre morte, chegada ao ninho e impacto de projétil
- [x] Placeholder visual do Dinosaur trocado (triângulo → silhueta de 6 pontos);
      `DinosaurDefinition.placeholder_color` finalmente conectado (campo existia desde a Phase
      0.4 sem efeito); cor trocada para laranja (contraste contra o debug de células BUILDABLE)
- [x] Ganchos de áudio documentados (click/placement/shot/hit/death/wave start/wave complete/egg
      hit/game over → sinais existentes) — nenhum placeholder sonoro criado (sem asset de áudio
      no projeto ainda)
- [x] Testes novos: `ux_tests.gd` (Main Menu, API pública da HUD, pausa/resume/menu, banners de
      wave, segundo placement via botão), `animated_visual_tests.gd` (fallback procedural,
      `set_base_modulate`, delegação para `AnimatedSprite2D` quando disponível);
      `placement_tests.gd` expandido (`dinosaur_placed`, `can_afford_selected`)
- [x] Bug real pré-existente encontrado e corrigido: `placement_preview.gd` usava
      `PackedVector2Array([...])` como valor de `const` (não é expressão constante válida em
      GDScript), quebrando a compilação de `main.gd` por cascata — só detectado ao rodar
      `run_tests.ps1` de verdade
- [x] `run_tests.ps1` (16 test suites, 43 scripts) e validação completa: sem SCRIPT ERROR, sem
      Parse Error, sem warning/erro de vazamento de recurso; `--quit-after N` limpo tanto em
      `MainMenu.tscn` quanto em `Main.tscn`; `--editor --quit` limpo
- [x] `docs/ARCHITECTURE.md` atualizado com as decisões reais desta fase
- [ ] **Teste manual interativo real no editor Godot não foi realizado** — sem loop de
      interação visual/mouse/teclado disponível nesta sessão; validação ficou limitada a
      headless (compile-check, testes automatizados, `--quit-after N`, scan do editor). Ver
      relatório da fase para o detalhamento honesto desta limitação
- [ ] Nenhuma economia premium, loja real, login/autenticação real, persistência entre sessões,
      novos dinossauros/inimigos, upgrades, tipos de ovo, ou arte/áudio final foi implementada —
      fora de escopo desta fase, conforme planejado

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
