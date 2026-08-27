extends SceneTree
## Testes do Primeiro Protótipo Visual — Checkpoint A (Ambiente): confirma que os PNGs de
## `assets/environment/` existem, têm as dimensões esperadas, transparência onde faz sentido
## (decorações/detalhes recortados vs. tiles de chão que preenchem o tile inteiro), e que as
## variações de tile realmente diferem entre si em pixels — não basta existirem 4 arquivos de
## grama, eles precisam ser visualmente distintos (mesma lição do bug do raptor na etapa
## anterior: nem sempre dá para confiar só na inspeção visual de miniatura).
##
## Não testa a integração em GridManager (isso já é coberto indiretamente pelo compile-check/
## scan do editor — `preload()` falha a compilação se o arquivo não existir) nem a composição
## artística em si (cores/formas exatas) — só o contrato de arquivo que o resto do pipeline
## depende.
##
## Executar com:
##   godot --headless --path game --script res://tests/environment_assets_tests.gd

var _failures: int = 0

const _GROUND_TILES := [
	"res://assets/environment/grass_01.png", "res://assets/environment/grass_02.png",
	"res://assets/environment/grass_03.png", "res://assets/environment/grass_04.png",
	"res://assets/environment/path_01.png", "res://assets/environment/path_02.png",
	"res://assets/environment/path_03.png",
]
const _EDGE_STRIPS_HORIZONTAL := ["res://assets/environment/path_edge_n.png", "res://assets/environment/path_edge_s.png"]
const _EDGE_STRIPS_VERTICAL := ["res://assets/environment/path_edge_e.png", "res://assets/environment/path_edge_w.png"]
const _DECORATIONS := [
	"res://assets/environment/bush_small.png", "res://assets/environment/bush_large.png",
	"res://assets/environment/tree_small.png", "res://assets/environment/tree_large.png",
	"res://assets/environment/rock_small.png", "res://assets/environment/rock_large.png",
	"res://assets/environment/rock_cluster.png", "res://assets/environment/stump.png",
]
const _DETAILS := [
	"res://assets/environment/flower_yellow.png", "res://assets/environment/flower_pink.png",
	"res://assets/environment/mushroom.png", "res://assets/environment/leaf.png",
	"res://assets/environment/twig.png", "res://assets/environment/root_detail.png",
	"res://assets/environment/grass_tuft.png",
]


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[environment_assets_tests] FAIL: %s" % message)


func _initialize() -> void:
	_test_ground_tiles_exist_and_are_opaque_32x32()
	_test_edge_strips_exist_with_correct_dimensions_and_opaque()
	_test_decorations_exist_32x32_with_transparency()
	_test_details_exist_32x32_with_transparency()
	_test_grass_variants_are_not_pixel_identical()
	_test_path_variants_are_not_pixel_identical()
	_test_decorations_not_touching_all_four_edges()

	if _failures == 0:
		print("[environment_assets_tests] ALL TESTS PASSED")
	else:
		print("[environment_assets_tests] %d TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	_check(img != null, "%s deveria carregar como Image válida" % path)
	return img


func _is_fully_opaque(img: Image) -> bool:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a < 0.99:
				return false
	return true


func _has_transparent_pixel(img: Image) -> bool:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a < 0.01:
				return true
	return false


## Tiles de chão preenchem a célula inteira — não devem ter nenhum pixel transparente (senão o
## fundo do CanvasItem vazaria através, quebrando a leitura do mapa).
func _test_ground_tiles_exist_and_are_opaque_32x32() -> void:
	for path in _GROUND_TILES:
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == 32 and img.get_height() == 32,
			"%s deveria ser 32x32, got %dx%d" % [path, img.get_width(), img.get_height()])
		_check(_is_fully_opaque(img), "%s é um tile de chão — não deveria ter pixels transparentes" % path)


