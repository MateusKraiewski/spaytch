extends SceneTree
## Ferramenta de pipeline (não faz parte do jogo em runtime, mesmo espírito de
## build_sprite_frames.gd/pixel_art_generator.gd) — V2, expansão de mapas: converte um layout
## ASCII (mesma legenda já usada em docs/ARCHITECTURE.md: `.`=EMPTY `B`=BUILDABLE `P`=PATH
## `E`=EGG `O`=OBSTACLE `S`=SPAWN `N`=NEST) num `MapDefinition` real, valida com
## `MapValidator.validate()` E `MapPath.build()` (a checagem mais estrita — rejeita bifurcação/
## célula solta, que `MapValidator` sozinho não pega) ANTES de salvar. Um mapa com erro de
## transcrição nunca chega a virar `.tres` — o erro aparece no console, não em produção.
##
## Executar com:
##   godot --headless --path game --script res://tools/map_builder.gd

const _CHAR_TO_TYPE := {
	".": CellType.EMPTY,
	"B": CellType.BUILDABLE,
	"P": CellType.PATH,
	"E": CellType.EGG,
	"O": CellType.OBSTACLE,
	"S": CellType.SPAWN,
	"N": CellType.NEST,
}


func _initialize() -> void:
	_build_map("trilha_sinuosa", [
		"..............",
		".BBBB...BBBB..",
		"SPPPP...PPPPN.",
		"....P...P.....",
		"....P...P.....",
		"....PPPPP.....",
		"....BBBBB.....",
		"....EE..EE....",
	])

	_build_map("delta_verdejante", [
		"..............",
		".BBBBBBBBBBB..",
		".BBBBBBBBBBB..",
		"SPPPPPPPPPPP..",
		".BBBBBBBBBBP..",
		".BBBBBBBBBBP..",
		"...........PN.",
		"............EE",
	])

	quit(0)


func _build_map(map_name: String, rows: Array) -> void:
	var height := rows.size()
	var width: int = rows[0].length()
	for row in rows:
		assert(row.length() == width, "[map_builder] '%s': todas as linhas precisam ter o mesmo comprimento" % map_name)

	var cells := PackedInt32Array()
	cells.resize(width * height)
	for y in range(height):
		var row: String = rows[y]
		for x in range(width):
			var ch := row[x]
			assert(_CHAR_TO_TYPE.has(ch), "[map_builder] '%s': caractere desconhecido '%s' em (%d,%d)" % [map_name, ch, x, y])
			cells[y * width + x] = _CHAR_TO_TYPE[ch]

	var definition := MapDefinition.new()
	definition.width = width
	definition.height = height
	definition.tile_size = 32
	definition.cells = cells

	var errors := MapValidator.validate(definition)
	if not errors.is_empty():
		printerr("[map_builder] '%s' FALHOU em MapValidator:" % map_name)
		for error in errors:
			printerr("  - %s" % error)
		return

	var path := MapPath.build(definition)
	if path == null:
		printerr("[map_builder] '%s' FALHOU em MapPath.build() — path com bifurcação, loop, ou célula PATH solta." % map_name)
		return

	var save_path := "res://data/maps/%s.tres" % map_name
	var err := ResourceSaver.save(definition, save_path)
	if err != OK:
		printerr("[map_builder] FAILED to save %s: %d" % [save_path, err])
	else:
		print("[map_builder] '%s' válido (%d waypoints) — salvo em %s" % [map_name, path.waypoints.size(), save_path])
