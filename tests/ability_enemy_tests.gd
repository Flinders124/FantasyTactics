extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var warden: CombatUnit
var scout: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
var commands: Array[Dictionary] = []
var uses: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh(id: String = "enemy-02") -> void:
	ai.enabled = false
	await controller.restart_encounter()
	while controller.scheduler.active_unit().stable_id != id:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	sentinel.global_position = Vector3(-4, 0, 7)
	raider.global_position = Vector3(-8, 0, -8)
	warden.global_position = Vector3(2, 0, 7)
	scout.global_position = Vector3(8, 0, -8)
	await physics_frame
	await physics_frame
	commands.clear()
	uses.clear()

func begin() -> void:
	ai.enabled = true
	ai.presentation_delay = 0.0
	controller.turn_started.emit(controller.scheduler.active_unit(), controller.turn_serial)

func wait_turn(actor: CombatUnit) -> void:
	for frame in range(900):
		await process_frame
		if controller.scheduler.active_unit() != actor or controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
			return
	check(false, "Ability AI completes turn within watchdog")
	ai.enabled = false

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	warden = controller.find_unit("hero-01")
	scout = controller.find_unit("hero-02")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	ai.command_submitted.connect(func(id: String, kind: String, accepted: bool) -> void: commands.append({"id": id, "kind": kind, "accepted": accepted}))
	controller.combat_event.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "ability":
			uses.append(data.ability))
	await fresh()
	sentinel.set_health(9)
	begin()
	await wait_turn(sentinel)
	check(sentinel.health == 15 and warden.health == 20 and uses == ["Mend"], "AI prioritizes legal self-Mend at exactly 50% over shot")
	check(commands.size() == 2 and commands[0].kind == "attack" and commands[1].kind == "end", "Healing uses one shared action and completes turn")
	await fresh()
	sentinel.set_health(9)
	raider.set_health(8)
	raider.global_position = Vector3(-5.5, 0, 7)
	await physics_frame
	await physics_frame
	begin()
	await wait_turn(sentinel)
	check(raider.health == 14 and sentinel.health == 9 and uses == ["Mend"], "AI heals legal injured friend, deterministic stable-ID tie")
	await fresh()
	sentinel.set_health(10)
	begin()
	await wait_turn(sentinel)
	check(sentinel.health == 10 and warden.health == 18 and warden.statuses.has("slowed") and uses == ["Crippling Shot"], "Above 50% skips Mend and prefers legal offensive ability")
	await fresh()
	sentinel.cooldown_ready_turn["crippling_shot"] = sentinel.owner_turn + 2
	begin()
	await wait_turn(sentinel)
	check(uses.is_empty() and warden.health == 16 and not warden.statuses.has("slowed"), "Cooldown and full-health Mend fall back to basic attack")
	await fresh("enemy-01")
	raider.global_position = Vector3(-4, 0, 7)
	warden.global_position = Vector3(-2.5, 0, 7)
	sentinel.global_position = Vector3(8, 0, -8)
	await physics_frame
	await physics_frame
	begin()
	await wait_turn(raider)
	ai.enabled = false
	check(warden.health == 13 and uses.has("Power Strike"), "Melee AI prefers legal offensive ability")
	# Reject a stale heal between decision and submission; do not retry forever.
	await fresh()
	sentinel.set_health(9)
	var invalidate_heal := func(message: String) -> void:
		if message.contains(" uses Mend"):
			sentinel.set_health(sentinel.definition.maximum_health)
	ai.status_changed.connect(invalidate_heal)
	begin()
	await wait_turn(sentinel)
	ai.status_changed.disconnect(invalidate_heal)
	check(commands.size() == 2 and not commands[0].accepted and commands[1].kind == "end" and sentinel.action_available and sentinel.cooldown_ready_turn.is_empty(), "Rejected AI ability preserves resources and ends safely")
	# Pending ability presentation must not affect a restarted encounter.
	await fresh()
	begin()
	for frame in range(120):
		await process_frame
		if ai.stage == EnemyController.Stage.WAIT_ATTACK:
			break
	check(ai.stage == EnemyController.Stage.WAIT_ATTACK, "Restart fixture reaches real AI ability resolution")
	await controller.restart_encounter()
	for frame in range(60):
		await process_frame
	check(controller.scheduler.active_unit() == warden and controller.state == CombatController.State.AWAITING_COMMAND and ai.stage == EnemyController.Stage.IDLE, "Restart cancels pending AI ability and completion work")
	for unit in controller.units:
		check(unit.health == unit.definition.maximum_health and unit.statuses.is_empty() and unit.cooldown_ready_turn.is_empty(), "Restart restores all ability state")
	var connections := controller.action_completed.get_connections().size()
	for iteration in range(3):
		await controller.restart_encounter()
	check(controller.action_completed.get_connections().size() == connections, "Repeated restart keeps single action-completion subscription")
	# Unreachable/off-map target: no legal spell or basic route, bounded End Turn.
	await fresh()
	warden.global_position = Vector3(40, 0, 40)
	scout.global_position = Vector3(-40, 0, -40)
	await physics_frame
	await physics_frame
	begin()
	await wait_turn(sentinel)
	check(uses.is_empty() and commands.size() == 1 and commands[0].kind == "end", "No useful legal ability or path ends without retries")
	encounter.queue_free()
	await process_frame
	print("ABILITY AI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
