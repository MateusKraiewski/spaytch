extends SceneTree
## Ferramenta de pipeline (não faz parte do jogo em runtime) — constrói os recursos `SpriteFrames`
## (.tres) a partir dos PNGs já gerados por pixel_art_generator.gd. Precisa rodar DEPOIS de um
## `godot --headless --editor --quit` (que importa os PNGs novos — gera o `.import`/UID que
## `load()` exige), senão os `load()` abaixo falham.
##
## Animações nomeadas exatamente como os estados de AnimatedVisual.State (minúsculo) — é assim
## que AnimatedVisual.play_state() decide usar o AnimatedSprite2D em vez do fallback procedural
## (ver scripts/visuals/animated_visual.gd). ATTACK/HIT não fazem loop (reação de um tiro só,
## AnimatedVisual volta sozinho ao loop anterior ao terminar — ver o reforço desta etapa em
## animated_visual.gd). IDLE/MOVE fazem loop.
##
## Executar com:
##   godot --headless --path game --script res://tools/build_sprite_frames.gd

func _initialize() -> void:
	_build_velociraptor()
	_build_basic_enemy()
	_build_egg()
	_build_projectile()
	_build_impact_effect()
	_build_spawn_effect()
	_build_aura_t3()
	_build_velociraptor_t1()
	_build_velociraptor_t2()
	_build_velociraptor_t3()
	_build_triceratops_t1()
	_build_triceratops_t2()
	_build_triceratops_t3()
	_build_trex_t1()
	_build_trex_t2()
	_build_trex_t3()
	quit(0)


func _build_velociraptor() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_animation(frames, "idle", [
		"res://assets/dinosaurs/velociraptor/idle_0.png",
		"res://assets/dinosaurs/velociraptor/idle_1.png",
		"res://assets/dinosaurs/velociraptor/idle_2.png",
		"res://assets/dinosaurs/velociraptor/idle_3.png",
	], 4.0, true)

	# MOVE preparado para reutilização futura da infraestrutura visual — Dinosaur.gd não chama
	# play_state(MOVE) hoje (a torre não anda), ver Checkpoint B do relatório/ARCHITECTURE.md.
	_add_animation(frames, "move", [
		"res://assets/dinosaurs/velociraptor/move_0.png",
		"res://assets/dinosaurs/velociraptor/move_1.png",
		"res://assets/dinosaurs/velociraptor/move_2.png",
		"res://assets/dinosaurs/velociraptor/move_3.png",
		"res://assets/dinosaurs/velociraptor/move_4.png",
		"res://assets/dinosaurs/velociraptor/move_5.png",
	], 10.0, true)

	_add_animation(frames, "attack", [
		"res://assets/dinosaurs/velociraptor/attack_0.png",
		"res://assets/dinosaurs/velociraptor/attack_1.png",
		"res://assets/dinosaurs/velociraptor/attack_2.png",
		"res://assets/dinosaurs/velociraptor/attack_3.png",
		"res://assets/dinosaurs/velociraptor/attack_4.png",
		"res://assets/dinosaurs/velociraptor/attack_5.png",
	], 14.0, false)

	# HIT preparado sem dependência de gameplay nova — a torre não recebe dano hoje.
	_add_animation(frames, "hit", [
		"res://assets/dinosaurs/velociraptor/hit_0.png",
		"res://assets/dinosaurs/velociraptor/hit_1.png",
		"res://assets/dinosaurs/velociraptor/hit_2.png",
	], 10.0, false)

	_save(frames, "res://data/dinosaurs/velociraptor_sprite_frames.tres")


