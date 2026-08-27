extends SceneTree
## Ferramenta de pipeline (Primeiro Protótipo Visual) — NÃO faz parte do jogo em runtime, só é
## executada manualmente para (re)gerar os PNGs placeholder em game/assets/. Desenha pixel art
## programaticamente via Image.set_pixel() (composição de formas primitivas — elipses, retângulos,
## polígonos), sem nenhuma dependência externa (ver docs/ART_DIRECTION.md). Existe porque o
## projeto não tinha nenhum pipeline de arte ainda; documentado como o pipeline mínimo atual —
## substituível por um artista/Aseprite depois sem mudar como o jogo consome os assets (PNG +
## SpriteFrames, ver build_sprite_frames.gd).
##
## Depois de rodar isto, é necessário um `godot --headless --editor --quit` (já faz parte de
## run_tests.ps1) para o editor importar os PNGs novos antes de build_sprite_frames.gd conseguir
## carregá-los como Texture2D.
##
## Executar com:
##   godot --headless --path game --script res://tools/pixel_art_generator.gd

const SIZE := 32


func _initialize() -> void:
	_generate_environment()
	_generate_velociraptor()
	_generate_basic_enemy()
	_generate_eggs()
	_generate_projectile()
	_generate_impact_effect()
	_generate_spawn_effect()
	print("[pixel_art_generator] done")
	quit(0)


# ---------------------------------------------------------------------------
# Canvas helpers — biblioteca mínima de composição de formas primitivas.
# ---------------------------------------------------------------------------

func _new_canvas() -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _set_px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_set_px(img, x, y, color)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				_set_px(img, x, y, color)


## Preenchimento por scanline — usado para bicos/cristas/cauda (formas triangulares).
func _fill_polygon(img: Image, points: PackedVector2Array, color: Color) -> void:
	var min_y := points[0].y
	var max_y := points[0].y
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		var xs: Array[float] = []
		var n := points.size()
		for i in range(n):
			var a := points[i]
			var b := points[(i + 1) % n]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				var t := (y - a.y) / (b.y - a.y)
				xs.append(a.x + t * (b.x - a.x))
		xs.sort()
		var i := 0
		while i + 1 < xs.size():
			var xa := int(round(xs[i]))
			var xb := int(round(xs[i + 1]))
			for x in range(xa, xb):
				_set_px(img, x, y, color)
			i += 2


