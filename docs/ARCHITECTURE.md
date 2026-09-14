# ARCHITECTURE — SPAYTCH

Documento técnico vivo. Descreve a arquitetura do projeto conforme ela existe e evolui.
Este documento é **descritivo do estado real do código**, não um plano aspiracional — atualize-o
quando a arquitetura mudar de fato.

> Status: **Phase 0.6 — First Playable / UX Pass, concluída e validada em Godot 4.7.2.** Além do
> game loop completo (0.5), o jogo agora tem um fluxo de apresentação real: `MainMenu.tscn`
> (título, subtítulo, JOGAR/OPÇÕES/SAIR) é a cena de boot (`project.godot` `run/main_scene`);
> JOGAR navega para `Main.tscn` (o jogo em si) via `get_tree().change_scene_to_file()` nativo —
> sem framework de cena, sem `GameSession` (não necessário: nenhum estado é compartilhado entre
> menu e jogo). A HUD ganhou um banner reutilizável (`show_banner`/`hide_banner`) para "WAVE N",
> "WAVE N COMPLETE! +recompensa" e "Coins insuficientes!"; um overlay de pausa (`PAUSADO` /
> `CONTINUAR` / `MENU`, o último retorna ao Main Menu descartando a partida); um botão para
> reselecionar o Velociraptor (agora é possível colocar mais de um por partida); e rótulos com
> emoji + texto (🥚/💰/🦖) mantendo um fallback textual caso o glyph não renderize. **Toda
> apresentação visual passou a ser desacoplada de gameplay via `AnimatedVisual`** (ver
> [AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06)): cada entidade
> (`Dinosaur`/`BasicEnemy`/`Egg`/`Projectile`) reage a 5 estados padronizados
> (IDLE/MOVE/ATTACK/HIT/DEATH) através de um componente único; morte/chegada ao ninho/impacto
> ganharam um efeito visual desacoplado (`DeathEffect`) que nunca atrasa a remoção real da
> entidade. **Primeiro Protótipo Visual (pixel art 16-bit original, ver
> [seção dedicada](#primeiro-protótipo-visual) e `docs/ART_DIRECTION.md`):** Velociraptor e
> `BasicEnemy` têm sprites/animações reais próprias (`AnimatedSprite2D`, silhuetas distintas entre
> si) pela primeira vez, mais 6 tiles de ambiente (grama/trilha/borda/arbusto/árvore/pedra)
> desenhando a grid do Vale dos Ovos — `Egg`/`Projectile` continuam com o fallback procedural
> (`Tween` sobre forma primitiva), fora do escopo desta rodada. Sem economia
> premium, loja, login real, persistência, novos dinossauros/inimigos, upgrades ou multiplayer.
> Seções abaixo descrevem o que existe de fato; o que ainda não existe permanece `TBD`.
>
> **Atualização (Sprint 1 — V1):** desde o snapshot acima, o roster foi fechado em 3 espécies
> (Velociraptor/Triceratops/T-Rex, cada uma com arte PixelLab real em T1) com sistema genérico de
> tier/fusão (`species_id`+`tier`+`evolves_to` em `DinosaurDefinition`, `Fusion`/
> `PlacementController.try_fuse()`, `AuraEffect` em qualquer T3), seleção de dinossauro via popup
> na HUD, e progressão automática de waves com countdown "3,2,1,GO!" (`Main.step()`,
> determinístico, sem `get_tree().create_timer()`). Resumo funcional em
> [ROADMAP.md](ROADMAP.md#sprint-1--espécietierfusão--waves-automáticas-v1); as seções detalhadas
> abaixo (Cenas, Sistemas, PlacementController, etc.) ainda descrevem o estado até a Phase 0.6 e
> **não foram reescritas** para refletir o Sprint 1 — dívida de documentação conhecida, não
> bloqueia gameplay. Triceratops/T-Rex ficam intencionalmente sem T2/T3 nesta versão (ver
> [GAME_BIBLE.md](GAME_BIBLE.md#future-ideas)).

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
├── project.godot               # run/main_scene = MainMenu.tscn (Phase 0.6; era Main.tscn)
├── scenes/
│   ├── MainMenu.tscn            # cena de boot — título/subtítulo/JOGAR/OPÇÕES/SAIR
│   └── Main.tscn                # cena de jogo — não é mais a cena de entrada do projeto
├── scripts/
│   ├── core/
│   │   └── main.gd            # composition root da cena de jogo
│   ├── menu/
│   │   └── main_menu.gd        # navegação do Main Menu, nenhuma lógica de jogo
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
│   ├── enemies/
│   │   ├── basic_enemy.gd      # movimento + HP/dano/morte de um inimigo, Node2D
│   │   └── enemy_spawner.gd    # cria BasicEnemy a partir de Grid+MapPath; registro de ativos, Node
│   ├── dinosaurs/
│   │   ├── dinosaur_definition.gd  # Resource: dados estáticos de um dinossauro
│   │   ├── dinosaur.gd             # runtime genérico: cooldown/targeting/disparo, Node2D
│   │   └── targeting.gd            # seleção de alvo (modo FIRST), RefCounted estático
│   ├── combat/
│   │   └── projectile.gd       # movimento determinístico + dano ao impacto, Node2D
│   ├── placement/
│   │   ├── placement_controller.gd  # máquina de estados IDLE/PLACING, valida/custa/instancia, Node
│   │   └── placement_preview.gd     # highlight válido/inválido + círculo de alcance, Node2D
│   ├── economy/
│   │   └── economy.gd          # coins de partida — gastar/ganhar, Node
│   ├── waves/
│   │   ├── wave_definition.gd  # Resource: dados estáticos de uma onda
│   │   └── wave_manager.gd     # orquestra spawning ao longo do tempo, Node
│   ├── eggs/
│   │   ├── egg.gd              # runtime de um ovo: hp/dano/destruição, Node2D
│   │   └── egg_manager.gd      # cria Egg a partir do mapa, aplica dano ao alcançar o ninho, Node
│   ├── visuals/
│   │   ├── animated_visual.gd  # Phase 0.6: play_state(IDLE/MOVE/ATTACK/HIT/DEATH), Node2D
│   │   ├── death_effect.gd     # Phase 0.6: efeito visual autônomo de morte/impacto, Node2D
│   │   └── damage_number.gd    # número de dano flutuante, autônomo (mesmo padrão de death_effect.gd), Node2D
│   └── ui/
│       └── hud.gd              # HUD: só exibe e encaminha input, CanvasLayer
├── data/
│   ├── maps/
│   │   └── vale_dos_ovos.tres  # único mapa JOGÁVEL, carregado por Main.tscn
│   ├── test/
│   │   └── test_map.tres       # fixture de teste (Phase 0.1) — não é mais mapa jogável
│   ├── dinosaurs/
│   │   ├── velociraptor.tres              # único DinosaurDefinition desta fase
│   │   └── velociraptor_sprite_frames.tres  # Checkpoint B — idle/move/attack/hit (19 frames)
│   ├── enemies/
│   │   └── basic_enemy_sprite_frames.tres   # Checkpoint C — move/hit/death (15 frames)
	├── eggs/egg_sprite_frames.tres          # Checkpoint D — idle/move/hit/death (16 frames)
	├── projectiles/projectile_sprite_frames.tres  # Checkpoint D — idle (único estado usado)
	├── effects/impact_sprite_frames.tres    # Checkpoint D — arte padrão do DeathEffect (4 frames)
	├── effects/spawn_sprite_frames.tres     # Checkpoint E — arte do SpawnEffect (4 frames)
│   └── waves/
│       ├── wave_01.tres        # 5 inimigos, intervalo 1.0s
│       ├── wave_02.tres        # 8 inimigos, intervalo 0.9s
│       └── wave_03.tres        # 10 inimigos, intervalo 0.8s, hp_override 25
├── assets/                     # Primeiro Protótipo Visual — PNGs pixel art (ver seção dedicada)
│   ├── environment/             # checkpoint Ambiente — 26 PNGs: grass_01-04/path_01-03 (32×32),
│   │                            # path_edge_n/s/e/w (32×10 ou 10×32), bush/tree/rock small+large,
│   │                            # rock_cluster, stump, flower_yellow/pink, mushroom, leaf, twig,
│   │                            # root_detail, grass_tuft (32×32)
│   ├── dinosaurs/velociraptor/  # Checkpoint B — 19 PNGs 48×48: idle_0-3, move_0-5, attack_0-5,
│   │                            # hit_0-2
│   ├── enemies/basic_enemy/     # Checkpoint C — 15 PNGs 48×48: move_0-5, hit_0-2, death_0-5
│   ├── eggs/                    # Checkpoint D — 16 PNGs 32×32: idle_0-3, move_0-3, hit_0-2, death_0-4
│   ├── projectiles/             # Checkpoint D — 4 PNGs 20×16 (não quadrado): idle_0-3
│   ├── effects/                 # Checkpoint D+E — impact_0-3 e spawn_0-3 (24×24, arte padrão de
	│                             # DeathEffect/SpawnEffect); DamageNumber continua procedural
│   └── ui/                      # reservado — HUD/MainMenu continuam Label/Button padrão
├── ui/                         # vazio — HUD.tscn vive em scenes/ui/, não aqui (ver Cenas)
├── tools/                      # Primeiro Protótipo Visual — pipeline de arte, NÃO faz parte do jogo em runtime
│   ├── pixel_art_generator.gd   # desenha e salva os PNGs de assets/ (Image.set_pixel())
│   ├── build_sprite_frames.gd   # monta os .tres de SpriteFrames a partir dos PNGs já importados
│   └── preview_contact_sheet.gd # ferramenta de revisão — amplia os PNGs numa folha de contato única
└── tests/
    ├── grid_tests.gd                  # testes headless da lógica pura de Grid/MapDefinition
    ├── map_tests.gd                   # testes headless de MapValidator + do mapa Vale dos Ovos
    ├── path_tests.gd                  # testes headless de MapPath (ordenação, rejeição de dados impossíveis)
    ├── enemy_tests.gd                 # movimento + HP/dano/morte/progresso de BasicEnemy (step() puro)
    ├── integration_tests.gd           # Main.tscn real, path following ponta a ponta (spawn manual)
    ├── dinosaur_definition_tests.gd   # campos válidos do Velociraptor real
    ├── placement_tests.gd             # validade de célula + efeito real do placement + custo/economia
    ├── targeting_tests.gd             # seleção FIRST, alcance, inimigo morto/terminado
    ├── dinosaur_tests.gd              # seleção de alvo, cooldown, disparo (step() puro)
    ├── projectile_tests.gd            # movimento, impacto, dano, alvo inválido/morto (step() puro)
    ├── combat_integration_tests.gd    # Main.tscn real, combate ponta a ponta (spawn manual)
    ├── economy_tests.gd               # coins, can_afford, spend, add, sinal coins_changed
    ├── egg_tests.gd                   # Egg (hp/dano/destruição) + EggManager (derivação, seleção, sinais)
    ├── wave_tests.gd                  # WaveManager: início, contagem de spawn, conclusão, recompensas, lock
    ├── game_loop_integration_tests.gd # Main.tscn real: loop completo + cenário de dano ao ovo
    ├── ux_tests.gd                    # Phase 0.6: MainMenu carrega, API pública da HUD, pausa/resume/menu e banners de wave via Main.tscn real
    ├── animated_visual_tests.gd       # Phase 0.6: AnimatedVisual — fallback procedural, set_base_modulate, delegação p/ AnimatedSprite2D
    ├── visual_prototype_tests.gd      # Primeiro Protótipo Visual: Dinosaur/BasicEnemy usam o AnimatedSprite2D de verdade, reação volta ao loop, DeathEffect recebe sprite da criatura
    └── run_tests.ps1                  # orquestra refresh de cache + compile-check + testes
```

`data/maps/` guarda mapas jogáveis; `data/test/` guarda fixtures de dado usadas só por testes —
essa separação de pastas (feita na Phase 0.2.1) deixa a distinção explícita no próprio caminho
do arquivo, não apenas em comentário.

Desvio documentado em relação à sugestão original: a pasta `tests/` foi adicionada (não estava
na sugestão original de estrutura) para manter o código de teste separado do código de produção
em `scripts/`, seguindo convenção comum e atendendo ao requisito de testes da Phase 0.1.

## Cenas (Scenes)

Dez cenas existem: `scenes/MainMenu.tscn` (Phase 0.6), `scenes/Main.tscn`,
`scenes/enemies/BasicEnemy.tscn`, `scenes/dinosaurs/Dinosaur.tscn`, `scenes/combat/Projectile.tscn`,
`scenes/eggs/Egg.tscn`, `scenes/effects/DeathEffect.tscn`, `scenes/effects/SpawnEffect.tscn`
(Checkpoint E — ver seção dedicada), `scenes/effects/DamageNumber.tscn` e `scenes/ui/HUD.tscn`.

`scenes/MainMenu.tscn` — cena de boot do projeto (`project.godot` `run/main_scene`), sem nenhuma
dependência da cena de jogo:

```
MainMenu (Control, main_menu.gd, tela cheia)
├── Background (ColorRect)
├── TitleLabel ("SPAYTCH")
├── SubtitleLabel ("Ovos de Dinossauro Defense")
├── PlayButton   ("JOGAR"   -> get_tree().change_scene_to_file("res://scenes/Main.tscn"))
├── OptionsButton ("OPÇÕES" -> ainda sem tela própria, ver Phase 0.6)
└── QuitButton   ("SAIR"    -> get_tree().quit())
```

Hierarquia de `Main` (cena de jogo, instanciada só depois que o jogador aperta JOGAR):

```
Main (Node2D, main.gd)
├── GridManager (Node2D, grid_manager.gd)
├── InputManager (Node, input_manager.gd)
├── EnemySpawner (Node, enemy_spawner.gd)
│       └── (BasicEnemy instanciado em runtime por spawn_enemy(), chamado por WaveManager)
├── Dinosaurs (Node2D, sem script)         # container neutro — ver decisão abaixo
│       └── (Dinosaur instanciado em runtime por PlacementController)
├── Projectiles (Node2D, sem script)       # container neutro — ver decisão abaixo
│       └── (Projectile instanciado em runtime por Dinosaur)
├── PlacementController (Node, placement_controller.gd)
├── PlacementPreview (Node2D, placement_preview.gd)
├── Economy (Node, economy.gd)
├── EggManager (Node, egg_manager.gd)
│       └── (Egg instanciado em setup(), um por posição EGG do mapa)
├── WaveManager (Node, wave_manager.gd)
└── HUD (instância de scenes/ui/HUD.tscn)
```

`Main` não contém lógica de grid/input/path/inimigo/dinossauro/placement/economia/onda/ovo
própria além de: conectar sinais no `_ready()`, construir o `MapPath`, ligar `EnemySpawner` (que
não spawna mais sozinho — ver [WaveManager](#wavemanager)), ligar `EggManager`/`WaveManager`/
`PlacementController` aos sistemas de que dependem, pré-selecionar o Velociraptor, ligar a `HUD`,
e controlar o **estado da partida** (`GameState`: `PREPARING`/`WAVE_ACTIVE`/`WAVE_COMPLETE`/
`GAME_OVER`) reagindo a sinais de `WaveManager`/`EggManager` (ver
[Gerenciamento de Estado](#gerenciamento-de-estado)). Todos os nodes filhos são mutuamente
desacoplados; `Main` é o único ponto de wiring (*composition root*).

**`Dinosaurs`/`Projectiles` são containers neutros** (nodes vazios, sem script) em vez de os
`Dinosaur`/`Projectile` serem filhos de quem os cria (`PlacementController`/`Dinosaur`
respectivamente): um `Projectile` em voo não deve ser destruído se o `Dinosaur` que o disparou
for removido no futuro (venda/upgrade, fora de escopo agora, mas a estrutura já não impede isso).
`Node2D` (não `Node` puro) por convenção — mesmo espírito de `GridManager`, containers de
entidades 2D — embora um `Node` funcionasse igualmente bem (Godot ignora ancestrais não-`CanvasItem`
ao compor a transform 2D).

**Desde a Phase 0.6, `Visual` em toda entidade tem o script `animated_visual.gd`** (era um
`Node2D` neutro até a Phase 0.5) — ver
[AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06).

`scenes/enemies/BasicEnemy.tscn` (reestruturado na Phase 0.6 — antes não tinha `Visual`, o
`Placeholder` era filho direto de `BasicEnemy`; alinhado agora com o padrão já usado por
`Dinosaur`/`Egg`/`Projectile` desde a Phase 0.4/0.5):

```
BasicEnemy (Node2D, basic_enemy.gd)
└── Visual (Node2D, animated_visual.gd)
        └── Placeholder (Polygon2D)   # visual TEMPORÁRIO — triângulo laranja, ver Enemies abaixo
```

`scenes/dinosaurs/Dinosaur.tscn`:

```
Dinosaur (Node2D, dinosaur.gd)
└── Visual (Node2D, animated_visual.gd)
        └── Placeholder (Polygon2D)   # TEMPORÁRIO — silhueta de 6 pontos, laranja (Phase 0.6)
```

Placeholder trocado da Phase 0.5 (triângulo verde) para uma silhueta de 6 pontos (cabeça/costas/
cauda/barriga/peito, ver `Dinosaur.tscn`) na Phase 0.6 — "mais amigável, mas ainda claramente
placeholder", sem gerar arte final (requisito explícito). Cor trocada para laranja: o verde
anterior era próximo demais do tingimento de debug de células `BUILDABLE` na grid (mesma faixa de
matiz), reduzindo contraste (ver [Hierarquia Visual](#hierarquia-visual-phase-06)).

`scenes/combat/Projectile.tscn`:

```
Projectile (Node2D, projectile.gd)
└── Visual (Node2D, animated_visual.gd)
        └── Placeholder (Polygon2D)   # TEMPORÁRIO — losango amarelo
```

`scenes/effects/DeathEffect.tscn` (Phase 0.6 — efeito visual autônomo, ver
[AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06)):

```
DeathEffect (Node2D, death_effect.gd)
└── Visual (Node2D, animated_visual.gd)
        └── Placeholder (Polygon2D)   # TEMPORÁRIO — pequeno losango bege/neutro
```

`scenes/effects/DamageNumber.tscn` (número de dano flutuante autônomo — sem `Visual`/
`AnimatedVisual`, desenha o próprio texto via `draw_string()`, não usa Polygon2D/estados):

```
DamageNumber (Node2D, damage_number.gd)
```

`scenes/eggs/Egg.tscn`:

```
Egg (Node2D, egg.gd)
└── Visual (Node2D, animated_visual.gd)
        └── Placeholder (Polygon2D)   # TEMPORÁRIO — hexágono amarelo, escurece com o dano
```

`scenes/ui/HUD.tscn` — `CanvasLayer` com `process_mode = PROCESS_MODE_ALWAYS` (continua
respondendo mesmo com `get_tree().paused = true`, ver [Pausa](#pausa-e-velocidade)):

```
HUD (CanvasLayer, hud.gd, process_mode = ALWAYS)
└── Root (Control, tela cheia, mouse_filter = IGNORE)
    ├── EggsLabel / CoinsLabel / WaveLabel / WaveStateLabel (Label, canto superior-esquerdo)
    ├── DinosaurButton / PauseButton / SpeedButton / StartWaveButton (Button, fileira única no
    │   rodapé — Checkpoint F: PauseButton/SpeedButton moveram do canto superior-direito, onde
    │   sobrepunham células EGG do mapa real; ver seção do Checkpoint F)
    ├── BannerLabel (Label, centro, oculto por padrão — "WAVE N", "WAVE N COMPLETE!
    │   +recompensa", "Coins insuficientes!"; ver show_banner()/hide_banner())
    ├── PauseOverlay (Panel, oculto por padrão, bloqueia clique quando visível)
    │   ├── PausedLabel ("PAUSADO")
    │   ├── ResumeButton ("▶ CONTINUAR")
    │   └── PauseMenuButton ("MENU" -> volta ao MainMenu, descarta a partida)
    └── GameOverOverlay (Panel, oculto por padrão, bloqueia clique quando visível)
        ├── GameOverLabel ("GAME OVER")
        └── GameOverMenuButton ("MENU" -> volta ao MainMenu)
```

Phase 0.6: `WaveCompleteBanner` foi substituído por `BannerLabel`, um único Label reutilizável
para toda mensagem central temporária (`show_banner(text, auto_hide_after)`/`hide_banner()`) — três
elementos de UI ad-hoc ("wave iniciou", "wave completou", "coins insuficientes") para a mesma ideia
("mensagem temporária no centro da tela") seria repetição desnecessária. Rótulos de estado
permanente ganharam um emoji como prefixo (🥚/💰) com o texto completo ainda presente (`"🥚 Eggs:
3/3"`, não só `"🥚 3/3"`) — hedge deliberado contra a fonte padrão do Godot não ter cobertura de
emoji colorido (não verificável sem abrir o editor com uma tela real; se o glyph não renderizar,
o texto continua claro sozinho).

## Scripts

- Linguagem: **GDScript** (decisão do escopo desta fase; C# não foi avaliado).
- Convenção de nomenclatura: `snake_case.gd` para arquivos, `PascalCase` para `class_name`.
- Classes com `class_name` (`CellType`, `Cell`, `Grid`, `MapDefinition`, `GridManager`,
  `InputManager`, `MapValidator`, `MapPath`, `BasicEnemy`, `EnemySpawner`, `DinosaurDefinition`,
  `Dinosaur`, `Targeting`, `Projectile`, `PlacementController`, `PlacementPreview`, `Economy`,
  `WaveDefinition`, `WaveManager`, `Egg`, `EggManager`, `HUD`, `AnimatedVisual`, `DeathEffect`,
  `DamageNumber`) são registradas
  globalmente pelo
  Godot e não exigem `preload`/`load` manual — **mas o registro depende de um scan de projeto já
  ter rodado** (ver limitação documentada na
  [Phase 0.3](#phase-03--path-system--primeiro-inimigo--movimento) abaixo).
- Regra aplicada: dado configurável/estático → `Resource` (`MapDefinition`, `DinosaurDefinition`,
  `WaveDefinition`); comportamento e estado runtime → script comum (`Grid`, `Cell`, `GridManager`,
  `InputManager`, `MapPath`, `BasicEnemy`, `EnemySpawner`, `Dinosaur`, `Targeting`, `Projectile`,
  `PlacementController`, `PlacementPreview`, `Economy`, `WaveManager`, `Egg`, `EggManager`, `HUD`).

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

### DinosaurDefinition (`scripts/dinosaurs/dinosaur_definition.gd`)

`Resource` customizado representando a definição **estática e autoral** de um dinossauro
defensor — mesmo padrão de `MapDefinition`. Campos: `display_name`, `range` (px, mundo),
`attack_interval` (s, cooldown), `damage` (int), `projectile_speed` (px/s), `projectile_scene`
(`PackedScene`), `placeholder_color` (reservado, ver [Dinosaur](#dinosaur)).

**Um único `Dinosaur.tscn` genérico consome qualquer instância deste Resource.** Novos
dinossauros (Triceratops, T-Rex, ...) não exigem cena nem classe novas — só um novo `.tres` —
enquanto não precisarem de comportamento realmente especial. `velociraptor.tres` é a única
instância existente nesta fase.

`cost` (int, coins) foi adicionado na Phase 0.5 junto com a economia — antes disso não fazia
sentido existir sem nenhum sistema para consumi-lo (ver [Economy](#economy)).

**Deliberadamente sem** upgrades, habilidade especial, ícone de UI. Nenhum sistema existe ainda
para consumir esses campos.

Sem `DinosaurValidator` dedicado (diferente de `MapValidator`): campos escalares simples cabem
em asserts diretos nos testes (`dinosaur_definition_tests.gd`) — a topologia de mapa validada por
`MapValidator` é genuinamente algorítmica; validar "6 números positivos" não justifica uma classe
separada.

### WaveDefinition (`scripts/waves/wave_definition.gd`)

`Resource` customizado representando a definição **estática e autoral** de uma onda de
inimigos — mesmo padrão de `MapDefinition`/`DinosaurDefinition`. Campos: `enemy_count`,
`spawn_interval` (s), `reward_per_kill` (coins), `wave_completion_reward` (coins),
`speed_override`/`hp_override` (`<= 0` = "usar o default do `BasicEnemy.tscn`").

**Deliberadamente simples, não um sistema genérico de "wave scripting"** (múltiplos grupos de
inimigos por onda, timings compostos, eventos no meio da onda): uma wave = N inimigos do mesmo
tipo, a um intervalo fixo. `wave_01.tres`/`wave_02.tres`/`wave_03.tres` são as três instâncias
desta fase, carregadas por `Main.gd` (ver [Decisões — Phase 0.5](#decisões-técnicas--phase-05)
sobre por quê via código e não via export no `.tscn`).

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

Nesta fase existem o **sistema de grid**, a **validação de mapa**, o **sistema de path**, o
**inimigo**, o **sistema de dinossauros/torres**, o **combate**, o **placement**, a **economia**,
as **ondas** e os **ovos**:

| Camada | Arquivo | Tipo | Responsabilidade |
|---|---|---|---|
| Dado estático | `map_definition.gd` | `Resource` | Definição autoral do mapa (tipos de célula) |
| Validação | `map_validator.gd` | `RefCounted` (métodos estáticos) | Verifica invariantes de um `MapDefinition` (ver [MapValidator](#mapvalidator)) |
| Lógica runtime | `grid.gd`, `cell.gd` | `RefCounted` | Conversões coordenada↔célula, limites, estado runtime por célula (`occupied`) |
| Apresentação/Node | `grid_manager.gd` | `Node2D` | Constrói o `Grid` a partir do `MapDefinition` (após validar), desenha visual de debug, resolve posição de ponteiro → célula |
| Input | `input_manager.gd` | `Node` | Normaliza mouse/touch em sinais `pointer_moved` / `pointer_pressed` |
| Path | `map_path.gd` | `RefCounted` (fábrica estática) | Converte as células PATH de um `MapDefinition` em uma sequência ordenada de waypoints (ver [MapPath](#mappath--path-following)) |
| Inimigo | `basic_enemy.gd` | `Node2D` | Percorre waypoints, HP/dano/morte, expõe progresso no caminho (ver [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner)) |
| Spawn/registro | `enemy_spawner.gd` | `Node` | Cria `BasicEnemy` sob demanda, converte waypoints para mundo, mantém registro dos inimigos ativos |
| Dado estático | `dinosaur_definition.gd` | `Resource` | Definição autoral de um dinossauro (ver [DinosaurDefinition](#dinosaurdefinition-scriptsdinosaursdinosaur_definitiongd)) |
| Dinossauro | `dinosaur.gd` | `Node2D` | Cooldown, pede alvo a `Targeting`, dispara `Projectile` (ver [Dinosaur](#dinosaur)) |
| Targeting | `targeting.gd` | `RefCounted` (funções estáticas) | Seleciona alvo entre candidatos por alcance + modo (ver [Targeting](#targeting)) |
| Combate | `projectile.gd` | `Node2D` | Movimento determinístico até o alvo + dano ao impacto (ver [Projectile](#projectile)) |
| Placement | `placement_controller.gd` | `Node` | Máquina de estados IDLE/PLACING, valida célula, verifica/desconta custo, instancia `Dinosaur`, marca ocupação (ver [PlacementController](#placementcontroller)) |
| Preview | `placement_preview.gd` | `Node2D` | Desenha highlight de validade + alcance aproximado, sem decidir nada (ver [PlacementPreview](#placementpreview)) |
| Dado estático | `wave_definition.gd` | `Resource` | Definição autoral de uma onda (ver [WaveDefinition](#wavedefinition-scriptswaveswave_definitiongd)) |
| Economia | `economy.gd` | `Node` | `coins` de partida — `can_afford`/`spend`/`add` centralizados (ver [Economy](#economy)) |
| Ondas | `wave_manager.gd` | `Node` | Orquestra spawning ao longo do tempo, detecta conclusão, concede recompensas (ver [WaveManager](#wavemanager)) |
| Ovo | `egg.gd` | `Node2D` | HP/dano/destruição de um ovo (ver [Egg e EggManager](#egg-e-eggmanager)) |
| Registro de ovos | `egg_manager.gd` | `Node` | Cria `Egg` a partir do mapa, aplica dano ao ovo seguinte quando um inimigo alcança o ninho |
| UI | `hud.gd` | `CanvasLayer` | Exibe estado da partida, encaminha input do jogador via sinais (ver [HUD](#hud)) |
| Menu | `main_menu.gd` | `Control` | Cena de boot: título/JOGAR/OPÇÕES/SAIR, navega para `Main.tscn` |
| Apresentação | `animated_visual.gd` | `Node2D` | Estados IDLE/MOVE/ATTACK/HIT/DEATH desacoplados de gameplay (ver [AnimatedVisual](#animatedvisual-e-deatheffect-phase-06)) |
| Efeito | `death_effect.gd` | `Node2D` | Feedback visual autônomo de morte/chegada/impacto, independente do `queue_free()` da entidade |
| Efeito | `damage_number.gd` | `Node2D` | Número de dano flutuante, autônomo (mesmo padrão de `death_effect.gd`) |

Nenhuma economia premium, loja, login/conta real, persistência entre sessões, ou arte/áudio final
existe ainda.

### Targeting

`scripts/dinosaurs/targeting.gd` — funções estáticas, puramente funcionais: recebe candidatos +
origem + alcance, devolve um alvo (ou `null`). Não conhece `Dinosaur`, não dispara nada, não sabe
de projétil.

**Só o modo `FIRST` está implementado** (`enum Mode { FIRST }`): entre os candidatos dentro do
alcance (`origin.distance_to(enemy.position) <= range`, distância no mundo — requisito 8) e
ativos (`enemy.is_active()`), seleciona o de maior `BasicEnemy.get_distance_traveled()` — maior
progresso no `MapPath`, não o fisicamente mais próximo do dinossauro.

**Enum + `match` em vez de Strategy Pattern:** com um único modo implementado, uma hierarquia de
classes (`TargetingStrategy` → `FirstTargetingStrategy` → ...) seria abstração prematura.
Adicionar `LAST`/`CLOSEST`/`STRONGEST`/`WEAKEST` no futuro é só mais um `case` no `match` — a
extensibilidade já está satisfeita sem esse custo.

### Dinosaur

`scripts/dinosaurs/dinosaur.gd`, `Node2D` — runtime **genérico**: a mesma cena/script serve
qualquer tipo de dinossauro; a diferenciação vem inteiramente de `DinosaurDefinition` (dado), não
de subclasses.

- `step(delta)` (chamado por `_process`, e diretamente pelos testes — mesmo padrão de
  `BasicEnemy`/`Projectile`): decrementa cooldown; se não há alvo válido (`null`, inválido,
  inativo, ou fora de alcance), pede um novo a `Targeting`; se há alvo e cooldown zerado, dispara.
- Mantém o **mesmo alvo** enquanto ele continuar válido, em vez de re-consultar `Targeting` a
  cada frame — evita flicker de alvo e é mais barato (busca linear O(dinossauros × inimigos),
  aceitável no tamanho atual do jogo — requisito 15).
- `_fire()`: instancia `definition.projectile_scene`, adiciona ao container `Projectiles`
  (**não** como filho do próprio `Dinosaur` — ver [Cenas](#cenas-scenes)), chama
  `projectile.initialize(alvo, dano, velocidade)`, reseta o cooldown. Não implementa nenhuma
  lógica de movimento/impacto de projétil.
- `current_target()` público, só para inspeção/teste — não é usado por nenhum outro sistema
  ainda.
- `signal fired(dinosaur, projectile)` (Phase 0.5) — gancho para feedback visual; consumido pela
  primeira vez na Phase 0.6 (ver abaixo).
- **Visual separado (`Visual`):** `Dinosaur.tscn` tem uma subárvore `Visual` dedicada (placeholder
  `Polygon2D` hoje) — a lógica de gameplay não sabe nada sobre o CONTEÚDO da apresentação (forma,
  número de nodes internos).
- **`placeholder_color` conectado (Phase 0.6):** `setup()` agora tinge `$Visual.modulate` com
  `definition.placeholder_color`. Revisão da decisão da Phase 0.4 (que deixava isso deliberadamente
  desconectado por medo de acoplar `dinosaur.gd` a "Visual contém um Polygon2D"): `modulate` é
  propriedade genérica de qualquer `CanvasItem`, então tingir `$Visual` (o node container, não o
  `Polygon2D` dentro dele) não cria essa dependência — continua funcionando sem nenhuma mudança no
  dia em que `Visual` virar um `Sprite2D`/`AnimatedSprite2D` com arte final.
- **Feedback de disparo (Phase 0.6):** `_fire()` chama `_play_fire_pulse()` — um pequeno pulso de
  `scale` em `$Visual` via `Tween`, revertendo sozinho (~0.12s). Guardado por `is_inside_tree()`:
  `create_tween()` exige uma `SceneTree` válida, e vários testes de `dinosaur_tests.gd` instanciam
  `Dinosaur.new()` sem `add_child()` — sem essa guarda, todo teste que chama `_fire()`
  indiretamente (via `step()`) quebraria.

### Projectile

`scripts/combat/projectile.gd`, `Node2D` — entidade de combate **separada** do `Dinosaur`; não
conhece cooldown nem targeting, só sabe perseguir um alvo e aplicar dano.

- **Sem física, sem `Area2D`:** movimento determinístico igual a `BasicEnemy`/`Dinosaur`
  (`step(delta)` público); "impacto" é uma checagem de distância (`distância ≤ quanto o projétil
  pode se mover neste passo`), não colisão real.
- **Homing simples, sem predição de mira:** persegue a posição *atual* do alvo a cada passo — não
  calcula onde o alvo estará (exigiria conhecer velocidade/trajetória futura do inimigo,
  complexidade não necessária para este vertical slice).
- Alvo inválido (`not is_instance_valid`) ou inativo (`not is_active()` — morto ou já chegou ao
  ninho) a qualquer momento do voo: o projétil se autodestrói **sem** causar dano ("miss"
  silencioso), sem tentar acessar um Node possivelmente já liberado.
- `_MAX_LIFETIME` (5s): rede de segurança defensiva contra dados degenerados — não deveria ser
  atingida em uso normal.
- `signal impacted(projectile, target)` (Phase 0.5) — gancho para feedback visual, emitido só em
  acerto real (não em "miss"), logo antes de `_target.take_damage()`.
- **Feedback de impacto (Phase 0.6):** em vez de reagir ao próprio `impacted` com um efeito
  separado, o "impacto" reaproveita o flash de dano do próprio `BasicEnemy` (ver
  [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner)) — o impacto É o que causa o dano, então
  um efeito distinto seria redundante. O `Projectile` em si ganha só um "pop" instantâneo de
  `scale` (sem `Tween`, um único `set()`) no frame em que se destrói, guardado por
  `is_inside_tree()`.

**Bug real encontrado e corrigido nesta fase** (ver
[Phase 0.4](#phase-04--dinosaurtower-system) abaixo): a checagem de "chegou perto o suficiente"
comparava contra um epsilon fixo pequeno em vez de contra `speed * delta` (quanto o projétil pode
efetivamente se mover naquele passo) — com um único `step()` de delta grande o bastante para
cobrir toda a distância até o alvo, o impacto (e o dano) só era detectado no **próximo** `step()`,
não no mesmo. Corrigido comparando contra `speed * delta + epsilon`, igual ao critério de
chegada já usado em `BasicEnemy`.

### PlacementController

`scripts/placement/placement_controller.gd`, `Node` — máquina de estados simples:

```
IDLE ──select_dinosaur(definition)──► PLACING ──clique/toque em célula válida──► (coloca) ──► IDLE
```

- **`IDLE`**: nenhum dinossauro selecionado; input de placement ignorado.
- **`PLACING`**: um `DinosaurDefinition` está selecionado; hover (PC) atualiza estado de preview;
  um clique/toque em célula válida coloca o dinossauro e volta para `IDLE`; em célula inválida,
  **permanece em `PLACING`** para permitir nova tentativa (decisão não especificada
  explicitamente — ver [Decisões — Phase 0.4](#decisões-técnicas--phase-04)).
- **Sem UI de seleção de dinossauro nesta fase.** `initial_definition` (`@export`) permite
  pré-selecionar o Velociraptor automaticamente em `Main._ready()`, simulando "o jogador já
  escolheu". `select_dinosaur(definition)` é o único ponto de entrada para trocar a seleção —
  genérico o suficiente para uma UI futura chamar com qualquer `DinosaurDefinition`, sem exigir
  nenhuma mudança nesta classe (requisito: arquitetura preparada para múltiplos dinossauros
  selecionáveis).
- **Validade de célula (`is_valid_placement`, público):** `grid.is_in_bounds(coord) and
  cell.is_buildable() and not cell.occupied`. PATH/SPAWN/NEST/EGG/OBSTACLE já excluídos por
  `is_buildable()`. Célula ocupada continua pertencendo ao **runtime** `Cell.occupied`
  (`Grid`/`Cell`), nunca a `MapDefinition` — `Cell.occupied` já existia desde a Phase 0.1
  (comentário previa exatamente este uso futuro) e ganha aqui seu primeiro consumidor real.
  `Cell.occupied` **nunca volta a `false`** nesta fase — não existe mecânica de remover/vender um
  dinossauro ainda.
- **Zero mudanças em `GridManager`** para esta fase: `PlacementController` recebe o `Grid` já
  construído via `setup()` (mesmo padrão de `EnemySpawner`), não precisa de nenhuma API nova de
  `GridManager`.
- **Nenhuma lógica de combate aqui** — cooldown, targeting e disparo vivem inteiramente em
  `Dinosaur`/`Targeting`/`Projectile`.
- PC e Android compartilham exatamente o mesmo fluxo: `on_pointer_pressed` (clique ou toque, via
  `InputManager` já existente, sem nenhuma mudança nele) confirma o placement. Hover
  (`on_pointer_moved`) só atualiza o estado de preview visual — nunca é exigido para confirmar
  (requisito Android: não depender de hover para gameplay).
- **Custo (Phase 0.5):** a checagem de coins acontece **só na confirmação** (`on_pointer_pressed`),
  não durante o hover/preview — a validade de célula (verde/vermelho) reflete só BUILDABLE+livre,
  nunca capacidade de pagar; essa ordem (célula válida → confirmar → verificar coins → descontar)
  é a mesma da especificação. Sem coins suficientes: nada é descontado, nenhum `Dinosaur` é
  instanciado, o controller permanece em `PLACING`, e `placement_failed("insufficient_coins")` é
  emitido (mais um `print()` de log) — a HUD reage a esse sinal mostrando um banner (ver
  [HUD](#hud)).
- **`signal dinosaur_placed(dinosaur, coord)` (Phase 0.6):** emitido em `_place_dinosaur()`, depois
  que o dinossauro já existe e a célula já está ocupada — gancho de feedback (visual/áudio) para um
  placement bem-sucedido, sem nenhum consumidor obrigatório ainda.
- **`can_afford_selected() -> bool` (Phase 0.6):** consulta pura (mesmo espírito de
  `is_valid_placement()`) usada por `PlacementPreview` para colorir a célula de hover como
  "válida mas sem coins suficientes" **antes** do jogador tentar confirmar, não só no clique.

### PlacementPreview

`scripts/placement/placement_preview.gd`, `Node2D` — só desenha; nunca decide validade nem
altera estado. Lê `PlacementController.state` / `.hovered_coord` / `.is_hover_valid` /
`.selected_definition` (leitura pública) e redesenha só quando `PlacementController.preview_changed`
dispara (mudança real de estado) — mesmo padrão de `GridManager` (redraw orientado a mudança, não
por frame). Desenha um retângulo na célula sob o cursor com três estados de cor (Phase 0.6): verde
(válida e paga), âmbar (válida mas `not can_afford_selected()` — feedback de coins insuficientes
já durante o hover), vermelho (inválida); um círculo translúcido do raio `definition.range`; e,
desde a Phase 0.6, uma silhueta translúcida do dinossauro (mesmos pontos de
`Dinosaur.tscn`/`Placeholder`, duplicados aqui deliberadamente — ambos são placeholder e serão
substituídos juntos pela arte final, então uma `Resource` compartilhada só para isso seria
overengineering nesta fase) tingida com a mesma cor de validade — requisito "mostrar o
sprite/placeholder do dinossauro durante o placement", não só um retângulo na célula.

### Economy

`scripts/economy/economy.gd`, `Node` — `coins` de partida: estado runtime mutável, não
`Resource` (mesmo raciocínio de `Cell.occupied`: dado que muda durante o jogo não deve viver num
Resource potencialmente compartilhado). Só `starting_coins` é configuração (`@export`, mesmo
padrão de `GridManager.map_definition`).

Regras centralizadas: `can_afford(amount)`, `spend(amount) -> bool` (retorna `false` e não
desconta nada se insuficiente) e `add(amount)` são os únicos pontos que tocam `coins` — quem quer
gastar/conceder moedas chama estes métodos, nunca lê/escreve `coins` diretamente de fora (por
convenção; GDScript não impõe privacidade real). Emite `coins_changed(new_amount)` a cada
mudança real (não em `spend()` que falha).

`reset()` público e separado de `_ready()`: mesmo motivo de `BasicEnemy.initialize()` — `_ready()`
só dispara quando o node entra numa `SceneTree`, e testes que instanciam `Economy.new()`
diretamente (sem `add_child`) precisam de um jeito de inicializar `coins` que funcione nos dois
contextos.

Sem loja, sem moeda premium, sem persistência — fora de escopo desta fase.

### WaveManager

`scripts/waves/wave_manager.gd`, `Node` — orquestra **quando** e **quantos** inimigos spawnar,
com base numa sequência de `WaveDefinition`. Responsabilidade distinta de `EnemySpawner` (que só
sabe criar UM inimigo por chamada e rastrear quem está vivo); combinar as duas faria
`EnemySpawner` acumular estado/timing de onda além de criação — candidato real a God Object.
Mantidas separadas por **composição**: `WaveManager` **usa** `EnemySpawner.spawn_enemy()` /
`.get_active_enemies()`, não os substitui nem duplica a lógica.

**Máquina de estados mínima** (`IDLE` / `SPAWNING` / `WAITING_FOR_CLEAR`):
`start_next_wave()` é ignorado se já houver uma wave ativa, se estiver travado (`lock()`, ver
Game Over abaixo), ou se não houver próxima wave — não permite duas waves simultâneas.

`step(delta)` (chamado por `_process` e diretamente pelos testes — mesmo padrão de
`BasicEnemy`/`Dinosaur`/`Projectile`): acumula tempo desde o último spawn; ao atingir
`spawn_interval`, chama `EnemySpawner.spawn_enemy(speed_override, hp_override)`; ao atingir
`enemy_count`, passa para `WAITING_FOR_CLEAR`; a wave só **completa** quando
`EnemySpawner.get_active_enemies()` fica vazia (nenhum inimigo spawnado por ela continua vivo/em
trânsito) — só então concede `wave_completion_reward` e emite `wave_completed`.

**Recompensas:** `wave_completed` concede `wave_completion_reward` diretamente em
`_complete_wave()`. `reward_per_kill` é concedido reagindo a `EnemySpawner.enemy_died` (não
`BasicEnemy.died` diretamente — ver [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner)),
usando os dados da wave **atual** (`current_wave_index`) — seguro porque waves são estritamente
sequenciais/não sobrepostas, então nenhum inimigo "órfão" de uma wave anterior pode estar vivo
quando a próxima começa.

**`lock()`** (chamado por `Main.gd` no GAME_OVER): trava permanentemente — nenhum spawn adicional
acontece e nenhuma wave nova começa, mesmo se `step()`/`start_next_wave()` continuarem sendo
chamados.

### Egg e EggManager

**`Egg`** (`scripts/eggs/egg.gd`, `Node2D`) — objeto real de gameplay (Phase 0.5), não mais dado
abstrato do mapa: `max_hp`/`hp`/`is_destroyed()`/`take_damage()`, mesmo padrão de `BasicEnemy`.
Placeholder visual reage ao dano de duas formas combinadas: um tingimento **permanente** por
fração de HP (fica mais vermelho conforme perde HP, cinza quando destruído — Phase 0.5) e, desde a
Phase 0.6, um **flash breve** (`Tween` de `modulate`, branco → cor permanente em 0.15s) marcando o
instante exato do dano. Guardado por `is_inside_tree()` (`create_tween()` exige uma `SceneTree`
válida): `egg_tests.gd` instancia `Egg.new()`/chama `initialize()` sem `add_child()` em vários
casos, e sem essa guarda esses testes quebrariam; fora de uma árvore, `modulate` é setado
diretamente (sem animação), preservando o comportamento síncrono que os testes já esperavam.

**`EggManager`** (`scripts/eggs/egg_manager.gd`, `Node`) — cria um `Egg` por posição EGG do mapa.
**Posições vêm de `MapDefinition.get_egg_positions()` — não duplicadas em nenhum outro Resource**
(requisito explícito; mesma regra já valia para spawn/nest/buildable desde a Phase 0.2).

**Regra determinística de seleção:** ao receber `EnemySpawner.enemy_reached_nest`, dano vai para
o **primeiro ovo ainda vivo**, na mesma ordem derivada de `get_egg_positions()` (row-major) — não
é "o mais próximo" nem aleatório, propositalmente simples (requisito 5 da especificação). O
mesmo handler chama `enemy.queue_free()` logo em seguida — é aqui, não em `BasicEnemy`, que a
decisão "remover o inimigo após causar dano ao ovo" é tomada (`BasicEnemy` continua sem se
autodestruir sozinho ao `reached_nest`, mesma decisão da Phase 0.3; quem consome o evento é quem
decide o que fazer depois).

`all_eggs_destroyed` é emitido uma única vez (`_all_destroyed_emitted`), consumido por `Main.gd`
para acionar GAME_OVER.

### HUD

`scripts/ui/hud.gd`, `CanvasLayer` — só **exibe** estado e **encaminha** intenção do jogador via
sinais (`start_wave_pressed`, `pause_pressed`, `resume_pressed`, `menu_pressed`, `speed_pressed`,
`dinosaur_button_pressed`); não decide nada sozinha — `Main.gd` decide o que fazer com cada sinal.
Mesmo princípio de `PlacementPreview` (visual, não lógica de jogo).

Métodos públicos (`set_coins`, `set_wave`, `set_wave_state`, `set_eggs`,
`set_dinosaur_button_label`, `show_banner`/`hide_banner`, `show_pause_overlay`/
`hide_pause_overlay`, `show_game_over`, `set_pause_label`, `set_speed_label`) são a única
superfície que o resto do jogo toca — trocar `Label`/`Panel` por arte final depois não exige mudar
quem chama esses métodos.

`process_mode = PROCESS_MODE_ALWAYS` (setado em `HUD.tscn`, não em código): é o que permite a HUD
continuar respondendo aos próprios botões mesmo com `get_tree().paused = true` — ver
[Pausa e Velocidade](#pausa-e-velocidade) abaixo. `Root.mouse_filter = IGNORE` deixa cliques sem
alvo (fora de botões) passarem para `_unhandled_input`/`InputManager`, para não bloquear
placement.

**Botão de dinossauro (Phase 0.6):** `DinosaurButton` reseleciona `initial_definition` sempre que
`PlacementController` está `IDLE` (`Main._on_dinosaur_button_pressed()`). Antes deste botão
existir, o jogador só conseguia colocar exatamente **um** Velociraptor por partida (a pré-seleção
automática do início) — `PlacementController` já suportava múltiplos placements via API
(`select_dinosaur()` genérico desde a Phase 0.4), só não havia como o jogador acionar isso de
novo pela UI. Não é profundidade de jogo nova, só torna utilizável uma capacidade que já existia.

### Pausa e Velocidade

Ambos usam mecanismos **nativos** do Godot, não código customizado de timing:

- **Pausa:** `Main._on_pause_pressed()`/`_on_resume_pressed()`/`_unpause()` alternam
  `get_tree().paused`. Todo node de gameplay usa o `process_mode` padrão
  (`PROCESS_MODE_INHERIT`), então `BasicEnemy`/`Dinosaur`/`Projectile`/`WaveManager` (todos com
  lógica em `_process(delta)` → `step(delta)`) simplesmente **param de ser chamados** pelo motor
  quando pausado — zero mudança de código nessas classes. Só a `HUD` tem `process_mode = ALWAYS`,
  para os próprios botões continuarem funcionando.
- **Overlay de pausa (Phase 0.6):** ao pausar, `HUD.show_pause_overlay()` mostra "PAUSADO" +
  `ResumeButton` ("▶ CONTINUAR") + `PauseMenuButton` ("MENU"), além do botão compacto de
  pausa/resume que já existia no canto superior — ambos levam ao mesmo `_unpause()`. `MENU`
  (`Main._on_menu_pressed()`) despausa **antes** de trocar de cena
  (`get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")`) — `get_tree().paused` é uma
  propriedade global da árvore, não por-cena; sem esse reset o Main Menu nasceria pausado. Voltar
  ao menu descarta a partida atual (permitido explicitamente nesta fase — sem `GameSession` ou
  equivalente para preservar estado, ver [Phase 0.6](#phase-06--first-playable--ux-pass)).
- **Velocidade x1/x2:** `Main._on_speed_pressed()` alterna `Engine.time_scale` entre `1.0` e
  `2.0`. `Engine.time_scale` escala uniformemente o `delta` recebido por todo `_process()`/
  `_physics_process()` do projeto — de novo, zero mudança nos `step()` já existentes (inclusive os
  `Tween`s de `AnimatedVisual`, que também são escalados por `time_scale` por padrão — ver
  [AnimatedVisual](#animatedvisual-e-deatheffect-phase-06)). `Main._ready()` reseta
  `Engine.time_scale = 1.0` explicitamente (é uma propriedade global do motor, não por-cena — sem
  esse reset, uma instância anterior de `Main` que tivesse ativado x2 vazaria esse estado para a
  próxima, relevante principalmente em testes que instanciam `Main.tscn` mais de uma vez no mesmo
  processo).

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

- `speed: float`, `max_hp: int` (`@export`) — **TBD/placeholder balance**, valores só para
  visualização/teste (`60.0` px/s, `20` hp), não são números de design final.
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

**HP, dano e morte (Phase 0.4):** `take_damage(amount)` (API pública genérica — qualquer coisa
pode chamar, hoje só `Projectile`) reduz `hp`; ao chegar a 0, `_die()` marca `is_dead()` e emite
`died(self)` **antes** de `queue_free()` (ordem importa: `queue_free()` é diferido, então quem
escuta `died` precisa reagir de forma síncrona, ex: remover o inimigo de um registro, antes do
Node realmente sumir). `is_active()` = `not (_finished or _dead)`, usado por `Targeting`/
`Projectile` para ignorar inimigos que não são mais alvos válidos sem cada um checar os dois
estados separadamente. `take_damage()` e `step()` não fazem nada se `not is_active()` (inimigo
morto não se move nem pode ser dano dobrado por dois projéteis no mesmo frame).

**Dano aos ovos (Phase 0.5):** `egg_damage: int` (`@export`, TBD/placeholder balance) — quanto
dano este inimigo causa a um ovo ao alcançar o ninho. Vive em `BasicEnemy` (não em `EggManager`
nem hardcoded em nenhum lugar) pelo mesmo raciocínio de `speed`/`max_hp`: é um dado intrínseco do
inimigo, extensível se tipos de inimigo diferentes existirem no futuro. `BasicEnemy` só carrega
esse número — quem realmente aplica dano a um ovo é `EggManager`, reagindo ao sinal
`reached_nest` (ver [Egg e EggManager](#egg-e-eggmanager)); `BasicEnemy` continua sem conhecer
`Egg`/`EggManager` diretamente. `signal damaged(enemy, amount)` também foi adicionado — gancho
para feedback visual futuro, emitido em `take_damage()` antes da checagem de morte.

**Progresso no caminho — `get_distance_traveled()` (requisito 7):** distância acumulada (px de
mundo) percorrida desde o SPAWN, atualizada em cada sub-passo de `step()`. Deliberadamente **não
normalizada** (0–1): `BasicEnemy` não precisa conhecer o comprimento total do `MapPath` para isso
ser útil — `Targeting` (modo FIRST) só precisa de valores comparáveis entre inimigos do mesmo
mapa, não de uma fração. Isso mantém `BasicEnemy` completamente **independente de
Dinosaur/Targeting** — ele só registra um fato sobre si mesmo (quanto andou), sem saber que
alguém vai usar isso para escolher alvos.

**Gotcha de inicialização de `hp` (descoberto durante a implementação):** `hp` é resetado dentro
de `initialize(waypoints)`, não em `_ready()` nem como inicializador de campo (`var hp := max_hp`
no corpo da classe). Dois motivos: (1) um inicializador de campo capturaria o valor **default do
script** de `max_hp`, não um valor sobrescrito depois via `.tscn` ou por um teste, porque
inicializadores de campo rodam durante a construção, antes de overrides de `@export` serem
aplicados; (2) `_ready()` só dispara quando o node entra numa `SceneTree` — testes que instanciam
`BasicEnemy.new()` diretamente (padrão já estabelecido desde a Phase 0.3) nunca chamam
`add_child()`, então `_ready()` nunca rodaria, deixando `hp` incorretamente zerado. Como
`initialize()` já era o ponto de entrada estabelecido de "preparar este inimigo para uma corrida"
— chamado tanto por `EnemySpawner.spawn_enemy()` quanto por todo teste existente — colocar a
inicialização de `hp` ali resolve os dois problemas de uma vez, sem precisar de um novo método.

Visual: `scenes/enemies/BasicEnemy.tscn` = `BasicEnemy` (script) + `Polygon2D` filho (triângulo
laranja simples). **Placeholder explicitamente temporário** — substituível por
`Sprite2D`/`AnimatedSprite2D` sem tocar em `basic_enemy.gd` (a lógica de movimento não sabe nada
sobre a apresentação visual).

**`EnemySpawner`** (`scripts/enemies/enemy_spawner.gd`, `Node`, não `Node2D` — sem identidade
espacial própria, mesmo raciocínio de `InputManager`) — recebe `Grid` e `MapPath` já prontos via
`setup()` (chamado por `Main`), e em `spawn_enemy(speed_override, hp_override)`: instancia
`BasicEnemy` a partir de `enemy_scene` (`@export PackedScene`), aplica os overrides opcionais
(`<= 0` = "usar o default do `.tscn`" — vindos de um `WaveDefinition`, mas `EnemySpawner` não
sabe disso, só recebe dois números), converte os waypoints do `MapPath` (grid) para mundo via
`Grid.cell_center_world()`, chama `initialize()`, e conecta aos sinais do inimigo. Reemite como
`enemy_reached_nest(enemy)` e `enemy_died(enemy)` (sinais do próprio spawner) — quem precisa
saber de mortes/chegadas (`WaveManager`, `EggManager`) escuta o spawner, não cada `BasicEnemy`
individualmente.

**Registro de inimigos ativos (`get_active_enemies()`):** `EnemySpawner` mantém
`_active_enemies: Array[BasicEnemy]`, adicionando cada inimigo em `spawn_enemy()` e removendo
quando ele: morre (`died`), chega ao ninho (`reached_nest`), ou é removido da árvore por
qualquer outro motivo (`tree_exited` — rede de segurança; `Array.erase()` não faz nada se o
elemento já não estiver presente, então é seguro conectar os três sem risco de remoção
duplicada causar erro). Consumido por `Dinosaur`/`Targeting` (escolher alvos) e por
`WaveManager` (detectar conclusão de wave).

**Deliberadamente NÃO extraído para uma classe `EnemyRegistry`/`EnemyManager` separada**
(explicitamente pedido para não criar, de novo, na Phase 0.5): a previsão feita na Phase 0.4 se
confirmou — `WaveManager` (Phase 0.5) de fato precisa dessa lista, e `EnemySpawner` já a mantinha
antes de `WaveManager` existir.

**Spawn não é mais automático nem único (mudança da Phase 0.5):** `Main._ready()` só chama
`_enemy_spawner.setup(...)` — quem decide **quando** e **quantos** `spawn_enemy()` chamar é
`WaveManager`, disparado pelo jogador via HUD. `EnemySpawner` continua sem saber nada sobre
waves — só cria UM inimigo por chamada, com os parâmetros que recebe.

### AnimatedVisual e DeathEffect (Phase 0.6)

**Regra do projeto a partir desta fase: nenhuma entidade fica visualmente estática como solução
definitiva.** `scripts/visuals/animated_visual.gd` (`class_name AnimatedVisual`, `Node2D`) é a
camada de apresentação compartilhada por `Dinosaur`/`BasicEnemy`/`Egg`/`Projectile` — cada uma tem
um node filho `Visual` com este script (em vez de um `Node2D` neutro, como era até a Phase 0.5).
Gameplay nunca manipula `Tween`/`Polygon2D`/`AnimatedSprite2D` diretamente; só chama
`_visual.play_state(AnimatedVisual.State.X)` com um dos 5 estados padronizados
(`IDLE`/`MOVE`/`ATTACK`/`HIT`/`DEATH`).

**Como é realizado hoje, sem pixel art final:** `play_state()` primeiro tenta uma animação de
mesmo nome (`"idle"`/`"move"`/`"attack"`/`"hit"`/`"death"`) num `AnimatedSprite2D` filho, se
existir e tiver essa animação em `sprite_frames`. Sem isso — o caso de hoje, em todo entity do
jogo — cai num fallback **procedural**: `Tween` simples sobre `rotation`/`scale`/`modulate` do
próprio `Visual`, usando só a engine, sem nenhum asset. É a "camada equivalente adequada" ao
`AnimatedSprite2D` para esta fase: no dia em que houver arte final, basta adicionar um
`AnimatedSprite2D` com `SpriteFrames` contendo animações "idle"/"move"/etc. como filho de
`Visual` — o fallback procedural para de ser usado automaticamente (a checagem
`sprite_frames.has_animation(name)` passa a ser verdadeira), **sem mudar uma linha de código de
gameplay**. Nenhuma arte final foi criada nesta fase — só a estrutura pronta para recebê-la.

**Duas trilhas de `Tween` independentes**, cada uma só mexendo nas suas próprias propriedades
(evita duas animações concorrentes brigando pela mesma propriedade no mesmo frame):

| Trilha | Estados | Propriedade | Comportamento |
|---|---|---|---|
| `_loop_tween` | IDLE, MOVE | `rotation` | looping infinito (`set_loops()`); MOVE balança mais rápido/perceptível que IDLE |
| `_reaction_tween` | ATTACK, HIT, DEATH | `scale` / `modulate` | um tiro só, sempre reiniciado (`kill()` do anterior) |

**"Feedback de spawn" embutido:** a primeira vez que qualquer estado de loop toca (IDLE ou MOVE),
a entidade nasce pequena e cresce até o tamanho normal (usa a trilha de reação, já que loop nunca
toca `scale`) — em vez de simplesmente aparecer estática no mapa. Cobre o requisito sem precisar
de um 6º estado dedicado.

**`base_modulate` + `set_base_modulate()`:** cor de "repouso" para onde HIT sempre relaxa de
volta. `Egg` a atualiza a cada mudança de HP (tingimento permanente por fração de vida,
comportamento que já existia desde a Phase 0.5) e `Dinosaur` a usa para
`DinosaurDefinition.placeholder_color` (ver [Dinosaur](#dinosaur)). `set_base_modulate()` (não só
setar o campo) existe porque um tingimento permanente precisa aparecer **na hora**, não só na
próxima vez que uma animação HIT tocar.

**Guarda universal `is_inside_tree()`** (dentro do próprio `play_state()`, não em cada chamador):
`create_tween()` exige uma `SceneTree` válida, e várias suítes de teste (`enemy_tests.gd`,
`dinosaur_tests.gd`, `egg_tests.gd`, `projectile_tests.gd`) instanciam entidades via `.new()` sem
`add_child()`, onde nenhum `Visual` sequer chega a existir (`@onready` nunca dispara). Cada
chamador (`BasicEnemy`/`Dinosaur`/`Egg`/`Projectile`) já checa `if _visual != null` antes de
chamar `play_state()`/`set_base_modulate()` — isso cobre o caso de `_visual` nunca ter sido
resolvido; `play_state()` cobre o caso (mais raro) de `_visual` existir mas o node ainda não estar
numa árvore viva.

**`DeathEffect`** (`scripts/visuals/death_effect.gd` + `scenes/effects/DeathEffect.tscn`) — efeito
visual autônomo para morte de inimigo, chegada ao ninho, e impacto de projétil. **Nunca** fica no
caminho crítico de remoção da entidade: `BasicEnemy._die()`/`_advance_waypoint()` (chegada) e
`Projectile.step()` (impacto) continuam chamando `queue_free()` **imediatamente**, exatamente como
antes — adiar isso para "esperar a animação terminar" arriscaria travar testes headless que não
bombeiam frames reais depois da morte/impacto (vários chamam `take_damage()` e seguem direto para
a próxima asserção). Em vez disso, a entidade que está desaparecendo instancia um `DeathEffect`
como **irmão** de si mesma (`get_parent().add_child(effect)` — o próprio `EnemySpawner`/container
de projéteis, que já sobrevive à entidade), toca `AnimatedVisual.State.DEATH` no próprio
`_ready()`, e se autodestrói sozinho via `get_tree().create_timer(0.4).timeout.connect(queue_free)`
— sem exigir nenhum acompanhamento externo. Como fica dentro da árvore de cena, é limpo
normalmente pelo shutdown do motor/`main.free()` em qualquer teste, mesmo se o timer nunca
disparar de verdade (testes que não bombeiam frames reais depois de spawná-lo).

**Por que não atrasar o `queue_free()` real em vez de duplicar um efeito:** foi a primeira opção
considerada e descartada. `queue_free()` já é deferred (não instantâneo), mas atrasá-lo por uma
animação inteira (~0.3–0.4s) faria um teste que chama `take_damage(lethal)` e verifica
`not is_instance_valid(enemy)` logo em seguida falhar, a menos que o teste também esperasse um
tempo real equivalente — fragilidade exatamente do tipo que este projeto vem evitando desde a
Phase 0.2.1 (harness de testes). Decoupling via node irmão evita o problema inteiro: o estado
lógico (`is_active()`, remoção de `EnemySpawner._active_enemies`) continua imediato; só a
apresentação visual tem vida própria.

**`Egg` não usa `DeathEffect`/`DEATH`:** o ovo não se move nem é removido da cena quando destruído
(continua visível, só visualmente "morto" — cinza, comportamento desde a Phase 0.5). Usar o
estado DEATH (que desaparece por completo, `modulate:a -> 0`) seria errado para um objeto que
precisa continuar visível — por isso `Egg` só usa HIT (flash + tingimento permanente), inclusive
na destruição.

**Bug real encontrado e corrigido nesta fase:** `PackedScene.instantiate()` retorna `Node`, não
`Node2D` — `var effect := _DEATH_EFFECT_SCENE.instantiate()` seguido de
`effect.global_position = ...` é um erro de tipagem estático (`Node` não tem `global_position`).
Corrigido com `as Node2D` explícito em `BasicEnemy._spawn_death_effect()` e
`Projectile._spawn_impact_effect()` — encontrado pelo compile-check individual do
`run_tests.ps1`, não por inspeção manual.

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

`InputManager` expõe `pointer_moved(world_pos)` e `pointer_pressed(world_pos)`. `GridManager` e
`PlacementController` expõem métodos públicos (`on_pointer_moved`/`on_pointer_pressed`), sem
conhecer quem os chama nem um ao outro — `Main.gd` (composition root) conecta ambos ao mesmo par
de sinais do `InputManager` no `_ready()` (Godot suporta múltiplos listeners no mesmo sinal
nativamente). Mesmo padrão para os sistemas novos da Phase 0.5: `EggManager` escuta
`EnemySpawner.enemy_reached_nest` diretamente (não é `Main.gd` que intermedia), `WaveManager`
escuta `EnemySpawner.enemy_died` diretamente, e `HUD` só emite sinais de intenção
(`start_wave_pressed`/`pause_pressed`/`resume_pressed`/`menu_pressed`/`speed_pressed`/
`dinosaur_button_pressed`) — quem decide o que fazer com cada um é sempre `Main.gd`. Nenhum desses
nodes tem referência direta a outro além do que recebe via `setup()`. `MainMenu` não se conecta a
nada de `Main`/gameplay — a única "comunicação" entre as duas cenas é
`get_tree().change_scene_to_file()`, sem nenhum sinal ou estado compartilhado (ver
[Phase 0.6](#phase-06--first-playable--ux-pass)).

### Event Bus

Não introduzido. Cada sistema novo continua se conectando diretamente à fonte do evento que
precisa (via `setup()`, chamado por `Main.gd`) — mesmo com bem mais sistemas do que na Phase 0.1,
nenhuma conexão precisou passar por um intermediário genérico. Reavaliar apenas se/quando isso
deixar de ser verdade.

## Gerenciamento de Estado

**Estado da partida (Phase 0.5):** `Main.gd` guarda um enum simples,
`GameState { PREPARING, WAVE_ACTIVE, WAVE_COMPLETE, GAME_OVER }`, controlado inteiramente pelo
*composition root* (requisito explícito da especificação) — não é uma máquina de estados abstrata
separada, é um `enum` + reações a sinais dos sistemas que de fato sabem quando algo aconteceu
(`WaveManager.wave_started`/`wave_completed`, `EggManager.all_eggs_destroyed`). `Main` nunca
decide *por* esses sistemas, só reage e atualiza a `HUD`.

Outro estado runtime existente: por-célula (`Cell.occupied`), a célula sob o cursor
(`GridManager._hovered_coord`, privado), o estado de seleção/hover de `PlacementController`
(`state`/`hovered_coord`/`is_hover_valid`/`selected_definition`), `Economy.coins`, o HP de cada
`Egg`, e o estado interno de `WaveManager` (`state`/`current_wave_index`).

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
- `game/tests/integration_tests.gd` (Phase 0.3, ajustado na 0.5) — instancia `Main.tscn` de
  verdade e confirma o pipeline MapPath→EnemySpawner→BasicEnemy ponta a ponta: chama
  `spawner.spawn_enemy()` diretamente (desde a Phase 0.5, `Main` não spawna mais sozinho — ver
  [WaveManager](#wavemanager)), o inimigo percorre o caminho todo (via `step(delta)`
  determinístico) e chega à posição de mundo do NEST emitindo `enemy_reached_nest`.
- `game/tests/dinosaur_definition_tests.gd` (Phase 0.4) — Velociraptor real: carrega, campos
  positivos, `projectile_scene` atribuído e instanciável como `Projectile`, `display_name`
  correto.
- `game/tests/placement_tests.gd` (Phase 0.4, expandido na 0.5) — `PlacementController.is_valid_placement()`
  contra `Grid` sintético para cada `CellType` (só BUILDABLE livre é válido), BUILDABLE já
  ocupado, coordenada fora dos limites; o efeito real de `on_pointer_pressed()`: célula fica
  ocupada, exatamente 1 `Dinosaur` é instanciado, estado volta para IDLE; célula inválida não
  instancia nada e permanece em PLACING; e (Phase 0.5) custo descontado ao colocar, placement
  recusado sem coins suficientes (nada descontado, nenhum `Dinosaur` criado,
  `placement_failed("insufficient_coins")` emitido).
- `game/tests/targeting_tests.gd` (Phase 0.4) — `Targeting.select_target()`: sem candidatos, um
  candidato dentro do alcance, fora do alcance, inimigo morto, inimigo que já chegou ao ninho, e
  FIRST desempatando corretamente por `get_distance_traveled()` mesmo quando o de maior progresso
  não é o fisicamente mais próximo.
- `game/tests/dinosaur_tests.gd` (Phase 0.4) — `Dinosaur.step(delta)` chamado diretamente: seleção
  de alvo dentro do alcance, nenhum alvo sem inimigos, dispara ao encontrar alvo (cooldown inicial
  zero), não dispara de novo antes do cooldown terminar, dispara de novo depois.
- `game/tests/projectile_tests.gd` (Phase 0.4) — `Projectile.step(delta)` chamado diretamente:
  avança em direção ao alvo sem overshoot, aplica dano exatamente uma vez ao impactar, alvo
  liberado (`free()`) ou morto antes do impacto não causa erro nem dano.
- `game/tests/combat_integration_tests.gd` (Phase 0.4, ajustado na 0.5) — vertical slice de
  combate com `Main.tscn` real: Velociraptor pré-selecionado (estado PLACING), placement numa
  célula BUILDABLE real do Vale dos Ovos, um inimigo criado via `spawn_enemy()` direto (sem
  envolver wave/economia — isso é `game_loop_integration_tests.gd`), `Dinosaur` real instanciado,
  inimigo avançado em lockstep com `Dinosaur.step()`/`Projectile.step()` até morrer pelos disparos
  do dinossauro **antes** de alcançar o ninho. Reforço pós Phase 0.6: confirma que cada hit gerou
  um `DamageNumber` e a morte gerou um `DeathEffect`, ambos como filhos de `EnemySpawner`.
- `game/tests/economy_tests.gd` (Phase 0.5) — `coins` inicial, `can_afford`, `spend`
  (sucesso/falha, e que falha não desconta), `add` (inclusive ignorar valores `<= 0`), sinal
  `coins_changed` (emitido em sucesso, não emitido em falha).
- `game/tests/egg_tests.gd` (Phase 0.5) — `Egg`: hp após `initialize()`, dano reduz hp,
  destruição em 0 hp (sem hp negativo), sinais `damaged`/`destroyed`, sem dano/sinal duplicado
  após destruído. `EggManager`: quantidade/posições derivadas de `MapDefinition.get_egg_positions()`,
  `all_destroyed()`, seleção determinística (primeiro ovo vivo, na ordem do mapa), sinal
  `all_eggs_destroyed`, e reação real a `EnemySpawner.enemy_reached_nest`. Reforço pós Phase 0.6
  (precisa de árvore real — `Egg.tscn` instanciado via `root.add_child`): loop de "vivo" escolhe
  `IDLE` acima do limiar crítico de HP e `MOVE` abaixo dele (`_visual.last_loop_state`), e para
  (`stop_loop()`) quando o ovo é destruído.
- `game/tests/wave_tests.gd` (Phase 0.5) — `WaveManager` com `EnemySpawner` real (mapa sintético
  SPAWN-PATH-NEST): início de wave + sinal, impedir duas waves simultâneas, contagem correta de
  spawn ao longo de `step(delta)`, conclusão só quando não sobra nenhum inimigo ativo,
  recompensa por kill e por conclusão de wave, `lock()` impede spawn/wave novos,
  `has_next_wave()`.
- `game/tests/game_loop_integration_tests.gd` (Phase 0.5) — `Main.tscn` real, dois cenários:
  (A) ciclo completo — mapa carrega, 3 eggs e economia existem, Velociraptor pré-selecionado é
  colocado (custo descontado), Wave 1 iniciada pelo botão real da HUD, inimigos spawnados e
  perseguidos pelo caminho em lockstep com `Dinosaur`/`Projectile`, coins aumentam, wave termina,
  nenhum ovo perdido; (B) sem nenhum dinossauro colocado — um inimigo alcança o ninho, um ovo
  recebe dano, e o inimigo desaparece (`queue_free`, confirmado após um `process_frame`).
- `game/tests/ux_tests.gd` (Phase 0.6) — `MainMenu.tscn` carrega e tem os 3 botões esperados; API
  pública da `HUD` (`set_coins`/`set_eggs`/`set_dinosaur_button_label`/`show_banner`/
  `hide_banner`/`show_pause_overlay`/`hide_pause_overlay`/`show_game_over`) instanciada
  standalone; via `Main.tscn` real: `pause_pressed`/`resume_pressed` pausam/despausam a árvore e
  mostram/escondem o overlay, iniciar uma wave mostra o banner "WAVE 1", completá-la mostra um
  banner com "COMPLETE", e o botão de dinossauro permite colocar um segundo Velociraptor depois do
  primeiro placement (deriva as coordenadas de `MapDefinition.get_buildable_cells()`, não
  hardcoded, para não depender de um layout específico do Vale dos Ovos). Reforço pós Phase 0.6:
  a última wave completada mostra um banner de "VITÓRIA" distinto do genérico "COMPLETE" das
  anteriores — testado avançando `current_wave_index` direto para a última e emitindo o sinal real
  `wave_completed` (não simula combate pelas 3 waves reais: sobreviver sem perder os 3 ovos
  depende da dificuldade/balance atual, que não é o que este teste quer verificar).
- `game/tests/animated_visual_tests.gd` (Phase 0.6) — `AnimatedVisual`: `play_state()` fora de
  uma árvore não lança erro; fallback procedural muda `modulate` num HIT real; `set_base_modulate()`
  aplica a cor imediatamente; com um `AnimatedSprite2D` filho tendo uma animação "hit" em
  `sprite_frames`, `play_state(HIT)` toca essa animação; sem uma animação "attack" correspondente,
  não finge tocar uma inexistente (cai no fallback). `placement_tests.gd` ganhou 2 casos novos:
  `dinosaur_placed` emitido com o `Dinosaur`/coordenada corretos, e `can_afford_selected()`
  refletindo `Economy` para custos diferentes. Reforço pós Phase 0.6: `last_state` reflete a
  chamada mais recente, `last_loop_state` ignora chamadas de reação (HIT/ATTACK/DEATH) que vêm
  depois de um loop, `stop_loop()` mata o loop tween e zera `rotation`, HIT distorce `scale`
  (squash) além de `modulate`, ATTACK desloca `position` (recoil) além de `scale`.

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
godot --headless --path game --script res://tests/dinosaur_definition_tests.gd
godot --headless --path game --script res://tests/placement_tests.gd
godot --headless --path game --script res://tests/targeting_tests.gd
godot --headless --path game --script res://tests/dinosaur_tests.gd
godot --headless --path game --script res://tests/projectile_tests.gd
godot --headless --path game --script res://tests/combat_integration_tests.gd
godot --headless --path game --script res://tests/economy_tests.gd
godot --headless --path game --script res://tests/egg_tests.gd
godot --headless --path game --script res://tests/wave_tests.gd
godot --headless --path game --script res://tests/game_loop_integration_tests.gd
godot --headless --path game --script res://tests/ux_tests.gd
godot --headless --path game --script res://tests/animated_visual_tests.gd
godot --headless --path game --script res://tests/visual_prototype_tests.gd
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

## Phase 0.4 — Dinosaur/Tower System

Dois problemas reais foram descobertos rodando (não apenas inspecionando) os testes desta fase.

### 1) `Projectile` só detectava impacto no `step()` seguinte, não no mesmo

**Sintoma:** `projectile_tests.gd` — um único `step(1.0)` com o alvo a 50px e velocidade 200px/s
(bastante para cobrir a distância inteira nesse passo) não aplicava dano (`hp` permanecia igual
ao inicial).

**Causa:** a checagem de chegada comparava `distance` contra um epsilon fixo pequeno
(`_ARRIVAL_EPSILON = 4.0`), independente de quanto o projétil realmente conseguia se mover
naquele `step()`. Um `step()` que movia o projétil os 50px inteiros (`position += direção * 50`)
deixava a nova posição exatamente EM CIMA do alvo, mas a checagem de "cheguei" só era feita no
**início** da chamada seguinte de `step()`, nunca reavaliada depois do próprio movimento dentro
da mesma chamada — diferente de `BasicEnemy.step()`, que já comparava contra "quanto posso me
mover neste passo" (`distance <= max_move`) antes de decidir mover ou chegar.

**Correção:** comparar contra `speed * delta + epsilon` (quanto o projétil pode se mover neste
passo, com uma pequena margem de segurança para erro de ponto flutuante) em vez de um epsilon
fixo — mesmo critério de chegada já usado em `BasicEnemy`. `combat_integration_tests.gd` não
detectou o bug porque usa `dt=0.05` (passos pequenos, muitos por segundo) — a aproximação gradual
naturalmente passa por um passo onde `distance <= max_move` já é verdade antes de "pular por
cima" do alvo; só um `step()` com delta grande o bastante para cobrir a distância inteira de uma
vez expõe o problema. Isso reforça a importância de testes de unidade com deltas grandes/únicos,
não só simulações com passos pequenos.

### 2) Cenas reais instanciadas em testes vazavam RID/CanvasItem se não fossem explicitamente liberadas

**Sintoma:** `placement_tests.gd` e `dinosaur_tests.gd` terminavam com `ALL TESTS PASSED` (exit
code `0`, todas as asserções corretas) mas imprimiam, ao sair do processo:
`ERROR: N resources still in use at exit`, `WARNING: N ObjectDB instances were leaked`,
`WARNING: N RIDs of type "CanvasItem" were leaked`.

**Causa:** ao contrário de `Grid`/`Cell`/`MapPath` (`RefCounted`, liberados automaticamente),
`PlacementController._place_dinosaur()` e `Dinosaur._fire()` instanciam **cenas reais**
(`Dinosaur.tscn`, `Projectile.tscn`) com nodes `Polygon2D` de verdade (recursos de renderização
no servidor gráfico) — e ficavam presos a containers `Node.new()` locais dos testes que nunca
eram liberados ao final da função de teste.

**Correção:** todo objeto criado em `placement_tests.gd`/`dinosaur_tests.gd` (containers,
`PlacementController`, `EnemySpawner`, `Dinosaur`) passou a ser registrado num array `_to_free` e
liberado explicitamente ao final de `_initialize()` (`Grid` continua isento — `RefCounted` não
precisa disso). `Node.free()` libera recursivamente os filhos (então registrar o container já é
suficiente para o `Dinosaur`/`Projectile` real instanciado dentro dele).

**Por que isso importava mesmo com exit code `0`:** nenhuma dessas linhas fazia `_check()` falhar
(não são assert de teste), mas são `ERROR`/`WARNING` reais no output — exatamente o tipo de coisa
que a especificação da Phase 0.4 pediu para não aceitar silenciosamente só porque
`ALL TESTS PASSED` apareceu. Corrigido antes de considerar a fase concluída.

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

## Decisões técnicas — Phase 0.4

- **`EnemySpawner` ganha o registro de inimigos ativos**, em vez de uma classe
  `EnemyRegistry`/`EnemyManager` separada (explicitamente pedido para não criar) — ver
  [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner).
- **Enum + `match` para `Targeting`**, não Strategy Pattern (explicitamente pedido para não
  criar) — ver [Targeting](#targeting).
- **`Dinosaur.tscn` único e genérico**, `.tres` por tipo de dinossauro — nenhuma subclasse por
  dinossauro (explicitamente pedido para não criar). `velociraptor.tres` é a única instância
  concreta desta fase.
- **`placeholder_color` existe em `DinosaurDefinition` mas não está conectado a nenhum visual
  ainda** — ver [Dinosaur](#dinosaur). Documentado como dado preparado, não como funcionalidade
  implementada, para não sugerir que já tem efeito.
- **Célula inválida durante PLACING não cancela a seleção**, permanece em `PLACING` para permitir
  nova tentativa — não estava explícito na especificação; escolhido por ser o comportamento mais
  natural (o jogador não perde a seleção por errar o clique/toque uma vez).
- **Projéteis parentados em `Projectiles` (container neutro sob `Main`), não como filho do
  `Dinosaur` que disparou** — um projétil em voo sobrevive à remoção futura do dinossauro de
  origem (venda/upgrade, fora de escopo agora, mas a estrutura já não impede).
- **`step(delta)` em `Dinosaur`/`Projectile`**, mesmo nome/convenção de `BasicEnemy.step(delta)`
  — vocabulário consistente em todas as entidades "simuladas" do jogo, todas testáveis
  diretamente sem depender de frame real.
- **`max_hp`/`hp` em `BasicEnemy` diretamente (`@export`), sem um `EnemyDefinition` Resource**
  ainda — só existe um tipo de inimigo; extrair um Resource de dados agora seria abstração
  prematura (mesmo raciocínio já aplicado a `speed` desde a Phase 0.3). Se/quando existir um
  segundo tipo de inimigo, `EnemyDefinition` (espelhando `DinosaurDefinition`) é o refactor
  natural.
- **`get_distance_traveled()` não normalizado (0–1)** — ver
  [BasicEnemy e EnemySpawner](#basicenemy-e-enemyspawner) para o racional completo (requisito 7).

## Phase 0.5 — Primeiro Game Loop Jogável Completo

Diferente das fases anteriores, **nenhuma limitação nova do Godot 4.7.2 foi descoberta** rodando
os testes desta fase — registrado aqui por completude/honestidade, não porque houvesse algo para
corrigir. O único bug real encontrado (`Projectile`, checagem de impacto contra epsilon fixo em
vez de `speed*delta`) já existia desde a Phase 0.4 e está documentado na seção
[Phase 0.4](#phase-04--dinosaurtower-system) — não foi reintroduzido nem alterado aqui.

**Precaução mantida, não um bug confirmado:** `WaveManager.waves` (`Array[WaveDefinition]`) é
montado em `Main.gd` via `load()` de caminhos fixos, não atribuído via export em `Main.tscn`.
Escrever manualmente o literal `Array[WaveDefinition](...)` no formato texto do `.tscn` é uma
sintaxe que este projeto não teve como validar contra o editor real antes deste momento — mesma
categoria de risco já evitada na Phase 0.1 (bloco de `InputMap` serializado à mão). Diferente do
`InputMap` da Phase 0.1 (nunca chegou a ser tentado), aqui a alternativa seria testável no editor
se necessário; a decisão foi não arriscar por uma economia pequena de código. Ver
[Decisões — Phase 0.5](#decisões-técnicas--phase-05).

**Mudança de comportamento deliberada:** desde esta fase, `Main._ready()` **não spawna mais um
inimigo sozinho** ao iniciar (diferente de Phase 0.3/0.4) — spawning é exclusivamente
responsabilidade de `WaveManager`, disparado pelo jogador via HUD. Isso quebrou dois testes de
integração mais antigos (`integration_tests.gd`, `combat_integration_tests.gd`), que assumiam o
spawn automático; ambos foram ajustados para chamar `spawn_enemy()` diretamente, preservando seu
escopo original (validar o encanamento MapPath→EnemySpawner e a mecânica de combate,
respectivamente, sem envolver waves/economia — isso é `game_loop_integration_tests.gd`).

## Decisões técnicas — Phase 0.5

- **`WaveManager` como classe separada de `EnemySpawner`** — orquestrar quando/quantos inimigos
  spawnar é uma responsabilidade temporal/de estado de onda distinta de "criar um inimigo e
  rastrear quem está vivo"; combinar as duas era candidato real a God Object. `WaveManager` usa
  `EnemySpawner` por composição, não duplica sua lógica.
- **Recompensa por kill vinculada à wave atual** (`WaveDefinition.reward_per_kill`, não um valor
  fixo por tipo de inimigo) — permite ondas posteriores pagarem mais por kill sem precisar de
  múltiplos tipos de `BasicEnemy`. Seguro porque waves são estritamente sequenciais (nunca duas
  ativas ao mesmo tempo), então "a wave atual" nunca é ambíguo quando um inimigo morre.
- **`EnemySpawner` ganha `enemy_died` (re-emissão de `BasicEnemy.died`)** — mesmo padrão já usado
  por `enemy_reached_nest`: quem precisa saber de mortes (`WaveManager`) escuta o spawner, nunca
  cada `BasicEnemy` individualmente.
- **Egg é `Node2D` com placeholder visual próprio** (não um dado puro/`RefCounted`) — só 3 no
  máximo, sem preocupação de performance como as 240 células da grid; ter posição/visual próprios
  simplifica o feedback de dano (`modulate`) sem precisar de um mecanismo de desenho agregado
  como o de `GridManager`.
- **Regra de seleção de ovo "primeiro vivo, na ordem do mapa"** — não "mais próximo" nem
  aleatório, propositalmente simples (requisito explícito 5).
- **Remoção do inimigo ao alcançar o ninho é decisão de `EggManager`, não de `BasicEnemy`** —
  `BasicEnemy` continua sem se autodestruir sozinho ao `reached_nest` (mesma decisão da Phase
  0.3); quem consome o evento (`EggManager`, agora) é quem decide chamar `queue_free()`.
- **Custo verificado só na confirmação do placement, não durante o hover/preview** — a validade
  de célula (verde/vermelho) reflete só BUILDABLE+livre; afordabilidade é checada separadamente
  em `on_pointer_pressed()`, na ordem exata pedida (célula válida → confirmar → verificar coins →
  descontar).
- **Pausa via `get_tree().paused` + `process_mode`, velocidade via `Engine.time_scale`** —
  mecanismos nativos do Godot, conforme sugerido explicitamente pela especificação; zero mudança
  de código nos `step()` determinísticos já existentes (`BasicEnemy`/`Dinosaur`/`Projectile`/
  `WaveManager`) para suportar os dois.
- **`WaveManager.waves` montado via `load()` em código, não via export tipado no `.tscn`** — ver
  [Phase 0.5](#phase-05--primeiro-game-loop-jogável-completo) acima.
- **Estado da partida (`GameState`) vive direto em `Main.gd`, sem classe própria** — requisito
  explícito ("controlado pelo composition root"); evitar uma máquina de estados abstrata separada
  quando o `enum` + reações a sinais já resolve com clareza.
- **`HUD` não decide nada** — só emite sinais de intenção do jogador (`start_wave_pressed` etc.) e
  expõe métodos de exibição; toda decisão (o que fazer quando o botão é apertado) vive em
  `Main.gd`. Mesmo princípio já aplicado a `PlacementPreview`.

## Phase 0.6 — First Playable / UX Pass

Objetivo: transformar o protótipo técnico da Phase 0.5 numa experiência jogável de ponta a ponta
e clara — BOOT → MAIN MENU → JOGAR → Vale dos Ovos → PREPARE → colocar Velociraptor → iniciar
wave → combate → recompensa → WAVE COMPLETE → próxima wave → GAME OVER — sem adicionar
profundidade de jogo nova (sem novos dinossauros/inimigos/upgrades/tipos de ovo/monetização/
login real/save/multiplayer).

**Dois blocos de trabalho, uma fase só:** esta fase foi interrompida por limite de sessão logo
depois da primeira leva de mudanças (Main Menu, HUD, placement UX, feedback de combate via `Tween`
ad-hoc por entidade) — o trabalho retomado NÃO refez nada já concluído; validou o que já existia
(achando e corrigindo dois bugs reais só então expostos por `run_tests.ps1`, ver abaixo) e
adicionou a arquitetura de animação (`AnimatedVisual`/`DeathEffect`, ver
[AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06)) por cima do que já estava
pronto, substituindo os `Tween`s ad-hoc duplicados em `BasicEnemy`/`Dinosaur`/`Egg`/`Projectile`
por chamadas ao componente compartilhado.

### 1) Main Menu como cena de boot separada

`scenes/MainMenu.tscn` (`Control`, `main_menu.gd`) é agora `project.godot`'s `run/main_scene`
(era `res://scenes/Main.tscn`). JOGAR chama `get_tree().change_scene_to_file("res://scenes/Main.tscn")`
— mecanismo **nativo** do Godot, sem framework de cena/transição customizado (explicitamente
pedido para não criar). `Main.tscn` continua sendo a cena de jogo (não foi renomeada para
`Game.tscn`/`game.gd`: o custo de tocar ~10 arquivos de teste que referenciam
`res://scenes/Main.tscn` superava o ganho de clareza de um rename puramente cosmético — "Main"
já é lido naturalmente como "a cena principal de jogo" agora que `MainMenu` é o verdadeiro ponto
de entrada do app).

**Sem `GameSession`/autoload:** não avaliado como necessário porque nenhum estado precisa
atravessar a fronteira menu↔jogo — `Main.tscn` reconstrói tudo do zero (`Economy`, `WaveManager`,
`EggManager`, ...) toda vez que é instanciada. Voltar ao menu (via `MENU` no overlay de pausa)
descarta a partida atual — permitido explicitamente nesta fase.

**Preparado para login/perfil futuro sem reestruturar:** `MainMenu` já separa BOOT de JOGO como
duas cenas independentes — inserir uma tela de LOGIN/PERFIL entre as duas no futuro é só mais uma
cena e uma troca de `change_scene_to_file()`, sem tocar em `Main.tscn`/`main.gd`. O botão OPÇÕES
existe na navegação mas não abre nada ainda (`print()` de log) — estrutura pronta, funcionalidade
fora de escopo.

### 2) HUD: banner único, overlay de pausa, botão de dinossauro

Ver [HUD](#hud) e [Pausa e Velocidade](#pausa-e-velocidade) acima para o detalhamento completo.
Resumo das mudanças: `WaveCompleteBanner` (Label único-propósito) virou `BannerLabel` +
`show_banner()`/`hide_banner()` (reutilizável para "WAVE N", "WAVE N COMPLETE! +recompensa" e
"Coins insuficientes!"); ganhou `PauseOverlay` (PAUSADO/CONTINUAR/MENU) e `GameOverOverlay` ganhou
um botão MENU; `DinosaurButton` permite recolocar o Velociraptor; rótulos de estado permanente
ganharam prefixo de emoji (🥚/💰/🦖) com fallback textual completo.

### 3) Placement UX: feedback de coins insuficientes durante o hover, silhueta do dinossauro

`PlacementController.can_afford_selected()` (consulta pura) permite a `PlacementPreview` colorir
a célula de âmbar quando ela é válida mas o jogador não tem coins suficientes — antes disso só era
possível descobrir isso ao clicar. `PlacementPreview` também desenha uma silhueta translúcida do
dinossauro (mesmos pontos do `Placeholder` de `Dinosaur.tscn`, duplicados deliberadamente — ver
[PlacementPreview](#placementpreview)) tingida pela mesma cor de validade, em vez de só um
retângulo na célula. `PlacementController.dinosaur_placed` (sinal) é um gancho de feedback para um
placement bem-sucedido.

### 4) Feedback visual de combate: arquitetura de animação (não apenas polimento pontual)

O maior bloco de trabalho novo desta fase — ver
[AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06) para o detalhamento
completo. Resumo: toda entidade visual ganhou um node `Visual` com o script `AnimatedVisual`
(antes, um `Node2D` neutro — exceto `BasicEnemy`, que não tinha nem esse wrapper e precisou ser
reestruturado nesta fase para ganhar um, alinhando com o padrão já usado por
`Dinosaur`/`Egg`/`Projectile` desde a Phase 0.4/0.5). Gameplay só chama
`play_state(IDLE/MOVE/ATTACK/HIT/DEATH)`; hoje isso é realizado por `Tween`s procedurais (sem
arte final), e no futuro por um `AnimatedSprite2D` com `SpriteFrames` reais, sem mudar nenhuma
linha de código de gameplay. Morte/chegada ao ninho/impacto de projétil ganharam um efeito visual
desacoplado (`DeathEffect`) que nunca atrasa a remoção real da entidade.

### 5) Placeholder visual do Dinosaur trocado (silhueta + cor tingida de verdade)

Ver [Cenas](#cenas-scenes) e o detalhamento em [Dinosaur](#dinosaur) — triângulo simples trocado
por uma silhueta de 6 pontos; `DinosaurDefinition.placeholder_color` finalmente conectado (via
`AnimatedVisual.set_base_modulate()`, não mais um campo "preparado mas não usado" como registrado
na Phase 0.4); cor trocada de verde para laranja por contraste contra o tingimento de debug de
células BUILDABLE (ver [Hierarquia Visual](#hierarquia-visual-phase-06)).

### Hierarquia Visual (Phase 0.6)

Checagem de contraste entre os tingimentos de debug da grid (`GridManager`) e as cores reais de
entidades, para garantir que PATH/BUILDABLE/OBSTACLE/EGG/NEST/SPAWN sejam distinguíveis de
DINOSAUR/ENEMY à primeira vista:

| Elemento | Cor | Nota |
|---|---|---|
| PATH (debug) | marrom | |
| BUILDABLE (debug) | verde | |
| OBSTACLE (debug) | vermelho escuro | |
| EGG (debug) | amarelo | reforça visualmente o `Egg` real (também amarelo) na mesma posição |
| SPAWN (debug) | azul | |
| NEST (debug) | roxo | |
| DINOSAUR (`Dinosaur.tscn`) | **laranja** (era verde) | trocado nesta fase — verde colidia com o tingimento de BUILDABLE |
| ENEMY (`BasicEnemy.tscn`) | vermelho-alaranjado | inalterado, já suficientemente distinto |
| Projectile | amarelo-claro | inalterado |
| DeathEffect | bege claro/neutro | novo nesta fase, deliberadamente neutro (não compete com nenhuma cor de entidade) |

Nenhuma outra mudança de cor foi necessária — as demais combinações já tinham contraste
suficiente por inspeção do código (não verificado visualmente em tela real, ver
[Limitações — validação manual](#17-teste-manual-obrigatório) abaixo).

### 6) Ganchos de áudio (documentados, não implementados)

Nenhum sistema de áudio foi implementado (fora de escopo explícito). Pontos exatos onde efeitos
sonoros devem ser conectados no futuro, mapeados para sinais/eventos que já existem:

| Efeito pedido | Gancho |
|---|---|
| click (UI) | `pressed` nativo de cada `Button` da HUD/MainMenu |
| placement | `PlacementController.dinosaur_placed` |
| shot | `Dinosaur.fired` |
| hit | `Projectile.impacted` / `BasicEnemy.damaged` |
| death | `BasicEnemy.died` |
| wave start | `WaveManager.wave_started` |
| wave complete | `WaveManager.wave_completed` (com `WaveManager.has_next_wave() == false`: ver "vitória/conclusão" abaixo) |
| egg hit | `Egg.damaged` |
| game over | `EggManager.all_eggs_destroyed` |
| vitória/conclusão | `WaveManager.wave_completed`, mesmo sinal de "wave complete" — quem for tocar áudio decide o clipe olhando `WaveManager.has_next_wave()` no momento do evento, igual à `HUD` já faz para o texto do banner (ver "Reforço de Feedback Visual e Combate" abaixo) |

Nenhum placeholder sonoro foi adicionado — o projeto não tem nenhum asset de áudio ainda, e gerar
um só para preencher esta tabela seria inventar conteúdo fora do escopo pedido.

### 7) Teste manual obrigatório

**Não foi possível realizar um playthrough manual interativo real no editor Godot nesta sessão**
— o agente que implementou esta fase não tem um loop de interação visual/mouse/teclado com o
editor rodando (só execução headless via linha de comando). O que FOI validado de fato:
compile-check individual de todo `.gd` do projeto, as 16 suítes de teste automatizado (incluindo
dois testes de integração que instanciam `Main.tscn` real e simulam um loop de jogo completo
ponta a ponta via `step(delta)` determinístico), `--quit-after N` tanto em `MainMenu.tscn` (cena
de boot real) quanto em `Main.tscn` (cena de jogo, onde toda a animação nova roda) sem nenhum
`ERROR`/`WARNING`, e um scan completo do editor (`--editor --quit`) sem erro de parsing em
nenhuma cena/script/resource. Isso cobre corretude lógica e ausência de erros/leaks, mas **não**
substitui observar o jogo rodando numa tela de verdade (legibilidade de cores, sensação das
animações, tamanho de botões ao toque, etc.) — ver limitação equivalente no relatório final desta
fase.

### Bug real encontrado e corrigido nesta fase (não introduzido por este trabalho — pré-existente, nunca validado)

`placement_preview.gd`'s `_DINOSAUR_SHAPE` foi originalmente escrito como
`const _DINOSAUR_SHAPE := PackedVector2Array([Vector2(...), ...])` — um array-literal-dentro-de-
`PackedVector2Array()` não é reconhecido pelo GDScript como expressão constante, causando
`SCRIPT ERROR: Parse Error: Assigned value for constant "_DINOSAUR_SHAPE" isn't a constant
expression` e quebrando a compilação de **qualquer** script que dependesse dele (`main.gd`
inclusive, por cascata). Só foi detectado ao rodar `run_tests.ps1` de verdade nesta sessão —
reforça, de novo, por que a Phase 0.2.1 existe (compile-check individual de cada script antes de
rodar qualquer teste). Corrigido com o mesmo padrão já estabelecido desde a Phase 0.2
(`const X: Array[Vector2] = [...]`, tipo explícito em vez de conversão para tipo Packed).

## Decisões técnicas — Phase 0.6

- **`Main.tscn`/`main.gd` não foram renomeados** apesar de `MainMenu` agora ser a cena de boot —
  ver [item 1](#1-main-menu-como-cena-de-boot-separada) acima; custo/risco do rename (tocar todos
  os testes que carregam `res://scenes/Main.tscn`) não compensava o ganho puramente cosmético.
- **Sem `GameSession`/autoload** — nenhum estado atravessa a fronteira menu↔jogo; `Main.tscn` é
  auto-suficiente. Reavaliar só se uma fase futura precisar preservar progresso entre partidas.
- **`AnimatedVisual` como componente compartilhado, não lógica duplicada por entidade** — a Phase
  0.6 original (antes da interrupção) tinha `Tween`s quase idênticos escritos separadamente em
  `BasicEnemy`/`Dinosaur`/`Egg`/`Projectile`; extraído para um componente único ao implementar a
  arquitetura de animação, não é abstração prematura (resolve duplicação real que já existia) nem
  Strategy Pattern (é um `Node2D` com um `match` interno, mesmo espírito de `Targeting`).
- **`DeathEffect` como node irmão autônomo, não atraso do `queue_free()` da entidade real** — ver
  [AnimatedVisual e DeathEffect](#animatedvisual-e-deatheffect-phase-06) para o racional completo
  (risco de travar testes headless que não bombeiam frames reais depois da morte).
- **`Egg` não usa o estado DEATH de `AnimatedVisual`** — usar um estado que faz o node desaparecer
  seria incorreto para uma entidade que deve continuar visível (cinza) depois de destruída.
- **Botão de dinossauro na HUD permite múltiplos placements** — não é profundidade de jogo nova,
  só expõe pela UI uma capacidade que `PlacementController.select_dinosaur()` já suportava desde a
  Phase 0.4 (ver [HUD](#hud)).
- **Nenhum placeholder de áudio foi criado** — o projeto não tem nenhum asset sonoro ainda; a
  tabela de ganchos (ver acima) documenta os pontos de integração futuros sem inventar conteúdo.

## Reforço de Feedback Visual e Combate (pós Phase 0.6)

Rodada de hardening sobre o que a Phase 0.6 já entregou — sem nova numeração de fase (o commit
`8b47669` já fechou a Phase 0.6; isto é refinamento do mesmo sistema, não conteúdo novo). Mudanças
reais:

- **`AnimatedVisual` ganhou `stop_loop()`** — mata o `_loop_tween` ativo e zera `rotation`; usado
  por `Egg` quando destruído (o loop de "vivo" deve parar, não continuar pulsando num ovo morto).
- **`AnimatedVisual` ganhou `last_state`/`last_loop_state`** — introspecção pura para testes (mesmo
  espírito de `Dinosaur.current_target()`), sem nenhum efeito em gameplay. Separados porque `Egg`
  chama um estado de loop e depois HIT no mesmo `_update_visual()` — `last_state` sozinho sempre
  acabaria em HIT, mascarando qual variante de loop foi escolhida.
- **HIT ganhou um "squash" de escala além do flash de cor**, e **ATTACK ganhou um pequeno recoil de
  posição** (~4px, eixo local -X) além do pulso de escala — ambos na trilha de reação já existente
  (`_reaction_tween`), sem introduzir uma terceira trilha nem tocar a trilha de loop. Efeito
  puramente estilístico: `AnimatedVisual` não conhece a direção real do alvo (permaneceria
  desacoplado de gameplay mesmo que conhecesse), então o recoil é uma aproximação, não mira de
  verdade.
- **`Egg` ganha um loop de "vivo" contínuo** (`IDLE` acima de 30% HP, `MOVE` — reaproveitado como
  "pulso de urgência", não literalmente "andando", o jogador nunca vê o nome do estado — abaixo
  disso), desligado via `stop_loop()` na destruição. Antes desta rodada, o ovo só reagia no
  instante do dano (flash de HIT); entre danos, ficava visualmente parado — violava a regra do
  projeto de "nenhuma entidade estática".
- **`DamageNumber`** (`scripts/visuals/damage_number.gd` + `scenes/effects/DamageNumber.tscn`,
  `class_name DamageNumber`) — número de dano flutuante, mesmo padrão de autonomia de
  `DeathEffect` (spawnado como irmão via `get_parent().add_child()`, nunca no caminho crítico,
  autodestrói via timer). Desenhado com `draw_string()` nativo do `CanvasItem` (texto já nasce em
  espaço de mundo, sem conversão de câmera) em vez de um `Label`/`Control` — mais simples para um
  efeito que só sobe e desaparece. Acionado em `BasicEnemy.take_damage()` e `Egg.take_damage()`.
- **`DeathEffect` ganhou `class_name`** (antes só tinha o de `DamageNumber` desde sua criação) —
  consistência entre os dois efeitos autônomos, e permite `child is DeathEffect` em testes em vez
  de checar `resource_path` do script manualmente.
- **Banner de vitória distinto na última wave:** `Main._on_wave_completed()` agora mostra
  "🏆 VITÓRIA! ..." em vez do banner genérico "WAVE N COMPLETE!" quando
  `not _wave_manager.has_next_wave()` — antes disso, terminar a última wave técnica de teste só
  desabilitava o botão "Iniciar Onda" silenciosamente, sem nenhuma explicação. Reaproveita o
  `WaveManager.wave_completed` já existente (mesmo sinal, decisão de texto diferente em `Main.gd`)
  — não é um novo estado de `GameState` nem um sistema de "vitória" novo; as 3 waves continuam
  sendo dados de validação técnica, não conteúdo final (ver `docs/GAME_BIBLE.md`, seção Waves).
- **Auditoria mobile/HUD/placement/legibilidade:** revisão completa contra o pedido desta rodada —
  nenhuma mudança de código foi necessária além do já existente (tamanhos de botão, contraste de
  grid, ausência de dependência de hover, HUD não cobrindo o mapa já atendiam ao critério). Ver
  relatório da sessão para o detalhamento ponto a ponto.

## Primeiro Protótipo Visual

Primeira arte real do jogo (pixel art 16-bit, identidade original — ver `docs/ART_DIRECTION.md`
para a direção completa), substituindo os placeholders geométricos (`Polygon2D`) do Velociraptor,
do `BasicEnemy` e do chão da grid. Sem nova numeração de fase — extensão do sistema visual já
existente (`AnimatedVisual`), não uma reescrita.

### Pipeline de arte (`game/tools/`)

O projeto não tinha nenhum pipeline de arte antes desta etapa. Três scripts, executados
manualmente (não fazem parte do jogo em runtime, nenhuma cena os referencia):

- **`pixel_art_generator.gd`** — desenha os PNGs (ambiente + frames do Velociraptor + frames do
  `BasicEnemy`) programaticamente via `Image.set_pixel()`, compondo formas primitivas
  (elipses/retângulos/polígonos com preenchimento por scanline) — sem nenhuma dependência externa.
  Salva em `game/assets/`. Também expõe 3 helpers de transformação pixel-a-pixel usados para
  derivar variações a partir de uma única arte-fonte já validada, em vez de desenhar cada
  orientação à mão: `_flip_y()`, `_flip_x()`, `_transpose()` (troca linhas por colunas). Usado no
  checkpoint de Ambiente para gerar as 4 tiras de transição grama↔trilha a partir de uma só (ver
  `GridManager` abaixo).
- **`build_sprite_frames.gd`** — carrega os PNGs já importados pelo editor e monta os `.tres` de
  `SpriteFrames` (`game/data/dinosaurs/velociraptor_sprite_frames.tres`,
  `game/data/enemies/basic_enemy_sprite_frames.tres`) com animações nomeadas exatamente como
  `AnimatedVisual.State` (`"idle"`, `"attack"`, `"move"`, `"hit"`, `"death"`). Precisa rodar
  **depois** de um `--editor --quit` (o `load()` de uma textura recém-criada exige o `.import`
  que só o editor gera — mesma categoria de gotcha já documentada para o cache de `class_name`).
- **`preview_contact_sheet.gd`** — ferramenta de revisão: amplia (nearest-neighbor) todos os PNGs
  e monta uma folha de contato única, só para inspeção visual durante o desenvolvimento; nunca
  referenciada por nenhuma cena, sem saída commitada (regenerável a qualquer momento). Redimensiona
  preservando a proporção original de cada fonte (em vez de forçar um quadrado) — necessário desde
  que as tiras de borda passaram a ser retangulares (32×10 / 10×32), não só quadradas 32×32.

Fluxo completo para regenerar/ajustar a arte: `pixel_art_generator.gd` →
`godot --headless --editor --quit` (importa os PNGs novos) → `build_sprite_frames.gd`. Documentado
aqui porque é o pipeline mínimo real do projeto agora — substituível por um artista/Aseprite
depois sem mudar como o jogo consome os assets (PNG + `SpriteFrames`, ver
[Animações](#animações) em `ART_DIRECTION.md`).

**Bug real encontrado durante a criação da arte (Velociraptor/BasicEnemy):** o primeiro desenho do
focinho do Velociraptor ia até x=33 num canvas de 32px — cortado pela borda no frame de ataque
(lunge de `dx=+2`), fazendo `idle`/`attack` parecerem visualmente idênticos apesar de terem código
diferente. Corrigido recentrando a composição com folga nas duas direções. Encontrado inspecionando
os PNGs gerados via a ferramenta `Read` (leitura de imagem) — não por execução do jogo.

**Lição reforçada no checkpoint de Ambiente — miniatura de pixel art pode enganar até inspeção
cuidadosa:** ao ajustar a proporção grama/trilha da tira de borda norte (formula original ~60–70%
grama), a correção parecia visualmente "ainda desbalanceada" na folha de contato ampliada, mesmo
depois de mudar o cálculo. Em vez de confiar nessa leitura visual (mesma armadilha do bug do
focinho acima), foi escrito um script descartável (`diff_check.gd`, removido depois de usado, não
faz parte do projeto) que conta pixels dominantes de cada cor por imagem — confirmou que a correção
estava de fato certa (~45% grama / 55% trilha, consistente nas 4 direções depois de transpor) e que
a percepção visual da miniatura pequena é que não era confiável. Padrão a repetir: para qualquer
proporção/diferença que precise ser exata, escrever uma medição objetiva em vez de só olhar.

### Integração — `Dinosaur.tscn` / `BasicEnemy.tscn`

Ambas as cenas ganharam um node `AnimatedSprite2D` (nome exato — é assim que
`AnimatedVisual.get_node_or_null("AnimatedSprite2D")` o encontra) dentro de `$Visual`, com
`sprite_frames` apontando para o `.tres` correspondente. O `Placeholder` (`Polygon2D`) foi
**removido** dessas duas cenas — cobria exatamente os mesmos estados que a arte nova cobre
(Dinosaur: IDLE/ATTACK; BasicEnemy: MOVE/HIT/DEATH), então o fallback procedural nunca seria
acionado para elas de qualquer forma. `Egg`/`Projectile` **não** mudaram — continuam com
`Polygon2D`, fora do escopo desta etapa (só Velociraptor e BasicEnemy foram pedidos).

### `AnimatedVisual` — reação sprite-driven precisa voltar sozinha ao loop

Gap real de arquitetura descoberto ao ligar a arte: no fallback procedural, IDLE/MOVE continuam
tocando **por baixo** de uma reação (ATTACK/HIT), porque são trilhas de `Tween` independentes
(`_loop_tween` vs. `_reaction_tween`, mexendo em propriedades diferentes). Com
`AnimatedSprite2D`, é **uma única** animação por vez — sem nenhum tratamento adicional, tocar
`"attack"`/`"hit"` (configuradas com `loop = false` no `SpriteFrames`) deixaria o sprite
congelado no último frame para sempre, já que nada re-dispara `"idle"`/`"move"` depois.

Corrigido com `_play_sprite()` + `_on_sprite_reaction_finished()`: ao tocar uma reação
sprite-driven, conecta (`CONNECT_ONE_SHOT`) o sinal `AnimatedSprite2D.animation_finished`, que ao
disparar chama `play_state(last_loop_state)` — volta sozinho para o loop que estava tocando antes
(`last_loop_state`, já existente desde o reforço pós Phase 0.6). API pública (`play_state`)
inalterada; gameplay continua sem saber que isso existe.

### `DeathEffect` — passthrough opcional do sprite da criatura

`DeathEffect` ganhou `set_death_sprite_frames(frames: SpriteFrames)` (opcional, chamado ANTES de
`add_child()`) e um `AnimatedSprite2D` filho (vazio por padrão). Sem chamar isso — caso padrão:
impacto de projétil, chegada ao ninho — o efeito continua mostrando o losango neutro genérico
(`Polygon2D`) de sempre. `BasicEnemy._die()` (só a morte de verdade, não a chegada ao ninho) passa
o próprio `SpriteFrames` (lido direto de `$Visual/AnimatedSprite2D`, sem duplicar a referência em
nenhum outro lugar) — o efeito de morte passa a mostrar os frames de `"death"` daquela criatura
específica em vez do genérico. `Placeholder` do `DeathEffect` é escondido (`visible = false`)
quando isso acontece, para as duas artes não desenharem sobrepostas.

**Bug real encontrado por `run_tests.ps1`:** a primeira versão de `set_death_sprite_frames()`
acessava o `AnimatedSprite2D` via `_visual.get_node_or_null(...)` (o campo `@onready` de
`DeathEffect`) — `SCRIPT ERROR: Cannot call method 'get_node_or_null' on a null value`, porque
esse método roda **antes** de `add_child()`, ou seja, antes do `_ready()` de `DeathEffect` (que
resolve `_visual`) sequer disparar. Corrigido navegando a partir de `self`
(`get_node_or_null("Visual/AnimatedSprite2D")`) — a estrutura da cena já instanciada existe assim
que `instantiate()` roda, um campo `@onready` cacheado não.

### `GridManager` — chão e decoração da grid

`debug_visible` **inverteu de sentido** (`@export var debug_visible: bool = false`, era `true`):
antes era a única forma de ver a grid (não havia arte); agora é o oposto — por padrão desenha os
tiles de `assets/environment/`, e F3 troca para o preenchimento plano de `DEBUG_COLORS` de sempre
(mantido como auxílio de desenvolvimento, não removido). Nenhuma lógica de grid mudou —
`Grid`/`Cell`/`MapDefinition`/`MapValidator` continuam exatamente como eram; isto é só uma segunda
forma de **desenhar** o mesmo dado (`_draw_cell_art()`, chamado em vez do preenchimento de debug).

- PATH/SPAWN/NEST desenham a base de trilha; todo o resto desenha grama. Cada uma escolhe entre
  variações (4 de grama, 3 de trilha — `grass_01..04.png`, `path_01..03.png`) via `_pick()`, um
  hash determinístico por coordenada (`absi(coord.x*mult_x + coord.y*mult_y) % textures.size()`,
  multiplicadores diferentes por lista para não repetir o mesmo índice relativo entre grama/
  trilha/decoração) — nunca `RandomNumberGenerator`, o mesmo mapa sempre desenha exatamente igual
  entre execuções. As variações usam a mesma linguagem visual (mesma paleta, mesmo nível de
  detalhe, só desloca o padrão de tufos/pedrinhas e no máximo acrescenta um elemento pequeno como
  uma flor ou uma pedra extra) — o objetivo é impedir repetição óbvia célula-a-célula sem o mapa
  parecer ter biomas diferentes.
- OBSTACLE desenha grama + uma decoração escolhida pelo mesmo `_pick()` dentre 6 opções
  (`rock_large`, `tree_large`, `bush_large`, `rock_cluster`, `tree_small`, `stump` — antes eram só
  3, ver `_OBSTACLE_DECORATIONS`). Nunca em BUILDABLE — vegetação decorativa não pode competir com
  a leitura de "aqui dá para construir" (regra explícita de `docs/ART_DIRECTION.md`).
- SPAWN/NEST/EGG ganham um tingimento translúcido por cima da textura base (`Color(cor_debug,
  alpha)`), preservando a distinção de cor já estabelecida sem precisar de tile próprio.
- Transição grama↔trilha agora cobre as **4 direções cardeais**, resolvendo a limitação conhecida
  da versão anterior (só norte/sul). Em vez de rotacionar uma textura em runtime
  (`draw_set_transform`, descartado por não dar para validar visualmente), o checkpoint de
  Ambiente desenha à mão só a tira norte (`path_edge_n.png`, "grama em cima, trilha embaixo") e
  deriva as outras 3 por transformação de pixels no próprio gerador — `path_edge_s =
  flip_y(edge_n)`, `path_edge_w = transpose(edge_n)`, `path_edge_e = flip_x(edge_w)` — garantindo
  consistência matemática entre as 4 sem depender de rotação em runtime; `_draw_path_edges()`
  desenha cada uma com `draw_texture_rect()` simples num `Rect2` posicionado na borda
  correspondente da célula. Sem asset dedicado para cantos (permitido explicitamente pelo escopo
  do checkpoint) — quando dois lados adjacentes de uma célula precisam de transição, as duas tiras
  são desenhadas sobrepostas, o que já cobre a leitura sem exigir um quarto conjunto de assets
  diagonais.

### Checkpoint B — Velociraptor (asset pack)

Redesenho completo do Velociraptor pedido pelo usuário depois do Checkpoint A aprovado: 19 frames
reais substituindo os 4 do protótipo anterior (IDLE 4, MOVE 6, ATTACK 6, HIT 3; MOVE/HIT
preparados para reutilização futura, `Dinosaur.gd` não os chama hoje). **Paleta laranja
(`#F28D26`) mantida** — a mesma identidade estabelecida desde a Phase 0.4, não uma cor nova; a
imagem de referência do asset pack (que mostra um raptor verde) foi usada só como direção de
silhueta/proporções/linguagem de pixel art, nunca como paleta a copiar. (Nota histórica: uma
iteração intermediária desta mesma etapa chegou a migrar a paleta para verde por instrução do
usuário; o usuário revisou logo em seguida e pediu para manter o laranja — o código e esta seção
já refletem só a decisão final.)

- **Canvas 48×48** (era 32×32) — permitido explicitamente pela instrução do checkpoint para dar
  folga real a poses dinâmicas de corrida/mordida/lunge sem recortar; ainda lê como "uma torre
  numa célula" (1.5× o lado do tile de 32px), não várias.
- **Geração por pose, não por parâmetro solto:** `_raptor_pose(overrides: Dictionary)` retorna uma
  pose neutra completa (postura parada, respirando) e cada um dos 19 frames só sobrescreve os
  campos que mudam naquele frame (`body_dx`/`body_dy` de lean-lunge, `head_tilt`, `mouth_open`,
  `chest_scale` de respiração, pontos de controle da cauda, joelho/pé de cada perna, offset do
  braço, `eye_shut`). Evita 19 chamadas com uma dúzia de parâmetros posicionais cada — cada pose
  lê como uma lista do que muda, não uma tabela de números soltos.
- **`_fill_thick_line()`** (novo helper) — segmento reto grosso entre dois pontos via polígono
  perpendicular à direção; usado para pernas (2 segmentos: coxa+canela, joelho visivelmente
  dobrado), cauda (2 segmentos, afinando) e braço. Deixa qualquer membro apontar em qualquer
  ângulo sem rotacionar a imagem inteira — rotacionar o sprite completo foi explicitamente excluído
  como "animação de verdade" pela instrução do checkpoint.
- **Mandíbula com dobradiça real** (`jaw_hinge`/`upper_tip`/`lower_tip`): maxilar superior e
  mandíbula inferior são duas peças que se separam a partir de um ponto comum, a mandíbula inferior
  descendo proporcionalmente a `mouth_open` — não um recorte cosmético.

**2 bugs reais encontrados e corrigidos nesta etapa** (ambos via inspeção de imagem ampliada, não
só a folha de contato em miniatura — mesma lição já registrada duas vezes antes: miniatura pequena
engana):
1. Canvas 40×40 inicial + cabeça perto o bastante da borda direita: nos frames de lunge do
   ATTACK, `body_dx` positivo somado ao deslocamento do focinho jogava a boca inteira para fora do
   canvas — `_set_px()` descarta pixel fora dos limites silenciosamente, sem erro, só uma boca que
   nunca aparecia. Corrigido alargando para 48×48 e recentrando as âncoras (`_R_HIP`,
   `_R_BODY_CENTER`, `_R_HEAD`, `_R_TAIL_BASE`) com folga real.
2. Mesmo depois de caber no canvas, o polígono do interior da boca aberta era pequeno demais
   (< 2px de área) para ler como "boca aberta" em qualquer frame, mesmo no de mordida máxima.
   Corrigido trocando o desenho por uma dobradiça real (acima) — a mandíbula inferior agora desce
   até 6px a mais que a superior no pico do ataque, uma separação clara em vez de uma fresta.

**Decisão de dado, não de arquitetura:** `game/data/dinosaurs/velociraptor.tres` tinha
`placeholder_color = Color(0.95, 0.55, 0.15, 1)` (o mesmo laranja, só que como tingimento de
placeholder) — `Dinosaur.setup()` aplica esse valor via `_visual.set_base_modulate()`, que
multiplica (`modulate`) por cima do `AnimatedSprite2D`. Com arte real, qualquer `modulate`
diferente de branco distorce as cores desenhadas à mão (mesmo sendo a mesma família de cor,
multiplicar laranja por laranja não reproduz o mesmo laranja). Corrigido para
`Color(1, 1, 1, 1)` (branco = modulate neutro, não altera a arte) — o campo continua existindo e
documentado como "reservado para uso futuro" em `dinosaur_definition.gd`, só não é mais usado para
tingir a arte real.

**Desacoplamento necessário:** `_draw_enemy()` (BasicEnemy, não tocado nesta etapa) reaproveitava
a constante `_RAPTOR_LIGHT` como cor de flash de dano. Como o Checkpoint B reestruturou por
completo a geração do Velociraptor (chegando a variar seus valores numa iteração intermediária),
`_draw_enemy()` não deveria depender de uma constante que pertence a outra criatura só porque os
valores coincidiam. Extraído para `_ENEMY_FLASH` (mesmo valor RGB de antes — visual do BasicEnemy
fica pixel-a-pixel igual), só desacoplado por nome.

### Checkpoint C — BasicEnemy (asset pack)

Redesenho completo do BasicEnemy com 15 frames reais (era 6 no protótipo anterior). Paleta mantida
(`#F35A1A`, vermelho-terroso, já estabelecida desde a Phase 0.4) — a diferenciação em relação ao
Velociraptor pedida pelo usuário vem de **plano corporal e postura**, não de recolor:

- Quadrúpede (4 pernas em estrutura — nunca braços, diferente do biped Velociraptor com 2 pernas +
  2 braços pequenos), corpo baixo e largo (o raptor é esguio e alto), cauda curta arrastando perto
  do chão (o raptor tem cauda longa erguida para equilíbrio — oposto deliberado), cabeça larga e
  romba com chifre pequeno (o raptor tem focinho afunilado com crista), crista de espinhos nas
  costas (mantida do protótipo anterior — já era um bom marcador de identidade).
- **Canvas 48×48** (era 32×32) — mesmo raciocínio do Checkpoint B: folga real para poses sem
  recortar.
- Mesma técnica de geração por pose (`_enemy_pose(overrides)`) e membros via `_fill_thick_line()`
  do Checkpoint B, mas pernas de **1 segmento só** (`_draw_enemy_leg()`, sem joelho articulado como
  a perna de 2 segmentos do raptor) — reforça a postura mais bruta/pesada do invasor por design,
  não só simplicidade de código.
- **MOVE (6 frames):** trote real — pares diagonais de pernas alternam apoio, corpo balança
  verticalmente com o passo, cauda baixa balança lateralmente.
- **HIT (3 frames):** recuo do corpo inteiro + achatamento de impacto + focinho abre num resmungo
  de dor — reação física real, não só um flash de cor por cima da pose parada (o flash de cor
  ainda existe, mas como complemento, nunca substituto).
- **DEATH (6 frames):** colapso real — pernas cedem (pés se espalham), corpo afunda e achata,
  crista deita (`spike_lift` 1→0.05), cauda cai no chão, olho fecha. `death` roda a 15fps (6
  frames × 1/15s = 0.4s) para caber exatamente em `DeathEffect._LIFETIME` (constante fixa,
  não alterada nesta etapa) — mesma relação já usada na versão de 2 frames anterior (5fps × 2 =
  0.4s); sem isso o efeito seria destruído por timer antes da animação de morte terminar de tocar.

**2 bugs reais encontrados e corrigidos nesta etapa** (o segundo só ficou óbvio na folha de
contato ampliada, não nos números isolados):
1. Erro de tipagem: `body_ry := 6.5 / pose.flatten` (então chamado `squash`) não compila —
   GDScript não infere o tipo de uma divisão sobre um valor `Variant` vindo de acesso a
   `Dictionary` com `:=`. Corrigido lendo o campo para uma `var flatten: float` tipada antes de
   usar em qualquer expressão aritmética atribuída com `:=` (mesma categoria de gotcha do array
   literal sem tipo, já documentada várias vezes neste arquivo).
2. **Fórmula do achatamento invertida:** a primeira versão usava `body_ry = 6.5 / squash` — com
   `squash < 1.0` (usado nos frames de morte), isso faz a ALTURA CRESCER e a LARGURA DIMINUIR
   conforme o valor cai, o oposto do que "achatar/colapsar" deveria fazer. O inimigo "morrendo"
   ficava mais alto e fino — parecia em pé, quase de cabeça para baixo, em vez de tombar achatado
   no chão. Corrigido renomeando o campo para `flatten` com semântica direta (`1.0` = normal,
   menor = mais baixo E mais largo): `body_ry = 6.5 * flatten`, `body_rx = 10.5 + (1.0 - flatten)
   * 6.0` — as duas dimensões respondem na mesma direção. Esse mesmo ajuste também corrigiu um
   problema latente no HIT (a versão antiga usava `squash > 1.0` para o impacto, que sob a fórmula
   invertida na verdade ficava MENOS achatado, contra a intuição de "squash de impacto").

### Checkpoint D — Ovos + Projéteis (asset pack)

Redesenho completo de `Egg` e `Projectile`, mais a primeira arte real de `DeathEffect` (era só um
losango procedural genérico). Paleta creme/palha para o ovo (tema pré-histórico, tom natural —
nunca branco genérico) e reaproveitamento da paleta do Velociraptor no projétil (é o que a torre
dispara — coerência visual entre quem atira e o que é disparado).

**D1 — Ovo (`assets/eggs/`, 16 frames):** silhueta composta por 2 elipses sobrepostas (base larga
+ topo estreito, não um círculo/oval genérico). 3 aparências discretas, mapeadas nos MESMOS
estados que `egg.gd` já decidia por fração de HP — nenhum estado novo:
- **IDLE = saudável** (4 frames): respiração lenta e sutil — `rx`/`ry` variam de verdade por
  frame (não é `scale` de `Tween`) + um brilho interno ("vida lá dentro") que muda de
  posição/tamanho a cada frame.
- **MOVE = crítico/ferido** (4 frames, reaproveitado — o nome do estado é interno a
  `AnimatedVisual`, o jogador nunca vê "MOVE"): mesma respiração com amplitude maior + marcas
  quentes de estresse na casca — visivelmente diferente da saudável, sem ainda estar quebrada.
- **HIT** (3 frames): squash/recoil real (`rx`/`ry` deformam por impacto) + flash de fratura
  momentâneo, relaxando de volta.
- **DEATH = destruído/quebrado** (5 frames, `loop = false`, congela no último frame para sempre):
  rachaduras se espalhando → casca se separando → fragmento assentando → destruído (interior
  escuro visível, cacos ao redor no chão). Silhueta genuinamente diferente por estágio
  (`_draw_egg_broken(stage)`), não uma variação paramétrica da forma inteira.

**Mudança de integração em `egg.gd`:** o golpe letal agora chama `play_state(DEATH)` diretamente
em vez de `stop_loop()` — DEATH nunca reconecta `animation_finished` (diferente de ATTACK/HIT),
então a arte de casca quebrada fica na tela para sempre sem nenhum mecanismo novo, preservando a
regra de gameplay "o ovo continua visível quando destruído". Um golpe não-letal nunca passa por
DEATH (só HIT, que reverteria ao loop de vida) — as duas coisas nunca tocam no mesmo golpe.

**Removido de `egg.gd`:** o tingimento contínuo por fração de HP (`set_base_modulate` com uma cor
interpolada de branco a vermelho, mais um cinza translúcido no destruído). Mesma categoria de
decisão do Checkpoint B (`placeholder_color`): `modulate` multiplica a cor do sprite, e um tom
não-branco por cima da arte real desenhada nesta etapa desbotaria/distorceria as cores em vez de
só tingir um polígono monocromático como antes. A diferença saudável/ferido/destruído agora vem
inteiramente da animação escolhida.

**D2 — Projétil (`assets/projectiles/`, 4 frames, canvas 20×16 — não quadrado):** dardo/garra
estilizado na paleta do Velociraptor, nariz sempre para +X (o node raiz já gira sozinho para a
direção do alvo em `projectile.gd`, sem mudança nenhuma aqui). Único estado usado por
`projectile.gd` é IDLE — sem MOVE/ATTACK/HIT/DEATH (nunca chamados, não criados à toa). Anima o
tufo/pluma traseiro esvoaçando + um brilho que percorre a lâmina, mantendo a silhueta principal
sempre igual (trajetória tem que continuar legível independente do frame).

**Arte padrão de `DeathEffect` (`assets/effects/`, 4 frames):** antes só existia um
`AnimatedSprite2D` vazio (nunca usado sem `set_death_sprite_frames()`) e um `Placeholder`
(`Polygon2D`) genérico por baixo. Agora o próprio `AnimatedSprite2D` tem `sprite_frames` reais
desde a cena — um burst de impacto pequeno e rápido (núcleo + raios que se espalham e recolhem),
usado sempre que o passthrough de sprite de uma criatura não é chamado (impacto de projétil,
chegada de inimigo ao ninho). O passthrough (morte real do BasicEnemy) continua sobrescrevendo
normalmente, sem nenhuma mudança nesse mecanismo. `death` roda a 10fps (4 frames = 0.4s) para
caber exatamente em `DeathEffect._LIFETIME` — mesma relação já usada no `death` do BasicEnemy.
`Placeholder` foi **removido** (mesmo raciocínio do Checkpoint A/B/C: com `sprite_frames` sempre
presente, o fallback procedural nunca seria acionado de qualquer forma) — `set_death_sprite_frames()`
simplificada, removendo a lógica agora morta de esconder um node que não existe mais.

**3 bugs reais de recorte encontrados e corrigidos nesta etapa** (nenhum visível na folha de
contato padrão — só depois de ampliar bem além dela, mesma lição já repetida nos Checkpoints B/C):
1. Sombra de contato do ovo tocando a última linha do canvas (`_EGG_GROUND_Y` perto demais da
   borda de 32px) — corrigida reduzindo a sombra e subindo a âncora vertical do corpo.
2. Tufo traseiro do projétil ultrapassando a borda esquerda do canvas de 16×16 original — corrigido
   alargando o canvas para 20×16 e recompondo as coordenadas com folga real (não só encurtando o
   tufo, que ficava curto demais na primeira tentativa).
3. Raios do burst de impacto alcançando ~14px de distância do centro num canvas de 24×24 (raio
   útil de ~9-10px) — fórmula original não levava o tamanho do canvas em conta. Corrigida para um
   alcance máximo proporcional ao espaço realmente disponível.

Também corrigido: uma variação "crítica"/"ferido" do ovo (`rx`/`ry` maiores) empurrava a própria
casca — não só a sombra — até a última linha do canvas; subir `_EGG_CY` deu folga para os dois
problemas ao mesmo tempo.

### Checkpoint E — Efeitos (asset pack)

Entre os 6 tipos de efeito do plano original do asset pack (spawn/attack/impact/damage/death/
nest-arrival), impact/death/nest-arrival já tinham arte real desde o Checkpoint D (`DeathEffect`
padrão + passthrough de criatura) e damage continua propositalmente procedural (`DamageNumber`,
texto flutuante — fora do escopo de pixel art, não revisitado). ATTACK já é a própria animação de
mordida do Velociraptor (Checkpoint B); adicionar um efeito separado no mesmo instante arriscava
redundância visual sem necessidade clara, então não foi feito. **O único gap real era SPAWN** — um
inimigo simplesmente "aparecia" no SPAWN sem nenhum reconhecimento visual, diferente de todo
outro evento do jogo (que já reage visualmente desde a Phase 0.6). Esse foi o escopo desta etapa.

**`SpawnEffect`** (`game/scripts/visuals/spawn_effect.gd` + `game/scenes/effects/SpawnEffect.tscn`)
— nova classe, mas **mesmo padrão arquitetural de `DeathEffect`**, não um sistema novo: autônomo,
instanciado como irmão da entidade (nunca filho), nunca bloqueia quem o gerou, se autodestrói
sozinho via `Timer` (`_LIFETIME := 0.35`). Reaproveita `AnimatedVisual.State.DEATH` para a
animação — não por ser uma "morte", mas porque DEATH já é o único estado com o contrato exato que
um efeito de um-tiro-só precisa (toca uma vez, não reconecta `animation_finished`, nunca reverte a
outro estado) — mesma reutilização de contrato que `DeathEffect` já fazia para o burst de impacto
genérico desde o Checkpoint D. Criar um 6º estado (`SPAWN`) em `AnimatedVisual` foi considerado e
descartado: adicionaria uma classe de estado nova para um contrato que já existe.

**Integração:** `EnemySpawner.spawn_enemy()` instancia um `SpawnEffect` logo depois de
`enemy.initialize()`, na posição do inimigo recém-criado (mesmo container que já hospeda
`DamageNumber`/`DeathEffect` — `EnemySpawner` em si, não `Main`). Guardado por `is_inside_tree()`
(mesmo raciocínio de `BasicEnemy`/`Projectile` para `DeathEffect`): evita instanciar um node cujo
`_ready()` nunca dispararia mesmo assim, relevante para `wave_tests.gd`, que usa um `EnemySpawner`
solto via `.new()`, nunca adicionado a uma `SceneTree` real. Nenhuma mudança em HP/dano/path
following/sinais — só uma chamada visual a mais, puramente aditiva.

**Arte** (`assets/effects/spawn_0-3.png`, 24×24, 4 frames, `loop = false`): poeira/terra
levantando do chão — o inimigo "emerge" do próprio terreno, tema pré-histórico — em vez de um
flash de luz (isso já é a linguagem do impacto; precisava ser visualmente distinto para não
parecer o mesmo efeito reaproveitado sem necessidade). Paleta terrosa puxando para a família de
cor da trilha, não uma cor nova sem relação com o resto. 4 puffs que mudam de posição/tamanho/tom
por frame (agrupados e escuros perto do chão → maiores e subindo → pico disperso e mais claro →
poucos remanescentes clareando antes de sumir) — nunca é só uma cor diferente por cima do mesmo
desenho.

**1 bug real de recorte encontrado e corrigido** (mesma classe dos 3 do Checkpoint D — só
apareceu no teste automatizado por pixel, não na inspeção visual): a primeira versão dos
multiplicadores de espalhamento/subida dos puffs (offset×7, subida×8, raio até 3.8) colocava
pixels opacos na borda do canvas de 24×24 no frame de pico (`spawn_2.png`, o mais espalhado).
Corrigida reduzindo os três multiplicadores com folga real, não só o mínimo que coubesse.

### Checkpoint F — Polimento e Integração

Não é um checkpoint de asset pack — nenhum PNG novo, nenhuma silhueta/paleta alterada. Objetivo:
auditar como os Checkpoints A–E funcionam JUNTOS dentro de `Main.tscn` de verdade (não só em
composições isoladas) e corrigir defeitos objetivos de integração (escala/offset/posição/timing/
frame rate/layering) — não redesenho.

**Bug real mais importante encontrado nesta etapa:** `Main.tscn` tinha `debug_visible = true`
como override de instância no `GridManager`, herdado desde antes de existir qualquer arte real
(quando debug colors eram a ÚNICA forma de ver a grid). O Checkpoint A mudou o **default** do
script para `false` ("por padrão desenha os tiles reais"), mas nunca tocou em `Main.tscn` — o
override de instância continuou vencendo o novo default silenciosamente. Na prática, **a cena de
produção nunca mostrou a arte pixel real por padrão em nenhum momento entre os Checkpoints A e F**
— todo o trabalho visual foi validado por inspeção isolada de PNGs/composições, nunca pela cena
real, porque a cena real sempre caía de volta nos retângulos de cor sólida de debug (F3 alternava
para o modo "outro" — ou seja, o jogador só veria a arte real apertando F3, o oposto do
pretendido). Corrigido removendo o override — `GridManager` volta a herdar `debug_visible = false`
do próprio script, exatamente como todos os outros checkpoints sempre assumiram que já era o caso.

**Layering (`z_index`):** nenhum node do projeto usava `z_index` antes desta etapa — a ordem de
desenho seguia só a ordem dos nós-irmãos em `Main.tscn`/containers. Isso deixava `DeathEffect`/
`SpawnEffect`/`DamageNumber` (todos hospedados dentro de `EnemySpawner` ou `Projectiles`, que vêm
ANTES de `Dinosaurs`/`Projectiles`/`EggManager` na árvore de `Main`) desenhados ATRÁS de qualquer
raptor/projétil/ovo que estivesse por cima no momento do efeito — contrariando "efeitos aparecerem
sobre o alvo". Corrigido com `z_index = 10` em `DeathEffect.tscn`/`SpawnEffect.tscn` e
`z_index = 15` em `DamageNumber.tscn` (mais alto que os outros dois, para o número de dano nunca
ficar escondido nem atrás de um personagem nem atrás de outro efeito no mesmo lugar) — resolve sem
precisar reordenar a árvore inteira (que também reordenaria inimigos, não só efeitos).

**HUD — bug real de sobreposição com o mapa:** `PauseButton`/`SpeedButton` ficavam no canto
superior direito (x:488–632, y:8–44). Auditando as posições REAIS de `vale_dos_ovos.tres` (não
assumidas — lidas do recurso), as 3 células EGG do mapa ficam em (576–640, 0–64) — o `SpeedButton`
(x:564–632, y:8–44) sobrepunha diretamente uma delas, e tocava a borda de outras duas. Violava
"ovos permanecerem claramente visíveis" pedido nesta etapa. Corrigido reagrupando os 4 botões
(`DinosaurButton`, `PauseButton`, `SpeedButton`, `StartWaveButton`) numa única fileira no rodapé
(y:332–376, mesma altura de todos, preenchendo o espaço livre entre os dois botões que já
existiam ali) — libera todo o topo do mapa, zero sobreposição com qualquer célula EGG/SPAWN/NEST
do mapa real (posições conferidas uma a uma).

**HUD — legibilidade de texto sobre o mapa:** com `debug_visible` corrigido, os `Label`s da HUD
(`EggsLabel`/`CoinsLabel`/`WaveLabel`/`WaveStateLabel`/`BannerLabel`/etc.) passam a desenhar por
cima da arte pixel de verdade (grama/trilha com tons variados), não mais sobre um fundo de debug
sólido e escuro que garantia contraste de graça. Adicionado um `Theme` mínimo (`Label/colors/
font_outline_color` + `Label/constants/outline_size = 3`) no `Root` da HUD — todo `Label` herda um
contorno escuro automaticamente, sem precisar repetir a configuração em cada node nem criar um
sistema de HUD novo. Mesmo raciocínio aplicado a `DamageNumber` (`draw_string_outline()` antes do
`draw_string()` colorido) — o número de dano é `CanvasItem.draw_string()` direto, não um `Label`,
então não herda o `Theme` da HUD; precisa do próprio contorno.

**Animações — timing auditado, nenhum ajuste necessário:** revisados os fps de todas as
`SpriteFrames` existentes (Velociraptor, BasicEnemy, Egg, Projectile, DeathEffect, SpawnEffect)
contra a métrica real de gameplay onde aplicável (ex: `attack_interval = 0.6s` do Velociraptor vs.
0.43s de duração da animação ATTACK — cabe com folga, nunca corta nem se sobrepõe ao próximo
disparo). Todos os valores já fazem sentido relativo entre si (loops mais lentos para estados
passivos, reações rápidas para HIT/ATTACK, `death`/`impact`/`spawn` casados com o lifetime fixo
dos efeitos que os usam) — nenhum frame rate estava "claramente inadequado" a ponto de justificar
mudança nesta etapa.

**Feedback de gameplay — auditoria de cobertura, nenhum efeito novo necessário:** todo evento
listado nesta etapa (nasceu/dano/morte/impacto/ovo-dano/ovo-destruído/wave-início/wave-fim/
última-wave/GAME OVER/pausa) já tinha um sinal real conectado a uma reação visual concreta antes
desta etapa (`Dinosaur.fired`, `BasicEnemy.damaged`/`died`, `Projectile.impacted`, `Egg.damaged`,
`WaveManager.wave_started`/`wave_completed`, `EggManager.all_eggs_destroyed`,
`EnemySpawner.enemy_spawned`) — confirmado lendo o código, não assumido. Nenhuma coleção de
efeitos redundante foi criada.

**Pontos de integração de áudio (documentação — nenhum asset/AudioManager criado nesta etapa):**
onde um som entraria naturalmente quando existir orçamento de áudio, todos já como sinais/pontos
de chamada existentes, sem precisar de nenhuma reestruturação:
- Ataque: `Dinosaur.fired(dinosaur, projectile)` (`scripts/dinosaurs/dinosaur.gd`)
- Impacto: `Projectile.impacted(projectile, target)` (`scripts/combat/projectile.gd`)
- Dano: `BasicEnemy.damaged(enemy, amount)` / `Egg.damaged(egg, amount)`
- Morte: `BasicEnemy.died(enemy)`
- Spawn: `EnemySpawner.enemy_spawned(enemy)` (mesmo ponto onde `SpawnEffect` já é instanciado)
- Início de wave: `WaveManager.wave_started(wave_index, wave)`
- Conclusão de wave / vitória: `WaveManager.wave_completed(wave_index, wave)` (`Main._on_wave_completed()`
  já diferencia "última wave" internamente para o banner de vitória — o mesmo sinal serve para SFX
  diferente por condição, se necessário)
- GAME OVER: `EggManager.all_eggs_destroyed()`
- Pausa: `HUD.pause_pressed`/`resume_pressed`

**Validação visual desta etapa — composição vs. tela real (distinção explícita, pedida pelo
usuário):** **validado por composição matemática** (mesma técnica do checkpoint de integração
anterior — PNGs reais na mesma matemática de posicionamento do jogo): posições exatas de
EGG/SPAWN/NEST lidas diretamente de `vale_dos_ovos.tres` (não estimadas), confirmando a
sobreposição do `SpeedButton` e a correção depois de aplicada. **NÃO confirmado em tela real:**
como o contorno dos `Label`s realmente fica sobre a textura da grama/trilha em movimento, timing
percebido das animações em jogo, e o efeito visual concreto do `debug_visible` corrigido (a
mudança mais importante desta etapa) — todos dependem de uma sessão no editor com tela real, ainda
não disponível neste ambiente (mesma tentativa de screenshot headless já documentada no checkpoint
anterior, que trava indefinidamente nesta plataforma).

### Testes

`game/tests/visual_prototype_tests.gd` — confirma que `Dinosaur`/`BasicEnemy` realmente
usam o `AnimatedSprite2D` (não caem silenciosamente no fallback procedural por um erro de
wiring), que uma reação sprite-driven (ATTACK/HIT) volta sozinha ao loop anterior ao terminar
(`animation_finished.emit()` simulado, sem depender de tempo real), e que `DeathEffect` recebe o
`SpriteFrames` da criatura numa morte de verdade. Não testa a arte em si (cores/formas exatas de
pixel) — só o contrato de estados que `AnimatedVisual`/gameplay dependem.

`game/tests/environment_assets_tests.gd` (novo, checkpoint de Ambiente) — cobre o contrato de
arquivo dos 26 PNGs de `assets/environment/`: tiles de chão (grama/trilha) existem, são 32×32 e
totalmente opacos; tiras de borda existem com as dimensões retangulares corretas (32×10 ou 10×32)
e também opacas; decorações e detalhes existem, são 32×32 e têm pelo menos um pixel transparente
(não são um bloco sólido cobrindo o tile); variações de grama e de trilha são de fato
pixel-a-pixel diferentes entre si (`_pixel_diff_count()` — não basta existir um nome de arquivo
diferente, mesma lição do bug do focinho do raptor); nenhuma decoração/detalhe toca as 4 bordas do
canvas simultaneamente (sinal de conteúdo vazando para fora da célula). Não testa a composição
artística em si (cores/formas exatas) nem a integração real em `GridManager` — isso é coberto
indiretamente pelo compile-check (`preload()` falha se o arquivo não existir).

`game/tests/velociraptor_assets_tests.gd` (novo, Checkpoint B) — cobre o contrato de arquivo dos
19 PNGs de `assets/dinosaurs/velociraptor/`: existem, são 48×48, têm fundo transparente; **nenhum
pixel opaco toca a borda externa do canvas** em nenhum frame (teste direto para a classe de bug de
recorte encontrada duas vezes nesta etapa — mais rigoroso que o equivalente de
`environment_assets_tests.gd`, que só rejeita tocar as 4 bordas ao mesmo tempo: aqui qualquer
única borda tocada já falha, porque um personagem nunca deveria legitimamente encostar na borda,
diferente de uma decoração de ambiente); frames consecutivos de cada animação não são
pixel-a-pixel idênticos; o `SpriteFrames` final tem as 4 animações (`idle`/`move`/`attack`/`hit`)
com a contagem mínima de frames exigida (4/6/6/3) e nenhum frame aponta para textura nula;
`Dinosaur.tscn` referencia esse `SpriteFrames`. Não testa a arte em si (cores/formas exatas).

`game/tests/basic_enemy_assets_tests.gd` (novo, Checkpoint C) — mesmo padrão de
`velociraptor_assets_tests.gd`, aplicado aos 15 PNGs de `assets/enemies/basic_enemy/`: existem,
são 48×48, fundo transparente, nenhum pixel opaco toca a borda do canvas, frames consecutivos
diferem de verdade, `SpriteFrames` com `move`/`hit`/`death` na contagem mínima (6/3/6) e nenhum
frame nulo, `BasicEnemy.tscn` referencia esse `SpriteFrames`.

`game/tests/egg_projectile_assets_tests.gd` (novo, Checkpoint D) — mesmo padrão, cobrindo os 3
grupos de uma vez: os 16 PNGs de `assets/eggs/` (32×32), os 4 de `assets/projectiles/` (20×16 —
único grupo não-quadrado até agora, o teste aceita largura/altura esperadas separadas), e os 4 de
`assets/effects/` (burst de impacto padrão, 24×24); dimensões, transparência, nenhum pixel opaco
na borda, frames consecutivos realmente diferentes, os 3 `SpriteFrames` (`egg_sprite_frames.tres`,
`projectile_sprite_frames.tres`, `impact_sprite_frames.tres`) com as animações esperadas e
contagem mínima, `Egg.tscn`/`Projectile.tscn`/`DeathEffect.tscn` referenciando cada um. Também em
`egg_tests.gd`: um teste novo confirma que o golpe letal toca `DEATH` diretamente (não `HIT`) e
que a animação não reverte para IDLE/MOVE depois de terminar (`animation_finished.emit()`
simulado) — a regra de gameplay "ovo continua visível quando destruído" depende disso.

`game/tests/spawn_effect_assets_tests.gd` (novo, Checkpoint E) — mesmo padrão, cobrindo os 4 PNGs
de `assets/effects/spawn_0-3.png` (24×24): dimensões, transparência, nenhum pixel opaco na borda,
frames consecutivos realmente diferentes, `spawn_sprite_frames.tres` com a animação `death` e
contagem mínima, `SpawnEffect.tscn` referenciando esse `SpriteFrames`. A integração (`EnemySpawner`
realmente instancia um `SpawnEffect` sibling ao spawnar) é coberta por um teste novo em
`integration_tests.gd` (que já carregava `Main.tscn` de verdade para o resto do pipeline
MapPath→EnemySpawner→BasicEnemy) — conta exatamente 1 `SpawnEffect` entre os filhos do
`EnemySpawner` depois de `spawn_enemy()`.

### Decisões que precisam de validação visual real

Sem loop de interação visual/mouse/teclado disponível — mesma limitação já registrada em fases
anteriores. **Capturar um screenshot real do motor em modo `--headless` foi tentado explicitamente
(checkpoint de integração entre D e E) e travou indefinidamente** — `get_viewport().get_texture()`
não renderiza nesta plataforma sem display; abortado, confirmando que não há uma forma segura
disponível, não só assumindo que não havia.

O que foi possível validar: inspeção direta de todos os PNGs via leitura de imagem em várias
escalas (confirmou silhueta/contraste/legibilidade dos personagens e tiles isoladamente; permitiu
corrigir o bug de recorte do focinho do raptor, o desbalanceamento grama/trilha da tira de borda,
o recorte do focinho no lunge do ATTACK e a mordida ilegível por área insuficiente do polígono no
Checkpoint B, a fórmula de achatamento invertida do colapso de morte no Checkpoint C, os 3
recortes de borda (sombra do ovo, tufo do projétil, raios do impacto) no Checkpoint D, e o recorte
dos puffs de poeira no Checkpoint E — nenhum desses ficou óbvio na folha de contato padrão, só
ampliando bem além dela ou, nos recortes de borda, com um teste automatizado dedicado por pixel);
a folha de contato ampliada (`preview_contact_sheet.gd`) para conferir as peças de ambiente e os
frames de personagens/ovo/projétil/impacto/spawn lado a lado; e, no checkpoint de integração, uma
composição manual dos PNGs já existentes usando a MESMA matemática de posicionamento real
(`_pick()` determinístico, `cell_to_world()+cell_size/2`, sprite centrado) — confirmou escala
relativa raptor/inimigo/ovo/projétil coerente, transição grama↔trilha contínua (um crop mais largo
tinha enganado a primeira leitura visual — um crop isolado das colunas de trilha confirmou que era
uma textura serrilhada única, não uma segunda lacuna), paleta consistente entre categorias, e
filtro Nearest confirmado via `.import`/`project.godot` (não só assumido). Ausência de
erro/warning/leak em todas as execuções headless, sempre. **Ainda não verificado:** como a grid
renderizada de verdade fica dentro do editor com tela real (alinhamento fino dos tiles, timing
real da animação em jogo — incluindo `SpriteFrames` de Velociraptor/BasicEnemy/Egg/Projectile/
DeathEffect/SpawnEffect —, legibilidade da cena completa com todos os elementos em movimento,
percepção real de velocidade de animação) — precisa de uma sessão no editor com tela real antes de
considerar o protótipo visual validado ponta a ponta.
