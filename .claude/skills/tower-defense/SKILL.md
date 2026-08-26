---
name: tower-defense
description: Conceitos técnicos gerais do gênero Tower Defense aplicáveis ao SPAYTCH — sem definir torres, inimigos ou conteúdo específico ainda (isso vive em docs/GAME_BIBLE.md).
---

# Tower Defense

## Purpose

Estabelecer conceitos técnicos e estruturais gerais do gênero Tower Defense que devem informar
a arquitetura do SPAYTCH, sem travar ainda o conteúdo específico (quais torres, quais inimigos,
quais mapas existirão). Conteúdo concreto só deve ser implementado depois de definido em
`docs/GAME_BIBLE.md`.

## When to use

- Ao projetar a arquitetura genérica de torres, inimigos, projéteis, ou waves.
- Ao decidir como o pathing de inimigos deve funcionar tecnicamente.
- Ao definir a interface genérica entre torre → alvo → dano → economia.
- Antes de implementar qualquer conteúdo específico de torre/inimigo — para garantir que a base
  técnica suporte variação de conteúdo sem retrabalho.

## Core Principles

- Um Tower Defense tem, tipicamente, os seguintes conceitos técnicos recorrentes que devem ser
  suportados pela arquitetura, independentemente do conteúdo final:
  - **Placement**: posicionamento de torres em posições válidas (grid ou livre).
  - **Targeting**: como uma torre seleciona um alvo entre inimigos no alcance (ex: mais próximo,
    mais avançado, mais vida).
  - **Pathing**: como inimigos se movem do ponto de spawn ao objetivo (caminho fixo, navmesh,
    ou grid-based pathfinding).
  - **Combat resolution**: como dano é calculado e aplicado (instantâneo, projétil, área).
  - **Wave orchestration**: como e quando inimigos são spawnados ao longo do tempo.
  - **Economy loop**: custo de construir/upgradar torres vs. recompensa por eliminar inimigos.
- Torres e inimigos devem ser modelados de forma **orientada a dados** (Resources) para que
  novo conteúdo não exija nova arquitetura (ver `game-architecture`).
- A base técnica deve suportar variação (tipos de dano, tipos de alvo, resistências) sem que
  cada combinação exija código especial — prefira sistemas de tags/categorias a `if/elif` em
  cascata.

## Do

- Projetar a interface genérica de "torre" e "inimigo" antes de qualquer conteúdo específico
  ser implementado.
- Prever, na arquitetura, pontos de extensão para: múltiplos tipos de alvo, múltiplos tipos de
  dano/resistência, e diferentes comportamentos de movimento — mesmo que hoje só exista um caso
  de cada.
- Consultar `docs/GAME_BIBLE.md` para confirmar que um conceito de design já foi definido antes
  de implementá-lo.
- Pensar em performance de pathing e targeting desde o início (potencialmente dezenas de
  inimigos e torres simultâneas, especialmente relevante em Android — ver `mobile-performance`).

## Don't

- Não definir ou inventar torres, inimigos, waves ou mapas específicos nesta skill — isso é
  conteúdo de design, não conceito técnico.
- Não implementar targeting/pathing com lógica hardcoded para um único caso quando o gênero
  exige suportar variação.
- Não acoplar a lógica de combate diretamente à lógica de economia — devem se comunicar via
  interface clara (ex: signal `enemy_defeated` consumido pelo sistema de economia).

## Workflow

1. Verificar em `docs/GAME_BIBLE.md` se o conceito já tem definição de design.
2. Projetar a interface técnica genérica (torre, inimigo, wave, economia) capaz de suportar
   variação futura de conteúdo.
3. Implementar a base técnica antes de qualquer conteúdo específico.
4. Validar com um caso mínimo de teste (ex: uma torre placeholder, um inimigo placeholder) antes
   de expandir.
5. Documentar decisões estruturais relevantes em `docs/ARCHITECTURE.md`.

## Relevant Project Files

- [docs/GAME_BIBLE.md](../../../docs/GAME_BIBLE.md)
- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [game-architecture skill](../game-architecture/SKILL.md)
- [gameplay-system skill](../gameplay-system/SKILL.md)