func _build_basic_enemy() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_animation(frames, "move", [
		"res://assets/enemies/basic_enemy/move_0.png",
		"res://assets/enemies/basic_enemy/move_1.png",
		"res://assets/enemies/basic_enemy/move_2.png",
		"res://assets/enemies/basic_enemy/move_3.png",
		"res://assets/enemies/basic_enemy/move_4.png",
		"res://assets/enemies/basic_enemy/move_5.png",
	], 10.0, true)

	_add_animation(frames, "hit", [
		"res://assets/enemies/basic_enemy/hit_0.png",
		"res://assets/enemies/basic_enemy/hit_1.png",
		"res://assets/enemies/basic_enemy/hit_2.png",
	], 12.0, false)

	# fps = 15 para 6 frames caberem exatamente nos 0.4s de DeathEffect._LIFETIME (fixo, não
	# alterado nesta etapa) — mesma relação já usada na versão de 2 frames (5.0fps × 2 = 0.4s);
	# sem isto o efeito seria destruído antes da animação terminar de tocar.
	_add_animation(frames, "death", [
		"res://assets/enemies/basic_enemy/death_0.png",
		"res://assets/enemies/basic_enemy/death_1.png",
		"res://assets/enemies/basic_enemy/death_2.png",
		"res://assets/enemies/basic_enemy/death_3.png",
		"res://assets/enemies/basic_enemy/death_4.png",
		"res://assets/enemies/basic_enemy/death_5.png",
	], 15.0, false)

	_save(frames, "res://data/enemies/basic_enemy_sprite_frames.tres")


func _build_egg() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# IDLE = saudável (egg.gd escolhe por fração de HP) — respiração bem lenta e sutil.
	_add_animation(frames, "idle", [
		"res://assets/eggs/idle_0.png",
		"res://assets/eggs/idle_1.png",
		"res://assets/eggs/idle_2.png",
		"res://assets/eggs/idle_3.png",
	], 2.0, true)

	# MOVE = crítico/ferido (mesmo estado que egg.gd já usa como "pulso de urgência" — nome do
	# estado é interno a AnimatedVisual, nunca aparece como texto para o jogador), mais agitado.
	_add_animation(frames, "move", [
		"res://assets/eggs/move_0.png",
		"res://assets/eggs/move_1.png",
		"res://assets/eggs/move_2.png",
		"res://assets/eggs/move_3.png",
	], 6.0, true)

	_add_animation(frames, "hit", [
		"res://assets/eggs/hit_0.png",
		"res://assets/eggs/hit_1.png",
		"res://assets/eggs/hit_2.png",
	], 10.0, false)

	# DEATH = destruído — congela no último frame para sempre (loop=false; diferente de
	# BasicEnemy/DeathEffect, o próprio Egg nunca é removido da árvore, então não há timer de
	# lifetime a respeitar aqui — a duração só precisa "parecer" uma quebra rápida e definitiva).
	_add_animation(frames, "death", [
		"res://assets/eggs/death_0.png",
		"res://assets/eggs/death_1.png",
		"res://assets/eggs/death_2.png",
		"res://assets/eggs/death_3.png",
		"res://assets/eggs/death_4.png",
	], 6.0, false)

	_save(frames, "res://data/eggs/egg_sprite_frames.tres")


func _build_projectile() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Único estado usado por projectile.gd — sem move/attack/hit/death (nunca chamados).
	_add_animation(frames, "idle", [
		"res://assets/projectiles/idle_0.png",
		"res://assets/projectiles/idle_1.png",
		"res://assets/projectiles/idle_2.png",
		"res://assets/projectiles/idle_3.png",
	], 8.0, true)

	_save(frames, "res://data/projectiles/projectile_sprite_frames.tres")


## Arte PADRÃO do AnimatedSprite2D de DeathEffect (usada quando `set_death_sprite_frames()` não é
## chamado — impacto de projétil, chegada de inimigo ao ninho). Uma morte de verdade (BasicEnemy)
## continua sobrescrevendo isto via passthrough, sem mudança nesse mecanismo.
func _build_impact_effect() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# fps = 10 para 4 frames caberem exatamente nos 0.4s de DeathEffect._LIFETIME (mesma relação
	# já usada para o death do BasicEnemy — 15fps × 6 frames = 0.4s).
	_add_animation(frames, "death", [
		"res://assets/effects/impact_0.png",
		"res://assets/effects/impact_1.png",
		"res://assets/effects/impact_2.png",
		"res://assets/effects/impact_3.png",
	], 10.0, false)

	_save(frames, "res://data/effects/impact_sprite_frames.tres")