## Contorno de 1px: qualquer pixel transparente adjacente (4-direções) a um pixel opaco vira
## `color`. Usa um snapshot (`src`) para não gerar contorno sobre o próprio contorno recém-pintado.
func _outline(img: Image, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.01:
				continue
			var has_opaque_neighbor := false
			var neighbor_offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for offset in neighbor_offsets:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.01:
					has_opaque_neighbor = true
					break
			if has_opaque_neighbor:
				img.set_pixel(x, y, color)


func _save(img: Image, path: String) -> void:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := img.save_png(path)
	if err != OK:
		printerr("[pixel_art_generator] FAILED to save %s: %d" % [path, err])
	else:
		print("[pixel_art_generator] saved %s" % path)


## Espelha uma imagem no eixo Y (linhas de cima viram linhas de baixo).
func _flip_y(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			out.set_pixel(x, h - 1 - y, img.get_pixel(x, y))
	return out


## Espelha uma imagem no eixo X (colunas da esquerda viram colunas da direita).
func _flip_x(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			out.set_pixel(w - 1 - x, y, img.get_pixel(x, y))
	return out


## Transpõe uma imagem WxH para HxW (linhas viram colunas) — usado para derivar as tiras de
## borda leste/oeste a partir da tira norte já desenhada, em vez de duplicar a lógica de desenho
## para cada direção (e assim arriscar 4 versões levemente diferentes/inconsistentes).
func _transpose(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(h, w, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			out.set_pixel(y, x, img.get_pixel(x, y))
	return out


# ---------------------------------------------------------------------------
# Environment (Checkpoint A — protótipo visual, ambiente)
# ---------------------------------------------------------------------------

const _GRASS_BASE := Color8(58, 110, 54)
const _GRASS_DARK := Color8(42, 88, 42)
const _GRASS_LIGHT := Color8(78, 138, 66)
const _PATH_BASE := Color8(139, 107, 61)
const _PATH_DARK := Color8(112, 84, 45)
const _PATH_LIGHT := Color8(163, 130, 82)
const _EDGE_STRIP_SIZE := 10


func _generate_environment() -> void:
	# Tiles de chão — 4 variações de grama e 3 de trilha (mesma linguagem visual, nunca biomas
	# diferentes: só desloca o padrão de tufos/pedras e acrescenta um elemento pontual por
	# variante). GridManager escolhe entre elas deterministicamente por coordenada.
	_save(_make_grass_tile(0), "res://assets/environment/grass_01.png")
	_save(_make_grass_tile(1), "res://assets/environment/grass_02.png")  # grama alta
	_save(_make_grass_tile(2), "res://assets/environment/grass_03.png")  # com flor
	_save(_make_grass_tile(3), "res://assets/environment/grass_04.png")  # esparsa

	_save(_make_path_tile(0), "res://assets/environment/path_01.png")
	_save(_make_path_tile(1), "res://assets/environment/path_02.png")  # pedregosa
	_save(_make_path_tile(2), "res://assets/environment/path_03.png")  # com raízes

	# Bordas de transição grama↔trilha — só a NORTE é desenhada à mão; as outras 3 são derivadas
	# por transformação geométrica pura (flip/transpose), não redesenhadas — garante consistência
	# entre as 4 direções sem 4x o trabalho manual (e sem depender de rotação em runtime, que não
	# dava para validar visualmente na rodada anterior).
	var edge_n := _make_path_edge_strip_north()
	_save(edge_n, "res://assets/environment/path_edge_n.png")
	_save(_flip_y(edge_n), "res://assets/environment/path_edge_s.png")
	var edge_w := _transpose(edge_n)
	_save(edge_w, "res://assets/environment/path_edge_w.png")
	_save(_flip_x(edge_w), "res://assets/environment/path_edge_e.png")

	# Decorações (só em OBSTACLE, nunca em BUILDABLE — ver docs/ART_DIRECTION.md) com variação de
	# tamanho.
	_save(_make_bush(0.65), "res://assets/environment/bush_small.png")
	_save(_make_bush(1.0), "res://assets/environment/bush_large.png")
	_save(_make_tree(0.7), "res://assets/environment/tree_small.png")
	_save(_make_tree(1.0), "res://assets/environment/tree_large.png")
	_save(_make_rock(0.6), "res://assets/environment/rock_small.png")
	_save(_make_rock(1.0), "res://assets/environment/rock_large.png")
	_save(_make_rock_cluster(), "res://assets/environment/rock_cluster.png")
	_save(_make_stump(), "res://assets/environment/stump.png")

	# Detalhes ambientais pequenos — assets individuais prontos para uso futuro (overlay leve em
	# cima da grama, por exemplo); não integrados ao desenho da grid nesta etapa além do que já
	# está embutido nas variantes de grass_0x acima (ver ARCHITECTURE.md).
	_save(_make_flower(Color8(240, 210, 60)), "res://assets/environment/flower_yellow.png")
	_save(_make_flower(Color8(225, 130, 160)), "res://assets/environment/flower_pink.png")
	_save(_make_mushroom(), "res://assets/environment/mushroom.png")
	_save(_make_leaf(), "res://assets/environment/leaf.png")
	_save(_make_twig(), "res://assets/environment/twig.png")
	_save(_make_root_detail(), "res://assets/environment/root_detail.png")
	_save(_make_grass_tuft_detail(), "res://assets/environment/grass_tuft.png")


## `variant`: 0 = base, 1 = grama alta, 2 = com flor, 3 = esparsa. Todas compartilham a mesma
## paleta e densidade base de tufos — só o padrão desloca (evita repetição visual idêntica entre
## células vizinhas) e cada variante acrescenta NO MÁXIMO um elemento pontual, para não virar um
## "bioma" visualmente diferente (pedido explícito: mesma linguagem visual).
func _make_grass_tile(variant: int) -> Image:
	var img := _new_canvas()
	_fill_rect(img, 0, 0, SIZE, SIZE, _GRASS_BASE)

	var tufts := [
		Vector2i(4, 6), Vector2i(12, 3), Vector2i(20, 8), Vector2i(27, 5),
		Vector2i(7, 15), Vector2i(16, 18), Vector2i(24, 14), Vector2i(3, 22),
		Vector2i(11, 26), Vector2i(19, 24), Vector2i(28, 20), Vector2i(14, 10),
	]
	var offset := Vector2i((variant * 7) % SIZE, (variant * 5) % SIZE)
	for i in range(tufts.size()):
		var p: Vector2i = Vector2i((tufts[i].x + offset.x) % SIZE, (tufts[i].y + offset.y) % SIZE)
		var c := _GRASS_DARK if i % 2 == 0 else _GRASS_LIGHT
		_set_px(img, p.x, p.y, c)
		_set_px(img, p.x, p.y - 1, c)

	match variant:
		1:  # grama alta — algumas lâminas mais longas, mesma paleta
			for p in [Vector2i(9, 24), Vector2i(21, 9), Vector2i(26, 26), Vector2i(13, 13)]:
				_set_px(img, p.x, p.y, _GRASS_DARK)
				_set_px(img, p.x, p.y - 1, _GRASS_DARK)
				_set_px(img, p.x, p.y - 2, _GRASS_LIGHT)
		2:  # com flor pontual
			_draw_flower_at(img, 22, 22, Color8(240, 210, 60))

	return img


## `variant`: 0 = base (pedrinhas), 1 = pedregosa (mais pedras, maiores), 2 = com raízes finas.
func _make_path_tile(variant: int) -> Image:
	var img := _new_canvas()
	_fill_rect(img, 0, 0, SIZE, SIZE, _PATH_BASE)

	var pebbles := [
		Vector2i(5, 7), Vector2i(13, 4), Vector2i(21, 9), Vector2i(26, 15),
		Vector2i(9, 19), Vector2i(17, 23), Vector2i(24, 27), Vector2i(3, 26),
		Vector2i(15, 13), Vector2i(29, 6),
	]
	var offset := Vector2i((variant * 6) % SIZE, (variant * 9) % SIZE)
	for i in range(pebbles.size()):
		var p: Vector2i = Vector2i((pebbles[i].x + offset.x) % SIZE, (pebbles[i].y + offset.y) % SIZE)
		var c := _PATH_LIGHT if i % 3 == 0 else _PATH_DARK
		_set_px(img, p.x, p.y, c)

	match variant:
		1:  # pedregosa — pedras extras, um pouco maiores (2x2)
			for p in [Vector2i(10, 10), Vector2i(20, 20), Vector2i(6, 22)]:
				_fill_rect(img, p.x, p.y, 2, 2, _PATH_DARK)
				_set_px(img, p.x, p.y, _PATH_LIGHT)
		2:  # raízes finas cruzando o chão
			_fill_polygon(img, PackedVector2Array([
				Vector2(4, 18), Vector2(28, 10), Vector2(28, 11), Vector2(4, 19),
			]), _PATH_DARK)

	return img


## Tira de transição grama→trilha (32×`_EDGE_STRIP_SIZE`), grama no topo/trilha embaixo — usada
## como a borda NORTE (vizinho não-trilha ao norte). As outras 3 direções são derivadas por
## transformação geométrica (ver _generate_environment()), não redesenhadas.
func _make_path_edge_strip_north() -> Image:
	var w := SIZE
	var h := _EDGE_STRIP_SIZE
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	# Fronteira perto de 50% (não 60-70%): esta mesma tira vira as bordas leste/oeste por
	# transposição (ver _generate_environment()) — uma fronteira desbalanceada aqui viraria uma
	# tira "quase toda grama" nessas direções depois de transpor. Bug real encontrado inspecionando
	# a folha de contato (path_edge_e/w tinham só ~30% de trilha visível).
	for x in range(w):
		var step := (x / 4) % 2
		var boundary := (h * 4 / 10) if step == 0 else (h * 5 / 10)
		for y in range(0, boundary):
			img.set_pixel(x, y, _GRASS_BASE)
		for y in range(boundary, h):
			img.set_pixel(x, y, _PATH_BASE)
	for p in [Vector2i(6, 2), Vector2i(22, 1)]:
		img.set_pixel(p.x, p.y, _GRASS_DARK)
	for p in [Vector2i(9, h - 2), Vector2i(20, h - 3)]:
		img.set_pixel(p.x, p.y, _PATH_LIGHT)
	return img


func _make_bush(scale: float) -> Image:
	var img := _new_canvas()
	var dark := Color8(36, 90, 42)
	var base := Color8(52, 120, 56)
	var light := Color8(90, 160, 80)
	_fill_ellipse(img, 16, 27, 9 * scale, 3, Color(0.1, 0.2, 0.1, 0.45))
	_fill_ellipse(img, 16 - 5 * scale, 20, 7 * scale, 6 * scale, dark)
	_fill_ellipse(img, 16 + 5 * scale, 20, 7 * scale, 6 * scale, dark)
	_fill_ellipse(img, 16, 16, 8 * scale, 7 * scale, base)
	_fill_ellipse(img, 16 - 3 * scale, 13, 4 * scale, 3 * scale, light)
	_outline(img, Color8(20, 40, 20))
	return img


func _make_tree(scale: float) -> Image:
	var img := _new_canvas()
	var trunk := Color8(90, 62, 38)
	var trunk_dark := Color8(66, 44, 26)
	var canopy_dark := Color8(34, 84, 40)
	var canopy := Color8(48, 110, 52)
	var canopy_light := Color8(84, 152, 74)
	var trunk_h := 11 * scale
	_fill_ellipse(img, 16, 29, 8 * scale, 2, Color(0.1, 0.2, 0.1, 0.45))
	_fill_rect(img, 14, int(29 - trunk_h), 4, int(trunk_h), trunk)
	_fill_rect(img, 14, int(29 - trunk_h), 1, int(trunk_h), trunk_dark)
	var canopy_cy := 29 - trunk_h - 9 * scale
	_fill_ellipse(img, 16, canopy_cy, 11 * scale, 10 * scale, canopy_dark)
	_fill_ellipse(img, 16, canopy_cy - 2, 10 * scale, 9 * scale, canopy)
	_fill_ellipse(img, 16 - 4 * scale, canopy_cy - 3, 4 * scale, 3 * scale, canopy_light)
	_outline(img, Color8(20, 30, 18))
	return img


func _make_rock(scale: float) -> Image:
	var img := _new_canvas()
	var dark := Color8(90, 90, 96)
	var base := Color8(130, 130, 138)
	var light := Color8(175, 175, 182)
	_fill_ellipse(img, 16, 27, 8 * scale, 2, Color(0.05, 0.05, 0.06, 0.4))
	_fill_ellipse(img, 17, 21, 9 * scale, 7 * scale, dark)
	_fill_ellipse(img, 14, 19, 8 * scale, 6 * scale, base)
	_fill_ellipse(img, 11, 16, 3 * scale, 2 * scale, light)
	_outline(img, Color8(40, 40, 44))
	return img


## Agrupamento de pedras (3 pedras pequenas justapostas) — variante distinta de rock_small/large,
## não só mais uma escala.
func _make_rock_cluster() -> Image:
	var img := _new_canvas()
	var dark := Color8(90, 90, 96)
	var base := Color8(130, 130, 138)
	var light := Color8(175, 175, 182)
	_fill_ellipse(img, 16, 27, 10, 2.5, Color(0.05, 0.05, 0.06, 0.4))
	_fill_ellipse(img, 10, 23, 5, 4, dark)
	_fill_ellipse(img, 9, 22, 4.5, 3.5, base)
	_fill_ellipse(img, 21, 24, 5.5, 4.5, dark)
	_fill_ellipse(img, 20, 23, 5, 4, base)
	_fill_ellipse(img, 16, 19, 6, 5, dark)
	_fill_ellipse(img, 15, 18, 5.5, 4.5, base)
	_fill_ellipse(img, 13, 16, 2, 1.5, light)
	_outline(img, Color8(40, 40, 44))
	return img


func _make_stump() -> Image:
	var img := _new_canvas()
	var wood := Color8(120, 88, 54)
	var wood_dark := Color8(90, 62, 38)
	var rings := Color8(150, 112, 72)
	_fill_ellipse(img, 16, 25, 7, 2, Color(0.1, 0.08, 0.05, 0.4))
	_fill_rect(img, 11, 16, 10, 9, wood_dark)
	_fill_ellipse(img, 16, 16, 6, 4, wood)
	_fill_ellipse(img, 16, 16, 4, 2.5, rings)
	_fill_ellipse(img, 16, 16, 2, 1.2, wood_dark)
	_outline(img, Color8(60, 44, 28))
	return img


func _draw_flower_at(img: Image, cx: int, cy: int, petal_color: Color) -> void:
	var angles := [0.0, 72.0, 144.0, 216.0, 288.0]
	for angle_deg in angles:
		var rad := deg_to_rad(angle_deg)
		_fill_ellipse(img, cx + cos(rad) * 3.0, cy + sin(rad) * 3.0, 2.0, 1.6, petal_color)
	_fill_ellipse(img, cx, cy, 1.6, 1.6, Color8(250, 220, 80))


func _make_flower(petal_color: Color) -> Image:
	var img := _new_canvas()
	_fill_rect(img, 15, 18, 2, 9, Color8(60, 110, 50))
	_draw_flower_at(img, 16, 15, petal_color)
	_outline(img, Color8(40, 40, 20))
	return img


func _make_mushroom() -> Image:
	var img := _new_canvas()
	var stem := Color8(230, 220, 200)
	var cap := Color8(190, 60, 50)
	var cap_dark := Color8(150, 40, 35)
	var spots := Color8(240, 235, 225)
	_fill_ellipse(img, 16, 26, 5, 1.5, Color(0.1, 0.08, 0.05, 0.35))
	_fill_rect(img, 14, 19, 4, 8, stem)
	_fill_ellipse(img, 16, 18, 7, 5, cap)
	_fill_ellipse(img, 16, 20, 7, 2, cap_dark)
	for p in [Vector2i(13, 16), Vector2i(19, 17), Vector2i(16, 14)]:
		_set_px(img, p.x, p.y, spots)
	_outline(img, Color8(70, 20, 15))
	return img


func _make_leaf() -> Image:
	var img := _new_canvas()
	var green := Color8(70, 130, 60)
	var green_dark := Color8(48, 100, 44)
	_fill_polygon(img, PackedVector2Array([
		Vector2(16, 9), Vector2(24, 17), Vector2(16, 27), Vector2(9, 17),
	]), green)
	for y in range(10, 27):
		_set_px(img, 16, y, green_dark)
	_outline(img, Color8(30, 60, 26))
	return img


func _make_twig() -> Image:
	var img := _new_canvas()
	var wood := Color8(120, 88, 52)
	var wood_dark := Color8(90, 62, 36)
	_fill_polygon(img, PackedVector2Array([
		Vector2(6, 23), Vector2(24, 10), Vector2(25, 12), Vector2(8, 25),
	]), wood)
	_fill_polygon(img, PackedVector2Array([
		Vector2(16, 16), Vector2(20, 11), Vector2(21, 12), Vector2(17, 17),
	]), wood_dark)
	_outline(img, Color8(60, 42, 24))
	return img


func _make_root_detail() -> Image:
	var img := _new_canvas()
	var wood := Color8(100, 74, 46)
	var wood_dark := Color8(72, 52, 32)
	_fill_polygon(img, PackedVector2Array([
		Vector2(7, 14), Vector2(24, 18), Vector2(23, 21), Vector2(6, 17),
	]), wood)
	_fill_polygon(img, PackedVector2Array([
		Vector2(14, 17), Vector2(11, 24), Vector2(13, 25), Vector2(16, 18),
	]), wood_dark)
	_fill_polygon(img, PackedVector2Array([
		Vector2(19, 18), Vector2(22, 23), Vector2(20, 24), Vector2(17, 19),
	]), wood_dark)
	_outline(img, Color8(50, 36, 22))
	return img


func _make_grass_tuft_detail() -> Image:
	var img := _new_canvas()
	var green := Color8(70, 130, 60)
	var green_dark := Color8(48, 100, 44)
	var blades := [
		[Vector2(11, 27), Vector2(13, 27), Vector2(10, 13)],
		[Vector2(15, 28), Vector2(17, 28), Vector2(16, 10)],
		[Vector2(19, 27), Vector2(21, 27), Vector2(23, 14)],
		[Vector2(13, 28), Vector2(14, 28), Vector2(12, 18)],
	]
	for i in range(blades.size()):
		var pts := PackedVector2Array(blades[i])
		_fill_polygon(img, pts, green if i % 2 == 0 else green_dark)
	return img


# ---------------------------------------------------------------------------
# Velociraptor (Checkpoint B — asset pack) — bípede esguio, cauda longa de equilíbrio, crista na
# cabeça, postura de predador. Silhueta própria: nariz aponta para +X (mesma convenção já usada
# pelos placeholders geométricos e pelo protótipo anterior). Canvas 48×48 (maior que o tile de
# 32×32, permitido explicitamente pela instrução do asset pack para dar folga a poses dinâmicas
# de corrida/ataque sem cortar na borda) — ainda lê como "uma torre numa célula", não várias
# (1.5× o lado do tile).
#
# **Bug real encontrado nesta etapa, mesma classe do bug do focinho no protótipo anterior:** uma
# primeira versão usava canvas 40×40 com a cabeça perto o suficiente da borda direita que, nos
# frames de lunge do ATTACK (`body_dx` positivo somado ao deslocamento do focinho), o
# focinho/boca inteiros caíam fora do canvas — `_set_px()` descarta silenciosamente pixels fora
## dos limites, então o resultado não era um erro, só uma boca que nunca aparecia aberta em
# nenhum frame (confirmado ampliando os frames individualmente via `Read`, não só pela folha de
# contato em miniatura — mesma lição já registrada antes: miniatura pequena engana). Corrigido
# alargando o canvas para 48×48 e recentrando as âncoras com folga real — margem confirmada por
# `velociraptor_bounds_tests.gd`, que verifica que nenhum pixel opaco toca a borda do canvas em
# nenhum dos 19 frames.
#
# Paleta: LARANJA (`#F28D26`) permanece a cor principal — decisão final do usuário (o Checkpoint B
# chegou a ser prototipado em verde numa rodada anterior desta mesma etapa, mas o usuário revisou
# e pediu para manter a identidade laranja já estabelecida desde a Phase 0.4; a imagem de
# referência do asset pack serve só de direção de silhueta/proporções/linguagem de pixel art, não
# de paleta a copiar). Valores idênticos ao protótipo anterior — mesma identidade de cor, arte
# nova. Ver docs/ART_DIRECTION.md.
# ---------------------------------------------------------------------------

const _RAPTOR_W := 48
const _RAPTOR_H := 48

const _RAPTOR_BASE := Color8(242, 141, 38)
const _RAPTOR_DARK := Color8(184, 100, 26)
const _RAPTOR_LIGHT := Color8(255, 197, 120)
const _RAPTOR_BELLY := Color8(255, 232, 198)
const _RAPTOR_MOUTH := Color8(122, 40, 32)
const _RAPTOR_TOOTH := Color8(238, 230, 214)
const _RAPTOR_OUTLINE := Color8(72, 40, 12)
const _RAPTOR_EYE := Color8(24, 18, 12)

## Âncoras absolutas do corpo em repouso (canvas 48×48) — todo o resto é desenhado como offset
## relativo a estes pontos, nunca coordenadas soltas, para as poses ficarem coerentes entre si.
const _R_HIP := Vector2(24, 27)
const _R_BODY_CENTER := Vector2(26, 24)
const _R_HEAD := Vector2(32, 17)
const _R_TAIL_BASE := Vector2(20, 25)
const _R_GROUND_Y := 41.0


func _new_raptor_canvas() -> Image:
	var img := Image.create_empty(_RAPTOR_W, _RAPTOR_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Pose neutra (parado, respirando) — cada chamador só sobrescreve os campos que importam para
## aquele frame. Evita 19 chamadas com uma dúzia de parâmetros posicionais cada (frágil, difícil
## de ler); um Dictionary com defaults nomeados deixa cada pose legível como uma lista de "o que
## muda nesse frame".
func _raptor_pose(overrides: Dictionary = {}) -> Dictionary:
	var pose := {
		"body_dx": 0.0, "body_dy": 0.0,       # lean/lunge do tronco+pescoço+cabeça+braço juntos
		"head_tilt": 0.0,                      # inclinação extra só da cabeça (aceno/flinch)
		"mouth_open": 0.0,                     # 0 = fechada, 1 = totalmente aberta
		"chest_scale": 1.0,                    # respiração (escala vertical do tronco)
		"tail_mid": Vector2(-8, -2),           # ponto de controle do meio da cauda (offset da base)
		"tail_tip": Vector2(-16, -7),          # ponta da cauda (offset da base)
		"front_knee": Vector2(1, 5),           # perna dianteira (mais perto da cabeça)
		"front_foot": Vector2(-1, 6),
		"back_knee": Vector2(-2, 5),           # perna traseira (mais perto da cauda)
		"back_foot": Vector2(1, 6),
		"arm_offset": Vector2(0, 1),
		"eye_shut": false,
	}
	for key in overrides:
		pose[key] = overrides[key]
	return pose


func _generate_velociraptor() -> void:
	# IDLE (4 frames, mín. 4) — vivo mesmo parado: ciclo de respiração + pequena troca de peso
	# entre as pernas. É uma torre parada, não precisa de grande movimento — só precisa não
	# parecer estática.
	_save(_draw_raptor(_raptor_pose()),
		"res://assets/dinosaurs/velociraptor/idle_0.png")
	_save(_draw_raptor(_raptor_pose({"chest_scale": 1.18, "body_dy": -0.6, "head_tilt": -0.4,
		"tail_tip": Vector2(-16, -8.5), "arm_offset": Vector2(0, 0.3)})),
		"res://assets/dinosaurs/velociraptor/idle_1.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(1.6, 4.6), "front_foot": Vector2(-1.6, 6.2),
		"back_knee": Vector2(-1.6, 5.4), "back_foot": Vector2(1.6, 5.8)})),
		"res://assets/dinosaurs/velociraptor/idle_2.png")
	_save(_draw_raptor(_raptor_pose({"chest_scale": 0.88, "body_dy": 0.6, "head_tilt": 0.5,
		"tail_tip": Vector2(-15, -5.5), "arm_offset": Vector2(0, 1.4)})),
		"res://assets/dinosaurs/velociraptor/idle_3.png")

	# MOVE (6 frames, mín. 6) — ciclo de corrida preparado para reutilização futura da
	# infraestrutura visual (ver Dinosaur.gd — não muda para MOVE hoje, só existe pronto).
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(3, 3), "front_foot": Vector2(4, 5),
		"back_knee": Vector2(-4, 3), "back_foot": Vector2(-6, 5), "body_dy": 0.8,
		"tail_mid": Vector2(-8, 1), "tail_tip": Vector2(-15, 3), "head_tilt": 0.3})),
		"res://assets/dinosaurs/velociraptor/move_0.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(1, 2), "front_foot": Vector2(1, 7),
		"back_knee": Vector2(-3, 1.5), "back_foot": Vector2(-3, 7.5), "body_dy": 1.2,
		"tail_mid": Vector2(-8, 0), "tail_tip": Vector2(-16, 1), "head_tilt": 0.1})),
		"res://assets/dinosaurs/velociraptor/move_1.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(-1, -1), "front_foot": Vector2(-2, 3),
		"back_knee": Vector2(2, 4), "back_foot": Vector2(5, 5.5), "body_dy": -1.0,
		"tail_mid": Vector2(-8, -3), "tail_tip": Vector2(-14, -8), "head_tilt": -0.3})),
		"res://assets/dinosaurs/velociraptor/move_2.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(-4, 3), "front_foot": Vector2(-6, 5),
		"back_knee": Vector2(3, 3), "back_foot": Vector2(4, 5), "body_dy": 0.8,
		"tail_mid": Vector2(-8, 1), "tail_tip": Vector2(-15, 3), "head_tilt": 0.3})),
		"res://assets/dinosaurs/velociraptor/move_3.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(-3, 1.5), "front_foot": Vector2(-3, 7.5),
		"back_knee": Vector2(1, 2), "back_foot": Vector2(1, 7), "body_dy": 1.2,
		"tail_mid": Vector2(-8, 0), "tail_tip": Vector2(-16, 1), "head_tilt": 0.1})),
		"res://assets/dinosaurs/velociraptor/move_4.png")
	_save(_draw_raptor(_raptor_pose({"front_knee": Vector2(2, 4), "front_foot": Vector2(5, 5.5),
		"back_knee": Vector2(-1, -1), "back_foot": Vector2(-2, 3), "body_dy": -1.0,
		"tail_mid": Vector2(-8, -3), "tail_tip": Vector2(-14, -8), "head_tilt": -0.3})),
		"res://assets/dinosaurs/velociraptor/move_5.png")

	# ATTACK (6 frames, mín. 6) — precisa transmitir claramente "acabou de atacar": antecipação →
	# investida → mordida → recuo. É o estado mais importante (torre disparando de verdade).
	_save(_draw_raptor(_raptor_pose({"body_dx": -3, "body_dy": 1.2, "chest_scale": 1.12,
		"head_tilt": 0.6, "front_knee": Vector2(2.5, 3.5), "front_foot": Vector2(0, 5),
		"tail_mid": Vector2(-6, -4), "tail_tip": Vector2(-13, -9), "arm_offset": Vector2(-1, 0)})),
		"res://assets/dinosaurs/velociraptor/attack_0.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": -1, "body_dy": 0.4, "mouth_open": 0.35,
		"head_tilt": 0.2, "tail_mid": Vector2(-7, -3), "tail_tip": Vector2(-14, -7)})),
		"res://assets/dinosaurs/velociraptor/attack_1.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": 3, "body_dy": -0.8, "mouth_open": 0.75,
		"head_tilt": -0.5, "front_knee": Vector2(3, 5), "front_foot": Vector2(4, 5.5),
		"tail_mid": Vector2(-8, 2), "tail_tip": Vector2(-16, 5), "arm_offset": Vector2(1, -1)})),
		"res://assets/dinosaurs/velociraptor/attack_2.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": 6, "body_dy": -1.0, "mouth_open": 1.0,
		"head_tilt": -0.8, "front_knee": Vector2(4, 5), "front_foot": Vector2(6, 5.5),
		"tail_mid": Vector2(-8, 3), "tail_tip": Vector2(-17, 7), "arm_offset": Vector2(1.5, -1.5)})),
		"res://assets/dinosaurs/velociraptor/attack_3.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": 5, "body_dy": -0.4, "mouth_open": 0.15,
		"head_tilt": -0.2, "front_knee": Vector2(3, 5), "front_foot": Vector2(4, 5.5),
		"tail_mid": Vector2(-8, 1), "tail_tip": Vector2(-16, 2)})),
		"res://assets/dinosaurs/velociraptor/attack_4.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": 1, "body_dy": 0.5, "chest_scale": 0.95,
		"tail_mid": Vector2(-8, -1), "tail_tip": Vector2(-15, -4)})),
		"res://assets/dinosaurs/velociraptor/attack_5.png")

	# HIT (3 frames, mín. 3) — sem uso de gameplay ainda (torre não recebe dano hoje), preparado
	# só para não criar dependência nova quando existir.
	_save(_draw_raptor(_raptor_pose({"body_dx": -2.5, "head_tilt": -1.6,
		"tail_mid": Vector2(-7, -5), "tail_tip": Vector2(-14, -11)})),
		"res://assets/dinosaurs/velociraptor/hit_0.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": -4, "chest_scale": 0.85, "head_tilt": -2.6,
		"eye_shut": true, "tail_mid": Vector2(-6, -6), "tail_tip": Vector2(-12, -13)})),
		"res://assets/dinosaurs/velociraptor/hit_1.png")
	_save(_draw_raptor(_raptor_pose({"body_dx": -1, "chest_scale": 0.96, "head_tilt": -0.6,
		"tail_mid": Vector2(-8, -3), "tail_tip": Vector2(-15, -8)})),
		"res://assets/dinosaurs/velociraptor/hit_2.png")


