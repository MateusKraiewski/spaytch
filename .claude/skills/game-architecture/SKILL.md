---
name: game-architecture
description: Orienta decisões de arquitetura sustentável para o SPAYTCH — organização de sistemas, separação de dados/comportamento, comunicação entre sistemas, e quando (não) usar autoloads.
---

# Game Architecture

## Purpose

Guiar decisões de arquitetura de software para um jogo 2D sustentável a longo prazo: fácil de
estender com novo conteúdo (torres, inimigos, mapas) sem reescrever sistemas existentes.

## When to use

- Ao projetar um novo sistema (economia, waves, combate, progressão, UI de jogo, etc.).
- Ao decidir onde um dado ou uma lógica deve viver (Resource vs. script vs. autoload).
- Ao avaliar se uma mudança exige alterar arquitetura existente.
- Antes de introduzir um autoload/singleton ou um event bus global.

## Core Principles

- **Dados configuráveis vivem em Resources**, não em código. Isso permite que design/balance
  seja ajustado sem recompilar ou reescrever lógica.
- **Comportamento é código; configuração é dado.** Uma torre "sabe atirar" (comportamento); o
  dano, alcance e cooldown dessa torre são dados.
- **Sistemas devem ter responsabilidade única.** Um sistema de economia não deve saber como uma
  torre atira; um sistema de waves não deve saber como a UI renderiza vida da base.
- **Acoplamento baixo, coesão alta.** Prefira comunicação via signals/eventos a referências
  diretas cruzadas entre sistemas não relacionados.
- **Autoloads são exceção, não padrão.** Um autoload deve ser justificado por uma necessidade
  real de estado ou serviço verdadeiramente global (ex: gerenciador de cena, configurações do
  jogador), não por conveniência de acesso.
- **Extensibilidade por dados, não por código duplicado.** Novo conteúdo (nova torre, novo
  inimigo) deve, idealmente, ser adicionável criando um novo Resource, não copiando e colando
  um script inteiro.

## Do

- Modelar entidades de gameplay configuráveis (torres, inimigos, waves, upgrades) como
  `Resource` customizados consumidos por scripts genéricos de comportamento.
- Definir claramente a fronteira de cada sistema antes de implementá-lo.
- Preferir signals locais (node → node próximo) para a maioria das comunicações.
- Justificar por escrito (em `docs/ARCHITECTURE.md`) qualquer autoload ou event bus introduzido.
- Revisar `docs/ARCHITECTURE.md` antes de propor uma mudança estrutural grande.

## Don't

- Não criar uma abstração genérica para um caso de uso único ("pode ser útil depois").
- Não duplicar lógica entre sistemas semelhantes (ex: duas implementações de "aplicar dano").
- Não misturar dado e comportamento em uma única classe monolítica quando a separação é natural.
- Não introduzir um Event Bus global só porque "pode ser conveniente" — signals diretos resolvem
  a maioria dos casos em um Tower Defense de escopo médio.
- Não alterar arquitetura existente sem explicar o motivo e o impacto.

## Workflow

1. Analisar a arquitetura existente relevante (`docs/ARCHITECTURE.md` + código atual).
2. Definir se o novo sistema precisa de dados configuráveis (Resource) e/ou comportamento
   (script).
3. Definir como esse sistema se comunica com os demais (signals, grupos, referência direta).
4. Avaliar se algo realmente precisa ser global antes de criar um autoload.
5. Implementar de forma incremental e modular.
6. Atualizar `docs/ARCHITECTURE.md` se a decisão for relevante para o entendimento futuro do
   projeto.

## Relevant Project Files

- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [CLAUDE.md](../../../CLAUDE.md)
- [godot-engine skill](../godot-engine/SKILL.md)
- [gameplay-system skill](../gameplay-system/SKILL.md)
