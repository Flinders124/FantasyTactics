extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://scenes/combat_encounter.tscn") as PackedScene
	var encounter := scene.instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	var manager := encounter.get_node("TurnManager") as TurnManager
	var controller := encounter.get_node("CombatController") as CombatController
	check(manager.order.size() == 4, "Four units must spawn")
	var expected: Array[String] = ["hero-01", "enemy-01", "enemy-02", "hero-02"]
	for index in range(4):
		check(manager.order[index].stable_id == expected[index], "Descending initiative and ID tie break")
	check(not controller.submit_command(null), "Null command rejected")
	check(not controller.submit_command(EndTurnCommand.new("unknown")), "Unknown actor rejected")
	check(not controller.submit_command(EndTurnCommand.new("enemy-01")), "Inactive actor rejected")
	check(manager.active_unit().stable_id == "hero-01", "Rejected commands preserve turn")
	var camera := encounter.get_node("TacticalCamera") as TacticalCamera
	check(camera.focus_target == manager.active_unit(), "Selection signal updates camera target")
	var right_press := InputEventMouseButton.new()
	right_press.button_index = MOUSE_BUTTON_RIGHT
	right_press.pressed = true
	Input.parse_input_event(right_press)
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 10000)
	camera._unhandled_input(motion)
	check(camera.yaw < 0.0 and is_equal_approx(camera.pitch, -1.4), "Orbit and pitch clamp respond")
	var right_release := right_press.duplicate() as InputEventMouseButton
	right_release.pressed = false
	Input.parse_input_event(right_release)
	Input.flush_buffered_events()
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	var old_distance := camera.distance
	camera._unhandled_input(zoom)
	check(camera.distance < old_distance, "Wheel zoom responds")
	camera.position = Vector3(10, 0, 10)
	var focus := InputEventKey.new()
	focus.keycode = KEY_F
	focus.pressed = true
	camera._unhandled_input(focus)
	check(camera.position.is_equal_approx(manager.active_unit().global_position), "Focus centers active unit")
	var pan := InputEventKey.new()
	pan.physical_keycode = KEY_W
	pan.pressed = true
	Input.parse_input_event(pan)
	Input.flush_buffered_events()
	var old_position := camera.position
	camera._process(0.1)
	check(not camera.position.is_equal_approx(old_position), "Keyboard pan responds")
	var pan_release := pan.duplicate() as InputEventKey
	pan_release.pressed = false
	Input.parse_input_event(pan_release)
	Input.flush_buffered_events()
	controller.state = CombatController.State.RESOLVING_ACTION
	check(not controller.submit_command(EndTurnCommand.new("hero-01")), "Wrong state rejected")
	controller.state = CombatController.State.AWAITING_COMMAND
	for index in range(4):
		check(manager.active_unit().stable_id == expected[index], "Expected active actor")
		check(controller.submit_command(EndTurnCommand.new(expected[index])), "Valid command accepted")
	check(manager.round_number == 2 and manager.active_unit().stable_id == "hero-01", "Full cycle advances round")
	manager.order[1].set_health(0)
	controller.submit_command(EndTurnCommand.new("hero-01"))
	check(manager.active_unit().stable_id == "enemy-02", "Dead unit skipped")
	manager.active_unit().set_health(0)
	check(controller.state == CombatController.State.VICTORY, "All enemies dead gives victory")
	check(not controller.submit_command(EndTurnCommand.new("enemy-02")), "Dead actor and terminal state rejected")
	# Restart to test death of the current actor and the defeat branch.
	for unit in controller.units:
		unit.reset_for_encounter()
	controller.setup(controller.units.duplicate(), manager)
	manager.active_unit().set_health(0)
	check(manager.active_unit().stable_id == "enemy-01", "Active death advances to next living actor")
	controller.units[1].set_health(0)
	check(controller.state == CombatController.State.DEFEAT, "All heroes dead gives defeat")
	var shared := load("res://definitions/hero.tres") as UnitDefinition
	var unit_scene := load("res://scenes/combat_unit.tscn") as PackedScene
	var a := unit_scene.instantiate() as CombatUnit
	var b := unit_scene.instantiate() as CombatUnit
	a.definition = shared
	b.definition = shared
	root.add_child(a)
	root.add_child(b)
	a.set_health(1)
	a.begin_turn()
	a.movement_remaining = 2.0
	a.attack_available = false
	check(b.health == shared.maximum_health and b.movement_remaining == 0.0, "Shared definition keeps instance state separate")
	check(shared.maximum_health == 20 and shared.movement_allowance == 6.0, "Definition remains unchanged")
	var map: RID = encounter.get_node("NavigationRegion3D").get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(-4, 0, 0), Vector3(4, 0, 0), true)
	print("Navigation polygons: ", encounter.get_node("NavigationRegion3D").navigation_mesh.get_polygon_count(), " path: ", path)
	check(path.size() > 2, "Navigation path must detour around central obstacle")
	for point in path:
		check(absf(point.x) > 1.5 or absf(point.z) > 1.0, "Path avoids obstacle footprint")
	var solo := TurnManager.new()
	root.add_child(solo)
	var pair: Array[CombatUnit] = [a, b]
	a.stable_id = "a"
	b.stable_id = "b"
	solo.configure(pair)
	check(solo.advance() == a, "Equal initiative sorts by stable ID")
	a.set_health(0)
	check(solo.advance() == b, "Living unit scheduled")
	check(solo.advance() == b and solo.round_number == 2, "Dead unit at round boundary skipped")
	b.set_health(0)
	check(solo.advance() == null, "All dead terminates scheduling")
	a.queue_free()
	b.queue_free()
	solo.queue_free()
	encounter.queue_free()
	await process_frame
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