## Arte de `SpawnEffect.tscn` (Checkpoint E) — poeira subindo do chão no instante em que um
## BasicEnemy nasce no SPAWN. `SpawnEffect._LIFETIME = 0.35`; fps = 4/0.35 ≈ 11.43 não seria um
## número limpo, então 4 frames a 11fps (≈0.364s) fica próximo o bastante do lifetime sem precisar
## de um valor fracionário estranho — a diferença (~14ms) é imperceptível e o node se autodestrói
## de qualquer forma quando o timer dispara, mesmo que o último frame não tenha chego a trocar.
func _build_spawn_effect() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_animation(frames, "death", [
		"res://assets/effects/spawn_0.png",
		"res://assets/effects/spawn_1.png",
		"res://assets/effects/spawn_2.png",
		"res://assets/effects/spawn_3.png",
	], 11.0, false)

	_save(frames, "res://data/effects/spawn_sprite_frames.tres")


## Arte de `AuraEffect.tscn` (Sprint 1 — aura do Velociraptor T3). Animação nomeada "idle" de
## propósito — reaproveita o contrato de loop contínuo que AnimatedVisual.State.IDLE já tem (ver
## aura_effect.gd), o mesmo raciocínio de DeathEffect/SpawnEffect reaproveitando State.DEATH para o
## contrato oposto (um tiro só). fps baixo — é um efeito ambiente, contínuo, não uma reação rápida.
func _build_aura_t3() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_animation(frames, "idle", [
		"res://assets/effects/aura_t3_0.png",
		"res://assets/effects/aura_t3_1.png",
		"res://assets/effects/aura_t3_2.png",
		"res://assets/effects/aura_t3_3.png",
	], 6.0, true)

	_save(frames, "res://data/effects/aura_t3_sprite_frames.tres")


## Velociraptor T1 aprovado (pipeline PixelLab, Sprint 1) — arte definitiva desta tier, com as 4
## animações completas. Pasta própria (`velociraptor_t1/`) para não sobrescrever nem depender do
## Velociraptor procedural antigo (`velociraptor/`, Checkpoints A-F), que continua intacto e
## referenciado por `velociraptor_sprite_frames.tres` como estava.
func _build_velociraptor_t1() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_animation(frames, "idle", [
		"res://assets/dinosaurs/velociraptor_t1/idle_0.png",
		"res://assets/dinosaurs/velociraptor_t1/idle_1.png",
		"res://assets/dinosaurs/velociraptor_t1/idle_2.png",
		"res://assets/dinosaurs/velociraptor_t1/idle_3.png",
	], 4.0, true)

	_add_animation(frames, "move", [
		"res://assets/dinosaurs/velociraptor_t1/move_0.png",
		"res://assets/dinosaurs/velociraptor_t1/move_1.png",
		"res://assets/dinosaurs/velociraptor_t1/move_2.png",
		"res://assets/dinosaurs/velociraptor_t1/move_3.png",
		"res://assets/dinosaurs/velociraptor_t1/move_4.png",
		"res://assets/dinosaurs/velociraptor_t1/move_5.png",
	], 8.0, true)

	_add_animation(frames, "attack", [
		"res://assets/dinosaurs/velociraptor_t1/attack_0.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_1.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_2.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_3.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_4.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_5.png",
		"res://assets/dinosaurs/velociraptor_t1/attack_6.png",
	], 12.0, false)

	_add_animation(frames, "hit", [
		"res://assets/dinosaurs/velociraptor_t1/hit_0.png",
		"res://assets/dinosaurs/velociraptor_t1/hit_1.png",
		"res://assets/dinosaurs/velociraptor_t1/hit_2.png",
		"res://assets/dinosaurs/velociraptor_t1/hit_3.png",
		"res://assets/dinosaurs/velociraptor_t1/hit_4.png",
	], 10.0, false)

	_save(frames, "res://data/dinosaurs/velociraptor_t1_sprite_frames.tres")


## Velociraptor T2/T3 aprovados — só a pose base (nenhuma animação foi gerada ainda para estas
## tiers, ver relatório da Etapa 1). Um único frame em "idle" é uma SpriteFrames válida (o
## AnimatedSprite2D mostra a pose parada) — não é um placeholder quebrado, é exatamente o que foi
## aprovado até agora; animações completas ficam para quando forem geradas.
func _build_velociraptor_t2() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", ["res://assets/dinosaurs/velociraptor_t2/idle_0.png"], 1.0, true)
	_save(frames, "res://data/dinosaurs/velociraptor_t2_sprite_frames.tres")


