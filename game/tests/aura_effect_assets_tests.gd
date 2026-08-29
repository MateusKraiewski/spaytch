extends SceneTree
## Testes da AuraEffect (Sprint 1 — aura do Velociraptor T3): confirma que os 4 PNGs de
## `assets/effects/aura_t3_*.png` existem, têm as dimensões esperadas, não têm nenhum pixel opaco
## tocando a borda do canvas, que os frames realmente diferem entre si em pixel (posição/faíscas
## variando por frame, não um "piscar" de cor), que `aura_t3_sprite_frames.tres` carrega com a
## animação/contagem mínima esperada em loop, e que `AuraEffect.tscn` referencia esse recurso e
## fica atrás de outras entidades (z_index negativo).
##
## Mesmo padrão de spawn_effect_assets_tests.gd — não testa a arte em si (formas/cores exatas) nem
## nenhuma integração de gameplay (não existe ainda — ver docs/ROADMAP.md, Sprint 1 Parte 5), só o
## contrato de arquivo/recurso/cena.
##
## Executar com:
##   godot --headless --path game --script res://tests/aura_effect_assets_tests.gd

var _failures: int = 0

const _SIZE := 176
const _FRAMES := ["aura_t3_0", "aura_t3_1", "aura_t3_2", "aura_t3_3"]
const _MIN_FRAMES := 4


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[aura_effect_assets_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_frames_exist_correct_size_transparent_and_not_clipped()
	_test_frames_are_not_all_pixel_identical()
	_test_sprite_frames_resource()
	_test_aura_effect_scene_references_sprite_frames_and_draws_behind()

	if _failures == 0:
		print("[aura_effect_assets_tests] ALL TESTS PASSED")
	else:
		print("[aura_effect_assets_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(img != null, "%s deveria carregar como Image válida" % path)
	return img


func _test_frames_exist_correct_size_transparent_and_not_clipped() -> void:
	for frame_name in _FRAMES:
		var path := "res://assets/effects/%s.png" % frame_name
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == _SIZE and img.get_height() == _SIZE,
			"%s deveria ser %dx%d, got %dx%d" % [path, _SIZE, _SIZE, img.get_width(), img.get_height()])

		var has_transparent := false
		var touches_edge := false
		var w := img.get_width()
		var h := img.get_height()
		for y in range(h):
			for x in range(w):
				var a := img.get_pixel(x, y).a
				if a < 0.01:
					has_transparent = true
				elif x == 0 or y == 0 or x == w - 1 or y == h - 1:
					touches_edge = true
		_check(has_transparent, "%s deveria ter fundo transparente" % path)
		_check(not touches_edge, "%s tem pixel opaco na borda do canvas — provável recorte" % path)


func _pixel_diff_count(a: Image, b: Image) -> int:
	var diff := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	return diff


func _test_frames_are_not_all_pixel_identical() -> void:
	for i in range(_FRAMES.size() - 1):
		var a := _load("res://assets/effects/%s.png" % _FRAMES[i])
		var b := _load("res://assets/effects/%s.png" % _FRAMES[i + 1])
		if a == null or b == null:
			continue
		_check(_pixel_diff_count(a, b) > 0,
			"%s e %s não deveriam ser pixel-a-pixel idênticos" % [_FRAMES[i], _FRAMES[i + 1]])


func _test_sprite_frames_resource() -> void:
	var frames := load("res://data/effects/aura_t3_sprite_frames.tres") as SpriteFrames
	_check(frames != null, "aura_t3_sprite_frames.tres deveria carregar como SpriteFrames válido")
	if frames == null:
		return
	_check(frames.has_animation("idle"), "aura_t3_sprite_frames.tres deveria ter a animação 'idle'")
	if frames.has_animation("idle"):
		var count := frames.get_frame_count("idle")
		_check(count >= _MIN_FRAMES, "'idle' deveria ter no mínimo %d frames, tem %d" % [_MIN_FRAMES, count])
		_check(frames.get_animation_loop("idle"), "'idle' deveria estar em loop — aura é contínua, não um tiro só")
		for i in range(count):
			_check(frames.get_frame_texture("idle", i) != null,
				"'idle' frame %d não deveria apontar para uma textura nula" % i)


func _test_aura_effect_scene_references_sprite_frames_and_draws_behind() -> void:
	var packed := load("res://scenes/effects/AuraEffect.tscn") as PackedScene
	_check(packed != null, "AuraEffect.tscn deveria carregar")
	if packed == null:
		return
	var effect := packed.instantiate()
	_check(effect.z_index < 0, "AuraEffect.tscn deveria ter z_index negativo (desenha atrás da criatura)")
	var sprite := effect.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "AuraEffect.tscn deveria ter Visual/AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames == load("res://data/effects/aura_t3_sprite_frames.tres"),
			"AnimatedSprite2D de AuraEffect.tscn deveria referenciar aura_t3_sprite_frames.tres")
	effect.free()
