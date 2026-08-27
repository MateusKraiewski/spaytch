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

#### Reforço pós Phase 0.6 — feedback visual e de combate

Rodada de hardening sobre o sistema visual já entregue (sem nova numeração de fase — commit
`8b47669` já fechou a Phase 0.6; isto refina o mesmo sistema).

- [x] `AnimatedVisual`: `stop_loop()`, introspecção `last_state`/`last_loop_state` para testes;
      HIT ganhou squash de escala além do flash; ATTACK ganhou recoil de posição além do pulso de
      escala — ambos na trilha de reação já existente, API pública (`play_state`) inalterada
- [x] `Egg` ganha loop de "vivo" contínuo (IDLE saudável / pulso agitado abaixo de 30% HP),
      parado (`stop_loop()`) na destruição — antes só reagia no instante do dano, ficando estático
      entre hits
- [x] `DamageNumber` (`class_name`, novo): número de dano flutuante autônomo, mesmo padrão de
      `DeathEffect`; acionado em `BasicEnemy`/`Egg` a cada `take_damage()`
- [x] `DeathEffect` ganhou `class_name` (consistência com `DamageNumber`)
- [x] Banner de vitória distinto ("🏆 VITÓRIA!") ao completar a última wave, reaproveitando o
      sinal `WaveManager.wave_completed` já existente — não é um `GameState` novo
- [x] Auditoria mobile/HUD/placement/legibilidade contra o pedido desta rodada: nenhuma mudança de
      código necessária além da já existente (tamanhos de botão, contraste, ausência de
      dependência de hover já atendiam)
- [x] Testes expandidos: `animated_visual_tests.gd`, `egg_tests.gd`, `combat_integration_tests.gd`,
      `ux_tests.gd` — 44 scripts, 16 suítes, `run_tests.ps1` + `--quit-after N` (MainMenu e
      Main.tscn) + `--editor --quit` limpos
- [ ] Teste manual interativo real no editor Godot ainda não foi realizado (mesma limitação já
      registrada na Phase 0.6)

#### Primeiro Protótipo Visual — pixel art 16-bit original

Primeira arte real do jogo, substituindo os placeholders geométricos do Velociraptor, do
`BasicEnemy` e do chão da grid. Sem nova numeração de fase — extensão do mesmo sistema visual
(`AnimatedVisual`). Direção completa em `docs/ART_DIRECTION.md`.

- [x] Pipeline de arte mínimo estabelecido (`game/tools/`: `pixel_art_generator.gd`,
      `build_sprite_frames.gd`, `preview_contact_sheet.gd`) — o projeto não tinha nenhum antes
- [x] 6 tiles de ambiente prototipados (grama, trilha, borda trilha↔grama, arbusto, árvore,
      pedra), 32×32px, `assets/environment/`
- [x] Velociraptor: sprite original (silhueta bípede esguia, crista, cauda de equilíbrio),
      animações `idle`/`attack` reais (2 frames cada)
- [x] `BasicEnemy`: sprite original (silhueta quadrúpede atarracada, crista de espinhos —
      claramente distinto do Velociraptor), animações `move`/`hit`/`death` reais (2 frames cada)
- [x] `GridManager` desenha os tiles reais por padrão; `debug_visible` (F3) inverteu de sentido —
      vira auxílio de desenvolvimento, não a única forma de ver a grid. Nenhuma lógica de
      grid/mapa mudou
- [x] `AnimatedVisual`: reação sprite-driven (ATTACK/HIT) volta sozinha ao loop anterior ao
      terminar (`animation_finished` + `CONNECT_ONE_SHOT`) — gap real descoberto ao integrar a
      arte (sem isso o sprite ficaria congelado no último frame da reação)
- [x] `DeathEffect`: passthrough opcional do `SpriteFrames` da criatura numa morte de verdade
      (`set_death_sprite_frames()`) — chegada ao ninho/impacto de projétil continuam com o
      efeito neutro genérico
- [x] Teste novo: `visual_prototype_tests.gd` — 48 scripts, 17 suítes, `run_tests.ps1` +
      `--quit-after N` (MainMenu e Main.tscn) + `--editor --quit` limpos
