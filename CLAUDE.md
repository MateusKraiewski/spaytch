# CLAUDE.md

Instruções globais para trabalho neste projeto. Leia antes de implementar qualquer coisa.

## Sobre o Projeto

**SPAYTCH** é um Tower Defense 2D em pixel art, desenvolvido em **Godot 4.x**, com lançamento
planejado para **PC e Android**.

Documentação de referência:
- Visão de jogo e conteúdo: [docs/GAME_BIBLE.md](docs/GAME_BIBLE.md)
- Arquitetura técnica: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Direção visual: [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md)
- Roadmap de desenvolvimento: [docs/ROADMAP.md](docs/ROADMAP.md)

Skills especializadas em [.claude/skills/](.claude/skills/) orientam decisões de implementação
em áreas específicas (Godot, arquitetura, gameplay, tower defense, pixel art, performance mobile,
testes). Consulte a skill relevante antes de trabalhar na área correspondente.

## Princípios de Engenharia

- **Clareza acima de esperteza.** Código deve ser fácil de ler e entender por qualquer pessoa
  que entre no projeto depois.
- **Modularidade.** Sistemas devem ser desacoplados o suficiente para serem testados, alterados
  ou removidos individualmente sem cascata de efeitos colaterais.
- **Evitar overengineering.** Não construa abstrações, camadas ou generalizações para problemas
  que ainda não existem. Resolva o problema atual da forma mais direta e sustentável.
- **Evitar duplicação.** Antes de escrever algo novo, verifique se já existe uma solução no
  projeto que possa ser reutilizada ou estendida.
- **Separar dados de comportamento** quando fizer sentido. Um inimigo, uma torre, um upgrade —
  seus valores (dano, vida, custo, cooldown) não devem estar hardcoded dentro da lógica que os
  usa.
- **Usar Resources do Godot para dados configuráveis.** `Resource` customizados (`.tres`) são a
  forma padrão de definir dados de gameplay (stats de torres, inimigos, waves, upgrades, etc.),
  permitindo edição no editor sem tocar em código.
- **Evitar hardcode de valores de gameplay.** Se um valor pode razoavelmente precisar de ajuste
  por design/balanceamento, ele deve viver em um Resource ou arquivo de configuração — não em
  uma constante enterrada no meio de um script.

## Regras de Arquitetura

- **Não modificar arquitetura existente sem justificar.** Se uma mudança estrutural for
  necessária, explique o motivo antes de aplicá-la.
- **Não adicionar funcionalidades não solicitadas.** Implemente o que foi pedido; não expanda
  escopo por conta própria.
- **Antes de implementar algo grande, analisar a arquitetura existente.** Leia
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) e o código relacionado antes de propor uma
  abordagem.
- **Preservar compatibilidade com Android.** Toda decisão técnica (input, shaders, rendering,
  filesystem, plugins) deve considerar se funciona em mobile, não só em desktop.
- **Considerar performance desde o início.** Não trate performance como algo a ser resolvido
  depois — especialmente em dispositivos Android de baixo/médio desempenho (veja a skill
  `mobile-performance`).
- **Não criar sistemas globais/autoloads sem justificativa.** Autoloads (singletons) devem ser
  a exceção, não o padrão. Justifique por que o estado ou serviço realmente precisa ser global.
- **Documentar decisões arquiteturais relevantes.** Mudanças estruturais importantes devem ser
  registradas em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Trade-off entre implementação rápida e arquitetura sustentável:** quando houver conflito,
  explique as duas opções e seus custos/benefícios antes de escolher um caminho. Não decida
  isso silenciosamente.

## Development Workflow

Para qualquer tarefa não trivial, siga este fluxo:

1. **Analisar** — entender o pedido, ler código e documentação relevante, identificar
   dependências e impacto.
2. **Planejar** — definir a abordagem antes de escrever código. Para mudanças grandes, apresentar
   o plano antes de implementar.
3. **Implementar** — escrever o código seguindo os princípios acima, de forma incremental.
4. **Testar** — validar que a implementação funciona conforme esperado (ver skill `testing`).
5. **Revisar** — checar o próprio trabalho: duplicação, hardcode, efeitos colaterais,
   compatibilidade com Android.
6. **Documentar quando necessário** — atualizar `docs/ARCHITECTURE.md`, `docs/GAME_BIBLE.md` ou
   comentários apenas quando a mudança introduz uma decisão ou conceito não óbvio.

## Escopo Atual

O projeto está na fase de **fundação** (Phase 0 — veja [docs/ROADMAP.md](docs/ROADMAP.md)).
Ainda não há gameplay, torres, inimigos, mapas ou assets implementados. Não assuma conteúdo de
design que ainda não foi definido — verifique `docs/GAME_BIBLE.md` antes de inventar detalhes.
