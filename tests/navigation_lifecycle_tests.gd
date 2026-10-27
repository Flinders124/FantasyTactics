extends "res://tests/generation_tests.gd"

func run() -> void:
	for cycle in range(30):
		var config := EncounterConfiguration.new()
		if cycle % 2 == 0:
			config.generator_settings.arena_size = Vector2(2,2)
		else:
			config.battlefield_seed = 404
			config.generator_settings.obstacle_count = 30
			config.generator_settings.obstacle_min_size = Vector2(10,10)
			config.generator_settings.obstacle_max_size = Vector2(10,10)
			config.generator_settings.placement_attempts = 3
			config.generator_settings.generation_attempts = 2
		var encounter := await prepare(config)
		check(encounter.navigation_ready and config.layout != null, "Repeated fallback generation becomes playable, cycle %d" % cycle)
		var region := encounter.get_node("NavigationRegion3D") as NavigationRegion3D
		check(not NavigationServer3D.region_get_use_async_iterations(region.get_rid()) and not NavigationServer3D.map_get_use_async_iterations(region.get_navigation_map()), "Static encounter navigation commits synchronously")
		await dispose(encounter)
	print("NAVIGATION LIFECYCLE RESULT: %d failures; 30 fallback replacements" % failures)
	quit(0 if failures == 0 else 1)
