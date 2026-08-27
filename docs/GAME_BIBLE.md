# GAME BIBLE — SPAYTCH

Documento vivo com a visão de design do jogo. Seções ainda não definidas permanecem como
placeholder (`TBD`/`FUTURE`). Não preencher com conteúdo definitivo antes de decisões reais
serem discutidas e confirmadas.

> Status geral: **identidade inicial definida** (nome, conceito, core loop, papéis de
> dinossauros/inimigos/ovos, filosofia de design). Números, balanceamento e conteúdo específico
> (torres/inimigos/mapas individuais) ainda **não** foram definidos.

---

## Vision

**Nome:** SPAYTCH

**Conceito:** Tower Defense 2D em pixel art no qual dinossauros defendem ovos contra ondas de
criaturas que tentam chegar ao ninho.

**Descrição provisória:** SPAYTCH é um Tower Defense de dinossauros onde o jogador posiciona e
evolui dinossauros defensores para proteger ovos durante ondas progressivamente mais difíceis.
*(Descrição sujeita a refinamento futuro.)*

### Filosofia de Design

> "Dinossauros protegem ovos; o objetivo do jogador é impedir que os inimigos alcancem o ninho."

O jogo deve priorizar, nesta ordem de importância conceitual (sem hierarquia numérica definida
ainda):

- Diversão
- Clareza
- Estratégia
- Personalidade
- Feedback visual
- Acessibilidade
- Sessões fáceis de entender
- Profundidade progressiva

Evitar violência gráfica ou conteúdo excessivamente pesado — o tom do jogo é carismático e
acessível, não sombrio.

*Pilares de design formais (3–5 frases-guia) — TBD.*

## Core Gameplay

**Core loop provisório:**

```
Preparar → Construir → Defender → Recompensar → Evoluir → Próxima onda
```

O jogador deve:

- posicionar dinossauros;
- defender ovos;
- enfrentar ondas de inimigos;
- receber recursos;
- melhorar ou desbloquear defensores;
- sobreviver a ondas progressivamente mais difíceis.

### Ovos

Os ovos são um objeto central de gameplay — **não** devem ser tratados como uma simples barra
de HP genérica.

