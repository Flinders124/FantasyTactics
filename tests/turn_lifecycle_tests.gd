extends "res://tests/stability_tests.gd"

func run() -> void:
	for boundary in ["feedback", "resolving", "turn_end", "resources"]:
		await fresh_fixture()
		if boundary == "feedback":
			controller.feedback_changed.connect(func(_message: String) -> void: controller.shutdown(), CONNECT_ONE_SHOT)
		elif boundary == "resources":
			hero.resources_changed.connect(func(_unit: CombatUnit) -> void: controller.shutdown(), CONNECT_ONE_SHOT)
		else:
			var expected := CombatController.State.RESOLVING_ACTION if boundary == "resolving" else CombatController.State.TURN_END
			controller.state_changed.connect(func(next: CombatController.State) -> void:
				if next == expected: controller.shutdown())
		controller.submit_command(EndTurnCommand.new(hero.stable_id))
		check(controller.state == CombatController.State.SETUP and raider.owner_turn == 0, "End Turn cancelled at %s cannot advance scheduler" % boundary)
	await fresh_fixture()
	# A deliberately passive legal battle can advance forever; distinguish it
	# from a routine waiting forever for an action completion.
	var initial_serial := controller.turn_serial
	var all_passes_accepted := true
	for turn in range(250):
		var active := controller.scheduler.active_unit()
		all_passes_accepted = controller.submit_command(EndTurnCommand.new(active.stable_id)) and all_passes_accepted
	check(all_passes_accepted and controller.turn_serial == initial_serial + 250 and controller.state == CombatController.State.AWAITING_COMMAND, "Nonterminal passive battle continues to advance every turn")
	check(controller.diagnostic_snapshot().recent_transitions.size() <= 24, "Development transition diagnostics stay bounded in endless advancing battle")
	await fresh_fixture()
	raider.position = hero.position + Vector3(1.5,0,0)
	await physics_frame
	check(controller.submit_command(AttackCommand.new(hero.stable_id,raider.stable_id)), "Attack accepted before actor death")
	hero.set_health(0)
	var serial := controller.turn_serial
	controller._process(1.0)
	check(controller.scheduler.active_unit() == raider and controller.turn_serial == serial and controller.state == CombatController.State.AWAITING_COMMAND, "Dead resolving actor advances once and stale timer cannot alter next turn")
	await fresh_fixture()
	var stale_distance := [0]
	controller.motor.distance_advanced.connect(func(_unit: CombatUnit, _distance: float) -> void: stale_distance[0] += 1)
	controller.motor.progress.connect(func() -> void: controller.shutdown(), CONNECT_ONE_SHOT)
	check(controller.submit_command(MoveCommand.new(hero.stable_id,Vector3(-3,0,3))), "Movement begins before progress cancellation")
	await physics_frame
	await physics_frame
	check(not controller.motor.running and stale_distance[0] == 0, "Cancelled movement emits no stale distance event")
	encounter.free()
	print("TURN LIFECYCLE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
