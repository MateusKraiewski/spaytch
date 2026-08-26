---
name: godot-engine
description: Orienta o uso correto e idiomático do Godot 4.x no projeto SPAYTCH — nodes, cenas, Resources, signals, GDScript/C#, e recursos específicos da engine.
---

# Godot Engine (4.x)

## Purpose

Garantir que o código e a estrutura do projeto usem Godot 4.x de forma idiomática, aproveitando
os recursos da engine (nodes, cenas, Resources, signals) em vez de lutar contra eles ou
reimplementar o que a engine já oferece.

## When to use

- Ao criar ou modificar qualquer cena (`.tscn`), script (`.gd`/`.cs`) ou Resource (`.tres`/`.gdres`).
- Ao decidir como estruturar composição de nodes, herança de cenas, ou comunicação via signals.
- Ao configurar projeto (Project Settings), input map, export presets, ou plugins.
- Sempre que houver dúvida entre "fazer do jeito Godot" vs. reinventar uma solução genérica.

## Core Principles

- Godot 4.x tem diferenças relevantes em relação ao Godot 3.x (ex: `Node2D` vs. mudanças de API,
  `AnimatedSprite2D`, sistema de tipagem estática mais forte em GDScript, mudanças em signals e
  em `@export`). Não assumir comportamento do Godot 3.x.
- Prefira composição de nodes e cenas sobre herança profunda de classes quando possível.
- Cenas devem ser autocontidas e reutilizáveis: uma cena representa uma unidade lógica clara
  (ex: uma torre, um projétil, um inimigo), não um agrupamento arbitrário.
- Use `@export` para expor parâmetros ajustáveis no editor em vez de hardcode.
- Use `Resource` customizados para dados que não precisam de lógica de node (stats, configs).
- Prefira signals para comunicação entre nodes desacoplados; use referências diretas apenas
  quando o acoplamento já é natural (ex: nó pai/filho direto).

## Do

- Usar tipagem estática em GDScript (`var health: int = 10`) para clareza e detecção de erros.
- Nomear nodes, cenas e scripts de forma consistente e descritiva.
- Usar grupos (`add_to_group`) e/ou signals para comunicação desacoplada entre sistemas.
- Verificar a documentação oficial do Godot 4.x quando a API não for clara, em vez de assumir
  comportamento por familiaridade com versões anteriores.
- Considerar o custo de nodes em runtime (quantidade de nodes ativos, `_process`/`_physics_process`)
  especialmente pensando em Android.

## Don't

- Não usar APIs ou padrões específicos do Godot 3.x sem verificar equivalência em 4.x.
- Não abusar de `get_node()` com caminhos frágeis (`../../../Foo`) — prefira `%UniqueName`,
  exports de NodePath, ou sinais.
- Não colocar lógica de gameplay pesada dentro de `_process()`/`_physics_process()` sem
  necessidade — considerar sinais, timers, ou eventos.
- Não criar autoloads por conveniência; ver `game-architecture` para critérios.
- Não misturar GDScript e C# sem justificativa clara de por que a interoperabilidade é
  necessária.

## Workflow

1. Antes de criar uma cena/script novo, verificar se um padrão equivalente já existe no projeto.
2. Definir a responsabilidade da cena/script claramente antes de implementar.
3. Expor via `@export` ou Resource os valores que podem precisar de ajuste.
4. Implementar comunicação via signals sempre que reduzir acoplamento.
5. Validar no editor Godot (não só por leitura de código) antes de considerar concluído.

## Relevant Project Files

- [CLAUDE.md](../../../CLAUDE.md)
- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md)
- [game-architecture skill](../game-architecture/SKILL.md)
