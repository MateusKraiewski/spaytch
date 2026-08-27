extends SceneTree
## Testes do Checkpoint D (Ovos + Projéteis) do asset pack visual: confirma que os PNGs de
## `assets/eggs/`, `assets/projectiles/` e `assets/effects/` (burst de impacto padrão do
## DeathEffect) existem, têm as dimensões esperadas, não têm nenhum pixel opaco tocando a borda
## do canvas, que os frames de cada animação realmente diferem entre si em pixel, e que os 3
## `SpriteFrames` finais carregam com as animações esperadas e a contagem mínima de frames.
##
## Mesmo padrão de velociraptor_assets_tests.gd/basic_enemy_assets_tests.gd — não testa a arte em
## si (cores/formas exatas) nem o comportamento de AnimatedVisual/egg.gd/projectile.gd, só o
## contrato de arquivo/recurso.
##
## Executar com:
##   godot --headless --path game --script res://tests/egg_projectile_assets_tests.gd

var _failures: int = 0

const _EGG_SIZE := 32
const _EGG_ANIMATIONS := {
	"idle": ["idle_0", "idle_1", "idle_2", "idle_3"],
	"move": ["move_0", "move_1", "move_2", "move_3"],
	"hit": ["hit_0", "hit_1", "hit_2"],
	"death": ["death_0", "death_1", "death_2", "death_3", "death_4"],
}
const _EGG_MIN_FRAMES := {"idle": 4, "move": 4, "hit": 3, "death": 5}

const _PROJ_W := 20  ## não é quadrado — lâmina + tufo traseiro precisam de mais largura que altura
const _PROJ_H := 16
const _PROJ_ANIMATIONS := {"idle": ["idle_0", "idle_1", "idle_2", "idle_3"]}
const _PROJ_MIN_FRAMES := {"idle": 4}

