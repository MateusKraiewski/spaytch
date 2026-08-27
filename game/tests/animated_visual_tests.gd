extends SceneTree
## Testes de AnimatedVisual: a camada de apresentação desacoplada
## (IDLE/MOVE/ATTACK/HIT/DEATH) usada por Dinosaur/BasicEnemy/Egg/Projectile.
##
## Cobre só a SUPERFÍCIE PÚBLICA (play_state/set_base_modulate) e os dois
## caminhos de realização: fallback procedural (sem AnimatedSprite2D — caso
## de hoje, sem arte final) e delegação para AnimatedSprite2D quando existe
## uma animação de mesmo nome em sprite_frames (caso de quando a arte final
## chegar). Não verifica valores exatos de easing/curva de Tween (frágil e
## não é o que importa) — só que a chamada não quebra e que a decisão de
## "qual caminho usar" está correta.
##
## Executar com:
##   godot --headless --path game --script res://tests/animated_visual_tests.gd

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[animated_visual_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_play_state_outside_tree_does_not_error()
	await _test_procedural_fallback_updates_modulate_on_hit()
	await _test_set_base_modulate_applies_immediately()
	await _test_sprite_animation_used_when_available()
	await _test_sprite_animation_ignored_when_missing()

	if _failures == 0:
		print("[animated_visual_tests] ALL TESTS PASSED")
	else:
		print("[animated_visual_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Fora de uma SceneTree (mesmo padrão de BasicEnemy.new()/Dinosaur.new() em
## outras suítes): play_state() não pode tentar criar Tween (exige árvore
## válida) nem lançar erro — só não faz nada.
func _test_play_state_outside_tree_does_not_error() -> void:
	var visual := AnimatedVisual.new()
	for state in AnimatedVisual.State.values():
		visual.play_state(state)
	_check(true, "play_state() fora da árvore não deveria lançar erro (chegar aqui já é o teste)")
	visual.free()


func _test_procedural_fallback_updates_modulate_on_hit() -> void:
	var visual := AnimatedVisual.new()
	root.add_child(visual)
	await process_frame

	visual.play_state(AnimatedVisual.State.HIT)
	_check(visual.modulate != Color.WHITE, "HIT deveria mudar modulate imediatamente (flash), got %s" % visual.modulate)

	root.remove_child(visual)
	visual.free()


func _test_set_base_modulate_applies_immediately() -> void:
	var visual := AnimatedVisual.new()
	root.add_child(visual)
	await process_frame

	var tint := Color(0.5, 0.2, 0.2)
	visual.set_base_modulate(tint)
	_check(visual.modulate == tint, "set_base_modulate deveria aplicar a cor na hora, got %s esperado %s" % [visual.modulate, tint])
	_check(visual.base_modulate == tint, "set_base_modulate deveria também guardar a cor de repouso")

	root.remove_child(visual)
	visual.free()


func _make_sprite_frames(animation_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.add_frame(animation_name, PlaceholderTexture2D.new())
	return frames


func _test_sprite_animation_used_when_available() -> void:
	var visual := AnimatedVisual.new()
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _make_sprite_frames("hit")
	visual.add_child(sprite)
	root.add_child(visual)
	await process_frame

	visual.play_state(AnimatedVisual.State.HIT)
	_check(sprite.animation == "hit", "com sprite_frames tendo 'hit', play_state(HIT) deveria tocar essa animação, got '%s'" % sprite.animation)

	root.remove_child(visual)
	visual.free()


## Sem a animação "attack" em sprite_frames (só "hit"): deve cair no
## fallback procedural em vez de travar/gerar erro tentando tocar uma
## animação inexistente.
func _test_sprite_animation_ignored_when_missing() -> void:
	var visual := AnimatedVisual.new()
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _make_sprite_frames("hit")
	visual.add_child(sprite)
	root.add_child(visual)
	await process_frame

	visual.play_state(AnimatedVisual.State.ATTACK)
	_check(sprite.animation != "attack", "sprite_frames sem 'attack' não deveria fingir que tocou essa animação")

	root.remove_child(visual)
	visual.free()
