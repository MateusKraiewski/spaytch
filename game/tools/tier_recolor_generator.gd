extends SceneTree
## Ferramenta descartável (mesmo espírito das outras em game/tools/, ver pixel_art_generator.gd) —
## V2, Sprint "Tiers completos": gera T2/T3 de Triceratops e T-Rex por RECOLOR PROCEDURAL do T1 já
## aprovado, em vez de gerar arte nova no PixelLab. Decisão explícita do usuário (orçamento
## PixelLab quase esgotado nesta sessão — 16 gerações restantes de um trial de 40 — "tudo
## procedural, zero geração nova").
##
## Não é um recolor arbitrário: T2 fica mais rico/saturado (mesma silhueta, paleta "carregada" —
## sinal visual de progressão); T3 puxa a paleta pra família ciano/azul da própria AuraEffect
## (`aura_t3_0-3.png`, tom ~195°) — a criatura T3 passa a visualmente "pertencer" à aura que ela
## ganha (`DinosaurDefinition.has_aura()`), em vez de ser só "T1 mais escuro". Luminância (o `v` do
## HSV) é preservada/levemente realçada, não recalculada do zero — a silhueta e a leitura de forma
## (sombra/luz já desenhadas à mão no T1) continuam intactas, só a matiz/saturação mudam.
##
## Executar com:
##   godot --headless --path game --script res://tools/tier_recolor_generator.gd

## anims: nome da animação -> quantidade de frames (0..N-1). Triceratops T1 tem as 4 animações
## completas (Sprint 1); T-Rex T1 só tem a pose "idle" (nenhuma animação foi gerada ainda para essa
## espécie) — o recolor herda exatamente essa mesma cobertura, não inventa frames que não existem.
const _SPECIES := [
	{"name": "triceratops", "anims": {"idle": 17, "move": 6, "attack": 7, "hit": 9}},
	{"name": "trex", "anims": {"idle": 1}},
]

const _AURA_HUE := 195.0 / 360.0  ## mesma família de cor de AuraEffect (aura_t3_*.png)


func _initialize() -> void:
	for species in _SPECIES:
		for tier in [2, 3]:
			_recolor_species_tier(species["name"], species["anims"], tier)
	print("[tier_recolor_generator] done")
	quit(0)


func _recolor_species_tier(species_name: String, anims: Dictionary, tier: int) -> void:
	var src_dir := "res://assets/dinosaurs/%s_t1/" % species_name
	var dst_dir := "res://assets/dinosaurs/%s_t%d/" % [species_name, tier]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst_dir))

	for anim_name in anims.keys():
		var count: int = anims[anim_name]
		for i in range(count):
			var src_path := "%s%s_%d.png" % [src_dir, anim_name, i]
			var img := Image.load_from_file(src_path)
			if img == null:
				printerr("[tier_recolor_generator] FAILED to load %s" % src_path)
				continue
			_recolor_image(img, tier)
			var dst_path := "%s%s_%d.png" % [dst_dir, anim_name, i]
			var err := img.save_png(dst_path)
			if err != OK:
				printerr("[tier_recolor_generator] FAILED to save %s: %d" % [dst_path, err])
			else:
				print("[tier_recolor_generator] saved %s" % dst_path)


func _recolor_image(img: Image, tier: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a <= 0.001:
				continue  # nunca reescreve pixel transparente (preserva a silhueta exata)
			img.set_pixel(x, y, _shift_color(c, tier))


## Multiplicar `s`/`v` (1ª versão desta função) ficou quase imperceptível em cima da paleta já
## bem dessaturada do T1 (verificado visualmente, não só por leitura de código — ver decisão do
## usuário "não invente, verifique"). Troca pra um BLEND real em direção a uma matiz/saturação-
## alvo (não uma multiplicação do que já existe): `v` continua só multiplicado, então contorno e
## sombra (quase pretos, `v`≈0) permanecem quase pretos — só o meio-tom/luz da pele muda de cor de
## verdade, a silhueta e o volume desenhados à mão no T1 continuam legíveis.
func _shift_color(c: Color, tier: int) -> Color:
	var target_hue: float
	var target_sat: float
	var hue_blend: float
	var sat_blend: float
	var value_mult: float
	if tier == 2:
		target_hue = 45.0 / 360.0  # dourado/âmbar — "carregado", ainda claramente da mesma família terrosa do T1
		target_sat = 0.75
		hue_blend = 0.55
		sat_blend = 0.6
		value_mult = 1.1
	else:
		target_hue = _AURA_HUE  # ciano/azul da própria AuraEffect — T3 "pertence" à aura que ganha
		target_sat = 0.85
		hue_blend = 0.75
		sat_blend = 0.75
		value_mult = 1.2

	var new_h := fmod(lerp_angle(c.h * TAU, target_hue * TAU, hue_blend) / TAU + 1.0, 1.0)
	var new_s := clampf(lerp(c.s, target_sat, sat_blend), 0.0, 1.0)
	var new_v := clampf(c.v * value_mult, 0.0, 1.0)
	return Color.from_hsv(new_h, new_s, new_v, c.a)
