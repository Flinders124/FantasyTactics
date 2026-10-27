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
var area_uses: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	ai.enabled = false
	await controller.restart_encounter()
	for turn in range(2):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	sentinel.global_position = Vector3(-5, 0, 7)
	warden.global_position = Vector3(0, 0, 7)
	scout.global_position = Vector3(2, 0, 7)
	raider.global_position = Vector3(-9, 0, -9)
	await physics_frame
	await physics_frame
	commands.clear()
	area_uses = 0

func begin() -> void:
	ai.enabled = true
	ai.presentation_delay = 0.0
	controller.turn_started.emit(sentinel, controller.turn_serial)

func wait_turn() -> void:
	for frame in range(900):
		await process_frame
		if controller.scheduler.active_unit() != sentinel or controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
			return
	check(false, "Area AI turn completes within watchdog")
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
	controller.combat_event.connect(func(kind: String, _data: Dictionary) -> void:
		if kind == "area":
			area_uses += 1)
	ai.command_submitted.connect(func(id: String, kind: String, accepted: bool) -> void: commands.append({"id": id, "kind": kind, "accepted": accepted}))
	await fresh()
	var choice := ai.choose_area(sentinel)
	check(choice != null and choice.point == warden.ground_anchor() and choice.score == 6, "Safe two-opponent area selected with stable equal-score tie")
	var repeat := ai.choose_area(sentinel)
	check(repeat != null and repeat.point == choice.point, "Bounded candidate search is deterministic")
	begin()
	await wait_turn()
	check(area_uses == 1 and warden.health == 17 and scout.health == 11 and sentinel.health == 18 and raider.health == 16, "AI uses one legal blast without friendly fire")
	check(commands.size() == 2 and commands[0].kind == "attack" and commands[0].accepted and commands[1].kind == "end", "Area obeys one-action limit and ends turn")
	# Nearby pair midpoint is necessary when neither target centre catches both.
	await fresh()
	warden.global_position = Vector3(-1, 0, 7)
	scout.global_position = Vector3(3, 0, 7)
	choice = ai.choose_area(sentinel)
	check(choice != null and choice.point == Vector3(1, 0, 7), "Midpoint candidate catches separated pair when centre candidates cannot")
	await fresh()
	raider.global_position = Vector3(0.5, 0, 7)
	check(ai.choose_area(sentinel) == null, "Area AI rejects every candidate affecting an ally")
	await fresh()
	sentinel.global_position = Vector3(1, 0, 9)
	check(ai.choose_area(sentinel) == null, "Area AI rejects candidates affecting caster")
	await fresh()
	scout.global_position = Vector3(9, 0, 9)
	check(ai.choose_area(sentinel) == null, "Area requires two opponents, not one useful hit")
	begin()
	await wait_turn()
	check(area_uses == 0 and warden.health == 18 and warden.statuses.has("slowed"), "Single target falls back to existing offensive ability and completes")
	await fresh()
	sentinel.cooldown_ready_turn["fireburst"] = sentinel.owner_turn + 2
	begin()
	await wait_turn()
	check(area_uses == 0 and warden.health == 18, "Area cooldown falls back safely")
	await fresh()
	sentinel.set_health(9)
	begin()
	await wait_turn()
	check(area_uses == 0 and sentinel.health == 15 and warden.health == 20 and scout.health == 14, "Existing critical-health Mend preference preserved before area")
	# Rejected area command must not create a second attempt or hang.
	await fresh()
	var reject := func(message: String) -> void:
		if message.contains(" uses Fireburst"):
			sentinel.cooldown_ready_turn["fireburst"] = sentinel.owner_turn + 1
	ai.status_changed.connect(reject)
	begin()
	await wait_turn()
	ai.status_changed.disconnect(reject)
	check(area_uses == 0 and commands.size() == 2 and not commands[0].accepted and commands[1].kind == "end" and sentinel.action_available, "Rejected area command ends with bounded recovery, no action spending")
	await fresh()
	warden.global_position = Vector3(40, 0, 40)
	scout.global_position = Vector3(-40, 0, -40)
	begin()
	await wait_turn()
	check(area_uses == 0 and commands.size() == 1 and commands[0].kind == "end", "Unreachable targets cannot trap area AI in its turn")
	# Restart while a real AI blast is resolving; no stale action on restored units.
	await fresh()
	begin()
	for frame in range(120):
		await process_frame
		if ai.stage == EnemyController.Stage.WAIT_ATTACK:
			break
	check(ai.stage == EnemyController.Stage.WAIT_ATTACK and area_uses == 1, "Restart fixture reaches real AI Fireburst")
	await controller.restart_encounter()
	for frame in range(60):
		await process_frame
	check(controller.scheduler.active_unit() == warden and controller.state == CombatController.State.AWAITING_COMMAND and ai.stage == EnemyController.Stage.IDLE, "Restart invalidates old area routine and completion work")
	check(controller.units.all(func(unit: CombatUnit) -> bool: return unit.health == unit.definition.maximum_health and unit.cooldown_ready_turn.is_empty()), "Restart restores blast damage and cooldowns")
	var presentation := encounter.get_node("CombatPresentation") as CombatPresentation
	check(presentation.blasts.is_empty(), "Restart clears pending blast effects")
	encounter.queue_free()
	await process_frame
	print("AREA AI RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
