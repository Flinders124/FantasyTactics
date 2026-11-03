extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var enemy: CombatUnit
var hero: CombatUnit
var scout: CombatUnit
var commands: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func count(kind: String) -> int:
	var total: int = 0
	for command in commands:
		if command.kind == kind and command.accepted:
			total += 1
	return total

func fresh() -> void:
	await controller.restart_encounter()
	controller.find_unit("enemy-01").set_health(0)
	commands.clear()
	await physics_frame

func begin() -> void:
	check(controller.submit_player_command(EndTurnCommand.new(hero.stable_id)), "Hero hands off to automatic ranged enemy")
	check(controller.scheduler.active_unit() == enemy, "Ranged enemy receives scheduled turn")

func wait_for_turn() -> void:
	for frame in range(900):
		await process_frame
		if controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW] or controller.scheduler.active_unit() != enemy:
			return
	check(false, "Ranged AI turn exceeded watchdog")
	ai.cancel()
	controller.motor.stop("Test watchdog")

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	# Isolate the preserved basic-attack policy; ability AI has its own suite.
	for unit in controller.units:
		unit.definition = unit.definition.duplicate() as UnitDefinition
		unit.definition.abilities = []
	enemy = controller.find_unit("enemy-02")
	hero = controller.find_unit("hero-01")
	scout = controller.find_unit("hero-02")
	ai.presentation_delay = 0.0
	controller.motor.movement_speed = 12.0
	ai.command_submitted.connect(func(id: String, kind: String, accepted: bool) -> void: commands.append({"actor": id, "kind": kind, "accepted": accepted}))
	await fresh()
	enemy.global_position = Vector3(2, 0, 7)
	hero.global_position = Vector3(-4, 0, 7)
	scout.global_position = Vector3(-9, 0, -9)
	await physics_frame
	begin()
	await wait_for_turn()
	check(count("attack") == 1 and count("move") == 0 and count("end") == 1 and hero.health == hero.definition.maximum_health - 4, "Ranged enemy immediately fires legal shot then ends")
	# Initial range is legal but the arena wall blocks it; AI must find a clear shot.
	await fresh()
	enemy.global_position = Vector3(-4, 0, 0)
	hero.global_position = Vector3(4, 0, 0)
	scout.global_position = Vector3(9, 0, -9)
	await physics_frame
	begin()
	check(controller.evaluate_attack(enemy, hero).error == "Line of sight blocked", "Initial ranged line obstructed by arena")
	var plan := ai.choose_approach(enemy)
	check(plan != null and controller.evaluate_approach(enemy, controller.find_unit(plan.target_id), plan.destination).valid(), "Firing position shares navigability/occupancy/range/LOS rules")
	await wait_for_turn()
	check(count("move") == 1 and count("attack") == 1 and count("end") == 1 and enemy.movement_remaining >= 0.0, "Ranged AI moves to legal firing position, reassesses and shoots once")
	# Too-close repositioning is only a search for an equipped-attack-valid position.
	await fresh()
	enemy.global_position = Vector3(-3, 0, 7)
	hero.global_position = Vector3(-4, 0, 7)
	scout.global_position = Vector3(9, 0, -9)
	await physics_frame
	begin()
	check(controller.evaluate_attack(enemy, hero).error == "Too close", "Minimum range applies to AI too")
	await wait_for_turn()
	check(count("move") == 1 and count("attack") == 1 and count("end") == 1, "Too-close enemy finds legal shot within one move")
	# Equal geometry AND equal threat profiles tie by ID; different roles now have tactical value.
	await fresh()
	var original_scout_definition := scout.definition
	scout.definition=hero.definition.duplicate(true) as UnitDefinition
	scout.set_health(scout.definition.maximum_health)
	enemy.global_position = Vector3(0, 0, 8)
	hero.global_position = Vector3(-10, 0, 8)
	scout.global_position = Vector3(10, 0, 8)
	await physics_frame
	begin()
	plan = ai.choose_approach(enemy)
	check(plan != null and plan.target_id == hero.stable_id, "Equal firing-path costs use stable target ID")
	await wait_for_turn()
	check(hero.health == hero.definition.maximum_health - 4 and scout.health == scout.definition.maximum_health, "Stable selected shot executed consistently")
	scout.definition=original_scout_definition
	await fresh()
	enemy.global_position = Vector3(-9, 0, 9)
	hero.global_position = Vector3(9, 0, -9)
	scout.global_position = Vector3(9, 0, 9)
	await physics_frame
	begin()
	plan = ai.choose_approach(enemy)
	var stop := ai.stopping_route(enemy, plan)
	check(plan != null and plan.route.distance > 6.0 and stop != null and stop.distance <= 6.0, "Distant firing position produces revalidated budget-limited endpoint")
	await wait_for_turn()
	check(count("move") == 1 and count("attack") == 0 and count("end") == 1 and enemy.movement_remaining >= 0.0 and enemy.movement_remaining < 0.1, "Out-of-range after move ends safely without extra action")
	await fresh()
	hero.global_position = Vector3(100, 0, 100)
	scout.global_position = Vector3(110, 0, 100)
	await physics_frame
	begin()
	check(ai.choose_approach(enemy) == null, "No reachable firing candidates for unreachable heroes")
	await wait_for_turn()
	check(count("move") == 0 and count("attack") == 0 and count("end") == 1, "Unreachable ranged turn completes without retries")
	await fresh()
	enemy.global_position = Vector3(-4, 0, 7)
	hero.global_position = Vector3(5, 0, 7)
	scout.global_position = Vector3(-9, 0, -9)
	await physics_frame
	var invalidate := func(_id: String, kind: String, accepted: bool) -> void:
		if kind == "move" and accepted:
			hero.set_health(0)
	ai.command_submitted.connect(invalidate)
	begin()
	await wait_for_turn()
	ai.command_submitted.disconnect(invalidate)
	check(count("move") == 1 and count("attack") == 0 and count("end") == 1, "Target death during movement prevents stale shot")
	# A real ranged action is pending when restart occurs.
	await fresh()
	enemy.global_position = Vector3(2, 0, 7)
	hero.global_position = Vector3(-4, 0, 7)
	scout.global_position = Vector3(-9, 0, -9)
	await physics_frame
	begin()
	for frame in range(120):
		await process_frame
		if ai.stage == EnemyController.Stage.WAIT_ATTACK:
			break
	check(ai.stage == EnemyController.Stage.WAIT_ATTACK, "Ranged action started before restart fixture")
	await controller.restart_encounter()
	var command_count := commands.size()
	for frame in range(40):
		await process_frame
	var presentation := encounter.get_node("CombatPresentation") as CombatPresentation
	check(commands.size() == command_count and presentation.tracers.is_empty() and controller.scheduler.active_unit() == hero and hero.health == hero.definition.maximum_health, "Restart cancels ranged AI/tracers and old damage/completion")
	var connections := controller.action_completed.get_connections().size()
	for restart in range(3):
		await controller.restart_encounter()
	check(controller.action_completed.get_connections().size() == connections, "Repeated restarts reuse AI connections")
	await fresh()
	scout.set_health(0)
	hero.set_health(1)
	enemy.global_position = hero.global_position + Vector3(0, 0, 3)
	await physics_frame
	begin()
	await wait_for_turn()
	check(controller.state == CombatController.State.DEFEAT and count("attack") == 1 and count("end") == 0 and presentation.tracers.is_empty(), "Lethal ranged shot ends encounter and cancels pending AI/effects")
	encounter.queue_free()
	await process_frame
	print("RANGED ENEMY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