## Segmento reto grosso entre dois pontos, via polígono perpendicular à direção — usado para
## membros/cauda em qualquer ângulo sem precisar rotacionar a imagem inteira (rotação do sprite
## completo não conta como "mudança de pose real", ver instrução do Checkpoint B).
func _fill_thick_line(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var dir := b - a
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x) * (width * 0.5)
	_fill_polygon(img, PackedVector2Array([a + perp, b + perp, b - perp, a - perp]), color)


## Uma perna = coxa (hip→joelho) + canela (joelho→pé) + garras — dois segmentos deixam o joelho
## visivelmente dobrado (postura de predador), em vez de uma perna reta única.
func _draw_raptor_leg(img: Image, hip: Vector2, knee_offset: Vector2, foot_offset: Vector2, color: Color) -> void:
	var knee := hip + knee_offset
	var foot := knee + foot_offset
	_fill_thick_line(img, hip, knee, 3.4, color)
	_fill_thick_line(img, knee, foot, 2.4, color)
	var toe_dir := (foot - knee).normalized()
	var toe_perp := Vector2(-toe_dir.y, toe_dir.x)
	_fill_polygon(img, PackedVector2Array([
		foot, foot + toe_dir * 3.0 + toe_perp * 1.6, foot + toe_perp * 1.6,
	]), _RAPTOR_OUTLINE)
	_fill_polygon(img, PackedVector2Array([
		foot, foot + toe_dir * 3.6, foot - toe_perp * 1.6,
	]), _RAPTOR_OUTLINE)