- [x] 2 bugs reais encontrados e corrigidos: recorte do focinho do Velociraptor (canvas 32px) e
      `DeathEffect.set_death_sprite_frames()` acessando um `@onready` ainda não resolvido
- [x] **Transição de borda trilha↔grama só nos lados norte/sul** — resolvido no checkpoint de
      Ambiente abaixo (4 direções, derivadas por flip/transpose de pixels em vez de rotação)
- [ ] Validação visual real no editor Godot (alinhamento de tiles, legibilidade da cena completa
      com tudo junto) não foi feita — mesma limitação de sessões anteriores
- [ ] `Egg`/`Projectile` continuam com o placeholder procedural — fora do escopo desta rodada
      (só Velociraptor e `BasicEnemy` foram pedidos)

#### PHASE VISUAL ART — Checkpoint A: Ambiente

Produção do primeiro asset pack real (substitui o protótipo de 6 tiles acima por um conjunto mais
rico e original), seguindo um plano em checkpoints (A: Ambiente → B: Velociraptor → C: BasicEnemy
→ D: Ovos + Projéteis → E: Efeitos + integração final), um de cada vez, com autorização explícita
entre cada um. **Checkpoints A, B, C, D e E executados — plano completo.**

- [x] 26 assets de ambiente em `assets/environment/` (32×32, exceto tiras de borda): 4 variações
      de grama + 3 de trilha (escolhidas deterministicamente por coordenada, nunca aleatório),
      4 tiras de transição grama↔trilha (norte desenhada à mão, sul/leste/oeste derivadas por
      `flip_y`/`flip_x`/`transpose` de pixels), arbusto/árvore/pedra em tamanho pequeno e grande,
      `rock_cluster`, `stump`, e detalhes pequenos (flor amarela, flor rosa, cogumelo, folha,
      graveto, raiz, tufo de grama)
- [x] `GridManager` atualizado para escolher entre as variações e desenhar as 4 bordas via
      `draw_texture_rect()` simples (sem rotação em runtime); `OBSTACLE` agora escolhe entre 6
      decorações (era 3)
- [x] Teste novo: `environment_assets_tests.gd` (arquivos existem, dimensões corretas,
      opacidade/transparência corretas, variações realmente diferem em pixel, nada vaza para fora
      da célula) — 49 scripts, 18 suítes, `run_tests.ps1` + os 3 comandos headless obrigatórios
      limpos
- [x] 1 bug real encontrado e corrigido: proporção grama/trilha da tira de borda norte
      desbalanceada (~60–70% grama) — corrigida e confirmada por contagem objetiva de pixels
      (script descartável), não só inspeção visual da miniatura
- [x] Checkpoint E (Efeitos) concluído — ver bloco dedicado abaixo

#### PHASE VISUAL ART — Checkpoint B: Velociraptor

Redesenho completo do Velociraptor com 19 frames reais (era 4 no protótipo anterior).

- [x] Paleta: **laranja `#F28D26` mantida** — decisão final do usuário depois de uma iteração
      intermediária desta mesma etapa ter migrado para verde por instrução anterior; a imagem de
      referência do asset pack foi usada só como direção de silhueta/proporções/linguagem de
      pixel art, nunca como paleta a copiar
- [x] Canvas 48×48 (era 32×32) — folga real para poses dinâmicas sem recortar; ainda lê como uma
      torre numa célula (1.5× o tile de 32px)
- [x] Geração por pose (`_raptor_pose()`, Dictionary com defaults nomeados) em vez de parâmetros
      posicionais soltos; membros (pernas/cauda/braço) desenhados como segmentos via
      `_fill_thick_line()`, ângulo real sem rotacionar a imagem inteira
- [x] IDLE (4 frames): respiração + troca de peso entre as pernas — vivo mesmo parado
- [x] MOVE (6 frames) e HIT (3 frames): preparados para reutilização futura da infraestrutura
      visual, sem criar dependência nova de gameplay (torre não anda nem recebe dano hoje)
- [x] ATTACK (6 frames): antecipação → investida → mordida com mandíbula de dobradiça real
      (maxilar fixo, mandíbula inferior desce até 6px proporcional a `mouth_open`) → recuo
