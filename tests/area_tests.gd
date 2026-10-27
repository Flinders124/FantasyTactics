extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var scout: CombatUnit
var warden: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
var events: Array[Dictionary] = []
var result_states: Array[int] = []
const POINT: Vector3 = Vector3(0, 0, 7)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh(actor: String = "hero-02") -> void:
	ai.enabled = false
	await controller.restart_encounter()
	while controller.scheduler.active_unit().stable_id != actor:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	scout.global_position = Vector3(-5, 0, 7)
	warden.global_position = Vector3(0, 0, 7)
	raider.global_position = Vector3(1, 0, 7)
	sentinel.global_position = Vector3(9, 0, -9)
	await physics_frame
	await physics_frame
	events.clear()
	result_states.clear()

func wait_action() -> void:
	for frame in range(300):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Area action completes within watchdog")

func ids(preview: AreaTargetingService.Result) -> PackedStringArray:
	var result: PackedStringArray = []
	for hit in preview.hits:
		result.append(hit.unit.stable_id)
	return result

func count(kind: String) -> int:
	var result: int = 0
	for event in events:
		if event.kind == kind:
			result += 1
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	scout = controller.find_unit("hero-02")
	warden = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	controller.combat_event.connect(func(kind: String, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	controller.state_changed.connect(func(state: CombatController.State) -> void:
		if state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
			result_states.append(state))
	await fresh()
	var ability := scout.ability_by_id("fireburst")
	check(ability != null and ability == sentinel.ability_by_id("fireburst"), "One hero/enemy share editable Fireburst definition")
	var preview := controller.evaluate_ground_ability(scout, POINT, "fireburst")
	check(preview.valid() and ids(preview) == PackedStringArray(["enemy-01", "hero-01"]), "Area contains each unit once in stable ID order")
	var duplicate_roster := controller.units.duplicate()
	duplicate_roster.append(raider)
	check(ids(controller.area_targeting.query(scout, ability, POINT, duplicate_roster, controller.navigation)) == ids(preview), "Query deduplicates repeated roster entries")
	# Full 3D radius, including exact inclusive boundary and vertical anchors.
	raider.global_position = POINT + Vector3(2.5, 0, 0)
	check(ids(controller.evaluate_ground_ability(scout, POINT, "fireburst")).has(raider.stable_id), "Exact radius boundary included")
	raider.global_position.x += 0.001
	check(not ids(controller.evaluate_ground_ability(scout, POINT, "fireburst")).has(raider.stable_id), "Beyond radius rejected")
	raider.global_position = POINT + Vector3(1.5, 2, 0)
	check(ids(controller.evaluate_ground_ability(scout, POINT, "fireburst")).has(raider.stable_id), "3D radius boundary included")
	raider.global_position.y += 0.01
	check(not ids(controller.evaluate_ground_ability(scout, POINT, "fireburst")).has(raider.stable_id), "Area inclusion uses full 3D, not flattened positions")
	# Cast distance uses origin marker to actual ground, not the offset blast origin.
	scout.global_position = POINT - Vector3(sqrt(64.0 - 0.64), 0, 0)
	preview = controller.evaluate_ground_ability(scout, POINT, "fireburst")
	check(preview.valid() and absf(preview.distance - 8.0) < 0.00001, "Exact 8 m cast boundary is legal")
	scout.position.x -= 0.001
	check(controller.evaluate_ground_ability(scout, POINT, "fireburst").error == "Out of cast range", "Beyond cast boundary rejected")
	await fresh()
	controller.navigation.ready_for_queries = false
	check(not controller.evaluate_ground_ability(scout, POINT, "fireburst").valid(), "No area query before navigation synchronization")
	controller.navigation.ready_for_queries = true
	for point in [Vector3(INF, 0, 0), Vector3(NAN, 0, 0), Vector3(40, 0, 40), POINT + Vector3.UP * 0.03, Vector3.ZERO]:
		check(not controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", point)), "Invalid/non-ground/obstacle/off-map cast rejected")
	# Strict command shape: absent, incompatible, conflicting and wrong-type targets.
	for command in [UseAbilityCommand.new(scout.stable_id, "", "fireburst"), UseAbilityCommand.new(scout.stable_id, raider.stable_id, "fireburst"), UseAbilityCommand.new(scout.stable_id, raider.stable_id, "fireburst", POINT), UseAbilityCommand.on_ground(scout.stable_id, "mend", POINT), UseAbilityCommand.new(scout.stable_id, "", "fireburst", "bad")]:
		check(not controller.submit_command(command), "Missing/conflicting/incompatible target data rejected")
	check(scout.action_available and scout.cooldown_ready_turn.is_empty(), "All rejected casts spend nothing")
	# Cast wall and corner blast shadow with the same static mask.
	scout.global_position = Vector3(-3, 0, 0)
	await physics_frame
	check(controller.evaluate_ground_ability(scout, Vector3(3, 0, 0), "fireburst").error == "Cast line blocked", "Central arena wall blocks cast")
	scout.global_position = Vector3(-4, 0, 0.6)
	raider.global_position = Vector3(0.2, 0, 1.6)
	warden.global_position = Vector3(-2.8, 0, 1.8)
	await physics_frame
	await physics_frame
	preview = controller.evaluate_ground_ability(scout, Vector3(-2, 0, 0.6), "fireburst")
	check(preview.valid() and not ids(preview).has(raider.stable_id) and ids(preview).has(warden.stable_id), "Wall shields radius-included unit, exposed unit still hit")
	# Intervening living units never shield another candidate or the cast.
	await fresh()
	warden.global_position = POINT + Vector3(1, 0, 0)
	raider.global_position = POINT + Vector3(2, 0, 0)
	await physics_frame
	await physics_frame
	preview = controller.evaluate_ground_ability(scout, POINT, "fireburst")
	check(ids(preview).has(warden.stable_id) and ids(preview).has(raider.stable_id), "Living body does not block blast propagation")
	warden.global_position = Vector3(-2.5, 0, 7)
	await physics_frame
	await physics_frame
	check(controller.evaluate_ground_ability(scout, POINT, "fireburst").valid(), "Living body does not block static-only cast line")
	# Faction flags are relative to actor, and caster has an independent bit.
	var config := ability.duplicate() as AbilityDefinition
	scout.global_position = POINT - Vector3(2, 0, 0)
	warden.global_position = POINT
	config.affected_factions = 1
	check(ids(controller.area_targeting.query(scout, config, POINT, controller.units, controller.navigation)) == PackedStringArray([raider.stable_id]), "Hostile-only area configuration")
	config.affected_factions = 4
	check(ids(controller.area_targeting.query(scout, config, POINT, controller.units, controller.navigation)) == PackedStringArray([scout.stable_id]), "Caster bit independent of allies")
	await fresh()
	scout.global_position = POINT - Vector3(2, 0, 0)
	await physics_frame
	await physics_frame
	preview = controller.evaluate_ground_ability(scout, POINT, "fireburst")
	var before: Dictionary = {}
	for unit in controller.units:
		before[unit.stable_id] = unit.health
	check(controller.submit_player_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)), "Valid area cast accepted")
	for unit in controller.units:
		check(unit.health == int(before[unit.stable_id]) - (3 if ids(preview).has(unit.stable_id) else 0), "Preview and fixed damage match exactly once for " + unit.stable_id)
	check(not scout.action_available and scout.cooldown_ready_turn.size() == 1 and sentinel.cooldown_ready_turn.is_empty(), "One shared action and independent cooldown spent once")
	check(count("area") == 1 and count("area_hit") == preview.hits.size(), "Single area event with one authoritative hit per affected unit")
	check(not controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)), "Repeated input during resolution rejected")
	var live_presentation := encounter.get_node("CombatPresentation") as CombatPresentation
	live_presentation.clear_effects()
	check(live_presentation.blasts.is_empty() and controller.state == CombatController.State.RESOLVING_ACTION, "Deleting presentation does not own gameplay completion")
	await wait_action()
	check(controller.state == CombatController.State.AWAITING_COMMAND and count("area") == 1, "Controller completes independently without duplicate effects")
	check(not controller.submit_command(AttackCommand.new(scout.stable_id, raider.stable_id)), "Area consumes the same action as basic attacks")
	# Recompute membership after state notifications, not an old preview snapshot.
	await fresh()
	var change := func(state: CombatController.State) -> void:
		if state == CombatController.State.RESOLVING_ACTION:
			raider.global_position = Vector3(9, 0, -9)
			sentinel.global_position = POINT + Vector3(1, 0, 0)
	controller.state_changed.connect(change)
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)), "Changing target membership revalidated at commitment")
	controller.state_changed.disconnect(change)
	check(raider.health == 16 and sentinel.health == 15, "Fresh affected snapshot replaces stale preview")
	await wait_action()
	# Simultaneous elimination: no intermediate victory/defeat; exactly one draw.
	await fresh()
	scout.global_position = POINT + Vector3(-1, 0, 0)
	warden.global_position = POINT + Vector3(1, 0, 0)
	raider.global_position = POINT + Vector3(0, 0, -1)
	sentinel.global_position = POINT + Vector3(0, 0, 1)
	for unit in controller.units:
		unit.set_health(3)
	await physics_frame
	await physics_frame
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)), "Lethal all-faction blast accepted")
	check(controller.units.all(func(unit: CombatUnit) -> bool: return not unit.is_alive()), "All snapshot damage applied despite caster death")
	check(controller.state == CombatController.State.DRAW and result_states == [CombatController.State.DRAW] and count("result") == 1 and count("death") == 4, "Atomic draw without conflicting results or duplicate deaths")
	var hud: CanvasLayer = encounter.get_node("HUD")
	check(hud.overlay.visible and hud.overlay_title.text == "DRAW", "Draw uses a single clear result overlay")
	check(not controller.submit_command(EndTurnCommand.new(scout.stable_id)), "Draw rejects gameplay commands")
	var presentation := encounter.get_node("CombatPresentation") as CombatPresentation
	check(presentation.blasts.size() == 1, "Resolved blast has a presentation-only effect")
	await controller.restart_encounter()
	check(presentation.blasts.is_empty() and presentation.effects.is_empty() and not hud.overlay.visible, "Restart clears draw and blast effects")
	# One-faction elimination is also evaluated only after the full snapshot.
	await fresh()
	warden.global_position = Vector3(-8, 0, -8)
	raider.global_position = POINT + Vector3(1, 0, 0)
	sentinel.global_position = POINT - Vector3(1, 0, 0)
	raider.set_health(3)
	sentinel.set_health(3)
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)) and controller.state == CombatController.State.VICTORY and count("result") == 1, "Area killing only enemies yields one victory")
	await fresh()
	scout.global_position = POINT - Vector3(1, 0, 0)
	scout.set_health(3)
	warden.set_health(3)
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)) and controller.state == CombatController.State.DEFEAT and raider.health == 13 and count("result") == 1, "Friendly blast can cause defeat after all target damage")
	# Actor self-kill advances once with surviving factions, never waits forever.
	await fresh()
	scout.global_position = POINT - Vector3(1, 0, 0)
	scout.set_health(3)
	warden.global_position = Vector3(-8, 0, -8)
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id, "fireburst", POINT)), "Self-lethal nonterminal cast accepted")
	check(controller.state == CombatController.State.AWAITING_COMMAND and controller.scheduler.active_unit() == warden and controller.scheduler.round_number == 2, "Dead caster safely advances to next living turn exactly once")
	# Kill the next scheduled actor and another unit; survivor cannot be skipped.
	await fresh("hero-01")
	warden.definition = warden.definition.duplicate() as UnitDefinition
	warden.definition.abilities.append(ability)
	warden.global_position = Vector3(-5, 0, 7)
	scout.global_position = POINT
	raider.global_position = POINT + Vector3(1, 0, 0)
	scout.set_health(3)
	raider.set_health(3)
	check(controller.submit_command(UseAbilityCommand.on_ground(warden.stable_id, "fireburst", POINT)), "Multi-death initiative fixture cast")
	await wait_action()
	check(controller.submit_command(EndTurnCommand.new(warden.stable_id)) and controller.scheduler.active_unit() == sentinel, "Multiple deaths skip dead slots without skipping living successor")
	encounter.queue_free()
	await process_frame
	print("AREA RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
