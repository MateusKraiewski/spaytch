# ART DIRECTION — SPAYTCH

Documento vivo com a direção visual do jogo. Valores técnicos marcados como **TBD** ainda não
foram decididos — não assuma nem invente números definitivos antes de decisão explícita.

---

## Direção Provisória (Identidade)

Pixel art colorida, com dinossauros carismáticos, em um mundo visualmente atraente para
crianças, mas com acabamento sofisticado o suficiente para também agradar jogadores adultos.

O objetivo é combinar pixel art com **VFX modernos** para manter o jogo visualmente vivo sem
perder a identidade pixel art:

- partículas;
- impactos;
- flashes;
- pequenos efeitos de iluminação;
- screen shake quando apropriado;
- efeitos de habilidades.

Esta é uma diretriz de tom e identidade — valores técnicos concretos (resolução, paleta, tile
size etc.) permanecem TBD nas seções abaixo e devem ser definidos separadamente, respeitando o
orçamento de performance mobile (ver skill `mobile-performance`).

## Pixel Art

*TBD — estilo de pixel art (ex: clean/hard-edge vs. dithered), nível de detalhe, referências
visuais.*

## Resolução Interna

*TBD — resolução base de renderização (ex: 320×180, 384×216). Deve ser escolhida considerando
proporção de tela comum em PC e Android, e escalonamento inteiro (integer scaling) para manter
pixels nítidos.*

## Tamanho de Tiles

*TBD — dimensão do tile base (ex: 16×16, 32×32 px). Deve ser consistente em todo o jogo
(tilemaps, torres, inimigos).*

## Escala

*TBD — fator de escala do jogo (pixel scale) em diferentes resoluções de tela/dispositivo, e
como manter escalonamento inteiro sempre que possível para evitar artefatos visuais.*

## Câmera

*TBD — comportamento de câmera (fixa vs. com pan/zoom), limites do mapa, adaptação a diferentes
aspect ratios (importante para variedade de telas Android).*

## Sprites

*TBD — convenções de tamanho, orientação (ex: top-down, isométrico), formato de arquivo,
organização de spritesheets/atlases.*

## Animações

**Decidido (Phase 0.6):** nenhuma entidade do jogo (dinossauro, inimigo, ovo, projétil) fica
visualmente estática como solução definitiva — toda entidade visual tem 5 estados de animação
padronizados: **IDLE, MOVE, ATTACK, HIT, DEATH**. A superfície que gameplay usa é
`AnimatedVisual.play_state(state)` (`scripts/visuals/animated_visual.gd`), que nunca expõe COMO a
animação é realizada por baixo — ver [ARCHITECTURE.md](ARCHITECTURE.md#animatedvisual-e-deatheffect-phase-06)
para o detalhamento técnico completo.

Convenção de nomenclatura fixada para quando a arte final chegar: um `AnimatedSprite2D` filho do
node `Visual` de cada entidade, com um `SpriteFrames` contendo animações nomeadas exatamente
`"idle"`, `"move"`, `"attack"`, `"hit"`, `"death"` (minúsculas). Assim que essas animações
existirem, elas substituem automaticamente o fallback procedural atual (`Tween` sobre
`rotation`/`scale`/`modulate`, usado hoje por não haver pixel art final) — nenhuma linha de código
de gameplay precisa mudar.

*Ainda TBD: frame rate de animação da arte final, número de frames por estado, se
`AnimationPlayer` (em vez de `AnimatedSprite2D`) faz mais sentido para algum caso específico
(ex: animações compostas com mais de um sprite).*

## Paleta

*TBD — paleta de cores global ou por bioma/mapa, número de cores, ferramentas/processo de
definição de paleta.*

## Iluminação

*TBD — se o jogo usará iluminação dinâmica (Light2D/shaders) ou lighting pintado nos próprios
sprites. Considerar custo de performance em mobile antes de decidir (ver skill
`mobile-performance`).*

## VFX

Direção provisória: ver [Direção Provisória (Identidade)](#direção-provisória-identidade) acima
— partículas, impactos, flashes, iluminação leve, screen shake e efeitos de habilidade.

*TBD — linguagem visual detalhada, orçamento concreto de VFX simultâneos, legibilidade em meio
a combate intenso.*

## UI

*TBD — estilo visual de UI, fontes, iconografia, consistência com a pixel art do jogo.*

## Legibilidade em Telas Pequenas

*TBD — regras para garantir que elementos de gameplay e UI permaneçam legíveis em telas de
celular (tamanho mínimo de elementos interativos, contraste, espessura de contorno em sprites
importantes). Crítico para a plataforma Android.*
