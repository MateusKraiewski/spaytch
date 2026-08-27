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