const _IMPACT_SIZE := 24
const _IMPACT_ANIMATIONS := {"death": ["impact_0", "impact_1", "impact_2", "impact_3"]}
const _IMPACT_MIN_FRAMES := {"death": 4}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[egg_projectile_assets_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_frame_group("res://assets/eggs/", _EGG_ANIMATIONS, _EGG_SIZE, _EGG_SIZE)
	_test_frame_group("res://assets/projectiles/", _PROJ_ANIMATIONS, _PROJ_W, _PROJ_H)
	_test_frame_group("res://assets/effects/", _IMPACT_ANIMATIONS, _IMPACT_SIZE, _IMPACT_SIZE)

	_test_frames_within_each_animation_are_not_all_pixel_identical("res://assets/eggs/", _EGG_ANIMATIONS)
	_test_frames_within_each_animation_are_not_all_pixel_identical("res://assets/projectiles/", _PROJ_ANIMATIONS)
	_test_frames_within_each_animation_are_not_all_pixel_identical("res://assets/effects/", _IMPACT_ANIMATIONS)

	_test_sprite_frames("res://data/eggs/egg_sprite_frames.tres", _EGG_MIN_FRAMES)
	_test_sprite_frames("res://data/projectiles/projectile_sprite_frames.tres", _PROJ_MIN_FRAMES)
	_test_sprite_frames("res://data/effects/impact_sprite_frames.tres", _IMPACT_MIN_FRAMES)

	_test_egg_scene_references_sprite_frames()
	_test_projectile_scene_references_sprite_frames()
	_test_death_effect_scene_references_impact_sprite_frames()

	if _failures == 0:
		print("[egg_projectile_assets_tests] ALL TESTS PASSED")
	else:
		print("[egg_projectile_assets_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(img != null, "%s deveria carregar como Image válida" % path)
	return img


## Dimensões corretas + fundo transparente (personagem/efeito recortado, nunca um bloco sólido) +
## nenhum pixel opaco tocando a borda do canvas (sinal de recorte, mesma classe de bug já
## encontrada nos Checkpoints B e C).
func _test_frame_group(dir: String, animations: Dictionary, expected_w: int, expected_h: int) -> void:
	for anim in animations:
		for frame_name in animations[anim]:
			var path := "%s%s.png" % [dir, frame_name]
			var img := _load(path)
			if img == null:
				continue
			_check(img.get_width() == expected_w and img.get_height() == expected_h,
				"%s deveria ser %dx%d, got %dx%d" % [path, expected_w, expected_h, img.get_width(), img.get_height()])

			var has_transparent := false
			var touches_edge := false
			var w := img.get_width()
			var h := img.get_height()
			for y in range(h):
				for x in range(w):
					var a := img.get_pixel(x, y).a
					if a < 0.01:
						has_transparent = true
					elif a > 0.01 and (x == 0 or y == 0 or x == w - 1 or y == h - 1):
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


func _test_frames_within_each_animation_are_not_all_pixel_identical(dir: String, animations: Dictionary) -> void:
	for anim in animations:
		var names: Array = animations[anim]
		for i in range(names.size() - 1):
			var a := _load("%s%s.png" % [dir, names[i]])
			var b := _load("%s%s.png" % [dir, names[i + 1]])
			if a == null or b == null:
				continue
			_check(_pixel_diff_count(a, b) > 0,
				"%s e %s (animação '%s') não deveriam ser pixel-a-pixel idênticos" % [names[i], names[i + 1], anim])


func _test_sprite_frames(path: String, min_frames: Dictionary) -> void:
	var frames := load(path) as SpriteFrames
	_check(frames != null, "%s deveria carregar como SpriteFrames válido" % path)
	if frames == null:
		return
	for anim in min_frames:
		_check(frames.has_animation(anim), "%s deveria ter a animação '%s'" % [path, anim])
		if frames.has_animation(anim):
			var count := frames.get_frame_count(anim)
			_check(count >= min_frames[anim],
				"%s: '%s' deveria ter no mínimo %d frames, tem %d" % [path, anim, min_frames[anim], count])
			for i in range(count):
				_check(frames.get_frame_texture(anim, i) != null,
					"%s: '%s' frame %d não deveria apontar para uma textura nula" % [path, anim, i])


func _test_egg_scene_references_sprite_frames() -> void:
	var packed := load("res://scenes/eggs/Egg.tscn") as PackedScene
	_check(packed != null, "Egg.tscn deveria carregar")
	if packed == null:
		return
	var egg := packed.instantiate()
	var sprite := egg.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "Egg.tscn deveria ter Visual/AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames == load("res://data/eggs/egg_sprite_frames.tres"),
			"AnimatedSprite2D de Egg.tscn deveria referenciar egg_sprite_frames.tres")
	egg.free()


func _test_projectile_scene_references_sprite_frames() -> void:
	var packed := load("res://scenes/combat/Projectile.tscn") as PackedScene
	_check(packed != null, "Projectile.tscn deveria carregar")
	if packed == null:
		return
	var projectile := packed.instantiate()
	var sprite := projectile.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "Projectile.tscn deveria ter Visual/AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames == load("res://data/projectiles/projectile_sprite_frames.tres"),
			"AnimatedSprite2D de Projectile.tscn deveria referenciar projectile_sprite_frames.tres")
	projectile.free()


func _test_death_effect_scene_references_impact_sprite_frames() -> void:
	var packed := load("res://scenes/effects/DeathEffect.tscn") as PackedScene
	_check(packed != null, "DeathEffect.tscn deveria carregar")
	if packed == null:
		return
	var effect := packed.instantiate()
	var sprite := effect.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "DeathEffect.tscn deveria ter Visual/AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames == load("res://data/effects/impact_sprite_frames.tres"),
			"AnimatedSprite2D de DeathEffect.tscn deveria referenciar impact_sprite_frames.tres (arte padrão)")
	effect.free()
