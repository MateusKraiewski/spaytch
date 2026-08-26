---
name: pixel-art
description: Regras técnicas para manter pixel art consistente no SPAYTCH — resolução, escala, import settings, sem definir valores finais ainda (ver docs/ART_DIRECTION.md).
---

# Pixel Art

## Purpose

Garantir que toda a arte pixel do SPAYTCH permaneça tecnicamente consistente — mesma escala,
mesmo tratamento de import, mesma nitidez — independentemente de quem produz o asset ou quando.
Valores finais (resolução exata, tamanho de tile) são definidos em
[docs/ART_DIRECTION.md](../../../docs/ART_DIRECTION.md) e podem estar como TBD.

## When to use

- Ao importar ou configurar qualquer sprite, spritesheet, tileset ou asset visual no Godot.
- Ao configurar câmera, viewport, ou escala de renderização.
- Ao revisar se um asset segue os padrões técnicos do projeto.
- Ao implementar shaders ou efeitos visuais que interagem com pixel art.

## Core Principles

- **Consistência de escala acima de tudo.** Todo pixel do jogo deve representar o mesmo tamanho
  físico na tela — misturar assets em escalas diferentes quebra a coesão visual.
- **Nitidez de pixel é inegociável.** Filtros de interpolação (linear/bilinear) não devem ser
  aplicados a texturas pixel art — usar filtro `Nearest` (ou equivalente em Godot 4.x) para
  preservar bordas nítidas.
- **Escalonamento inteiro (integer scaling)** deve ser preferido sobre escalonamento fracionário
  sempre que a resolução de tela permitir, para evitar artefatos de pixels desiguais.
- **Resolução interna fixa** (viewport de renderização) desacoplada da resolução de tela do
  dispositivo — a tela escala a partir da resolução interna, não o contrário.
- Todos os valores técnicos definitivos (resolução interna, tamanho de tile, escala) vivem em
  `docs/ART_DIRECTION.md` — esta skill não define números, define regras de consistência.

## Do

- Configurar import settings de texturas para filtro `Nearest` / sem mipmaps desnecessários.
- Manter todos os sprites do jogo alinhados ao mesmo grid de tile definido no projeto.
- Verificar `docs/ART_DIRECTION.md` antes de assumir resolução, tamanho de tile ou escala.
- Preferir configuração de projeto centralizada (viewport stretch settings) a ajustes manuais
  espalhados pelo código.
- Testar a nitidez visual em pelo menos uma resolução de PC e uma proporção de tela mobile antes
  de considerar um asset/config finalizado.

## Don't

- Não importar ou usar assets com escala/resolução diferente do padrão do projeto sem
  justificativa.
- Não aplicar filtros de suavização em texturas pixel art.
- Não usar escalonamento não-inteiro quando escalonamento inteiro for viável.
- Não inventar valores definitivos de resolução/tile/escala nesta skill — eles pertencem a
  `docs/ART_DIRECTION.md` e devem ser decididos explicitamente, não assumidos.
- Não misturar diferentes densidades de pixel (ex: um asset "high-res" pixel art com um "low-res")
  no mesmo contexto visual.

## Workflow

1. Verificar em `docs/ART_DIRECTION.md` os valores técnicos vigentes (resolução, tile, escala).
   Se estiverem como TBD, sinalizar isso em vez de assumir um valor.
2. Configurar import settings do asset conforme o padrão do projeto.
3. Validar alinhamento ao grid de tile e nitidez visual no editor.
4. Testar em diferentes resoluções/aspect ratios quando relevante (especialmente Android).
5. Atualizar `docs/ART_DIRECTION.md` se uma decisão técnica nova for tomada.

## Relevant Project Files

- [docs/ART_DIRECTION.md](../../../docs/ART_DIRECTION.md)
- [mobile-performance skill](../mobile-performance/SKILL.md)
