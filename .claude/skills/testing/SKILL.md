---
name: testing
description: Estratégia inicial de testes e debugging para o SPAYTCH — como validar sistemas de gameplay de forma confiável em Godot 4.x.
---

# Testing

## Purpose

Estabelecer uma estratégia inicial e pragmática para testar e debugar sistemas do SPAYTCH,
garantindo que implementações sejam validadas antes de serem consideradas concluídas.

## When to use

- Ao terminar a implementação de qualquer sistema de gameplay ou correção de bug.
- Ao projetar um sistema novo — para definir, desde o início, como ele será validado.
- Ao investigar um comportamento inesperado ou bug reportado.

## Core Principles

- **Todo sistema deve ser validável.** Se não há forma clara de verificar que um sistema
  funciona, isso é um sinal de que a interface do sistema precisa ser revisada.
- **Testar não é só "rodar o jogo uma vez".** Cobrir o caminho feliz e casos de borda razoáveis
  (ex: torre sem alvo no alcance, wave vazia, economia no zero).
- **Preferir testes automatizados para lógica pura** (cálculos, regras de negócio de gameplay
  desacopladas de nodes) sempre que o Godot/GDScript permitir isolar essa lógica.
- **Testes manuais no editor são válidos e necessários** para validar comportamento visual,
  feel de gameplay, e integração entre sistemas — mas não substituem verificação estruturada
  quando lógica crítica está envolvida.
- **Reprodutibilidade importa.** Um bug só está resolvido quando se sabe como reproduzi-lo e
  como confirmar que não ocorre mais.

## Do

- Ao projetar um sistema, considerar como ele pode ser testado isoladamente (ver skill
  `gameplay-system`) — isso geralmente empurra para melhor design (baixo acoplamento).
- Usar o framework de testes do Godot (ex: GUT — GoDot Unit Testing, ou equivalente a ser
  adotado) para lógica de gameplay crítica, quando o projeto adotar uma ferramenta formal.
- Validar manualmente no editor qualquer mudança antes de considerá-la concluída, mesmo quando
  há testes automatizados.
- Registrar passos de reprodução claros ao investigar um bug.
- Testar cenários de borda relevantes ao Tower Defense (ex: zero inimigos, zero torres, recursos
  no limite, muitas entidades simultâneas — ver `mobile-performance`).

## Don't

- Não considerar uma implementação "concluída" sem alguma forma de validação (automatizada ou
  manual estruturada).
- Não depender exclusivamente de teste manual para lógica de gameplay complexa ou crítica
  (cálculos de dano, economia, progressão) — esses são candidatos naturais a testes
  automatizados.
- Não ignorar casos de borda só porque o caminho feliz funciona.
- Não deixar bugs conhecidos sem registro — mesmo que não sejam corrigidos imediatamente.

## Workflow

1. Antes de implementar, considerar como o sistema será validado.
2. Implementar de forma incremental, validando cada parte à medida que é construída.
3. Testar o caminho feliz e ao menos os casos de borda mais óbvios.
4. Para lógica crítica/pura, preferir teste automatizado quando viável.
5. Validar manualmente no editor/build antes de considerar a tarefa concluída.
6. Ao corrigir um bug, confirmar reprodução do problema antes e ausência dele depois da correção.

## Relevant Project Files

- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [gameplay-system skill](../gameplay-system/SKILL.md)
- [mobile-performance skill](../mobile-performance/SKILL.md)