- [x] Teste novo: `velociraptor_assets_tests.gd` (arquivos existem, 48×48, transparência, nenhum
      pixel opaco toca a borda do canvas em nenhum frame, frames consecutivos realmente diferem,
      `SpriteFrames` com as 4 animações e contagem mínima de frames) — 50 scripts, 20 suítes,
      `run_tests.ps1` + os 3 comandos headless obrigatórios limpos
- [x] 2 bugs reais encontrados e corrigidos: focinho recortado no lunge do ATTACK (canvas 40×40
      inicial, corrigido para 48×48 com âncoras recentradas) e boca aberta ilegível por área
      insuficiente do polígono (corrigido com mandíbula de dobradiça real) — ambos só perceptíveis
      ampliando bem além da folha de contato padrão, não pela miniatura
- [x] `placeholder_color` de `velociraptor.tres` zerado para branco (era o mesmo laranja aplicado
      como tingimento) — com arte real, qualquer `modulate` não-branco distorce as cores desenhadas
      à mão; campo continua reservado para uso futuro
- [x] `_ENEMY_FLASH` extraída do `_draw_enemy()` do BasicEnemy — antes reaproveitava
      `_RAPTOR_LIGHT`, acoplamento indevido a uma constante de outra criatura

#### PHASE VISUAL ART — Checkpoint C: BasicEnemy

Redesenho completo do BasicEnemy com 15 frames reais (era 6 no protótipo anterior). Paleta
mantida (`#F35A1A`) — diferenciação do Velociraptor vem de plano corporal/postura, não de recolor.

- [x] Quadrúpede (4 pernas, nunca braços) baixo e largo, cauda curta arrastando perto do chão,
      cabeça larga e romba com chifre pequeno, crista de espinhos nas costas — silhueta/postura
      claramente distintas do biped esguio/alto do Velociraptor
- [x] Canvas 48×48 (era 32×32); pernas de 1 segmento só (`_draw_enemy_leg()`, sem joelho
      articulado como o raptor) — postura mais bruta por design
- [x] MOVE (6 frames): trote real, pares diagonais de pernas alternando apoio, corpo balançando
      com o passo, cauda baixa balançando lateralmente
- [x] HIT (3 frames): recuo do corpo inteiro + achatamento de impacto + focinho abre num
      resmungo de dor — reação física real, flash de cor só como complemento
- [x] DEATH (6 frames): colapso real — pernas cedem, corpo afunda e achata, crista deita, cauda
      cai no chão, olho fecha; `death` a 15fps (6 frames = 0.4s) para caber em
      `DeathEffect._LIFETIME` (constante fixa, não alterada)
- [x] Teste novo: `basic_enemy_assets_tests.gd` (mesmo padrão do Checkpoint B) — 51 scripts,
      21 suítes, `run_tests.ps1` + os 3 comandos headless obrigatórios limpos
- [x] 2 bugs reais encontrados e corrigidos: erro de tipagem (`:=` não infere tipo de divisão
      sobre campo `Variant` de Dictionary) e **fórmula de achatamento invertida** — a primeira
      versão fazia o inimigo "morrendo" ficar mais ALTO e FINO em vez de tombar achatado (só
      ficou óbvio na folha de contato ampliada, não nos números isolados); corrigido com `flatten`
      de semântica direta (menor = mais baixo E mais largo, nunca uma dimensão crescendo enquanto
      a outra encolhe)

#### PHASE VISUAL ART — Checkpoint D: Ovos + Projéteis

Redesenho completo de `Egg`/`Projectile` + primeira arte real de `DeathEffect` (era um losango
procedural genérico). Ovo em creme/palha (tema pré-histórico); projétil reaproveita a paleta do
Velociraptor.

- [x] Ovo (`assets/eggs/`, 16 frames, 32×32): silhueta de 2 elipses sobrepostas; 3 aparências
      discretas mapeadas nos estados que `egg.gd` já decidia por HP — IDLE=saudável (respiração
      sutil + brilho interno pulsando), MOVE=crítico/ferido (mesma respiração mais agitada +
      marcas de estresse), sem estado novo