## Desenha o Velociraptor a partir de uma pose (ver `_raptor_pose()`). Ordem de desenho:
## sombra → cauda → perna traseira (atrás) → perna dianteira (na frente) → tronco → braço →
## pescoço → cabeça/focinho/crista/olho → contorno — cada camada por cima da anterior, mesma
## lógica de composição já usada no protótipo anterior (ambiente/BasicEnemy).
func _draw_raptor(pose: Dictionary) -> Image:
	var img := _new_raptor_canvas()
	var body_offset := Vector2(pose.body_dx, pose.body_dy)

	_fill_ellipse(img, _R_HIP.x, _R_GROUND_Y, 12, 2, Color(0.08, 0.07, 0.05, 0.4))

	# cauda — 2 segmentos (base→meio→ponta), afinando, usada para equilíbrio (levanta/whip nas
	# poses de corrida e ataque, nunca encosta no chão)
	var tail_base: Vector2 = _R_TAIL_BASE + body_offset
	var tail_mid: Vector2 = tail_base + pose.tail_mid
	var tail_tip: Vector2 = tail_base + pose.tail_tip
	_fill_thick_line(img, tail_base, tail_mid, 4.2, _RAPTOR_DARK)
	_fill_thick_line(img, tail_mid, tail_tip, 2.2, _RAPTOR_DARK)
	_fill_thick_line(img, tail_base, tail_mid, 2.8, _RAPTOR_BASE)
	_fill_thick_line(img, tail_mid, tail_tip, 1.2, _RAPTOR_BASE)

	# pernas — claramente separadas (gap visível), traseira desenhada primeiro (fica atrás da
	# dianteira, dá senso de profundidade sem precisar de shading extra)
	_draw_raptor_leg(img, _R_HIP + Vector2(-2, 0), pose.back_knee, pose.back_foot, _RAPTOR_DARK)
	_draw_raptor_leg(img, _R_HIP + Vector2(2, 0), pose.front_knee, pose.front_foot, _RAPTOR_BASE)

	# tronco (esguio, não arredondado demais) + barriga clara + listra dorsal (mesma família de cor,
	# um tom mais escuro — marca de personalidade, não um acento de cor separada)
	var body: Vector2 = _R_BODY_CENTER + body_offset
	_fill_ellipse(img, body.x, body.y, 6.6, 4.0 * pose.chest_scale, _RAPTOR_BASE)
	_fill_ellipse(img, body.x - 2.0, body.y - 2.4, 3.0, 1.4 * pose.chest_scale, _RAPTOR_LIGHT)
	_fill_ellipse(img, body.x - 1.5, body.y + 1.8, 4.4, 2.0 * pose.chest_scale, _RAPTOR_BELLY)
	_fill_thick_line(img, body + Vector2(-5, -3.2), body + Vector2(4.5, -3.6), 1.0, _RAPTOR_DARK)

	# bracinho pequeno (tamanho reduzido de propósito — predador bípede, não usa os braços)
	var arm_root: Vector2 = body + Vector2(3, 1)
	var arm_tip: Vector2 = arm_root + Vector2(2, 2) + pose.arm_offset
	_fill_thick_line(img, arm_root, arm_tip, 1.8, _RAPTOR_DARK)
	_fill_ellipse(img, arm_tip.x, arm_tip.y, 0.9, 0.9, _RAPTOR_DARK)

	# pescoço
	var head: Vector2 = _R_HEAD + body_offset + Vector2(0, pose.head_tilt)
	_fill_thick_line(img, body + Vector2(3.5, -2.2), head + Vector2(-2.5, 1.5), 4.2, _RAPTOR_BASE)

	# cabeça + focinho — mandíbula com dobradiça real: maxilar superior (fixo, só sobe um pouco) e
	# mandíbula inferior (desce proporcional a mouth_open) são DUAS peças que se separam de verdade
	# a partir de um ponto comum (jaw_hinge), não um triângulo único com um recorte quase
	# imperceptível — bug real encontrado nesta etapa: a primeira versão calculava um gap
	# proporcional a mouth_open mas os pontos ficavam tão próximos entre si (< 2px de área) que o
	# interior nunca lia como "boca aberta" em nenhum frame, nem no de mordida máxima (confirmado
	# ampliando 24x a região do focinho via Read, não só pela folha de contato).
	_fill_ellipse(img, head.x, head.y, 3.6, 3.2, _RAPTOR_BASE)
	var jaw_hinge: Vector2 = head + Vector2(2, 0)
	var upper_tip: Vector2 = jaw_hinge + Vector2(5.0, -1.0 - pose.mouth_open * 1.0)
	var lower_tip: Vector2 = jaw_hinge + Vector2(4.2, 1.0 + pose.mouth_open * 6.0)
	_fill_polygon(img, PackedVector2Array([
		jaw_hinge + Vector2(-1, -2.2), upper_tip, jaw_hinge + Vector2(0.5, -0.2),
	]), _RAPTOR_BASE)
	_fill_polygon(img, PackedVector2Array([
		jaw_hinge + Vector2(0.5, 0.3), lower_tip, jaw_hinge + Vector2(-1, 2.0),
	]), _RAPTOR_DARK)
	if pose.mouth_open > 0.15:
		_fill_polygon(img, PackedVector2Array([
			jaw_hinge + Vector2(1.0, -0.2), upper_tip + Vector2(-0.8, 0.3),
			lower_tip + Vector2(-0.8, -0.3), jaw_hinge + Vector2(1.0, 0.4),
		]), _RAPTOR_MOUTH)
	if pose.mouth_open > 0.6:
		_set_px(img, int(upper_tip.x - 0.5), int(upper_tip.y + 0.8), _RAPTOR_TOOTH)
		_set_px(img, int(lower_tip.x - 0.5), int(lower_tip.y - 0.8), _RAPTOR_TOOTH)

	# crista (silhueta/personalidade própria — mesma família de cor do corpo, um tom mais escuro)
	_fill_polygon(img, PackedVector2Array([
		head + Vector2(-1.2, -2.6), head + Vector2(0.6, -6.2), head + Vector2(2.2, -2.2),
	]), _RAPTOR_DARK)

	# olho (fechado durante o pico do HIT — única mudança booleana da pose, o resto é sempre
	# geometria contínua)
	if pose.eye_shut:
		_set_px(img, int(head.x + 1.2), int(head.y - 0.4), _RAPTOR_EYE)
		_set_px(img, int(head.x + 3.0), int(head.y - 0.4), _RAPTOR_EYE)
	else:
		_set_px(img, int(head.x + 2.2), int(head.y - 0.5), _RAPTOR_EYE)
		_set_px(img, int(head.x + 2.2), int(head.y - 1.4), _RAPTOR_LIGHT)

	_outline(img, _RAPTOR_OUTLINE)
	return img