## Tiras de borda: norte/sul são 32 de largura por _EDGE_STRIP_SIZE de altura; leste/oeste são a
## transposição disso. Também precisam ser opacas (mesma razão dos tiles de chão).
func _test_edge_strips_exist_with_correct_dimensions_and_opaque() -> void:
	for path in _EDGE_STRIPS_HORIZONTAL:
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == 32 and img.get_height() < 32,
			"%s deveria ser 32 de largura e mais baixa que 32, got %dx%d" % [path, img.get_width(), img.get_height()])
		_check(_is_fully_opaque(img), "%s deveria ser opaca (é uma tira de chão)" % path)

	for path in _EDGE_STRIPS_VERTICAL:
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_height() == 32 and img.get_width() < 32,
			"%s deveria ser 32 de altura e mais estreita que 32, got %dx%d" % [path, img.get_width(), img.get_height()])
		_check(_is_fully_opaque(img), "%s deveria ser opaca (é uma tira de chão)" % path)


## Decorações são objetos recortados sobre fundo transparente — precisam ter pelo menos alguns
## pixels transparentes (senão são um bloco sólido cobrindo o tile inteiro, o que quebraria a
## leitura da grama por baixo).
func _test_decorations_exist_32x32_with_transparency() -> void:
	for path in _DECORATIONS:
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == 32 and img.get_height() == 32,
			"%s deveria ser 32x32, got %dx%d" % [path, img.get_width(), img.get_height()])
		_check(_has_transparent_pixel(img), "%s deveria ter fundo transparente (não é um tile de chão)" % path)


func _test_details_exist_32x32_with_transparency() -> void:
	for path in _DETAILS:
		var img := _load(path)
		if img == null:
			continue
		_check(img.get_width() == 32 and img.get_height() == 32,
			"%s deveria ser 32x32, got %dx%d" % [path, img.get_width(), img.get_height()])
		_check(_has_transparent_pixel(img), "%s deveria ter fundo transparente" % path)


func _pixel_diff_count(a: Image, b: Image) -> int:
	var diff := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	return diff


## Não basta existirem 4 arquivos de grama — eles precisam realmente parecer diferentes (nem que
## seja sutil), senão "variação" é só um nome de arquivo diferente para o mesmo desenho.
func _test_grass_variants_are_not_pixel_identical() -> void:
	var paths := ["res://assets/environment/grass_01.png", "res://assets/environment/grass_02.png",
		"res://assets/environment/grass_03.png", "res://assets/environment/grass_04.png"]
	for i in range(paths.size()):
		for j in range(i + 1, paths.size()):
			var a := _load(paths[i])
			var b := _load(paths[j])
			if a == null or b == null:
				continue
			_check(_pixel_diff_count(a, b) > 0,
				"%s e %s não deveriam ser pixel-a-pixel idênticos" % [paths[i], paths[j]])


func _test_path_variants_are_not_pixel_identical() -> void:
	var paths := ["res://assets/environment/path_01.png", "res://assets/environment/path_02.png",
		"res://assets/environment/path_03.png"]
	for i in range(paths.size()):
		for j in range(i + 1, paths.size()):
			var a := _load(paths[i])
			var b := _load(paths[j])
			if a == null or b == null:
				continue
			_check(_pixel_diff_count(a, b) > 0,
				"%s e %s não deveriam ser pixel-a-pixel idênticos" % [paths[i], paths[j]])


## Sanity de composição: uma decoração que toca as 4 bordas do canvas (linha/coluna 0 e 31 todas
## opacas) provavelmente vazou pra fora da célula por engano, em vez de ficar contida nela.
func _test_decorations_not_touching_all_four_edges() -> void:
	for path in _DECORATIONS + _DETAILS:
		var img := _load(path)
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var touches_top := false
		var touches_bottom := false
		var touches_left := false
		var touches_right := false
		for x in range(w):
			if img.get_pixel(x, 0).a > 0.01:
				touches_top = true
			if img.get_pixel(x, h - 1).a > 0.01:
				touches_bottom = true
		for y in range(h):
			if img.get_pixel(0, y).a > 0.01:
				touches_left = true
			if img.get_pixel(w - 1, y).a > 0.01:
				touches_right = true
		_check(not (touches_top and touches_bottom and touches_left and touches_right),
			"%s parece tocar as 4 bordas do canvas — pode ter vazado para fora da célula" % path)
