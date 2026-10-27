extends SceneTree

var failures: int = 0
var completed: int = 0
var fallbacks: int = 0
var detours: int = 0
const SCENE: PackedScene = preload("res://scenes/combat_encounter.tscn")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func prepare(config: EncounterConfiguration) -> CombatEncounter:
	var encounter := SCENE.instantiate() as CombatEncounter
	encounter.configuration = config
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	for frame in range(1600):
		if not encounter.preparing:
			return encounter
		await process_frame
	check(false, "Generation exceeds bounded preparation watchdog")
	return encounter

func dispose(encounter: CombatEncounter) -> void:
	encounter.shutdown()
	encounter.queue_free()
	await process_frame
	await physics_frame
	await physics_frame

func rectangles(layout: BattlefieldLayout, settings: BattlefieldSettings) -> void:
	var arena := Rect2(-layout.arena_size * 0.5 + Vector2.ONE * settings.boundary_margin, layout.arena_size - Vector2.ONE * settings.boundary_margin * 2)
	var previous: Array[Rect2] = []
	for index in range(layout.obstacle_centers.size()):
		var center := layout.obstacle_centers[index]
		var size := layout.obstacle_sizes[index]
		var rect := Rect2(Vector2(center.x, center.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
		check(arena.encloses(rect), "Obstacle remains inside arena margins")
		check(not rect.intersects(layout.hero_zone.grow(settings.clearance), true) and not rect.intersects(layout.enemy_zone.grow(settings.clearance), true), "Both spawn zones remain clear")
		for other in previous:
			check(not rect.grow(settings.clearance * 0.5).intersects(other.grow(settings.clearance * 0.5), true), "Obstacle clearance is preserved")
		previous.append(rect)

func run() -> void:
	var generator := BattlefieldGenerator.new()
	root.add_child(generator)
	var settings := BattlefieldSettings.new()
	var signatures: Dictionary = {}
	for seed_value in range(1, 26):
		var config := EncounterConfiguration.new()
		config.battlefield_seed = seed_value
		var encounter := await prepare(config)
		check(encounter.navigation_ready, "Seed %d becomes playable" % seed_value)
		if encounter.navigation_ready:
			completed += 1
			var layout := config.layout
			fallbacks += 1 if layout.used_fallback else 0
			var repeated := generator.make_layout(seed_value, settings, layout.attempt, layout.used_fallback)
			check(repeated != null and repeated.signature() == layout.signature() and repeated.spawns == layout.spawns and repeated.obstacle_centers == layout.obstacle_centers and repeated.obstacle_sizes == layout.obstacle_sizes, "Same seed/settings/attempt reproduce exact layout/spawns")
			signatures[layout.geometry_signature()] = true
			rectangles(layout, settings)
			var controller := encounter.get_node("CombatController") as CombatController
			var navigation := encounter.get_node("NavigationService") as NavigationService
			check(controller.units.size() == 4 and controller.state == CombatController.State.AWAITING_COMMAND, "Only four fresh units start after navigation")
			for first in range(4):
				check(controller.units[first].global_position == layout.spawns[first], "Spawn configuration transfers exactly")
				for second in range(first):
					check(navigation.query_path(layout.spawns[first], layout.spawns[second]).valid(), "All six spawn connections are valid")
			# Collision/visibility uses the same generated static bodies as navigation.
			if not layout.obstacle_centers.is_empty():
				var center := layout.obstacle_centers[0]
				var size := layout.obstacle_sizes[0]
				var left := Vector3(center.x - size.x * 0.5 - 1, 0, center.z)
				var right := Vector3(center.x + size.x * 0.5 + 1, 0, center.z)
				var ray := PhysicsRayQueryParameters3D.create(left + Vector3.UP * 0.8, right + Vector3.UP * 0.8, 8)
				check(not encounter.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Generated obstacle blocks line of sight")
				var route := navigation.query_path(left, right)
				if route.valid():
					check(route.distance > left.distance_to(right) + 0.1, "Generated obstacle forces a full-route detour")
					detours += 1
		await dispose(encounter)
	check(completed == 25 and signatures.size() == 25 and detours > 0, "At least 25 distinct seeds pass generation and navigation")
	# Deliberately impossible density: bounded placement attempts then open fallback.
	var crowded := EncounterConfiguration.new()
	crowded.battlefield_seed = 404
	crowded.generator_settings.obstacle_count = 30
	crowded.generator_settings.obstacle_min_size = Vector2(10, 10)
	crowded.generator_settings.obstacle_max_size = Vector2(10, 10)
	crowded.generator_settings.placement_attempts = 3
	crowded.generator_settings.generation_attempts = 2
	var fallback := await prepare(crowded)
	check(fallback.navigation_ready and crowded.layout != null and crowded.layout.used_fallback and crowded.layout.attempt == 3 and crowded.layout.obstacle_centers.is_empty(), "Exhausted retries recover to known playable open arena")
	check(crowded.layout != null and fallback.generator.total_placement_tries <= 2 * 30 * 3 and crowded.layout.original_seed == 404, "Retries/placement are bounded and preserve original seed")
	await dispose(fallback)
	var invalid := EncounterConfiguration.new()
	invalid.generator_settings.arena_size = Vector2(2, 2)
	var safe := await prepare(invalid)
	check(safe.navigation_ready and invalid.layout != null and invalid.layout.used_fallback and invalid.layout.arena_size == Vector2(28, 22), "Invalid dimensions recover through canonical fallback")
	await dispose(safe)
	# Real post-bake clearance failure, not a test-only production flag.
	var retry_config := EncounterConfiguration.new()
	retry_config.battlefield_seed = 17
	var first_layout := generator.make_layout(17, retry_config.generator_settings, 1)
	var retry := SCENE.instantiate() as CombatEncounter
	retry.configuration = retry_config
	retry.get_node("EnemyController").enabled = false
	var blocker := StaticBody3D.new()
	blocker.position = first_layout.spawns[0] + Vector3.UP * 0.8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	blocker.add_child(collision)
	retry.add_child(blocker) # Outside the baked region, but blocks spawn clearance.
	var blocker_ref: WeakRef = weakref(blocker)
	var synchronization_count: Array[int] = [0]
	retry.get_node("NavigationService").synchronization_finished.connect(func(_success: bool) -> void:
		synchronization_count[0] += 1
		check(retry.get_node("CombatController").state == CombatController.State.SETUP and retry.get_node("Units").get_child_count() == 0, "Generation never exposes units/commands before validation")
		if synchronization_count[0] == 1:
			blocker_ref.get_ref().queue_free())
	root.add_child(retry)
	for frame in range(1600):
		if not retry.preparing:
			break
		await process_frame
	check(retry.navigation_ready and retry_config.layout.attempt == 2 and synchronization_count[0] == 2, "Failed spawn validation follows deterministic second-seed attempt")
	await dispose(retry)
	generator.queue_free()
	await process_frame
	print("GENERATION RESULT: %d failures; %d fixed seeds, %d fallbacks, %d detour checks" % [failures, completed, fallbacks, detours])
	quit(0 if failures == 0 else 1)