func _build_velociraptor_t3() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", ["res://assets/dinosaurs/velociraptor_t3/idle_0.png"], 1.0, true)
	_save(frames, "res://data/dinosaurs/velociraptor_t3_sprite_frames.tres")


## Triceratops T1 aprovado — Idle já com a correção dos 3 chifres (rastreada frame a frame, ver
## Sprint 1). Move/Attack/Hit existem e foram aceitos "como estão" (paleta corrigida, mas ainda
## com 1 chifre só) — não são um erro desta etapa, é o estado aprovado.
func _build_triceratops_t1() -> void:
	_build_triceratops_frames("triceratops_t1", "res://data/dinosaurs/triceratops_t1_sprite_frames.tres")


## V2 — T2/T3 de Triceratops via recolor procedural do T1 (ver tools/tier_recolor_generator.gd;
## decisão do usuário: orçamento PixelLab quase esgotado, "tudo procedural, zero geração nova").
## Mesma estrutura de animação do T1 (17 idle / 6 move / 7 attack / 9 hit) — o recolor herda a
## cobertura exata do T1, não inventa frame novo nenhum, só reaproveita a função acima com outra
## pasta de origem.
func _build_triceratops_t2() -> void:
	_build_triceratops_frames("triceratops_t2", "res://data/dinosaurs/triceratops_t2_sprite_frames.tres")


func _build_triceratops_t3() -> void:
	_build_triceratops_frames("triceratops_t3", "res://data/dinosaurs/triceratops_t3_sprite_frames.tres")


func _build_triceratops_frames(asset_dir: StringName, output_path: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var idle_paths: Array[String] = []
	for i in range(17):
		idle_paths.append("res://assets/dinosaurs/%s/idle_%d.png" % [asset_dir, i])
	_add_animation(frames, "idle", idle_paths, 8.0, true)

	var move_paths: Array[String] = []
	for i in range(6):
		move_paths.append("res://assets/dinosaurs/%s/move_%d.png" % [asset_dir, i])
	_add_animation(frames, "move", move_paths, 8.0, true)

	var attack_paths: Array[String] = []
	for i in range(7):
		attack_paths.append("res://assets/dinosaurs/%s/attack_%d.png" % [asset_dir, i])
	_add_animation(frames, "attack", attack_paths, 10.0, false)

	var hit_paths: Array[String] = []
	for i in range(9):
		hit_paths.append("res://assets/dinosaurs/%s/hit_%d.png" % [asset_dir, i])
	_add_animation(frames, "hit", hit_paths, 10.0, false)

	_save(frames, output_path)


## T-Rex T1 aprovado — só a pose base corrigida (cauda + braços vestigiais), nenhuma animação
## gerada ainda.
func _build_trex_t1() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", ["res://assets/dinosaurs/trex_t1/idle_0.png"], 1.0, true)
	_save(frames, "res://data/dinosaurs/trex_t1_sprite_frames.tres")


## V2 — T2/T3 de T-Rex via recolor procedural do T1 (mesma decisão/ferramenta do Triceratops
## acima). T1 só tem a pose "idle" — o recolor herda exatamente essa cobertura.
func _build_trex_t2() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", ["res://assets/dinosaurs/trex_t2/idle_0.png"], 1.0, true)
	_save(frames, "res://data/dinosaurs/trex_t2_sprite_frames.tres")


func _build_trex_t3() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "idle", ["res://assets/dinosaurs/trex_t3/idle_0.png"], 1.0, true)
	_save(frames, "res://data/dinosaurs/trex_t3_sprite_frames.tres")


func _add_animation(frames: SpriteFrames, anim_name: StringName, texture_paths: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for path in texture_paths:
		var texture := load(path) as Texture2D
		if texture == null:
			printerr("[build_sprite_frames] FAILED to load %s (rode --editor --quit antes?)" % path)
			continue
		frames.add_frame(anim_name, texture)


func _save(frames: SpriteFrames, path: String) -> void:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := ResourceSaver.save(frames, path)
	if err != OK:
		printerr("[build_sprite_frames] FAILED to save %s: %d" % [path, err])
	else:
		print("[build_sprite_frames] saved %s" % path)