# ---------------------------------------------------------------------------
# BasicEnemy (Checkpoint C — asset pack) — quadrúpede atarracado e baixo, 4 pernas curtas em
# ESTRUTURA (nunca braços — diferença de plano corporal em relação ao Velociraptor, não só de
# proporção), cauda curta arrastando perto do chão (o raptor tem cauda longa erguida para
# equilíbrio — oposto deliberado), cabeça larga e romba com um chifre pequeno e crista de
# espinhos nas costas. Lê como "o invasor" — postura baixa, larga, pesada — contra a postura
# alta/esguia/ágil do Velociraptor. Paleta mantida (`#F35A1A`, já estabelecida desde a Phase 0.4 e
# reafirmada por docs/ART_DIRECTION.md) — a diferenciação visual pedida no Checkpoint C vem de
# silhueta/postura/plano corporal, não de reformular a identidade cromática já aprovada.
# ---------------------------------------------------------------------------

const _ENEMY_W := 48
const _ENEMY_H := 48

const _ENEMY_BASE := Color8(243, 90, 26)
const _ENEMY_DARK := Color8(182, 62, 15)
const _ENEMY_LIGHT := Color8(255, 140, 80)
const _ENEMY_BELLY := Color8(232, 192, 150)
const _ENEMY_SPIKE := Color8(140, 30, 10)
const _ENEMY_MAW := Color8(90, 20, 15)
const _ENEMY_OUTLINE := Color8(62, 16, 5)
const _ENEMY_EYE := Color8(20, 10, 8)
## Cor de flash de dano — valor idêntico ao antigo `_RAPTOR_LIGHT` (mantém o visual de hit
## pixel-a-pixel igual ao protótipo anterior), só desacoplado por nome (ver Checkpoint B).
const _ENEMY_FLASH := Color8(255, 197, 120)

## Âncoras absolutas do corpo em repouso (canvas 48×48) — mesmo princípio do Velociraptor: tudo
## desenhado como offset relativo a estas, nunca coordenadas soltas.
const _E_BODY_CENTER := Vector2(24, 25)
const _E_FRONT_HIP := Vector2(33, 29)
const _E_BACK_HIP := Vector2(17, 29)
const _E_HEAD := Vector2(35, 24)
const _E_TAIL_BASE := Vector2(15, 27)
const _E_GROUND_Y := 39.0


