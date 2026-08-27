extends SceneTree
## Testes do Primeiro Protótipo Visual: confirma que Dinosaur/BasicEnemy realmente usam o
## AnimatedSprite2D (não silenciosamente o fallback procedural por um erro de wiring), e que
## reações sprite-driven de um tiro só (ATTACK/HIT) voltam sozinhas ao loop anterior ao terminar
## — mecanismo novo em AnimatedVisual._on_sprite_reaction_finished(), sem o qual o sprite ficaria
## congelado no último frame da reação para sempre (diferente do fallback procedural, onde
## IDLE/MOVE continuam rodando por baixo da reação em trilhas de Tween independentes).
##
## Não testa a arte em si (cores/formas exatas de pixel) — só o contrato de estados que
## AnimatedVisual/gameplay dependem.
##
## Executar com:
##   godot --headless --path game --script res://tests/visual_prototype_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[visual_prototype_tests] FAIL: %s" % message)


func _initialize() -> void:
	await _test_dinosaur_uses_sprite_and_reverts_after_attack()
	await _test_enemy_uses_sprite_and_reverts_after_hit()
	await _test_enemy_death_effect_uses_creature_sprite()

	if _failures == 0:
		print("[visual_prototype_tests] ALL TESTS PASSED")
	else:
		print("[visual_prototype_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_dinosaur_uses_sprite_and_reverts_after_attack() -> void:
	var packed := load("res://scenes/dinosaurs/Dinosaur.tscn") as PackedScene
	var dinosaur := packed.instantiate() as Dinosaur
	root.add_child(dinosaur)
	await process_frame

	var sprite := dinosaur.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite.sprite_frames != null, "Dinosaur.tscn deveria ter um SpriteFrames real atribuído")
	_check(sprite.sprite_frames.has_animation("idle") and sprite.sprite_frames.has_animation("attack"),
		"SpriteFrames do Velociraptor deveria ter as animações 'idle' e 'attack'")

	var definition := DinosaurDefinition.new()
	definition.range = 100.0
	definition.attack_interval = 1.0
	definition.damage = 5
	definition.projectile_speed = 200.0
	definition.projectile_scene = load("res://scenes/combat/Projectile.tscn") as PackedScene

	# Alvo "nu" (BasicEnemy.new(), sem cena real) usado só como dado de posição/estado para o
	# Targeting — NUNCA adicionado à árvore: sem isso, o @onready var _visual: ... = $Visual de
	# basic_enemy.gd dispara no _ready() e falha (não existe $Visual numa instância sem a cena
	# real). Mesmo padrão já usado em dinosaur_tests.gd.
	var enemy := BasicEnemy.new()
	enemy.speed = 0.0
	enemy.initialize([Vector2(50, 0), Vector2(51, 0)])

	var spawner := EnemySpawner.new()
	spawner._active_enemies = [enemy]
	root.add_child(spawner)

	var projectiles := Node.new()
	root.add_child(projectiles)

	dinosaur.setup(definition, spawner, projectiles)
	_check(sprite.animation == "idle", "Dinosaur recém-criado deveria estar tocando 'idle', got '%s'" % sprite.animation)

	dinosaur.step(0.001)  # cooldown inicial é 0 — dispara imediatamente
	_check(sprite.animation == "attack", "disparar deveria trocar a animação para 'attack', got '%s'" % sprite.animation)

	# simula o fim da animação de ataque (não dependemos de tempo real correndo)
	sprite.animation_finished.emit()
	_check(sprite.animation == "idle", "depois do ataque terminar, deveria voltar sozinho para 'idle', got '%s'" % sprite.animation)

	root.remove_child(dinosaur)
	root.remove_child(spawner)
	root.remove_child(projectiles)
	dinosaur.free()
	enemy.free()
	spawner.free()
	projectiles.free()


func _test_enemy_uses_sprite_and_reverts_after_hit() -> void:
	var packed := load("res://scenes/enemies/BasicEnemy.tscn") as PackedScene
	var enemy := packed.instantiate() as BasicEnemy
	root.add_child(enemy)
	await process_frame

	var sprite := enemy.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite.sprite_frames != null, "BasicEnemy.tscn deveria ter um SpriteFrames real atribuído")
	_check(sprite.sprite_frames.has_animation("move") and sprite.sprite_frames.has_animation("hit")
		and sprite.sprite_frames.has_animation("death"),
		"SpriteFrames do BasicEnemy deveria ter 'move', 'hit' e 'death'")

	enemy.initialize([Vector2(0, 0), Vector2(100, 0)])
	_check(sprite.animation == "move", "BasicEnemy inicializado deveria estar tocando 'move', got '%s'" % sprite.animation)

	enemy.take_damage(1)
	_check(sprite.animation == "hit", "tomar dano deveria trocar a animação para 'hit', got '%s'" % sprite.animation)

	sprite.animation_finished.emit()
	_check(sprite.animation == "move", "depois do hit terminar, deveria voltar sozinho para 'move', got '%s'" % sprite.animation)

	root.remove_child(enemy)
	enemy.free()


## O DeathEffect gerado por uma morte de verdade (não a chegada ao ninho) deve receber e tocar o
## SpriteFrames da própria criatura, não o losango neutro genérico — ver
## BasicEnemy._spawn_death_effect()/DeathEffect.set_death_sprite_frames().
func _test_enemy_death_effect_uses_creature_sprite() -> void:
	var packed := load("res://scenes/enemies/BasicEnemy.tscn") as PackedScene
	var enemy := packed.instantiate() as BasicEnemy
	var container := Node.new()
	root.add_child(container)
	container.add_child(enemy)
	await process_frame

	enemy.max_hp = 5
	enemy.initialize([Vector2(0, 0), Vector2(100, 0)])
	enemy.take_damage(999)  # mata — gera 1 DamageNumber (todo hit) + 1 DeathEffect (morte)

	var effect: DeathEffect = null
	for child in container.get_children():
		if child is DeathEffect:
			effect = child
	_check(effect != null, "deveria existir um DeathEffect entre os filhos")
	if effect != null:
		var effect_sprite := effect.get_node("Visual/AnimatedSprite2D") as AnimatedSprite2D
		_check(effect_sprite.sprite_frames != null and effect_sprite.sprite_frames.has_animation("death"),
			"DeathEffect de uma morte de verdade deveria ter recebido o SpriteFrames da criatura (com animação 'death')")

	# `enemy` já tem um queue_free() pendente e deferido (chamado por _die()) — remover/liberar
	# `container` manualmente aqui arriscaria um double-free. Como este é o último teste do
	# arquivo, deixar `container` (e seus filhos) presos à árvore até o quit() logo abaixo é
	# seguro: o shutdown do motor libera tudo o que ainda está na árvore, sem conflito com o
	# queue_free() já agendado (mesmo padrão já usado em egg_tests.gd para o mesmo cenário).
