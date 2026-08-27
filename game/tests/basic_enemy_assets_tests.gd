extends SceneTree
## Testes do Checkpoint C (BasicEnemy) do asset pack visual: confirma que os 15 PNGs de
## `assets/enemies/basic_enemy/` existem, têm as dimensões esperadas, não têm nenhum pixel opaco
## tocando a borda do canvas (sinal de recorte), que os frames de cada animação realmente diferem
## entre si em pixel, e que o `SpriteFrames` final carrega com as 3 animações (move/hit/death) e a
## contagem mínima de frames.
##
## Mesmo padrão de `velociraptor_assets_tests.gd` (Checkpoint B) — não testa a arte em si
## (cores/formas exatas) nem o comportamento de AnimatedVisual, só o contrato de arquivo/recurso
## específico do BasicEnemy.
##
## Executar com:
##   godot --headless --path game --script res://tests/basic_enemy_assets_tests.gd

var _failures: int = 0

const _ANIMATIONS := {
	"move": ["move_0", "move_1", "move_2", "move_3", "move_4", "move_5"],
	"hit": ["hit_0", "hit_1", "hit_2"],
	"death": ["death_0", "death_1", "death_2", "death_3", "death_4", "death_5"],
}
const _MIN_FRAMES := {"move": 6, "hit": 3, "death": 6}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[basic_enemy_assets_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_frames_exist_correct_size_and_transparent()
	_test_no_frame_is_clipped_at_canvas_edge()
	_test_frames_within_each_animation_are_not_all_pixel_identical()
	_test_sprite_frames_resource_has_all_animations_with_min_counts()
	_test_enemy_scene_references_basic_enemy_sprite_frames()

	if _failures == 0:
		print("[basic_enemy_assets_tests] ALL TESTS PASSED")
	else:
		print("[basic_enemy_assets_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _all_frame_names() -> Array[String]:
	var names: Array[String] = []
	for anim in _ANIMATIONS:
		for frame_name in _ANIMATIONS[anim]:
			names.append(frame_name)
	return names


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(img != null, "%s deveria carregar como Image válida" % path)
	return img


func _test_frames_exist_correct_size_and_transparent() -> void:
	for frame_name in _all_frame_names():
		var path := "res://assets/enemies/basic_enemy/%s.png" % frame_name
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == 48 and img.get_height() == 48,
			"%s deveria ser 48x48, got %dx%d" % [path, img.get_width(), img.get_height()])
		var has_transparent := false
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a < 0.01:
					has_transparent = true
					break
			if has_transparent:
				break
		_check(has_transparent, "%s deveria ter fundo transparente (personagem recortado, não um tile)" % path)


## Nenhum pixel opaco pode tocar a borda externa do canvas — sinal de recorte (ver bug do focinho
## do raptor no Checkpoint B, mesma classe de problema).
func _test_no_frame_is_clipped_at_canvas_edge() -> void:
	for frame_name in _all_frame_names():
		var path := "res://assets/enemies/basic_enemy/%s.png" % frame_name
		var img := _load(path)
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var touches_edge := false
		for x in range(w):
			if img.get_pixel(x, 0).a > 0.01 or img.get_pixel(x, h - 1).a > 0.01:
				touches_edge = true
				break
		if not touches_edge:
			for y in range(h):
				if img.get_pixel(0, y).a > 0.01 or img.get_pixel(w - 1, y).a > 0.01:
					touches_edge = true
					break
		_check(not touches_edge, "%s tem pixel opaco na borda do canvas — provável recorte" % path)


func _pixel_diff_count(a: Image, b: Image) -> int:
	var diff := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	return diff


func _test_frames_within_each_animation_are_not_all_pixel_identical() -> void:
	for anim in _ANIMATIONS:
		var names: Array = _ANIMATIONS[anim]
		for i in range(names.size() - 1):
			var a := _load("res://assets/enemies/basic_enemy/%s.png" % names[i])
			var b := _load("res://assets/enemies/basic_enemy/%s.png" % names[i + 1])
			if a == null or b == null:
				continue
			_check(_pixel_diff_count(a, b) > 0,
				"%s e %s (animação '%s') não deveriam ser pixel-a-pixel idênticos" % [names[i], names[i + 1], anim])


func _test_sprite_frames_resource_has_all_animations_with_min_counts() -> void:
	var frames := load("res://data/enemies/basic_enemy_sprite_frames.tres") as SpriteFrames
	_check(frames != null, "basic_enemy_sprite_frames.tres deveria carregar como SpriteFrames válido")
	if frames == null:
		return
	for anim in _MIN_FRAMES:
		_check(frames.has_animation(anim), "SpriteFrames deveria ter a animação '%s'" % anim)
		if frames.has_animation(anim):
			var count := frames.get_frame_count(anim)
			_check(count >= _MIN_FRAMES[anim],
				"'%s' deveria ter no mínimo %d frames, tem %d" % [anim, _MIN_FRAMES[anim], count])
			for i in range(count):
				_check(frames.get_frame_texture(anim, i) != null,
					"'%s' frame %d não deveria apontar para uma textura nula" % [anim, i])


func _test_enemy_scene_references_basic_enemy_sprite_frames() -> void:
	var packed := load("res://scenes/enemies/BasicEnemy.tscn") as PackedScene
	_check(packed != null, "BasicEnemy.tscn deveria carregar")
	if packed == null:
		return
	var enemy := packed.instantiate()
	var sprite := enemy.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "BasicEnemy.tscn deveria ter Visual/AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames == load("res://data/enemies/basic_enemy_sprite_frames.tres"),
			"AnimatedSprite2D de BasicEnemy.tscn deveria referenciar basic_enemy_sprite_frames.tres")
	enemy.free()