- [x] HIT (3 frames): squash/recoil real (`rx`/`ry` deformam) + flash de fratura momentâneo
- [x] DEATH = destruído (5 frames, `loop=false`, congela para sempre): rachaduras → casca se
      separando → fragmento assentando → destruído (interior escuro, cacos no chão) — silhueta
      genuinamente diferente por estágio, não uma variação paramétrica da forma inteira
- [x] `egg.gd`: golpe letal chama `play_state(DEATH)` direto (era só `stop_loop()`) — DEATH nunca
      reverte sozinho, preservando "ovo continua visível quando destruído" sem mecanismo novo;
      removido o tingimento contínuo por HP (`set_base_modulate`) — com arte real, um `modulate`
      não-branco por cima distorceria as cores desenhadas à mão (mesma decisão do
      `placeholder_color` no Checkpoint B)
- [x] Projétil (`assets/projectiles/`, 4 frames, canvas 20×16): dardo/garra na paleta do
      Velociraptor, único estado usado é IDLE (sem MOVE/ATTACK/HIT/DEATH — nunca chamados); tufo
      esvoaçando + brilho percorrendo a lâmina, silhueta principal sempre legível
- [x] `DeathEffect` ganhou arte padrão real (`assets/effects/impact_0-3.png`, burst de impacto,
      4 frames a 10fps = 0.4s = `DeathEffect._LIFETIME`) — usada quando o passthrough de sprite de
      uma criatura não é chamado; `Placeholder` removido (mesmo raciocínio dos checkpoints
      anteriores: com `sprite_frames` sempre presente, o fallback nunca seria acionado)
- [x] Teste novo: `egg_projectile_assets_tests.gd` (mesmo padrão dos Checkpoints B/C, cobrindo os
      3 grupos) + teste novo em `egg_tests.gd` (DEATH não reverte para IDLE/MOVE) — 52 scripts,
      22 suítes, `run_tests.ps1` + os 3 comandos headless obrigatórios limpos
- [x] 3 bugs reais de recorte encontrados e corrigidos (nenhum visível na folha de contato
      padrão): sombra do ovo tocando a borda inferior do canvas; tufo do projétil ultrapassando a
      borda esquerda (canvas alargado de 16×16 para 20×16); raios do impacto alcançando ~14px de
      um canvas de 24×24 (raio útil ~9-10px) — fórmula original não considerava o tamanho do
      canvas

#### PHASE VISUAL ART — Checkpoint Visual de Integração

Auditoria (sem criar assets novos, sem alterar gameplay) verificando se os Checkpoints A–D
funcionam visualmente como um conjunto — escala relativa, alinhamento, sobreposição, paleta
coerente, filtro Nearest.

- [x] Captura de screenshot real via `get_viewport().get_texture()` em modo `--headless` tentada e
      travou indefinidamente — confirmado que não há forma segura disponível nesta plataforma,
      não só assumido
- [x] Alternativa usada: composição manual dos PNGs existentes com a mesma matemática de
      posicionamento real do jogo (`_pick()`, `cell_to_world()+cell_size/2`, sprite centrado)
- [x] Escala Velociraptor/BasicEnemy/Ovo/Projétil, alinhamento com o caminho e com as posições dos
      ovos, vegetação nunca em BUILDABLE, transição grama/trilha, paleta coerente entre
      categorias, e filtro Nearest (confirmado via `.import`/`project.godot`) — tudo verificado,
      **nenhum problema real encontrado, nenhuma correção necessária**

#### PHASE VISUAL ART — Checkpoint E: Efeitos

Dos 6 tipos de efeito do plano original (spawn/attack/impact/damage/death/nest-arrival),
impact/death/nest-arrival já tinham arte desde o Checkpoint D e damage continua procedural
(`DamageNumber`, fora de escopo). ATTACK já é a própria animação de mordida do Velociraptor — um
efeito separado no mesmo instante foi considerado e descartado por redundância. **Único gap real:
SPAWN** — inimigo aparecia sem nenhum reconhecimento visual.