func _new_enemy_canvas() -> Image:
	var img := Image.create_empty(_ENEMY_W, _ENEMY_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Pose neutra (mesmo padrão do `_raptor_pose()`) — cada frame só sobrescreve o que muda.
func _enemy_pose(overrides: Dictionary = {}) -> Dictionary:
	var pose := {
		"body_dx": 0.0, "body_dy": 0.0,   # desloca corpo+cabeça+quadris+cauda juntos (recuo/afundar)
		"head_dy": 0.0,                    # bob extra só da cabeça
		"mouth_open": 0.0,                 # 0 = focinho fechado, 1 = boca bem aberta (rugido/dor)
		"flatten": 1.0,                    # 1 = normal; menor = mais achatado/largo (impacto, morte)
		"spike_lift": 1.0,                 # 1 = crista erguida, 0 = totalmente achatada (morte)
		"tail_mid": Vector2(-5, 1),        # ponto de controle do meio da cauda (offset da base)
		"tail_tip": Vector2(-9, 2),        # ponta da cauda — sempre baixa, arrastando (não ergue)
		"front_near_foot": Vector2(-1, 6), # 4 pernas independentes — cada uma só um offset de pé
		"front_far_foot": Vector2(2, 7),   # (pernas curtas/atarracadas: 1 segmento só, sem joelho
		"back_near_foot": Vector2(1, 6),   # articulado como o Velociraptor — postura mais bruta)
		"back_far_foot": Vector2(-2, 7),
		"eye_shut": false,
		"flash": false,
	}
	for key in overrides:
		pose[key] = overrides[key]
	return pose


func _generate_basic_enemy() -> void:
	# MOVE (6 frames) — marcha real: pares diagonais de pernas alternam apoio (trote), corpo
	# balança verticalmente com o passo, cauda baixa balança de um lado a outro.
	_save(_draw_enemy(_enemy_pose({"front_near_foot": Vector2(-4, 4), "back_far_foot": Vector2(-4, 4),
		"front_far_foot": Vector2(5, 8), "back_near_foot": Vector2(5, 8),
		"body_dy": 0.8, "head_dy": 0.4, "tail_tip": Vector2(-9, 0)})),
		"res://assets/enemies/basic_enemy/move_0.png")
	_save(_draw_enemy(_enemy_pose({"front_near_foot": Vector2(-1, 6), "back_far_foot": Vector2(-1, 6),
		"front_far_foot": Vector2(2, 6), "back_near_foot": Vector2(2, 6),
		"body_dy": -0.8, "head_dy": -0.3, "tail_tip": Vector2(-10, 3)})),
		"res://assets/enemies/basic_enemy/move_1.png")
	_save(_draw_enemy(_enemy_pose({"front_far_foot": Vector2(-4, 4), "back_near_foot": Vector2(-4, 4),
		"front_near_foot": Vector2(5, 8), "back_far_foot": Vector2(5, 8),
		"body_dy": 0.8, "head_dy": 0.4, "tail_tip": Vector2(-8, 1)})),
		"res://assets/enemies/basic_enemy/move_2.png")
	_save(_draw_enemy(_enemy_pose({"front_far_foot": Vector2(-1, 6), "back_near_foot": Vector2(-1, 6),
		"front_near_foot": Vector2(2, 6), "back_far_foot": Vector2(2, 6),
		"body_dy": -0.8, "head_dy": -0.3, "tail_tip": Vector2(-10, 4)})),
		"res://assets/enemies/basic_enemy/move_3.png")
	_save(_draw_enemy(_enemy_pose({"front_near_foot": Vector2(-5, 3), "back_far_foot": Vector2(-3, 5),
		"front_far_foot": Vector2(4, 7), "back_near_foot": Vector2(6, 8),
		"body_dy": 1.1, "head_dy": 0.6, "tail_tip": Vector2(-7, 0)})),
		"res://assets/enemies/basic_enemy/move_4.png")
	_save(_draw_enemy(_enemy_pose({"front_far_foot": Vector2(-5, 3), "back_near_foot": Vector2(-3, 5),
		"front_near_foot": Vector2(4, 7), "back_far_foot": Vector2(6, 8),
		"body_dy": 1.1, "head_dy": 0.6, "tail_tip": Vector2(-9, 5)})),
		"res://assets/enemies/basic_enemy/move_5.png")

	# HIT (3 frames) — reação física clara: recuo do corpo inteiro + achatamento de impacto +
	# focinho abre num resmungo de dor, não só um flash de cor por cima da pose parada.
	_save(_draw_enemy(_enemy_pose({"body_dx": -2, "flatten": 0.7, "mouth_open": 0.6,
		"head_dy": -1.2, "flash": true})),
		"res://assets/enemies/basic_enemy/hit_0.png")
	_save(_draw_enemy(_enemy_pose({"body_dx": -3.5, "flatten": 0.85, "mouth_open": 0.85,
		"head_dy": -1.8, "eye_shut": true})),
		"res://assets/enemies/basic_enemy/hit_1.png")
	_save(_draw_enemy(_enemy_pose({"body_dx": -1, "flatten": 1.0, "mouth_open": 0.2,
		"head_dy": -0.3})),
		"res://assets/enemies/basic_enemy/hit_2.png")

	# DEATH (6 frames) — colapso de verdade: pernas cedem, corpo afunda e achata, crista deita,
	# cauda cai no chão, olho fecha — não é um fade nem uma simples troca de cor.
	_save(_draw_enemy(_enemy_pose({"body_dy": 0.6, "flatten": 0.9, "spike_lift": 0.9,
		"mouth_open": 0.4, "head_dy": 0.3})),
		"res://assets/enemies/basic_enemy/death_0.png")
	_save(_draw_enemy(_enemy_pose({"body_dy": 1.8, "flatten": 0.75, "spike_lift": 0.7,
		"mouth_open": 0.6, "head_dy": 0.8, "tail_tip": Vector2(-8, 4),
		"front_near_foot": Vector2(-3, 5), "back_far_foot": Vector2(4, 5)})),
		"res://assets/enemies/basic_enemy/death_1.png")
	_save(_draw_enemy(_enemy_pose({"body_dy": 3.0, "flatten": 0.55, "spike_lift": 0.5,
		"eye_shut": true, "head_dy": 1.4, "tail_tip": Vector2(-7, 5),
		"front_far_foot": Vector2(-5, 3), "back_near_foot": Vector2(5, 3)})),
		"res://assets/enemies/basic_enemy/death_2.png")
	_save(_draw_enemy(_enemy_pose({"body_dy": 4.2, "flatten": 0.4, "spike_lift": 0.3,
		"eye_shut": true, "head_dy": 1.8, "tail_tip": Vector2(-6, 6),
		"front_near_foot": Vector2(-6, 2), "back_far_foot": Vector2(6, 2)})),
		"res://assets/enemies/basic_enemy/death_3.png")
	_save(_draw_enemy(_enemy_pose({"body_dy": 5.0, "flatten": 0.28, "spike_lift": 0.15,
		"eye_shut": true, "head_dy": 2.0, "tail_tip": Vector2(-5, 6)})),
		"res://assets/enemies/basic_enemy/death_4.png")
	_save(_draw_enemy(_enemy_pose({"body_dy": 5.4, "flatten": 0.2, "spike_lift": 0.05,
		"eye_shut": true, "head_dy": 2.1, "tail_tip": Vector2(-4, 6)})),
		"res://assets/enemies/basic_enemy/death_5.png")


## Uma perna curta e atarracada = 1 segmento (quadril→pé) + garra pequena — deliberadamente mais
## simples/bruta que a perna de 2 segmentos do Velociraptor (ver `_draw_raptor_leg()`): reforça a
## diferença de postura (invasor pesado vs. predador ágil), não só preguiça de código.
func _draw_enemy_leg(img: Image, hip: Vector2, foot_offset: Vector2, color: Color) -> void:
	var foot := hip + foot_offset
	_fill_thick_line(img, hip, foot, 3.8, color)
	var dir := (foot - hip).normalized()
	var perp := Vector2(-dir.y, dir.x)
	_fill_polygon(img, PackedVector2Array([
		foot, foot + dir * 2.4 + perp * 1.4, foot + dir * 2.4 - perp * 1.4,
	]), _ENEMY_OUTLINE)


## Desenha o BasicEnemy a partir de uma pose (ver `_enemy_pose()`). Ordem: sombra → cauda → pernas
## distantes (atrás) → corpo+barriga → crista → pernas próximas (na frente) → cabeça/focinho/
## chifre/olho → contorno.
func _draw_enemy(pose: Dictionary) -> Image:
	var img := _new_enemy_canvas()
	var base := _ENEMY_FLASH if pose.flash else _ENEMY_BASE
	var dark := _ENEMY_LIGHT if pose.flash else _ENEMY_DARK
	var belly := Color8(255, 245, 230) if pose.flash else _ENEMY_BELLY
	var spike := _ENEMY_LIGHT if pose.flash else _ENEMY_SPIKE

	var body_offset := Vector2(pose.body_dx, pose.body_dy)
	var front_hip: Vector2 = _E_FRONT_HIP + body_offset
	var back_hip: Vector2 = _E_BACK_HIP + body_offset

	_fill_ellipse(img, _E_BODY_CENTER.x, _E_GROUND_Y, 13, 2.2, Color(0.08, 0.06, 0.05, 0.4))

	# cauda curta, SEMPRE baixa/arrastando (oposto deliberado da cauda longa erguida do
	# Velociraptor) — 2 segmentos afinando, igual técnica do raptor (`_fill_thick_line`).
	var tail_base: Vector2 = _E_TAIL_BASE + body_offset
	var tail_mid: Vector2 = tail_base + pose.tail_mid
	var tail_tip: Vector2 = tail_base + pose.tail_tip
	_fill_thick_line(img, tail_base, tail_mid, 4.6, dark)
	_fill_thick_line(img, tail_mid, tail_tip, 2.6, dark)

	# pernas distantes (desenhadas primeiro — ficam atrás do corpo, dão profundidade)
	_draw_enemy_leg(img, back_hip + Vector2(1, -1), pose.back_far_foot, dark)
	_draw_enemy_leg(img, front_hip + Vector2(1, -1), pose.front_far_foot, dark)

	# corpo — largo e baixo (bem mais largo que alto, oposto do tronco esguio do raptor).
	# `flatten` < 1 encolhe a altura E alarga a base — nunca as duas coisas em direções opostas
	# (bug real encontrado nesta etapa: uma primeira versão usava `body_ry = 6.5 / flatten`, que
	# faz a ALTURA CRESCER conforme flatten cai — o inimigo "morrendo" ficava mais alto e fino, em
	# pé, em vez de tombar achatado; só ficou óbvio na folha de contato ampliada, não nos números
	# isolados). Corrigido para as duas dimensões responderem na mesma direção.
	var body: Vector2 = _E_BODY_CENTER + body_offset
	var flatten: float = pose.flatten
	var body_ry: float = 6.5 * flatten
	var body_rx: float = 10.5 + (1.0 - flatten) * 6.0
	_fill_ellipse(img, body.x, body.y, body_rx, body_ry, base)
	_fill_ellipse(img, body.x - 1, body.y + 2, body_rx * 0.6, body_ry * 0.5, belly)

	# crista de espinhos nas costas (achata na morte via spike_lift — personalidade própria)
	var spike_lift: float = pose.spike_lift
	for sx in [-6, -2, 2, 6]:
		var spike_x: float = body.x + sx
		var spike_top_y: float = body.y - 4 - 5.0 * spike_lift
		_fill_polygon(img, PackedVector2Array([
			Vector2(spike_x - 2, body.y - 4), Vector2(spike_x, spike_top_y), Vector2(spike_x + 2, body.y - 4),
		]), spike)

	# pernas próximas (na frente do corpo)
	_draw_enemy_leg(img, back_hip + Vector2(-1, 1), pose.back_near_foot, dark)
	_draw_enemy_leg(img, front_hip + Vector2(-1, 1), pose.front_near_foot, dark)

	# cabeça larga e romba (não afunilada como o focinho do raptor) + focinho curto que abre num
	# resmungo/rugido (`mouth_open`, mudança geométrica real, não só cor)
	var head: Vector2 = _E_HEAD + body_offset + Vector2(0, pose.head_dy)
	_fill_ellipse(img, head.x, head.y, 4.6, 4.0, base)
	var snout: Vector2 = head + Vector2(4.5, 1.0)
	_fill_polygon(img, PackedVector2Array([
		head + Vector2(2.5, -1.5), snout + Vector2(0, -1.0 - pose.mouth_open * 2.0), head + Vector2(3, 0.3),
	]), dark)
	_fill_polygon(img, PackedVector2Array([
		head + Vector2(2.5, 0.6), snout + Vector2(-0.5, 1.0 + pose.mouth_open * 2.5), head + Vector2(3, 2.5),
	]), dark)
	if pose.mouth_open > 0.2:
		_fill_polygon(img, PackedVector2Array([
			head + Vector2(3, -0.4), snout + Vector2(-1.8, 0.2), head + Vector2(3, 1.6),
		]), _ENEMY_MAW)

	# pequeno chifre (acento — silhueta/personalidade própria, distinta da crista do raptor)
	_fill_polygon(img, PackedVector2Array([
		head + Vector2(-1.5, -2.8), head + Vector2(0, -6.0), head + Vector2(1.3, -2.6),
	]), spike)

	if pose.eye_shut:
		_set_px(img, int(head.x + 1.2), int(head.y - 1.2), _ENEMY_EYE)
		_set_px(img, int(head.x + 2.6), int(head.y - 1.2), _ENEMY_EYE)
	else:
		_set_px(img, int(head.x + 2.0), int(head.y - 1.4), _ENEMY_EYE)

	_outline(img, _ENEMY_OUTLINE)
	return img


# ---------------------------------------------------------------------------
# Ovo (Checkpoint D1 — asset pack) — casca creme/palha com pintas, tema pré-histórico. 3
# aparências discretas mapeadas nos MESMOS estados que egg.gd já decide por fração de HP
# (IDLE = saudável, MOVE = crítico/ferido — reaproveitado como estado visual, não "andando"; ver
# egg.gd) mais DEATH = destruído/quebrado (congela no último frame, não desaparece — regra de
# gameplay preservada). HIT é a reação de dano não-letal, comum aos dois estados vivos.
# ---------------------------------------------------------------------------

const _EGG_W := 32
const _EGG_H := 32

const _EGG_BASE := Color8(226, 210, 162)
const _EGG_DARK := Color8(184, 164, 110)
const _EGG_LIGHT := Color8(248, 240, 206)
const _EGG_SPOT := Color8(150, 122, 78)
const _EGG_OUTLINE := Color8(92, 72, 42)
const _EGG_CRACK := Color8(74, 50, 34)
const _EGG_GLOW := Color8(255, 214, 140)
const _EGG_CRITICAL := Color8(198, 96, 48)
const _EGG_INNER_DARK := Color8(46, 38, 30)

const _EGG_CX := 16.0
const _EGG_CY := 17.5
const _EGG_GROUND_Y := 27.5


func _new_egg_canvas() -> Image:
	var img := Image.create_empty(_EGG_W, _EGG_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Pose neutra (mesmo padrão de `_raptor_pose()`/`_enemy_pose()`) para os 3 estados "inteiros" do
## ovo (idle/move/hit — só o `death`, que quebra a silhueta, usa `_draw_egg_broken()` à parte).
func _egg_pose(overrides: Dictionary = {}) -> Dictionary:
	var pose := {
		"rx": 10.0, "ry": 11.5,        # meio-eixos do corpo — "respiração" real (não é scale/Tween)
		"glow_offset": Vector2(0, -1), # a "vida lá dentro" se move sutilmente entre frames
		"glow_scale": 1.0,
		"critical": false,             # marcas quentes de estresse (ferido, ainda não destruído)
		"crack_flash": 0.0,            # 0 = sem fratura visível; >0 = linha(s) de rachadura + brilho
	}
	for key in overrides:
		pose[key] = overrides[key]
	return pose


func _generate_eggs() -> void:
	# IDLE (4 frames) — saudável: respiração lenta e sutil + brilho interno pulsando de leve.
	_save(_draw_egg(_egg_pose()), "res://assets/eggs/idle_0.png")
	_save(_draw_egg(_egg_pose({"rx": 10.3, "ry": 11.2, "glow_offset": Vector2(0.4, -1.3), "glow_scale": 1.15})),
		"res://assets/eggs/idle_1.png")
	_save(_draw_egg(_egg_pose()), "res://assets/eggs/idle_2.png")
	_save(_draw_egg(_egg_pose({"rx": 9.7, "ry": 11.8, "glow_offset": Vector2(-0.4, -0.7), "glow_scale": 0.85})),
		"res://assets/eggs/idle_3.png")

	# MOVE (4 frames) — reaproveitado por egg.gd como o loop "crítico/ferido": mesma respiração,
	# amplitude maior (mais agitada) + marcas quentes de estresse pulsando — aparência visivelmente
	# diferente da saudável, sem quebrar a casca ainda.
	_save(_draw_egg(_egg_pose({"rx": 10.6, "ry": 10.9, "glow_offset": Vector2(0.6, -1.6), "glow_scale": 1.3, "critical": true})),
		"res://assets/eggs/move_0.png")
	_save(_draw_egg(_egg_pose({"rx": 9.4, "ry": 12.1, "glow_offset": Vector2(-0.2, -0.5), "glow_scale": 0.7, "critical": true})),
		"res://assets/eggs/move_1.png")
	_save(_draw_egg(_egg_pose({"rx": 10.6, "ry": 10.9, "glow_offset": Vector2(-0.6, -1.6), "glow_scale": 1.3, "critical": true})),
		"res://assets/eggs/move_2.png")
	_save(_draw_egg(_egg_pose({"rx": 9.4, "ry": 12.1, "glow_offset": Vector2(0.2, -0.5), "glow_scale": 0.7, "critical": true})),
		"res://assets/eggs/move_3.png")

	# HIT (3 frames) — reação de dano não-letal: squash/recoil real (rx/ry deformam, não é um
	# scale de Tween) + flash de fratura momentâneo, relaxando de volta à forma normal.
	_save(_draw_egg(_egg_pose({"rx": 12.5, "ry": 9.0, "crack_flash": 1.0})), "res://assets/eggs/hit_0.png")
	_save(_draw_egg(_egg_pose({"rx": 11.3, "ry": 10.2, "crack_flash": 0.5})), "res://assets/eggs/hit_1.png")
	_save(_draw_egg(_egg_pose({"rx": 10.2, "ry": 11.3, "crack_flash": 0.15})), "res://assets/eggs/hit_2.png")

	# DEATH (5 frames, não faz loop, congela no último) — quebra de verdade: rachaduras se
	# espalhando → casca se separando → fragmento caindo → destruído (interior escuro visível,
	# cacos ao redor) — nunca "desaparece" (regra de gameplay preservada: Egg continua visível).
	_save(_draw_egg_broken(0), "res://assets/eggs/death_0.png")
	_save(_draw_egg_broken(1), "res://assets/eggs/death_1.png")
	_save(_draw_egg_broken(2), "res://assets/eggs/death_2.png")
	_save(_draw_egg_broken(3), "res://assets/eggs/death_3.png")
	_save(_draw_egg_broken(4), "res://assets/eggs/death_4.png")


## Desenha o ovo "inteiro" (idle/move/hit) a partir de uma pose — silhueta composta por 2 elipses
## sobrepostas (base larga embaixo + topo mais estreito) para aproximar um contorno de ovo de
## verdade, não um círculo/oval genérico.
func _draw_egg(pose: Dictionary) -> Image:
	var img := _new_egg_canvas()
	var rx: float = pose.rx
	var ry: float = pose.ry
	var critical: bool = pose.critical
	var crack_flash: float = pose.crack_flash

	_fill_ellipse(img, _EGG_CX, _EGG_GROUND_Y, rx * 0.9, 1.5, Color(0.08, 0.07, 0.05, 0.4))

	_fill_ellipse(img, _EGG_CX, _EGG_CY + ry * 0.28, rx, ry * 0.68, _EGG_BASE)
	_fill_ellipse(img, _EGG_CX, _EGG_CY - ry * 0.42, rx * 0.68, ry * 0.55, _EGG_BASE)

	# sombra inferior + brilho superior (volume) — sempre presentes, não fazem parte da animação
	# sozinhos (só um componente a mais dentro de cada silhueta já diferente por frame)
	_fill_ellipse(img, _EGG_CX + 1, _EGG_CY + ry * 0.55, rx * 0.75, ry * 0.32, _EGG_DARK)
	_fill_ellipse(img, _EGG_CX - rx * 0.32, _EGG_CY - ry * 0.55, rx * 0.32, ry * 0.28, _EGG_LIGHT)

	# pintas — posições fixas (decorativas, não animam), só entram se couberem dentro da silhueta
	# atual (rx/ry variam por frame — ver `_egg_pose()`)
	for spot in [Vector2(-4, -2), Vector2(3, -5), Vector2(-5, 4), Vector2(4, 5), Vector2(0, 8)]:
		if absf(spot.x) < rx * 0.75 and absf(spot.y) < ry * 0.75:
			_fill_ellipse(img, _EGG_CX + spot.x, _EGG_CY + spot.y, 1.1, 1.0, _EGG_SPOT)

	if critical:
		# marcas quentes de estresse — cor sólida pré-misturada com a casca (nunca semi-
		# transparente: Image.set_pixel SOBRESCREVE em vez de compor alpha — um preenchimento
		# translúcido aqui abriria um "buraco" mostrando o que estiver atrás do ovo em runtime,
		# em vez de tingir a própria casca. Mesma lição já aplicada noutros pontos do pipeline:
		# sempre assar a cor final, nunca depender de alpha em cima de outro desenho já opaco).
		# Nunca cobrem a casca toda, só indicam "ferido".
		_fill_ellipse(img, _EGG_CX - 3, _EGG_CY + 2, 2.4, 1.6, _EGG_BASE.lerp(_EGG_CRITICAL, 0.6))
		_fill_ellipse(img, _EGG_CX + 4, _EGG_CY - 3, 1.8, 1.3, _EGG_BASE.lerp(_EGG_CRITICAL, 0.45))

	# brilho interno ("vida lá dentro") — muda de posição/tamanho a cada frame (ver `_egg_pose()`),
	# nunca é só um `modulate` por cima do sprite inteiro; cor sólida pré-misturada (mesmo motivo
	# do bloco `critical` acima).
	var glow_offset: Vector2 = pose.glow_offset
	var glow_scale: float = pose.glow_scale
	_fill_ellipse(img, _EGG_CX + glow_offset.x, _EGG_CY + glow_offset.y, 2.6 * glow_scale, 2.2 * glow_scale, _EGG_BASE.lerp(_EGG_GLOW, 0.55))

	if crack_flash > 0.0:
		_fill_thick_line(img, Vector2(_EGG_CX - 2, _EGG_CY - ry * 0.5), Vector2(_EGG_CX + 1, _EGG_CY), 0.8, _EGG_CRACK)
		_fill_thick_line(img, Vector2(_EGG_CX + 1, _EGG_CY), Vector2(_EGG_CX - 1, _EGG_CY + ry * 0.4), 0.8, _EGG_CRACK)
		if crack_flash > 0.6:
			for p in [Vector2(-6, -8), Vector2(6, -7), Vector2(-7, 6), Vector2(7, 7)]:
				_set_px(img, int(_EGG_CX + p.x), int(_EGG_CY + p.y), _EGG_LIGHT)

	_outline(img, _EGG_OUTLINE)
	return img


## Ovo quebrado (DEATH) — silhueta genuinamente diferente por estágio, não uma variação
## paramétrica da forma inteira (a casca de fato se separa em pedaços). `stage` 0..4;
## `stage` 4 é o quadro final, onde a animação (`loop = false`) congela para sempre.
func _draw_egg_broken(stage: int) -> Image:
	var img := _new_egg_canvas()
	_fill_ellipse(img, _EGG_CX, _EGG_GROUND_Y, 11, 1.5, Color(0.08, 0.07, 0.05, 0.4))

	match stage:
		0:
			# ainda inteiro, mas com rachaduras profundas se espalhando pela casca inteira
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 3.2, 10, 7.8, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX, _EGG_CY - 4.8, 6.8, 6.3, _EGG_BASE)
			for line in [
				[Vector2(-6, -8), Vector2(-2, -1), Vector2(2, -4), Vector2(5, 2)],
				[Vector2(2, -4), Vector2(-1, 3), Vector2(-4, 8)],
				[Vector2(5, 2), Vector2(7, 8)],
			]:
				for i in range(line.size() - 1):
					_fill_thick_line(img, Vector2(_EGG_CX, _EGG_CY) + line[i], Vector2(_EGG_CX, _EGG_CY) + line[i + 1], 0.9, _EGG_CRACK)
			for p in [Vector2(-8, -9), Vector2(8, -8), Vector2(-9, 7), Vector2(9, 8), Vector2(0, -11)]:
				_set_px(img, int(_EGG_CX + p.x), int(_EGG_CY + p.y), _EGG_LIGHT)
		1:
			# a metade de cima acabou de se separar — a tampa cai para o lado, já apoiada no chão
			# (perto de `_EGG_GROUND_Y`, nunca "flutuando" acima do fragmento principal)
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 4.5, 10, 6.8, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 1, 8.5, 2.6, _EGG_INNER_DARK)
			_fill_ellipse(img, _EGG_CX + 0.5, _EGG_CY + 3.2, 7.5, 2.0, _EGG_DARK)
			_fill_ellipse(img, _EGG_CX - 9, _EGG_CY + 6.5, 4.2, 3.0, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX - 10, _EGG_CY + 5.5, 1.8, 1.2, _EGG_LIGHT)
		2:
			# fragmento principal assentando mais, cacos pequenos já no chão dos dois lados
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 6, 10.5, 5.6, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 3, 9, 3.4, _EGG_INNER_DARK)
			_fill_ellipse(img, _EGG_CX - 9, _EGG_CY + 7, 3.4, 2.3, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX + 8.5, _EGG_CY + 7.5, 2.2, 1.6, _EGG_BASE)
		3:
			# fragmento inferior menor ainda, mais cacos espalhados no chão ao redor
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 7.5, 10.5, 4.4, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 5, 8.6, 2.6, _EGG_INNER_DARK)
			_fill_ellipse(img, _EGG_CX - 9.5, _EGG_CY + 6.5, 2.6, 1.8, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX + 9, _EGG_CY + 7, 2.3, 1.6, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX - 3, _EGG_CY + 8.5, 1.4, 1.0, _EGG_BASE)
		_:
			# estágio final (congela aqui) — só a base fragmentada e alguns cacos no chão, interior
			# escuro e vazio, sem brilho de vida — a leitura de "destruído" tem que durar para
			# sempre, então nenhum caco fica "no ar": tudo assentado na linha do chão.
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 8, 10.5, 3.6, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX, _EGG_CY + 6.2, 8.6, 2.0, _EGG_INNER_DARK)
			_fill_ellipse(img, _EGG_CX - 9.5, _EGG_CY + 6.8, 2.4, 1.7, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX + 9, _EGG_CY + 7.2, 2.1, 1.5, _EGG_BASE)
			_fill_ellipse(img, _EGG_CX - 3, _EGG_CY + 9, 1.4, 1.0, _EGG_BASE)

	_outline(img, _EGG_OUTLINE)
	return img


