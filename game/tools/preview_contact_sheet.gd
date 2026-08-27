extends SceneTree
## Ferramenta de revisão (não faz parte do jogo): amplia (nearest-neighbor, sem suavizar) todos os
## PNGs gerados por pixel_art_generator.gd e monta uma folha de contato única, só para inspeção
## visual durante o desenvolvimento — nunca referenciada por nenhuma cena.
##
## Executar com:
##   godot --headless --path game --script res://tools/preview_contact_sheet.gd

const SCALE := 8
const CELL := 32 * SCALE
const PADDING := 6
const COLS := 6

const PATHS := [
	"res://assets/environment/grass_01.png",
	"res://assets/environment/grass_02.png",
	"res://assets/environment/grass_03.png",
	"res://assets/environment/grass_04.png",
	"res://assets/environment/path_01.png",
	"res://assets/environment/path_02.png",
	"res://assets/environment/path_03.png",
	"res://assets/environment/path_edge_n.png",
	"res://assets/environment/path_edge_s.png",
	"res://assets/environment/path_edge_e.png",
	"res://assets/environment/path_edge_w.png",
	"res://assets/environment/bush_small.png",
	"res://assets/environment/bush_large.png",
	"res://assets/environment/tree_small.png",
	"res://assets/environment/tree_large.png",
	"res://assets/environment/rock_small.png",
	"res://assets/environment/rock_large.png",
	"res://assets/environment/rock_cluster.png",
	"res://assets/environment/stump.png",
	"res://assets/environment/flower_yellow.png",
	"res://assets/environment/flower_pink.png",
	"res://assets/environment/mushroom.png",
	"res://assets/environment/leaf.png",
	"res://assets/environment/twig.png",
	"res://assets/environment/root_detail.png",
	"res://assets/environment/grass_tuft.png",
	"res://assets/dinosaurs/velociraptor/idle_0.png",
	"res://assets/dinosaurs/velociraptor/idle_1.png",
	"res://assets/dinosaurs/velociraptor/idle_2.png",
	"res://assets/dinosaurs/velociraptor/idle_3.png",
	"res://assets/dinosaurs/velociraptor/move_0.png",
	"res://assets/dinosaurs/velociraptor/move_1.png",
	"res://assets/dinosaurs/velociraptor/move_2.png",
	"res://assets/dinosaurs/velociraptor/move_3.png",
	"res://assets/dinosaurs/velociraptor/move_4.png",
	"res://assets/dinosaurs/velociraptor/move_5.png",
	"res://assets/dinosaurs/velociraptor/attack_0.png",
	"res://assets/dinosaurs/velociraptor/attack_1.png",
	"res://assets/dinosaurs/velociraptor/attack_2.png",
	"res://assets/dinosaurs/velociraptor/attack_3.png",
	"res://assets/dinosaurs/velociraptor/attack_4.png",
	"res://assets/dinosaurs/velociraptor/attack_5.png",
	"res://assets/dinosaurs/velociraptor/hit_0.png",
	"res://assets/dinosaurs/velociraptor/hit_1.png",
	"res://assets/dinosaurs/velociraptor/hit_2.png",
	"res://assets/enemies/basic_enemy/move_0.png",
	"res://assets/enemies/basic_enemy/move_1.png",
	"res://assets/enemies/basic_enemy/move_2.png",
	"res://assets/enemies/basic_enemy/move_3.png",
	"res://assets/enemies/basic_enemy/move_4.png",
	"res://assets/enemies/basic_enemy/move_5.png",
	"res://assets/enemies/basic_enemy/hit_0.png",
	"res://assets/enemies/basic_enemy/hit_1.png",
	"res://assets/enemies/basic_enemy/hit_2.png",
	"res://assets/enemies/basic_enemy/death_0.png",
	"res://assets/enemies/basic_enemy/death_1.png",
	"res://assets/enemies/basic_enemy/death_2.png",
	"res://assets/enemies/basic_enemy/death_3.png",
	"res://assets/enemies/basic_enemy/death_4.png",
	"res://assets/enemies/basic_enemy/death_5.png",
	"res://assets/eggs/idle_0.png",
	"res://assets/eggs/idle_1.png",
	"res://assets/eggs/idle_2.png",
	"res://assets/eggs/idle_3.png",
	"res://assets/eggs/move_0.png",
	"res://assets/eggs/move_1.png",
	"res://assets/eggs/move_2.png",
	"res://assets/eggs/move_3.png",
	"res://assets/eggs/hit_0.png",
	"res://assets/eggs/hit_1.png",
	"res://assets/eggs/hit_2.png",
	"res://assets/eggs/death_0.png",
	"res://assets/eggs/death_1.png",
	"res://assets/eggs/death_2.png",
	"res://assets/eggs/death_3.png",
	"res://assets/eggs/death_4.png",
	"res://assets/projectiles/idle_0.png",
	"res://assets/projectiles/idle_1.png",
	"res://assets/projectiles/idle_2.png",
	"res://assets/projectiles/idle_3.png",
	"res://assets/effects/impact_0.png",
	"res://assets/effects/impact_1.png",
	"res://assets/effects/impact_2.png",
	"res://assets/effects/impact_3.png",
]


func _initialize() -> void:
	var rows := ceili(float(PATHS.size()) / COLS)
	var sheet_w := COLS * (CELL + PADDING) + PADDING
	var sheet_h := rows * (CELL + PADDING) + PADDING
	var sheet := Image.create_empty(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.15, 0.15, 0.17, 1.0))

	for i in range(PATHS.size()):
		var src := Image.load_from_file(ProjectSettings.globalize_path(PATHS[i]))
		if src == null:
			printerr("[preview_contact_sheet] failed to load %s" % PATHS[i])
			continue
		# Preserva a proporção original (tiras de borda não são quadradas, 32×10/10×32) em vez de
		# esticar tudo para CELLxCELL — senão a folha de contato mentiria sobre a forma real.
		var src_w := src.get_width()
		var src_h := src.get_height()
		var scaled_w := CELL if src_w >= src_h else int(CELL * float(src_w) / float(src_h))
		var scaled_h := CELL if src_h >= src_w else int(CELL * float(src_h) / float(src_w))
		src.resize(scaled_w, scaled_h, Image.INTERPOLATE_NEAREST)
		var col := i % COLS
		var row := i / COLS
		var x := PADDING + col * (CELL + PADDING) + (CELL - scaled_w) / 2
		var y := PADDING + row * (CELL + PADDING) + (CELL - scaled_h) / 2
		sheet.blend_rect(src, Rect2i(0, 0, scaled_w, scaled_h), Vector2i(x, y))

	var out_path := "res://tools/preview_contact_sheet_output.png"
	var err := sheet.save_png(out_path)
	if err != OK:
		printerr("[preview_contact_sheet] FAILED to save: %d" % err)
	else:
		print("[preview_contact_sheet] saved %s" % out_path)
	quit(0)
