extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var navigation: NavigationService
var motor: MovementMotor
var hero: CombatUnit
var observed_distance: float = 0.0
var observed_position: Vector3

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_for_motor() -> void:
	for frame in range(600):
		await physics_frame
		if not motor.running:
			return
	check(false, "Movement did not finish within test watchdog")
	motor.stop("Test watchdog")

func make_blocker(position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2, 2)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	encounter.add_child(body)
	return body

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	controller = encounter.get_node("CombatController") as CombatController
	navigation = encounter.get_node("NavigationService") as NavigationService
	motor = encounter.get_node("MovementMotor") as MovementMotor
	check(not navigation.query_path(Vector3.ZERO, Vector3.ONE).valid(), "Queries disabled before map synchronization")
	while not encounter.navigation_ready:
		await physics_frame
	hero = controller.scheduler.active_unit()
	motor.movement_speed = 12.0
	motor.blocked_timeout = 0.15
	var simple := PackedVector3Array([Vector3.ZERO, Vector3(3, 0, 0), Vector3(3, 0, 4)])
	check(is_equal_approx(NavigationService.path_length(simple), 7.0), "Path cost sums all segments")
	var detour := navigation.query_path(Vector3(-4, 0, 0), Vector3(4, 0, 0))
	check(detour.valid() and detour.distance > 8.1, "Obstacle route costs more than straight line")
	var original_budget := hero.movement_remaining
	check(not controller.submit_command(MoveCommand.new("hero-02", Vector3(-3, 0, 3))), "Inactive hero cannot move")
	check(not controller.submit_command(MoveCommand.new("missing", Vector3(-3, 0, 3))), "Unknown actor cannot move")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(100, 0, 100))), "Off-map destination rejected")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3.ZERO)), "Obstacle footprint rejected")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(NAN, 0, 0))), "Non-finite destination rejected")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(9, 0, 9))), "Over-budget move rejected")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, controller.units[1].global_position)), "Occupied destination rejected")
	check(is_equal_approx(hero.movement_remaining, original_budget), "Rejected commands cost no movement")
	# An affordable preview is not a reservation: submission rechecks occupancy.
	var stale_target := Vector3(-3, 0, 3)
	check(controller.evaluate_move(hero, stale_target).valid(), "Initial preview valid")
	var other := controller.units[1]
	var other_position := other.global_position
	other.global_position = stale_target
	await physics_frame
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, stale_target)), "Stale preview revalidated for occupancy")
	other.global_position = other_position
	await physics_frame
	# First move and command lockout, with camera controls exercised mid-action.
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3, 0, 3))), "First move accepted")
	check(controller.state == CombatController.State.RESOLVING_ACTION, "Moving resolves action")
	check(not controller.submit_command(EndTurnCommand.new(hero.stable_id)), "End Turn cannot interrupt movement")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-2, 0, 3))), "Repeated move cannot queue")
	var camera := encounter.get_node("TacticalCamera") as TacticalCamera
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	var old_distance := camera.distance
	camera._unhandled_input(zoom)
	check(camera.distance < old_distance, "Camera zoom available while moving")
	await wait_for_motor()
	check(controller.state == CombatController.State.AWAITING_COMMAND, "Movement returns control")
	check(hero.global_position.distance_to(Vector3(-3, 0, 3)) < 0.02, "Motor reaches approved endpoint")
	check(absf(hero.movement_remaining - 5.0) < 0.02, "Actual first move deducted")
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-2, 0, 3))), "Second move accepted")
	await wait_for_motor()
	check(absf(hero.movement_remaining - 4.0) < 0.03, "Multiple moves share budget")
	# Change budget after preview; validation must use the current budget.
	var target := Vector3(-1, 0, 3)
	check(controller.evaluate_move(hero, target).valid(), "Preview affordable before budget change")
	hero.movement_remaining = 0.4
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, target)), "Submission revalidates current budget")
	# Exact remaining budget: travel must not overspend (2 mm tolerance).
	hero.movement_remaining = 0.5
	var before := hero.global_position
	check(controller.submit_command(MoveCommand.new(hero.stable_id, before + Vector3(0, 0, -0.5))), "Exact-budget move accepted")
	await wait_for_motor()
	check(hero.global_position.distance_to(before) <= 0.5 + MovementMotor.NUMERICAL_TOLERANCE, "Motor caps travel to remaining allowance")
	check(hero.movement_remaining >= 0.0 and hero.movement_remaining < 0.02, "Budget never becomes negative")
	# Block a route after approval. Static navmesh cannot foresee this dynamic obstruction.
	hero.movement_remaining = 6.0
	hero.global_position = Vector3(-4, 0, 7)
	await physics_frame
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-1, 0, 7))), "Unblocked route initially accepted")
	var blocker := make_blocker(Vector3(-2.5, 1, 7))
	before = hero.global_position
	observed_position = before
	observed_distance = 0.0
	var observe := func() -> void:
		observed_distance += hero.global_position.distance_to(observed_position)
		observed_position = hero.global_position
	motor.progress.connect(observe)
	await wait_for_motor()
	motor.progress.disconnect(observe)
	var spent := 6.0 - hero.movement_remaining
	check(controller.state == CombatController.State.AWAITING_COMMAND and not motor.running, "Blocked movement returns control within bound")
	check(spent > 0.1 and spent < 2.0, "Blocked move charges only partial travel")
	check(absf(spent - observed_distance) < 0.001, "Blocked travel charged matches sum of actual physics travel")
	blocker.queue_free()
	await physics_frame
	check(controller.submit_command(MoveCommand.new(hero.stable_id, hero.global_position + Vector3(0, 0, 0.5))), "Can move again after obstruction stops action")
	await wait_for_motor()
	var remaining_before_turn := hero.movement_remaining
	controller.submit_command(EndTurnCommand.new(hero.stable_id))
	var enemy := controller.scheduler.active_unit()
	check(not controller.submit_player_command(MoveCommand.new(enemy.stable_id, enemy.global_position + Vector3.LEFT)), "Active enemy cannot receive player moves")
	check(is_equal_approx(hero.movement_remaining, remaining_before_turn), "End Turn does not reset movement")
	for index in range(3):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(controller.scheduler.active_unit() == hero and is_equal_approx(hero.movement_remaining, 6.0), "Next own turn resets allowance")
	# Execute a complete obstacle detour using the same route the preview returns.
	hero.global_position = Vector3(-4, 0, 0)
	hero.movement_remaining = 20.0 # Test fixture only: longer than a normal turn.
	await physics_frame
	var approved := controller.evaluate_move(hero, Vector3(4, 0, 0))
	check(approved.valid() and approved.distance > 8.1, "Affordable detour preview")
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(4, 0, 0))), "Detour command accepted")
	await wait_for_motor()
	check(hero.global_position.distance_to(Vector3(4, 0, 0)) < 0.02, "Approved detour executes around obstacle")
	check(absf(20.0 - hero.movement_remaining - approved.distance) < 0.05, "Detour execution agrees with preview cost")
	# Add a disconnected navigation island to test a real partial route.
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(29, 0, 29), Vector3(29, 0, 31), Vector3(31, 0, 31), Vector3(31, 0, 29)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	encounter.add_child(region)
	await process_frame
	await physics_frame
	NavigationServer3D.map_force_update(navigation.map)
	check(not navigation.query_path(hero.global_position, Vector3(30, 0, 30)).valid(), "Disconnected island partial path rejected")
	var dead_id := hero.stable_id
	hero.set_health(0)
	check(not controller.submit_command(MoveCommand.new(dead_id, Vector3(-3, 0, 7))), "Dead actor cannot move")
	encounter.queue_free()
	await process_frame
	print("MOVEMENT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
