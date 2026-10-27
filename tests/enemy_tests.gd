extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var hero: CombatUnit
var scout: CombatUnit
var enemy: CombatUnit
var sentinel: CombatUnit
var commands: Array[Dictionary] = []
var routines: Array[int] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _record(id: String, kind: String, accepted: bool) -> void:
	commands.append({"actor": id, "kind": kind, "accepted": accepted})

func count(kind: String, accepted: bool = true) -> int:
	var total: int = 0
	for command in commands:
		if command.kind == kind and command.accepted == accepted:
			total += 1
	return total

func fresh() -> void:
	await controller.restart_encounter()
	ai.presentation_delay = 0.0
	sentinel.set_health(0)
	commands.clear()
	routines.clear()
	await physics_frame

func begin_enemy() -> void:
	check(controller.submit_player_command(EndTurnCommand.new(hero.stable_id)), "Hero End Turn accepted")
	check(controller.scheduler.active_unit() == enemy, "Enemy turn begins")

func wait_for_turn_end() -> void:
	for frame in range(900):
		await process_frame
		if controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
			return
		if controller.scheduler.active_unit() != enemy:
			return
	check(false, "AI turn exceeded bounded watchdog")
	ai.cancel()
	controller.motor.stop("Test watchdog")

func run() -> void:
	root.size = Vector2i(1280, 720)
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
	hero = controller.find_unit("hero-01")
	scout = controller.find_unit("hero-02")
	enemy = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	controller.motor.movement_speed = 12.0
	controller.motor.blocked_timeout = 0.15
	ai.command_submitted.connect(_record)
	ai.routine_started.connect(func(_id: String, serial: int) -> void: routines.append(serial))
	await fresh()
	# Equal damage AND equal threat geometry: stable hero ID wins. The ranged
	# hero's normal minimum range would make these positions tactically unequal.
	var scout_attack := scout.definition.basic_attack
	scout.definition.basic_attack=hero.definition.basic_attack
	enemy.global_position = Vector3(0, 0, 8)
	hero.global_position = Vector3(-1.5, 0, 8)
	scout.global_position = Vector3(1.5, 0, 8)
	await physics_frame
	begin_enemy()
	var serial := controller.turn_serial
	controller.turn_started.emit(enemy, serial)
	await wait_for_turn_end()
	check(hero.health == hero.definition.maximum_health - 4 and scout.health == scout.definition.maximum_health, "Immediate attack chooses stable target ID")
	check(count("attack") == 1 and count("move") == 0 and count("end") == 1, "Immediate attack preferred; at most one attack and movement")
	check(routines.size() == 1, "Duplicate turn-start signal does not start duplicate routine")
	scout.definition.basic_attack=scout_attack
	# Symmetric full approach costs use stable target IDs; positions are not occupied centres.
	await fresh()
	enemy.global_position = Vector3(0, 0, 8)
	hero.global_position = Vector3(-4, 0, 8)
	scout.global_position = Vector3(4, 0, 8)
	await physics_frame
	begin_enemy()
	var approach := ai.choose_approach(enemy)
	check(approach != null and approach.target_id == hero.stable_id, "Equal reachable approach costs use stable target ID")
	if approach != null:
		check(approach.destination.distance_to(hero.global_position) > 0.7 and controller.evaluate_approach(enemy, hero, approach.destination).valid(), "Approach endpoint is navigable, free and melee-valid")
	await wait_for_turn_end()
	check(count("move") == 1 and count("attack") == 1 and count("end") == 1, "Move completes before reassessed attack and End Turn")
	# In range across an arena corner, but a wall blocks the chest line.
	await fresh()
	enemy.global_position = Vector3(2.4, 0, 0.3)
	hero.global_position = Vector3(0.6, 0, 1.5)
	scout.global_position = Vector3(-9, 0, -9)
	await physics_frame
	begin_enemy()
	check(controller.evaluate_attack(enemy, hero).error.contains("obstructed"), "Enemy cannot immediately attack through arena wall")
	await wait_for_turn_end()
	check(count("move") == 1 and count("attack") == 1 and hero.health == hero.definition.maximum_health - 4, "Enemy first moves to an unobstructed melee position")
	# Force the shortest target route around the central obstacle.
	await fresh()
	enemy.global_position = Vector3(-4, 0, 0)
	hero.global_position = Vector3(4, 0, 0)
	scout.global_position = Vector3(9, 0, -9)
	await physics_frame
	begin_enemy()
	approach = ai.choose_approach(enemy)
	check(approach != null and approach.route.path.size() > 2 and approach.route.distance > enemy.global_position.distance_to(approach.destination) + 0.1, "Enemy approach path detours around static obstacle")
	var observe_detour := func() -> void:
		var position := enemy.global_position
		check(absf(position.x) > 1.5 or absf(position.z) > 1.0, "Enemy execution avoids central obstacle footprint")
	controller.motor.progress.connect(observe_detour)
	await wait_for_turn_end()
	controller.motor.progress.disconnect(observe_detour)
	check(count("move") == 1 and count("end") == 1, "Obstacle detour completes its bounded turn")
	# A closer centre behind the central obstacle loses to the shorter actual approach path.
	await fresh()
	enemy.global_position = Vector3(-4, 0, 0)
	hero.global_position = Vector3(1.9, 0, 0)
	scout.global_position = Vector3(-4, 0, 6)
	await physics_frame
	begin_enemy()
	approach = ai.choose_approach(enemy)
	check(approach != null and approach.target_id == scout.stable_id, "Target selection compares navigation approach costs, not centre distances")
	await wait_for_turn_end()
	# Long route: cut a path prefix, requery actual endpoint and enforce budget.
	await fresh()
	enemy.global_position = Vector3(-8, 0, 8)
	hero.global_position = Vector3(8, 0, -8)
	scout.global_position = Vector3(9, 0, 8)
	await physics_frame
	begin_enemy()
	approach = ai.choose_approach(enemy)
	var stopping := ai.stopping_route(enemy, approach)
	check(approach != null and approach.route.distance > 6.0 and stopping != null and stopping.distance <= 6.0, "Budget-limited stopping point has revalidated affordable path")
	var start := enemy.global_position
	check(not controller.submit_player_command(MoveCommand.new(enemy.stable_id, start + Vector3.RIGHT)), "Player cannot move an active enemy")
	check(not controller.submit_player_command(AttackCommand.new(enemy.stable_id, hero.stable_id)), "Player cannot attack as enemy")
	check(not controller.submit_player_command(EndTurnCommand.new(enemy.stable_id)), "Player cannot end an enemy turn")
	var hud: CanvasLayer = encounter.get_node("HUD")
	check(hud.button.disabled and hud.attack_button.disabled and hud.result_label.text.contains("ENEMY TURN"), "HUD indicates and protects enemy turn")
	var player := encounter.get_node("PlayerController") as PlayerController
	player.toggle_attack_targeting()
	check(not player.attack_mode, "Player cannot enter attack targeting during enemy turn")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	check(commands.is_empty() and controller.state == CombatController.State.AWAITING_COMMAND, "Player click cannot issue enemy command")
	var camera := encounter.get_node("TacticalCamera") as TacticalCamera
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	var old_distance := camera.distance
	camera._unhandled_input(zoom)
	check(camera.distance < old_distance, "Camera zoom responds during enemy turn")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	var old_yaw := camera.yaw
	camera._unhandled_input(motion)
	check(camera.yaw != old_yaw, "Camera orbit responds during enemy turn")
	var release := right.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	var pan := InputEventKey.new()
	pan.physical_keycode = KEY_W
	pan.pressed = true
	Input.parse_input_event(pan)
	Input.flush_buffered_events()
	var old_pivot := camera.position
	camera._process(0.1)
	check(camera.position != old_pivot, "Camera pan responds during enemy turn")
	var pan_release := pan.duplicate() as InputEventKey
	pan_release.pressed = false
	Input.parse_input_event(pan_release)
	Input.flush_buffered_events()
	await wait_for_turn_end()
	check(count("move") == 1 and count("end") == 1 and enemy.movement_remaining >= 0.0 and enemy.movement_remaining < 0.1, "Enemy spends one budget-limited movement then ends")
	check(enemy.global_position.distance_to(start) <= 6.002, "Enemy cannot exceed movement allowance")
	# Both heroes live on a disconnected island: candidate queries reject partial paths.
	await fresh()
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(35, 0, 35), Vector3(35, 0, 45), Vector3(45, 0, 45), Vector3(45, 0, 35)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	encounter.add_child(region)
	hero.global_position = Vector3(38, 0, 40)
	scout.global_position = Vector3(42, 0, 40)
	await physics_frame
	NavigationServer3D.map_force_update(controller.navigation.map)
	begin_enemy()
	check(ai.choose_approach(enemy) == null, "Disconnected heroes have no reachable approach")
	await wait_for_turn_end()
	check(count("move") == 0 and count("attack") == 0 and count("end") == 1, "Unreachable targets cannot create an endless turn")
	region.queue_free()
	await physics_frame
	# Inject an obstruction after movement acceptance; recovery cannot retry movement.
	await fresh()
	enemy.global_position = Vector3(-4, 0, 7)
	hero.global_position = Vector3(4, 0, 7)
	scout.global_position = Vector3(9, 0, -9)
	await physics_frame
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2, 2)
	collision.shape = box
	blocker.add_child(collision)
	var inject := func(id: String, kind: String, accepted: bool) -> void:
		if id == enemy.stable_id and kind == "move" and accepted:
			blocker.position = Vector3(-2.5, 1, 7)
			encounter.add_child(blocker)
	ai.command_submitted.connect(inject)
	begin_enemy()
	await wait_for_turn_end()
	ai.command_submitted.disconnect(inject)
	check(count("move") == 1 and count("end") == 1 and enemy.movement_remaining > 3.0, "Blocked move stops, preserves partial spending, and ends without another move")
	blocker.queue_free()
	await physics_frame
	# Make an affordable planned move invalid immediately before submission.
	await fresh()
	var reject_move := func(message: String) -> void:
		if message.ends_with(" moves"):
			enemy.movement_remaining = 0.0 # Test fixture; production AI never mutates resources.
	ai.status_changed.connect(reject_move)
	begin_enemy()
	await wait_for_turn_end()
	ai.status_changed.disconnect(reject_move)
	check(count("move", false) == 1 and count("move") == 0 and count("end") == 1, "Rejected movement has bounded fallback to End Turn")
	# A target dies after the plan was selected but before attack submission.
	await fresh()
	enemy.global_position = hero.global_position + Vector3(1.5, 0, 0)
	scout.global_position = Vector3(9, 0, 9)
	await physics_frame
	var invalidate_target := func(message: String) -> void:
		if message.contains(" attacks "):
			hero.set_health(0)
	ai.status_changed.connect(invalidate_target)
	begin_enemy()
	await wait_for_turn_end()
	ai.status_changed.disconnect(invalidate_target)
	check(count("attack", false) == 1 and count("attack") == 0 and count("end") == 1, "Stale target attack rejection ends safely")
	# During move, remove the selected hero; reassessment uses remaining living targets.
	await fresh()
	enemy.global_position = Vector3(-4, 0, 7)
	hero.global_position = Vector3(0, 0, 7)
	scout.global_position = Vector3(9, 0, -9)
	await physics_frame
	var kill_target := func(_id: String, kind: String, accepted: bool) -> void:
		if kind == "move" and accepted:
			hero.set_health(0)
	ai.command_submitted.connect(kill_target)
	begin_enemy()
	await wait_for_turn_end()
	ai.command_submitted.disconnect(kill_target)
	check(count("move") == 1 and count("attack") == 0 and count("end") == 1, "Movement completion reassesses targets instead of attacking stale ID")
	# Restart thinking, moving, and attacking; old epochs cannot affect the fresh hero turn.
	await fresh()
	var connection_count := controller.action_completed.get_connections().size()
	for repetition in range(3):
		ai.presentation_delay = 0.3
		begin_enemy()
		await controller.restart_encounter()
		sentinel.set_health(0)
		for frame in range(30):
			await process_frame
		check(controller.scheduler.active_unit() == hero and hero.health == hero.definition.maximum_health and not controller.motor.running, "Restart cancels pending presentation work")
	check(controller.action_completed.get_connections().size() == connection_count, "Repeated restarts do not duplicate completion subscriptions")
	await fresh()
	begin_enemy()
	for frame in range(120):
		await process_frame
		if controller.motor.running:
			break
	check(controller.motor.running, "Movement started before cancellation fixture")
	await controller.restart_encounter()
	var old_count := commands.size()
	for frame in range(60):
		await process_frame
	check(commands.size() == old_count and enemy.global_position == Vector3(4, 0, -3) and hero.health == hero.definition.maximum_health, "Restart during movement cancels old decisions and motor")
	await fresh()
	enemy.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	begin_enemy()
	for frame in range(120):
		await process_frame
		if ai.stage == EnemyController.Stage.WAIT_ATTACK:
			break
	check(ai.stage == EnemyController.Stage.WAIT_ATTACK, "Attack started before cancellation fixture")
	await controller.restart_encounter()
	old_count = commands.size()
	for frame in range(60):
		await process_frame
	check(commands.size() == old_count and hero.health == hero.definition.maximum_health and controller.scheduler.active_unit() == hero, "Restart during attack cancels old completion and damage work")
	# Actor death while delayed cancels even when the scheduled timeout later expires.
	await fresh()
	ai.presentation_delay = 0.3
	begin_enemy()
	enemy.set_health(0)
	for frame in range(60):
		await process_frame
	check(controller.state == CombatController.State.VICTORY and commands.is_empty() and ai.stage == EnemyController.Stage.IDLE, "Actor death and outcome cancel pending AI")
	# Lethal attack stops immediately on shared defeat evaluation, without End Turn.
	await fresh()
	scout.set_health(0)
	hero.set_health(1)
	enemy.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	begin_enemy()
	await wait_for_turn_end()
	old_count = commands.size()
	for frame in range(60):
		await process_frame
	check(controller.state == CombatController.State.DEFEAT and count("attack") == 1 and count("end") == 0 and commands.size() == old_count, "Last hero death stops all further AI actions")
	encounter.queue_free()
	await process_frame
	print("ENEMY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
