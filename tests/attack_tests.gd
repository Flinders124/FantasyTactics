extends SceneTree

var failures: int = 0
var controller: CombatController
var encounter: Node3D
var hero: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
var scout: CombatUnit
var death_events: int = 0
var health_events: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_for_action() -> void:
	for frame in range(600):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Action exceeded watchdog")

func restart() -> void:
	await controller.restart_encounter()
	await physics_frame

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	hero = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	scout = controller.find_unit("hero-02")
	var damage := hero.definition.basic_attack.damage
	var attack := AttackCommand.new(hero.stable_id, raider.stable_id)
	check(damage == 4 and is_equal_approx(hero.definition.basic_attack.melee_range, 1.5), "Editable prototype attack values")
	check(not controller.submit_command(AttackCommand.new("missing", raider.stable_id)), "Unknown actor rejected")
	check(not controller.submit_command(AttackCommand.new(scout.stable_id, raider.stable_id)), "Inactive actor rejected")
	check(not controller.submit_command(AttackCommand.new(hero.stable_id, "missing")), "Unknown target rejected")
	check(not controller.submit_command(AttackCommand.new(hero.stable_id, scout.stable_id)), "Friendly target rejected")
	check(not controller.submit_command(AttackCommand.new(hero.stable_id, hero.stable_id)), "Self target rejected")
	check(not controller.submit_command(attack), "Out-of-range target rejected")
	check(hero.attack_available and raider.health == raider.definition.maximum_health, "Invalid attacks spend nothing")
	# Range uses capsule surface gap: 2.2 centre distance equals 1.5 reach.
	raider.global_position = hero.global_position + Vector3(2.2, 0, 0)
	await physics_frame
	check(controller.evaluate_attack(hero, raider).valid(), "Collision-surface range boundary accepted")
	raider.global_position.x += 0.02
	await physics_frame
	check(not controller.evaluate_attack(hero, raider).valid(), "Beyond surface range rejected")
	raider.global_position = hero.global_position + Vector3(2, 0, 0)
	var wall := StaticBody3D.new()
	wall.position = hero.global_position + Vector3(1, 0.8, 0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 1.5, 1)
	collider.shape = shape
	wall.add_child(collider)
	encounter.add_child(wall)
	await physics_frame
	await physics_frame
	check(controller.evaluate_attack(hero, raider).error.contains("obstructed"), "Preview checks wall obstruction")
	check(not controller.submit_command(attack) and hero.attack_available, "Wall rejection does not spend attack")
	wall.queue_free()
	await physics_frame
	await physics_frame
	hero.global_position = Vector3(1.9, 0, 0.5)
	raider.global_position = Vector3(1, 0, 1.4)
	await physics_frame
	check(controller.evaluate_attack(hero, raider).error.contains("obstructed"), "Existing arena obstacle blocks melee across its corner")
	hero.global_position = Vector3(-4, 0, 3)
	# Move, attack, and move again without resetting either resource.
	raider.global_position = Vector3(-1, 0, 3)
	await physics_frame
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3, 0, 3))), "Pre-attack move accepted")
	await wait_for_action()
	var movement_before := hero.movement_remaining
	var health_before := raider.health
	raider.health_changed.connect(func(_unit: CombatUnit) -> void: health_events += 1)
	check(controller.evaluate_attack(hero, raider).valid(), "Preview and command share valid range/obstruction checks")
	check(controller.submit_command(attack), "Valid melee command accepted")
	check(controller.state == CombatController.State.RESOLVING_ACTION, "Attack enters resolving state")
	check(raider.health == health_before - damage and health_events == 1, "Damage applied once immediately")
	check(not hero.attack_available and scout.attack_available == false, "Attack availability is per instance")
	for click in range(5):
		check(not controller.submit_command(attack), "Repeated resolving attack rejected")
	check(not controller.submit_command(EndTurnCommand.new(hero.stable_id)), "End Turn cannot interrupt attack")
	check(not controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3, 0, 2))), "Move cannot interrupt attack")
	var camera := encounter.get_node("TacticalCamera") as TacticalCamera
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	var zoom_before := camera.distance
	camera._unhandled_input(zoom)
	check(camera.distance < zoom_before, "Camera responds during attack resolution")
	# Kill presentation: combat completion must remain independent.
	hero.character.player.stop()
	raider.character.player.stop()
	await wait_for_action()
	check(controller.state == CombatController.State.AWAITING_COMMAND and raider.health == health_before - damage and health_events == 1, "Presentation cannot repeat damage or hold combat open")
	check(not controller.submit_command(attack), "Second attack same turn rejected")
	check(is_equal_approx(hero.movement_remaining, movement_before), "Attack does not spend movement")
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3, 0, 2))), "Post-attack movement accepted")
	await wait_for_action()
	check(hero.movement_remaining < movement_before and hero.movement_remaining > 3.9, "Move-attack-move shares one budget")
	# Next own turn restores attack and movement, not End Turn itself.
	controller.submit_command(EndTurnCommand.new(hero.stable_id))
	check(not hero.attack_available, "End Turn does not replenish attack")
	for turn in range(3):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(hero.attack_available and is_equal_approx(hero.movement_remaining, 6.0), "Own next turn replenishes resources")
	# Kill next scheduled unit; immutable schedule slots preserve living successors.
	raider.set_health(1)
	raider.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	raider.died.connect(func(_unit: CombatUnit) -> void: death_events += 1)
	check(controller.submit_command(attack), "Lethal command accepted")
	check(raider.health == 0 and death_events == 1 and raider.collision_layer == 0 and not raider.input_ray_pickable, "Death clamps HP and disables collision/selection once")
	raider.set_health(-100)
	check(death_events == 1, "Repeated zero health cannot repeat death handling")
	await wait_for_action()
	check(not controller.evaluate_attack(hero, raider).valid(), "Dead target preview rejected")
	hero.attack_available = true # Focused validation fixture.
	check(not controller.submit_command(attack) and hero.attack_available, "Dead target rejected without spending")
	check(controller.evaluate_move(hero, raider.global_position).valid(), "Dead body no longer occupies destination")
	check(controller.submit_command(MoveCommand.new(hero.stable_id, raider.global_position)), "Move into corpse location accepted")
	await wait_for_action()
	check(hero.global_position.distance_to(raider.global_position) < 0.02, "Dead body does not block movement execution")
	controller.submit_command(EndTurnCommand.new(hero.stable_id))
	check(controller.scheduler.active_unit() == sentinel, "Killing next unit does not skip living successor")
	# Restart during an action cancels pending completion without duplicating signals.
	await restart()
	check(controller.scheduler.active_unit() == hero and controller.scheduler.round_number == 1, "Restart restores initiative and round")
	for unit in controller.units:
		check(unit.is_alive() and unit.health == unit.definition.maximum_health and unit.collision_layer == 5, "Restart restores unit health and collision")
	check(hero.global_position == Vector3(-4, 0, 3) and hero.attack_available, "Restart restores spawns and active resources")
	var health_connections := raider.health_changed.get_connections().size()
	raider.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	controller.submit_command(attack)
	await restart()
	for frame in range(30):
		await process_frame
	check(raider.health == raider.definition.maximum_health and hero.attack_available, "Restart cancels old attack completion/effects")
	await restart()
	check(raider.health_changed.get_connections().size() == health_connections, "Restart does not duplicate signal connections")
	check(controller.submit_command(MoveCommand.new(hero.stable_id, hero.global_position + Vector3.RIGHT)), "Movement fixture accepted before restart")
	await restart()
	var motor := encounter.get_node("MovementMotor") as MovementMotor
	check(not motor.running and hero.global_position == Vector3(-4, 0, 3) and is_equal_approx(hero.movement_remaining, 6.0), "Restart cancels motor and restores turn budget")
	# Final-enemy death evaluates victory immediately after damage.
	sentinel.set_health(0)
	raider.set_health(1)
	raider.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	check(controller.submit_command(attack), "Final enemy lethal attack accepted")
	check(controller.state == CombatController.State.VICTORY, "Final enemy damage triggers immediate victory")
	check(not controller.submit_command(EndTurnCommand.new(hero.stable_id)) and not controller.submit_command(attack), "Terminal encounter rejects all gameplay commands")
	var player := encounter.get_node("PlayerController") as PlayerController
	check(not player.attack_mode and player.line.mesh == null, "Encounter completion clears targeting and previews")
	# Same command API supports future enemy AI, and the same evaluator gives defeat.
	await restart()
	scout.set_health(0)
	hero.set_health(1)
	controller.submit_command(EndTurnCommand.new(hero.stable_id))
	raider.global_position = hero.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	check(controller.submit_command(AttackCommand.new(raider.stable_id, hero.stable_id)), "Enemy uses identical AttackCommand")
	check(controller.state == CombatController.State.DEFEAT and hero.health == 0, "Final hero death triggers defeat through shared evaluation")
	check(not controller.submit_command(AttackCommand.new(hero.stable_id, raider.stable_id)), "Dead actor cannot act")
	await restart()
	check(controller.state == CombatController.State.AWAITING_COMMAND and controller.units.all(func(unit: CombatUnit) -> bool: return unit.is_alive()), "Restart after defeat produces playable encounter")
	hero.set_health(9999)
	check(hero.health == hero.definition.maximum_health, "Health clamps to maximum")
	encounter.queue_free()
	await process_frame
	print("ATTACK RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
