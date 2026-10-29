extends "res://tests/generation_tests.gd"
var records: Array[Dictionary] = []
var baked: int = 0

func run() -> void:
	var presets := EncounterOptions.presets()
	check(presets.size() == 5, "Two battlefield presets append after original three")
	for index in range(3):
		check(presets[index].preset_id == ["open_courtyard", "ruined_lanes", "central_plaza"][index], "Original indexes remain stable")
	var generator := BattlefieldGenerator.new()
	root.add_child(generator)
	for id in ["narrow_approach", "split_courtyard"]:
		var path := "res://definitions/presets/%s.tres" % id
		check(ResourceLoader.exists(path), "New preset exists: " + id)
		if not ResourceLoader.exists(path): continue
		var settings := load(path) as BattlefieldSettings
		check(settings != null and settings.valid() and settings.generator_version == 2, "Valid version-two preset")
		for objective in EncounterOptions.objectives():
			for seed_value in range(1, 11):
				var count := 2 + seed_value % 3
				var layout := generator.make_layout(seed_value, settings, 1, false, objective, count)
				check(layout != null, "Topology generates without fallback")
				if layout == null: continue
				rectangles(layout, settings)
				check(layout.obstacle_sizes.size() == 4, "Four authored masonry blockers")
				for size in layout.obstacle_sizes:
					check(size.x > size.z if id == "narrow_approach" else size.z > size.x, "Each new preset has its own authored wall orientation")
				check(generator.make_layout(seed_value, settings, 1, false, objective, count).signature() == layout.signature(), "Exact seed reproducibility")
				var cosmetic := settings.duplicate(true) as BattlefieldSettings
				cosmetic.detail_density = 0
				cosmetic.vegetation_density = 0
				cosmetic.rubble_density = 0
				check(generator.make_layout(seed_value, cosmetic, 1, false, objective, count).signature() == layout.signature(), "Density cannot alter geometry or spawns")
				await validate_bake(generator, layout, settings, objective, count)
				completed += 1
			var invalid := settings.duplicate(true) as BattlefieldSettings
			invalid.arena_size = Vector2(2, 2)
			check(generator.make_layout(404, invalid, 1, false, objective, 4) == null, "Invalid dimensions reject normal attempt")
			var fallback := generator.make_layout(404, invalid, 4, true, objective, 4)
			check(fallback != null and fallback.used_fallback and fallback.attempt == 4 and fallback.preset_id == id, "Fallback preserves preset and bounded attempt")
			if fallback != null:
				check(fallback.arena_size == Vector2(28, 22), "Canonical fallback dimensions")
				rectangles(fallback, settings)
				await validate_bake(generator, fallback, settings, objective, 4)
		var selection := PartySelection.new()
		selection.selected = ["knight", "ranger"]
		selection.preset_index = 3 if id == "narrow_approach" else 4
		check(selection.ready(), "Appended preset selectable")
		var config := selection.configuration(42)
		check(config != null and config.generator_settings.preset_id == id, "Selection reaches configuration")
		if config != null:
			var restored := PartySelection.new()
			restored.populate(config)
			check(restored.preset_index == selection.preset_index and restored.ready(), "Restored preset index")
	check(completed == 60 and baked == 66, "Sixty seeded and six fallback real bakes")
	check(RegressionReport.write_json("mission-m3/layouts/results.json", records), "Verification report written")
	generator.free()
	print("MISSION LAYOUT RESULT: %d failures; %d seeded layouts; %d real bakes" % [failures, completed, baked])
	quit(0 if failures == 0 else 1)

func validate_bake(generator: BattlefieldGenerator, layout: BattlefieldLayout, settings: BattlefieldSettings, objective: ObjectiveDefinition, count: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.cell_size = .25
	mesh.cell_height = .25
	mesh.agent_radius = .5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = .25
	region.navigation_mesh = mesh
	world.add_child(region)
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	NavigationServer3D.map_set_use_async_iterations(region.get_navigation_map(), false)
	var navigation := NavigationService.new()
	world.add_child(navigation)
	generator.build(region, layout, settings)
	region.bake_navigation_mesh(false)
	await navigation.synchronize(region)
	check(navigation.ready_for_queries, "Real navigation bake synchronizes")
	check(generator.validate_spawns(layout, navigation, world.get_world_3d(), settings, count), "All spawns have body clearance and connected routes: " + generator.validation_error)
	check(generator.validate_objective(layout, navigation, objective), "Objective disc, approaches and travel: " + generator.validation_error)
	for z in [-9.2, 0.0, 9.2]:
		var left := Vector3(-6.5, 0, z)
		var right := Vector3(6.5, 0, z)
		check(navigation.query_path(left, right).valid() and navigation.query_path(layout.spawns[0], left).valid() and navigation.query_path(right, layout.spawns[2]).valid(), "Center and perimeter alternative routes connect")
	baked += 1
	records.append({"preset": layout.preset_id, "objective": objective.stable_id, "seed": layout.original_seed, "enemies": count, "attempt": layout.attempt, "fallback": layout.used_fallback, "polygons": mesh.get_polygon_count(), "valid": generator.validation_error.is_empty()})
	world.free()
	await process_frame
	await physics_frame
