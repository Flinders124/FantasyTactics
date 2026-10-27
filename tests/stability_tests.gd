extends "res://tests/attack_tests.gd"
## Lifecycle fault injection at real signal boundaries; no balance changes.
var nested_accepted: bool = false

func fresh_fixture() -> void:
	if is_instance_valid(encounter):
		encounter.free()
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	hero = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	scout = controller.find_unit("hero-02")
	sentinel = controller.find_unit("enemy-02")

func run() -> void:
	await fresh_fixture()
	controller.state_changed.connect(func(state: CombatController.State) -> void:
		if state == CombatController.State.RESOLVING_ACTION:
			controller.shutdown(), CONNECT_ONE_SHOT)
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3,0,3))), "Shutdown during move acceptance rejects stale command")
	check(not controller.motor.running and controller.state == CombatController.State.SETUP, "Shutdown cannot leave a motor running")
	await fresh_fixture()
	controller.state_changed.connect(func(_state: CombatController.State) -> void:
		hero.movement_remaining = 0.0, CONNECT_ONE_SHOT)
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3,0,3))), "Move rechecks budget after state notifications")
	check(not controller.motor.running and controller.state == CombatController.State.AWAITING_COMMAND, "Rejected changed budget returns control")
	await fresh_fixture()
	nested_accepted = false
	controller.feedback_changed.connect(func(_message: String) -> void:
		nested_accepted = controller.submit_command(EndTurnCommand.new(hero.stable_id)), CONNECT_ONE_SHOT)
	check(controller.submit_command(EndTurnCommand.new(hero.stable_id)), "Outer End Turn accepted")
	check(not nested_accepted and controller.scheduler.active_unit() == raider and hero.owner_turn == 1 and raider.owner_turn == 1, "Reentrant End Turn cannot skip an actor")
	await fresh_fixture()
	raider.position = hero.position + Vector3(1.5,0,0)
	await physics_frame
	await physics_frame
	hero.resources_changed.connect(func(_unit: CombatUnit) -> void:
		controller.restart_encounter(), CONNECT_ONE_SHOT)
	controller.submit_command(AttackCommand.new(hero.stable_id,raider.stable_id))
	for frame in range(12):
		await physics_frame
	check(controller.state == CombatController.State.AWAITING_COMMAND and controller.scheduler.active_unit() == hero, "Restart requested while committing completes cleanly")
	check(controller.units.all(func(unit: CombatUnit) -> bool: return unit.health == unit.definition.maximum_health and unit.cooldown_ready_turn.is_empty() and unit.statuses.is_empty()), "An old committed action cannot damage fresh restart state")
	await fresh_fixture()
	controller.restart_encounter()
	controller.shutdown()
	for frame in range(6):
		await physics_frame
	check(controller.state == CombatController.State.SETUP and controller.scheduler.active_unit().owner_turn == 0, "Shutdown cancels an awaiting direct restart")
	await fresh_fixture()
	controller.state_changed.connect(func(_state: CombatController.State) -> void:
		controller.shutdown(), CONNECT_ONE_SHOT)
	controller._start_next_turn()
	check(controller.state == CombatController.State.SETUP and raider.owner_turn == 0, "Turn-start notifications cannot resurrect a shut down encounter")
	await fresh_fixture()
	hero.apply_status(load("res://definitions/slowed.tres") as StatusEffectDefinition)
	for turn in range(4):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(hero.owner_turn == 2 and hero.movement_granted == 3.0 and hero.movement_remaining == 3.0, "Slowed allocation granted exactly once at next owner turn")
	check(encounter.get_node("HUD").label.text.contains("3.00 / 3.00 m"), "HUD shows the actual reduced turn allocation")
	hero.apply_status(load("res://definitions/slowed.tres") as StatusEffectDefinition)
	check(hero.movement_granted == 3.0 and hero.movement_remaining == 3.0, "Refreshing a status does not change movement already granted")
	await fresh_fixture()
	root.size = Vector2i(1280,720)
	var player := encounter.get_node("PlayerController") as PlayerController
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(Vector3(-2,0,3))
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = camera.unproject_position(Vector3(-3,0,3))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	check(controller.motor.running and controller.motor.path[-1].distance_to(Vector3(-3,0,3)) < 0.01, "A queued click targets its own position, not a newer hover position")
	encounter.free()
	await process_frame
	print("STABILITY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
