---
name: mobile-performance
description: Considerações de performance para Android no SPAYTCH, priorizando dispositivos de baixo/médio desempenho — CPU, GPU, memória e bateria.
---

# Mobile Performance

## Purpose

Garantir que decisões técnicas do SPAYTCH considerem performance em Android desde o início,
priorizando dispositivos de baixo/médio desempenho em vez de assumir hardware topo de linha.

## When to use

- Ao projetar qualquer sistema que rode continuamente (`_process`/`_physics_process`).
- Ao decidir sobre quantidade de nodes, partículas, shaders, ou luzes dinâmicas em cena.
- Ao implementar pathing/targeting de inimigos e torres (potencialmente muitas entidades ativas).
- Ao configurar export settings para Android.
- Sempre que uma decisão de arquitetura ou arte tiver impacto direto em performance.

## Core Principles

- **Baixo/médio desempenho é o baseline, não o pior caso a tolerar.** Projetar pensando neste
  público evita retrabalho de otimização tardia.
- **CPU costuma ser o gargalo em Tower Defense**, não GPU — muitos inimigos, muitas torres,
  muitos cálculos de targeting/pathing por frame.
- **Menos é mais em `_process`.** Lógica que não precisa rodar todo frame não deve rodar todo
  frame (usar timers, sinais, ou throttling quando aplicável).
- **Draw calls e batching importam.** Uso consistente de atlases/texturas compartilhadas reduz
  draw calls, relevante para GPUs móveis.
- **Memória é mais restrita em mobile.** Evitar carregar assets desnecessários, texturas
  sobredimensionadas, ou manter referências que impedem garbage collection.
- **Bateria e aquecimento também são UX.** Um jogo que roda a 60fps mas esquenta o aparelho ou
  drena bateria rapidamente prejudica a experiência, mesmo com bom framerate.

## Do

- Perfilar (profile) cedo usando o profiler do Godot antes de assumir que algo é "rápido o
  suficiente".
- Usar object pooling para entidades criadas/destruídas com frequência (ex: projéteis, inimigos)
  quando o volume justificar.
- Preferir `_physics_process` com passo fixo para lógica de gameplay determinística, e evitar
  lógica cara em `_process` quando não há necessidade de rodar a cada frame renderizado.
- Testar em (ou simular) um dispositivo Android de médio/baixo desempenho, não só no editor
  desktop.
- Considerar o custo de shaders e efeitos de partículas antes de aplicá-los em massa.
- Ajustar densidade de efeitos visuais (VFX) de forma escalável por plataforma/dispositivo, se
  necessário.

## Don't

- Não assumir que uma solução "funciona bem" só porque roda bem no editor/desktop do
  desenvolvedor.
- Não instanciar/destruir objetos em alta frequência sem considerar pooling.
- Não usar iluminação dinâmica, shaders pesados ou grandes quantidades de partículas sem medir
  o impacto em hardware mobile.
- Não ignorar o custo de UI complexa (muitos Controls, muitas atualizações por frame) — UI
  também consome performance.
- Não otimizar prematuramente a ponto de comprometer clareza de código para ganhos
  insignificantes — otimizar onde o profiling mostrar impacto real.

## Workflow

1. Ao projetar um sistema com potencial de escala (muitas entidades, muitos efeitos), considerar
   o custo por instância antes de implementar.
2. Implementar da forma mais simples e correta primeiro.
3. Perfilar antes de otimizar — não otimizar por suposição.
4. Ajustar (pooling, throttling, LOD de efeitos) apenas onde o profiling indicar necessidade.
5. Validar em cenário representativo de Android de médio/baixo desempenho antes de considerar
   concluído (ver skill `testing`).
6. Documentar decisões de performance relevantes em `docs/ARCHITECTURE.md`.

## Relevant Project Files

- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [docs/ART_DIRECTION.md](../../../docs/ART_DIRECTION.md)
- [pixel-art skill](../pixel-art/SKILL.md)
- [testing skill](../testing/SKILL.md)