# ---------------------------------------------------------------------------
# Projétil (Checkpoint D2 — asset pack) — pequeno dardo/garra estilizado, paleta do Velociraptor
# (é o que a torre dispara). Canvas pequeno (16×16) — "pequeno e claramente visível", não precisa
# ocupar espaço de personagem. Nariz aponta para +X (projectile.gd gira o node raiz na direção do
# alvo — a arte só precisa estar desenhada olhando para a direção de viagem "0°").
# ---------------------------------------------------------------------------

const _PROJ_W := 20
const _PROJ_H := 16

const _PROJ_BASE := Color8(224, 138, 46)
const _PROJ_DARK := Color8(176, 100, 30)
const _PROJ_LIGHT := Color8(255, 210, 140)
const _PROJ_OUTLINE := Color8(72, 40, 12)


func _new_projectile_canvas() -> Image:
	var img := Image.create_empty(_PROJ_W, _PROJ_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _generate_projectile() -> void:
	# IDLE (4 frames, único estado que projectile.gd usa) — silhueta do dardo sempre legível e
	# consistente (garra curva apontando para +X); o que anima é o pluma/tufo traseiro esvoaçando
	# e um brilho que percorre a lâmina — "vivo em voo" sem mexer na leitura da trajetória.
	_save(_draw_projectile(0.0, 0), "res://assets/projectiles/idle_0.png")
	_save(_draw_projectile(0.6, 1), "res://assets/projectiles/idle_1.png")
	_save(_draw_projectile(0.0, 2), "res://assets/projectiles/idle_2.png")
	_save(_draw_projectile(-0.6, 1), "res://assets/projectiles/idle_3.png")


## `flutter`: desloca a ponta do tufo traseiro (esvoaçando). `glint_phase`: posição do brilho
## percorrendo a lâmina (0/1/2 — muda de verdade a posição do highlight, não só o brilho geral).
##
## Canvas alargado para 20×16 (era 16×16) — bug real encontrado por
## `egg_projectile_assets_tests.gd`: com 16×16 e a lâmina perto da borda direita, o tufo traseiro
## (que precisa de espaço à esquerda para esvoaçar) tinha pontas em x negativo — fora do canvas.
## `_set_px` descarta o que fica fora silenciosamente, mas a largura da linha (1.0) ainda pintava
## pixels reais bem na coluna 0, tocando a borda. Recomposto com folga real dos dois lados.
func _draw_projectile(flutter: float, glint_phase: int) -> Image:
	var img := _new_projectile_canvas()
	var cy := 8.0

	# lâmina curva (garra estilizada) — corpo principal
	_fill_polygon(img, PackedVector2Array([
		Vector2(17, cy), Vector2(9, cy - 2.2), Vector2(4, cy - 0.6),
		Vector2(4, cy + 0.6), Vector2(9, cy + 2.2),
	]), _PROJ_BASE)
	_fill_polygon(img, PackedVector2Array([
		Vector2(17, cy), Vector2(10, cy - 1.2), Vector2(6, cy),
	]), _PROJ_DARK)

	# tufo/pluma traseira — esvoaça (posição da ponta muda por frame). Margem extra em x (2.2/1.9,
	# não 1.2/0.9): a largura da linha (0.8) desloca a borda do polígono perpendicularmente à
	# direção do traço, então a ponta "x" sozinha não é o pixel mais à esquerda de verdade — bug
	# real encontrado por `egg_projectile_assets_tests.gd` mesmo depois de uma primeira correção.
	_fill_thick_line(img, Vector2(4.5, cy), Vector2(2.2, cy - 3.2 + flutter), 0.8, _PROJ_DARK)
	_fill_thick_line(img, Vector2(4.5, cy), Vector2(1.9, cy + 3.0 - flutter), 0.8, _PROJ_DARK)

	# brilho percorrendo a lâmina — 3 posições possíveis ao longo do comprimento
	var glint_x := 8.0 + glint_phase * 2.7
	_set_px(img, int(glint_x), int(cy - 1), _PROJ_LIGHT)

	_outline(img, _PROJ_OUTLINE)
	return img


# ---------------------------------------------------------------------------
# Efeito de impacto genérico (Checkpoint D2 — asset pack) — arte padrão do AnimatedSprite2D de
# DeathEffect (game/scenes/effects/DeathEffect.tscn), usada sempre que
# `set_death_sprite_frames()` NÃO é chamado (impacto de projétil, chegada de inimigo ao ninho) —
# a passagem de sprite de uma criatura de verdade (morte do BasicEnemy) continua sobrescrevendo
# isto normalmente, sem mudança nenhuma nesse mecanismo (ver death_effect.gd).
# ---------------------------------------------------------------------------

const _IMPACT_W := 24
const _IMPACT_H := 24

const _IMPACT_CORE := Color8(255, 246, 214)
const _IMPACT_BASE := Color8(255, 210, 120)
const _IMPACT_EDGE := Color8(214, 130, 40)


func _new_impact_canvas() -> Image:
	var img := Image.create_empty(_IMPACT_W, _IMPACT_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _generate_impact_effect() -> void:
	# 4 frames, não faz loop — um "pop" rápido: núcleo pequeno → estica os raios → pico → some.
	_save(_draw_impact(0.3, 0.5), "res://assets/effects/impact_0.png")
	_save(_draw_impact(0.6, 1.0), "res://assets/effects/impact_1.png")
	_save(_draw_impact(1.0, 0.7), "res://assets/effects/impact_2.png")
	_save(_draw_impact(0.5, 0.25), "res://assets/effects/impact_3.png")


## `core_scale`: tamanho do núcleo brilhante. `ray_length`: comprimento dos raios que se espalham
## (0 = nenhum raio visível, 1 = comprimento máximo) — as duas dimensões mudam juntas por frame,
## nunca é só uma cor diferente por cima do mesmo desenho.
func _draw_impact(core_scale: float, ray_length: float) -> Image:
	var img := _new_impact_canvas()
	var cx := 12.0
	var cy := 12.0

	_fill_ellipse(img, cx, cy, 5.5 * core_scale, 5.5 * core_scale, _IMPACT_EDGE)
	_fill_ellipse(img, cx, cy, 3.8 * core_scale, 3.8 * core_scale, _IMPACT_BASE)
	_fill_ellipse(img, cx, cy, 1.8 * core_scale, 1.8 * core_scale, _IMPACT_CORE)

	# `tip_dist` máximo (ray_length=1.0) = 9.5, dentro do canvas 24×24 (raio útil ~9.5 a partir do
	# centro em 12,12, folga de ~2.5px) — bug real encontrado por `egg_projectile_assets_tests.gd`:
	# a fórmula original ia a 14px de distância do centro, quase o dobro do raio disponível.
	var tip_dist := 2.5 + 7.0 * ray_length
	if ray_length > 0.05:
		var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
			Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]
		for dir in dirs:
			var tip: Vector2 = Vector2(cx, cy) + dir * tip_dist
			_fill_thick_line(img, Vector2(cx, cy) + dir * 2.5, tip, 1.1, _IMPACT_BASE)

	return img


# ---------------------------------------------------------------------------
# Efeito de spawn (Checkpoint E — asset pack) — arte de `SpawnEffect.tscn`
# (`scripts/visuals/spawn_effect.gd`), instanciado por `EnemySpawner.spawn_enemy()` como irmão do
# `BasicEnemy` recém-criado. Poeira/terra levantando do chão (tema pré-histórico — o inimigo
# "emerge" do próprio terreno) em vez de um flash de luz (isso já é a linguagem do impacto, ver
# `_draw_impact()` acima — precisa ser visualmente distinto para não parecer o mesmo efeito
# reaproveitado sem necessidade). Paleta terrosa, puxando pra a mesma família de cor da trilha
# (`_PATH_*`) — reforça "isto é terra/poeira", não uma cor nova inventada sem relação com o resto.
# ---------------------------------------------------------------------------

const _SPAWN_W := 24
const _SPAWN_H := 24

const _SPAWN_DUST_DARK := Color8(112, 86, 50)
const _SPAWN_DUST_BASE := Color8(150, 118, 72)
const _SPAWN_DUST_LIGHT := Color8(196, 168, 122)


func _new_spawn_canvas() -> Image:
	var img := Image.create_empty(_SPAWN_W, _SPAWN_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _generate_spawn_effect() -> void:
	# 4 frames, não faz loop — poeira sobe e se dispersa: puffs pequenos e escuros perto do chão →
	# maiores e subindo → pico disperso e mais claro (poeira fina) → poucos remanescentes clareando
	# antes de sumir. Nunca é só uma cor diferente por cima do mesmo desenho — a posição/tamanho de
	# cada puff muda de verdade por frame.
	_save(_draw_spawn_dust(0.35, 0.1, _SPAWN_DUST_DARK), "res://assets/effects/spawn_0.png")
	_save(_draw_spawn_dust(0.7, 0.4, _SPAWN_DUST_BASE), "res://assets/effects/spawn_1.png")
	_save(_draw_spawn_dust(1.0, 0.8, _SPAWN_DUST_BASE), "res://assets/effects/spawn_2.png")
	_save(_draw_spawn_dust(0.5, 1.0, _SPAWN_DUST_LIGHT), "res://assets/effects/spawn_3.png")


## `spread`: o quão espalhados os puffs estão (0 = agrupados no centro, 1 = espalhados e subindo).
## `rise`: deslocamento vertical para cima (poeira subindo com o tempo). `tone`: cor predominante
## do frame (escurece perto do chão, clareia conforme dispersa — poeira fina reflete mais luz).
func _draw_spawn_dust(spread: float, rise: float, tone: Color) -> Image:
	var img := _new_spawn_canvas()
	var cx := 12.0
	var cy := 16.0  # perto da base do canvas — a poeira sobe do "chão", não do centro

	_fill_ellipse(img, cx, 20, 7.0 * (1.0 - rise * 0.3), 1.8, Color(0.08, 0.06, 0.04, 0.35))

	# Multiplicadores de offset/subida/raio reduzidos com folga real (não só o mínimo que cabia) —
	# bug real encontrado por `spawn_effect_assets_tests.gd`: a primeira versão (offset×7, subida×8,
	# raio até 3.8) colocava pixels opacos bem na borda do canvas de 24×24 em spawn_2.png (o frame
	# de pico, mais espalhado). Confirmado pelo teste automatizado, não por inspeção visual.
	var offsets := [Vector2(0, 0), Vector2(-1, -0.3), Vector2(1, -0.2), Vector2(-0.4, -0.8), Vector2(0.6, -0.6)]
	var puff_count := 2 + int(round(spread * 3.0))
	for i in range(puff_count):
		var offset: Vector2 = offsets[i % offsets.size()]
		var puff_pos := Vector2(cx, cy) + offset * (1.6 + spread * 3.6) + Vector2(0, -rise * 5.5)
		var puff_r := 1.9 + spread * 1.1 - float(i) * 0.12
		_fill_ellipse(img, puff_pos.x, puff_pos.y, puff_r, puff_r * 0.85, tone)

	_outline(img, _SPAWN_DUST_DARK)
	return img