- Inimigos podem ter como objetivo alcançar o ninho e **roubar** ovos (não apenas causar dano).
- A quantidade e a posição dos ovos podem variar por mapa (ver [Maps](#maps)).
- **FUTURE/TBD:** diferentes tipos de ovos com propriedades próprias. Não definido em detalhes
  neste momento — apenas registrado como possibilidade futura.

**Implementado (Phase 0.5):** os ovos já são objetos reais de jogo, com HP próprio. Nesta
primeira versão, um inimigo que alcança o ninho **causa dano** ao ovo (não ainda o "roubo"
descrito acima — isso continua `FUTURE/TBD`); quando todos os ovos de uma partida são destruídos,
a partida termina (GAME_OVER). Valores de HP/dano são técnicos e provisórios — ver
[ARCHITECTURE.md](ARCHITECTURE.md), não definitivos de design.

## Player Experience

*TBD — como a filosofia de design (acima) se traduz em sensação momento-a-momento: tensão,
poder, ritmo. Depende de playtesting e balanceamento ainda não realizados.*

## Game Loop

**Loop de curto prazo (dentro de uma wave):** preparar posicionamento → construir/ajustar
defensores → defender contra a wave atual.

**Loop de médio prazo (dentro de uma partida):** recompensar após a wave → evoluir/desbloquear
defensores → encarar a próxima wave, progressivamente mais difícil.

**Loop de longo prazo (meta-progressão entre partidas):** *TBD.*

## Towers

Na SPAYTCH, o papel tradicional de "torre" é preenchido por **dinossauros defensores**. Ver
seção [Dinossauros](#dinossauros-defensores) abaixo.

### Dinossauros (Defensores)

Cada dinossauro deve ter uma identidade de gameplay própria, não apenas variação de números.

**Categorias provisórias** (conceitos iniciais, não lista final de dinossauros):

- Tank / Crowd Control
- DPS rápido
- Long Range
- Burst Damage
- Aéreo
- Defesa
- Debuff

Nenhum outro dinossauro específico foi definido ainda além do Velociraptor.

**Velociraptor** é o primeiro dinossauro concreto do jogo (primeiro vertical slice do sistema de
torres — Phase 0.4): papel **DPS**, alcance médio, ataque rápido baseado em projétil, dano
baixo/médio, targeting inicial FIRST (maior progresso no caminho), sem habilidade especial e sem
upgrades nesta fase. Números exatos de balanceamento (dano, alcance, cooldown) são técnicos e
provisórios — ver [ARCHITECTURE.md](ARCHITECTURE.md), não definitivos de design.

## Enemies

O objetivo principal de todo inimigo é alcançar os ovos.

**Comportamentos especializados possíveis (FUTURE/TBD, não implementados nem detalhados):**

- alta velocidade;
- ataque aos defensores;
- roubo de ovos;
- voo;
- resistência;
- suporte a outros inimigos;
- habilidades especiais.

Nenhum inimigo específico ou estatística foi definido ainda.

## Waves

Ondas devem ser **progressivamente mais difíceis** ao longo de uma partida (ver Core Gameplay).
Estrutura detalhada de ritmo, composição e escalonamento: *TBD.*

**Implementado (Phase 0.5):** existem 3 ondas técnicas de teste (5, 8 e 10 inimigos, com
intervalo de spawn decrescente) — o jogador inicia cada onda manualmente pela HUD, nunca
automático. São dados de validação do sistema, não conteúdo final de design; composição
(sempre o mesmo tipo de inimigo), ritmo e progressão de dificuldade reais ainda são `TBD`.

## Maps

A quantidade e a posição dos ovos/ninho podem variar por mapa. Estrutura geral de mapas
(quantidade planejada, critérios de design de nível, caminhos): *TBD.*

### Princípio de Level Design

> **O mapa deve criar decisões interessantes antes de o jogador possuir upgrades.**

A geometria de um mapa (caminho, curvas, áreas construíveis com identidade estratégica própria,
posição dos ovos) já deve gerar escolhas de posicionamento relevantes por si só — antes de
qualquer sistema de evolução, upgrade ou economia entrar em cena. Este é um princípio de design
do SPAYTCH, não uma regra específica de um mapa. Ver `Vale dos Ovos` (primeiro mapa,
[ARCHITECTURE.md](ARCHITECTURE.md)) como primeira aplicação concreta desse princípio.

### Vale dos Ovos (primeiro mapa)

Primeiro mapa do jogo, com o objetivo de ensinar o jogador a proteger ovos, ler o caminho dos
inimigos e reconhecer áreas estratégicas diferentes (DPS, controle/choke point, long range) —
antes de qualquer upgrade existir. Layout técnico e decisões de implementação documentados em
[ARCHITECTURE.md](ARCHITECTURE.md); este é apenas o registro de que o mapa existe e sua intenção
de design. Balanceamento (dano, alcance, custo) não foi definido — fora de escopo desta fase.

## Economy

Economia gira em torno de recursos ganhos **durante as partidas**.

**Fontes possíveis:**

- derrotar inimigos;
- completar ondas;
- objetivos;
- sistemas de recompensa futuros (não definidos).

**Fora de escopo neste momento:** loja, monetização, gacha, sistemas de energia. Não devem ser
projetados nem implementados sem decisão explícita futura.

**Implementado (Phase 0.5):** a moeda **coins** existe de verdade dentro de uma partida — o
jogador começa com uma quantidade inicial, gasta coins para posicionar o Velociraptor, e ganha
coins ao matar inimigos e ao completar uma onda (as duas primeiras fontes da lista acima).
"Objetivos" e "sistemas de recompensa futuros" continuam `TBD`. Nenhuma persistência entre
partidas — coins zeram a cada nova sessão do jogo. Valores exatos (quantidade inicial, custo do
Velociraptor, recompensas) são técnicos e provisórios — ver [ARCHITECTURE.md](ARCHITECTURE.md).

## Progression

Há intenção de permitir **evolução dos dinossauros** por especialização, não apenas aumento
linear de estatísticas.

**Exemplo conceitual (apenas ilustrativo, TBD):**

```
Velociraptor
 → especialização em velocidade
 → especialização em dano
 → especialização em crítico
```

Este é um conceito de design provisório. Árvores de especialização reais, custos e efeitos:
*TBD.*

## Bosses

*TBD — não mencionado nas decisões de design até o momento.*

## Abilities

*TBD — habilidades especiais de inimigos foram citadas como possibilidade futura (ver
[Enemies](#enemies)); habilidades de dinossauros/jogador ainda não definidas.*

## UI/UX

**Implementado (Phase 0.6):** o jogo abre numa tela de título (Main Menu) — "SPAYTCH" / "Ovos de
Dinossauro Defense" — com JOGAR/OPÇÕES/SAIR, antes de entrar na partida propriamente dita. Uma
tela de LOGIN/PERFIL não existe ainda (nem autenticação real — fora de escopo), mas a estrutura já
comporta inserir isso entre o Main Menu e o jogo no futuro sem reestruturar. Detalhes técnicos em
[ARCHITECTURE.md](ARCHITECTURE.md).

Restante (fluxos de tela detalhados, iconografia, tom de copy): *TBD.*

## Audio

*TBD.*

## VFX

Diretriz provisória: combinar pixel art com VFX modernos (partículas, impactos, flashes,
iluminação leve, screen shake quando apropriado, efeitos de habilidades) para manter o jogo
visualmente vivo sem perder a identidade pixel art. Detalhes técnicos em
[ART_DIRECTION.md](ART_DIRECTION.md).

## Art Direction

Ver documento dedicado: [ART_DIRECTION.md](ART_DIRECTION.md). Direção provisória: pixel art
colorida, dinossauros carismáticos, mundo visualmente atraente para crianças mas com
acabamento sofisticado o suficiente para agradar também jogadores adultos.

## Mobile

*TBD.*

## Future Ideas

- Tipos de ovos com propriedades próprias (FUTURE/TBD — ver [Ovos](#ovos)).
- Especializações de evolução por dinossauro além do exemplo ilustrativo do Velociraptor.
- Comportamentos especializados adicionais de inimigos (ver [Enemies](#enemies)).
- Sistemas de recompensa futuros além das fontes de economia já listadas.
