extends "res://tests/generation_tests.gd"
var records: Array[Dictionary]=[]

func run() -> void:
	var generator := BattlefieldGenerator.new()
	root.add_child(generator)
	for preset in EncounterOptions.presets():
		for objective in EncounterOptions.objectives():
			for seed_value in range(1,11):
				var config := EncounterConfiguration.new()
				config.generator_settings=preset.duplicate(true) as BattlefieldSettings
				config.objective=objective
				config.battlefield_seed=seed_value
				var encounter := await prepare(config)
				check(encounter.navigation_ready,"%s/%s/%d ready"%[preset.preset_id,objective.stable_id,seed_value])
				if encounter.navigation_ready:
					completed+=1
					var layout := config.layout
					var navigation := encounter.get_node("NavigationService") as NavigationService
					check(generator.validate_objective(layout,navigation,objective),"All objective routes, gates and travel distances validated")
					rectangles(layout,preset)
					var repeat := generator.make_layout(seed_value,preset,layout.attempt,layout.used_fallback,objective)
					check(repeat!=null and repeat.signature()==layout.signature(),"Same preset/objective/version/seed reproduce geometry")
					var density := preset.duplicate(true) as BattlefieldSettings
					density.detail_density=0
					density.vegetation_density=0
					density.rubble_density=0
					check(generator.make_layout(seed_value,density,layout.attempt,layout.used_fallback,objective).signature()==layout.signature(),"Cosmetic density cannot affect layout/objective/spawns")
					if seed_value==1:
						var dressing := encounter.get_node("CourtyardDressing") as CourtyardDressing
						var replica := CourtyardDressing.new()
						root.add_child(replica)
						replica.build(layout,preset)
						check(dressing.signature()==replica.signature(),"Same seed/config reproduce dressing")
						replica.free()
					var copied := config.snapshot() as EncounterConfiguration
					check(copied.layout.signature()==layout.signature() and copied.objective.stable_id==objective.stable_id and copied.generator_settings.preset_id==preset.preset_id,"Retry snapshot retains objective/preset/layout")
					records.append({"preset":preset.preset_id,"objective":objective.stable_id,"seed":seed_value,"attempt":layout.attempt,"fallback":layout.used_fallback,"obstacles":layout.obstacle_sizes.size()})
				await dispose(encounter)
			# Exercise each preset/objective fallback explicitly with zero retries.
			var fallback_config := EncounterConfiguration.new()
			fallback_config.generator_settings=preset.duplicate(true) as BattlefieldSettings
			fallback_config.objective=objective
			fallback_config.battlefield_seed=404
			fallback_config.layout=generator.make_layout(404,preset,4,true,objective)
			var fallback := await prepare(fallback_config)
			check(fallback.navigation_ready and fallback_config.layout.used_fallback,"Preset-specific fallback remains playable")
			await dispose(fallback)
	# Deliberately invalid structural dimensions force canonical preset recovery.
	for index in range(3):
		var difficult := EncounterConfiguration.new()
		difficult.generator_settings=EncounterOptions.presets()[index].duplicate(true) as BattlefieldSettings
		difficult.generator_settings.arena_size=Vector2(2,2)
		difficult.generator_settings.generation_attempts=2
		difficult.objective=EncounterOptions.objectives()[2].duplicate(true) as ObjectiveDefinition
		difficult.objective.minimum_exit_travel=25
		var recovered := await prepare(difficult)
		check(recovered.navigation_ready and difficult.layout.used_fallback and difficult.layout.preset_id==difficult.generator_settings.preset_id,"Invalid dimensions/long exit use bounded preset fallback")
		await dispose(recovered)
	check(completed==90,"Ten seeds across all nine combinations")
	check(RegressionReport.write_json("objectives/generation.json",records),"Regression report written")
	generator.queue_free()
	await process_frame
	print("OBJECTIVE GENERATION RESULT: %d failures; %d combinations/seeds and nine fallbacks"%[failures,completed])
	quit(0 if failures==0 else 1)
