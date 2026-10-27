extends "res://tests/generation_tests.gd"

func run() -> void:
	var generator := BattlefieldGenerator.new()
	root.add_child(generator)
	for settings in EncounterOptions.presets():
		for objective in EncounterOptions.objectives():
			for count in [2,3,4]:
				var config := EncounterConfiguration.new()
				config.battlefield_seed=734
				config.generator_settings=settings.duplicate(true)
				config.objective=objective
				while config.enemies.size()<count:
					config.enemies.append(config.enemies[0].duplicate(true))
				var encounter := await prepare(config)
				check(encounter.navigation_ready,"%s/%s/%d prepares navigation" % [settings.preset_id,objective.stable_id,count])
				if encounter.navigation_ready:
					var layout := config.layout
					check(layout.spawns.size()==count+2,"Each roster has sufficient reserved spawns")
					var repeated := generator.make_layout(734,settings,layout.attempt,layout.used_fallback,objective,count)
					check(repeated!=null and repeated.signature()==layout.signature(),"Seed reproduces variable roster positions")
					var legacy := generator.make_layout(734,settings,layout.attempt,layout.used_fallback,objective)
					check(legacy!=null and legacy.spawns==layout.spawns.slice(0,4) and legacy.obstacle_centers==layout.obstacle_centers and legacy.obstacle_sizes==layout.obstacle_sizes,"Extra spawns preserve original four and obstacle sequence")
					var controller := encounter.get_node("CombatController") as CombatController
					check(controller.units.size()==count+2,"Every opponent is spawned")
					for index in range(count):
						var unit := controller.find_unit("enemy-%02d" % (index+1))
						check(unit!=null and unit.definition!=config.enemies[index] and unit.position==layout.spawns[index+2],"Stable enemy IDs, adjusted definition copies and positions")
					var snapshot := config.snapshot() as EncounterConfiguration
					check(snapshot.layout.signature()==layout.signature(),"Snapshot keeps exact retry positions")
				await dispose(encounter)
	var cramped := BattlefieldSettings.new()
	cramped.spawn_spacing=4
	check(generator.make_layout(99,cramped,1,false,null,4)==null,"Insufficient reserved capacity rejects bounded attempt")
	var safe := generator.make_layout(99,cramped,4,true,null,4)
	check(safe!=null and safe.spawns.size()==6,"Canonical fallback reserves capacity for four enemies")
	check(generator.make_layout(99,cramped,1,false,null,5)==null,"Unsupported enemy capacity is rejected")
	var fallback_config := EncounterConfiguration.new()
	fallback_config.generator_settings=cramped
	fallback_config.generator_settings.generation_attempts=1
	while fallback_config.enemies.size()<4:
		fallback_config.enemies.append(fallback_config.enemies[0].duplicate(true))
	var fallback_encounter := await prepare(fallback_config)
	check(fallback_encounter.navigation_ready and fallback_config.layout.used_fallback,"Capacity fallback passes baked navigation with original custom settings")
	var retry_config := fallback_config.snapshot() as EncounterConfiguration
	var saved_signature := retry_config.layout.signature() if retry_config.layout!=null else ""
	await dispose(fallback_encounter)
	var retry := await prepare(retry_config)
	check(retry.navigation_ready and retry_config.layout.signature()==saved_signature,"Cached Retry keeps exact six-spawn battlefield")
	await dispose(retry)
	generator.queue_free()
	print("FACTION SPAWN RESULT: %d failures" % failures)
	quit(1 if failures else 0)

