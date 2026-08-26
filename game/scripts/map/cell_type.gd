class_name CellType
extends RefCounted
## Taxonomia fechada de tipos de célula da grid.
##
## Escolhido como enum (em vez de Resource por tipo) porque os tipos de célula
## formam um conjunto pequeno e fixo, usado para comparações/branches frequentes
## em vários sistemas (render de debug, input, futuras regras de gameplay).
## Um Resource por tipo só se justificaria se cada tipo precisasse de dados ricos
## e configuráveis próprios — isso pode ser adicionado depois (ex: CellTypeInfo)
## sem quebrar esta base, caso vire necessário.

enum {
	EMPTY,
	PATH,
	BUILDABLE,
	EGG,
	OBSTACLE,
	SPAWN,
	NEST,
}

const NAMES := {
	EMPTY: "EMPTY",
	PATH: "PATH",
	BUILDABLE: "BUILDABLE",
	EGG: "EGG",
	OBSTACLE: "OBSTACLE",
	SPAWN: "SPAWN",
	NEST: "NEST",
}


static func name_of(type: int) -> String:
	return NAMES.get(type, "UNKNOWN(%d)" % type)
