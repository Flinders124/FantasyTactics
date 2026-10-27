extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var commands_per_turn: Dictionary = {}
var serials: Dictionary = {}
var positions: Dictionary = {}
var distances: Dictionary = {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _on_routine(id: String, serial: int) -> void:
	serials[id] = serial
	var key := "%s/%d" % [id, serial]
	check(not commands_per_turn.has(key), "Only one AI routine starts per turn")
	commands_per_turn[key] = {"move": 0, "attack": 0, "end": 0}
	distances[key] = 0.0
	positions[id] = controller.find_unit(id).global_position

func _on_command(id: String, kind: String, accepted: bool) -> void:
	check(accepted, "Normal encounter AI command is accepted")
	var key := "%s/%d" % [id, int(serials[id])]
	commands_per_turn[key][kind] += 1
	check(commands_per_turn[key][kind] <= 1, "At most one command of each kind in enemy turn")

func _on_progress() -> void:
	var actor := controller.motor.actor
	if actor.faction != CombatUnit.Faction.ENEMY:
		return
	var key := "%s/%d" % [actor.stable_id, int(serials[actor.stable_id])]
	var previous: Vector3 = positions[actor.stable_id]
	distances[key] += NavigationService.planar(actor.global_position - previous).length()
	positions[actor.stable_id] = actor.global_position
	check(distances[key] <= actor.definition.movement_allowance + 0.002, "Every enemy respects total movement budget")

func wait_for_action() -> void:
	for frame in range(900):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Hero action timed out")

func terminal() -> bool:
	return controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]

func attack_if_legal(actor: CombatUnit) -> bool:
	for target in ai.living_targets(actor):
		if controller.evaluate_attack(actor, target).valid():
			return controller.submit_player_command(AttackCommand.new(actor.stable_id, target.stable_id))
	return false

func simulate(heroes_fight: bool) -> void:
	# Test harness only: hero inputs use the real player submission boundary.
	# Production EnemyController still activates exclusively for enemy units.
	var waiting_frames: int = 0
	for step in range(12000):
		if terminal():
			return
		var actor := controller.scheduler.active_unit()
		if controller.state != CombatController.State.AWAITING_COMMAND or actor.faction != CombatUnit.Faction.HERO:
			waiting_frames += 1
			check(waiting_frames < 900, "Automatic enemy turns complete without manual advancement")
			if waiting_frames >= 900:
				return
			await process_frame
			continue
		waiting_frames = 0
		if heroes_fight:
			if attack_if_legal(actor):
				await wait_for_action()
			else:
				var approach := ai.choose_approach(actor)
				if approach != null:
					var endpoint := NavigationService.point_at_distance(approach.route.path, minf(approach.route.distance, actor.movement_remaining - 0.02))
					if controller.evaluate_move(actor, endpoint).valid():
						check(controller.submit_player_command(MoveCommand.new(actor.stable_id, endpoint)), "Simulated hero move accepted")
						await wait_for_action()
						if not terminal() and attack_if_legal(actor):
							await wait_for_action()
		if not terminal():
			check(controller.submit_player_command(EndTurnCommand.new(actor.stable_id)), "Simulated hero End Turn accepted")
		await process_frame
	check(false, "Encounter exceeded overall watchdog")

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	ai.presentation_delay = 0.0
	controller.motor.movement_speed = 12.0
	ai.routine_started.connect(_on_routine)
	ai.command_submitted.connect(_on_command)
	controller.motor.progress.connect(_on_progress)
	await simulate(true)
	check(terminal(), "Default full encounter reaches an outcome with automated enemies")
	print("Fighting heroes: ", CombatController.State.keys()[controller.state], " in round ", controller.scheduler.round_number)
	await controller.restart_encounter()
	await simulate(false)
	check(controller.state == CombatController.State.DEFEAT, "Enemies defeat passive heroes without manual enemy commands")
	print("Passive heroes: ", CombatController.State.keys()[controller.state], " in round ", controller.scheduler.round_number)
	# A different legal opening must also finish. Improved enemies can defeat this
	# deliberately simple hero policy; generated tactical victory has its own test.
	# Warden supports Scout instead of rushing away from the ranged hero.
	await controller.restart_encounter()
	var warden := controller.find_unit("hero-01")
	for destination in [Vector3(-4, 0, 5), Vector3(-1, 0, 5)]:
		check(controller.submit_player_command(MoveCommand.new(warden.stable_id, destination)), "Support opening uses ordinary movement")
		await wait_for_action()
	controller.submit_player_command(EndTurnCommand.new(warden.stable_id))
	await simulate(true)
	check(terminal(), "Support opening completes through real commands against improved enemies")
	print("Support opening: ", CombatController.State.keys()[controller.state], " in round ", controller.scheduler.round_number)
	check(commands_per_turn.size() >= 4, "Multiple enemy turns exercised")
	encounter.queue_free()
	await process_frame
	print("PLAYABLE ENCOUNTER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
