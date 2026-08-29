class_name Fusion
extends RefCounted
## Regra de fusão (Sprint 1, Etapa 5): duas DinosaurDefinition da MESMA espécie e MESMO tier
## (tier < 3) produzem a definição do próximo tier. Puramente funcional — não conhece Dinosaur,
## Cell nem Grid, só compara dados e devolve uma resposta, sem efeito colateral (mesmo espírito
## de Targeting: recebe dados, devolve resultado). Quem manipula a árvore de cena/grid a partir
## do resultado é PlacementController.try_fuse() — mesmo dono da instanciação de Dinosaur que já
## existe para o placement normal.
##
## Orientado por dados, não por espécie: não existe nenhum "if species_id == 'velociraptor'"
## aqui, nem em PlacementController. O próximo tier vem de
## `DinosaurDefinition.evolves_to` (Etapa 5) — um campo apontando direto para o `.tres` do
## próximo tier. Uma espécie nova só precisa preencher esse campo nos próprios `.tres` para
## participar da fusão, sem tocar neste arquivo.


## `species_id` vazio (`&""`) é a marca da espécie legada (Velociraptor procedural, sem tier —
## ver Cell/DinosaurDefinition) e nunca funde, mesmo contra si mesma — evita a fusão "funcionar
## por acaso" entre duas instâncias legadas só porque ambas têm `species_id == &""` e
## `tier == 1`, o que não faz sentido nenhum (não são a mesma espécie real, só compartilham um
## default).
static func can_fuse(a: DinosaurDefinition, b: DinosaurDefinition) -> bool:
	if a == null or b == null:
		return false
	if a.species_id == &"" or b.species_id == &"":
		return false
	if a.species_id != b.species_id:
		return false
	if a.tier != b.tier:
		return false
	if a.evolves_to == null:
		return false  # cobre tier 3 (nunca tem evolves_to) e qualquer tier sem próximo tier definido ainda
	return true


## `null` se `can_fuse()` for falso — chamador não precisa checar can_fuse() antes, só tratar
## `null` como "não pode fundir" (mesmo padrão de Targeting.select_target() podendo devolver null).
static func resulting_definition(a: DinosaurDefinition, b: DinosaurDefinition) -> DinosaurDefinition:
	if not can_fuse(a, b):
		return null
	return a.evolves_to