- [x] `SpawnEffect` novo (`scripts/visuals/spawn_effect.gd` + `scenes/effects/SpawnEffect.tscn`) —
      mesmo padrão arquitetural de `DeathEffect` (autônomo, irmão da entidade, autodestrói via
      timer), reaproveita `AnimatedVisual.State.DEATH` (mesmo contrato de "um-tiro-só" que
      `DeathEffect` já reaproveita para o impacto genérico) em vez de criar um 6º estado
- [x] `EnemySpawner.spawn_enemy()` instancia o `SpawnEffect` na posição do inimigo recém-criado,
      guardado por `is_inside_tree()` (mesmo raciocínio de BasicEnemy/Projectile) — nenhuma
      mudança em HP/dano/path following/sinais
- [x] Arte (`assets/effects/spawn_0-3.png`, 24×24, 4 frames): poeira/terra subindo do chão —
      visualmente distinta do burst de impacto, paleta terrosa da família da trilha
- [x] Teste novo: `spawn_effect_assets_tests.gd` (mesmo padrão B/C/D) + teste novo em
      `integration_tests.gd` (EnemySpawner realmente gera 1 SpawnEffect) — 54 scripts, 23 suítes,
      `run_tests.ps1` + os 3 comandos headless obrigatórios limpos
- [x] 1 bug real de recorte encontrado e corrigido (só no teste automatizado, não na inspeção
      visual): multiplicadores de espalhamento/subida dos puffs de poeira colocavam pixels opacos
      na borda do canvas 24×24 no frame de pico — corrigido com folga real, não só o mínimo

#### PHASE VISUAL ART — Checkpoint F: Polimento e Integração

Auditoria de como os Checkpoints A–E funcionam JUNTOS em `Main.tscn` de verdade — sem asset novo,
sem silhueta/paleta alterada, só correções objetivas de integração.

- [x] **Bug real mais importante do projeto até aqui:** `Main.tscn` tinha `debug_visible = true`
      como override de instância no `GridManager`, nunca atualizado quando o Checkpoint A mudou o
      DEFAULT do script para `false` — a cena de produção nunca mostrou a arte pixel real por
      padrão em nenhum momento entre os Checkpoints A–E, só retângulos de cor de debug. Corrigido
      removendo o override.
- [x] `z_index = 10` em `DeathEffect.tscn`/`SpawnEffect.tscn`, `z_index = 15` em
      `DamageNumber.tscn` — antes, todos ficavam atrás de qualquer personagem/efeito que estivesse
      por cima no momento (nenhum node do projeto usava `z_index`), contrariando "efeito aparece
      sobre o alvo"
- [x] Bug real de sobreposição HUD↔mapa: `SpeedButton` (canto superior-direito) sobrepunha
      diretamente uma célula EGG do mapa real (posições conferidas em `vale_dos_ovos.tres`, não
      assumidas). Corrigido reagrupando os 4 botões numa fileira única no rodapé
- [x] `Theme` mínimo no `Root` da HUD (contorno escuro em todo `Label`) + `draw_string_outline()`
      em `DamageNumber` — texto da HUD passou a desenhar sobre a arte pixel de verdade (não mais
      sobre o fundo de debug sólido que garantia contraste de graça)
- [x] Timing de animação auditado (fps de todas as `SpriteFrames` existentes vs. métricas reais de
      gameplay, ex: `attack_interval` do Velociraptor) — nenhum ajuste necessário, tudo já coerente
- [x] Cobertura de feedback de gameplay auditada (nasceu/dano/morte/impacto/wave/GAME OVER/pausa)
      — todos já tinham sinal real conectado a reação visual antes desta etapa, nenhum efeito novo
- [x] Pontos de integração de áudio documentados (sinais existentes) — nenhum asset/AudioManager
      criado
- [x] `run_tests.ps1` (54 scripts, 23 suítes) + os 3 comandos headless obrigatórios limpos antes e
      depois das mudanças; nenhum TODO/FIXME/HACK/XXX novo; nenhum preload/load quebrado
- [ ] Validação em tela real continua pendente — captura de screenshot headless tentada
      novamente e confirmada inviável nesta plataforma (trava indefinidamente); validado só por
      composição matemática (posições exatas lidas do mapa real, não estimadas)

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
