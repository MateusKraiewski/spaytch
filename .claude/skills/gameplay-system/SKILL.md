---
name: gameplay-system
description: Orienta a implementação modular de sistemas de gameplay no SPAYTCH — como estruturar um sistema novo (não conteúdo específico como torres/inimigos individuais).
---

# Gameplay System

## Purpose

Guiar *como* implementar um sistema de gameplay de forma modular e testável — independente de
qual sistema seja (economia, dano, waves, upgrades, etc.). Esta skill trata do padrão de
implementação, não do conteúdo específico de design (isso vive em `docs/GAME_BIBLE.md` e é
implementado apenas quando definido).

## When to use

- Ao implementar um sistema de gameplay novo (ex: sistema de dano, sistema de economia, sistema
  de spawn de inimigos).
- Ao estender um sistema existente com uma nova capacidade.
- Ao decidir a interface entre um sistema de gameplay e a UI ou outros sistemas.

## Core Principles

- Um sistema de gameplay deve ser **modular**: possível de entender, testar e modificar de forma
  isolada.
- Um sistema deve expor uma **interface clara** (métodos públicos, signals) e esconder detalhes
  internos de implementação.
- Sistemas devem ser **orientados a dados** sempre que o conteúdo (torres, inimigos, waves) puder
  variar — a lógica não deve precisar mudar quando só o balanceamento muda.
- Sistemas devem **falhar de forma previsível**: estados inválidos devem ser evitados por design,
  não silenciosamente ignorados.
- Gameplay systems não devem depender de detalhes de apresentação (UI, VFX) — a lógica de jogo
  deve funcionar mesmo sem a camada visual acoplada diretamente.

## Do

- Definir a interface pública do sistema (o que ele expõe) antes de implementar o interior.
- Usar signals para notificar mudanças de estado relevantes a outros sistemas/UI (ex:
  `health_changed`, `wave_started`).
- Escrever o sistema pensando em como ele seria testado isoladamente (ver skill `testing`).
- Consumir dados de `Resource` para tudo que for configurável.
- Manter o sistema pequeno e focado; dividir em sistemas menores se a responsabilidade crescer.

## Don't

- Não implementar conteúdo específico (uma torre específica, um inimigo específico) como parte
  desta skill — isso pertence à skill `tower-defense` e a decisões de design já confirmadas.
- Não acoplar lógica de gameplay diretamente a nodes de UI específicos.
- Não implementar um sistema "genérico" para múltiplos casos hipotéticos futuros — resolver o
  caso atual de forma extensível, não especular.
- Não deixar um sistema depender de estado global desnecessário (ver `game-architecture`).

## Workflow

1. Confirmar que o conteúdo/design necessário já está definido em `docs/GAME_BIBLE.md` (ou
   perguntar antes de assumir).
2. Definir a interface pública do sistema e como ele se comunica com o resto do jogo.
3. Definir quais dados o sistema consome via Resource.
4. Implementar de forma incremental, validando cada parte.
5. Testar o sistema isoladamente antes de integrá-lo a outros.
6. Documentar em `docs/ARCHITECTURE.md` se o sistema introduzir um conceito arquitetural novo.

## Relevant Project Files

- [docs/GAME_BIBLE.md](../../../docs/GAME_BIBLE.md)
- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [game-architecture skill](../game-architecture/SKILL.md)
- [testing skill](../testing/SKILL.md)
