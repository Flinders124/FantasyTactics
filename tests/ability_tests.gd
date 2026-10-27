extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var ai: EnemyController
var warden: CombatUnit
var scout: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
var events: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_action() -> void:
	for frame in range(300):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Action completes within watchdog")

func fresh(actor_id: String = "hero-01") -> void:
	ai.enabled = false
	await controller.restart_encounter()
	while controller.scheduler.active_unit().stable_id != actor_id:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	warden.global_position = Vector3(-4, 0, 7)
	scout.global_position = Vector3(-8, 0, -8)
	raider.global_position = Vector3(-2.5, 0, 7)
	sentinel.global_position = Vector3(8, 0, -8)
	await physics_frame
	await physics_frame
	events.clear()

func cycle(actor: CombatUnit) -> void:
	check(controller.submit_command(EndTurnCommand.new(actor.stable_id)), "Owner ends turn")
	for turn in range(4):
		if controller.scheduler.active_unit() == actor:
			return
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(false, "Owner receives next scheduled turn")

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
	warden = controller.find_unit("hero-01")
	scout = controller.find_unit("hero-02")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	controller.combat_event.connect(func(kind: String, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	await fresh()
	check(warden.ability_by_id("power_strike") != null and scout.ability_by_id("crippling_shot") != null and sentinel.ability_by_id("mend") != null, "Editable roster equips all three abilities")
	var power := UseAbilityCommand.new(warden.stable_id, raider.stable_id, "power_strike")
	for invalid in [UseAbilityCommand.new(warden.stable_id, scout.stable_id, "power_strike"), UseAbilityCommand.new(warden.stable_id, raider.stable_id, "missing"), UseAbilityCommand.new(scout.stable_id, raider.stable_id, "crippling_shot")]:
		check(not controller.submit_command(invalid), "Invalid actor, faction or unequipped ability rejects")
	check(warden.action_available and warden.cooldown_ready_turn.is_empty(), "Rejected abilities spend no action or cooldown")
	var before := raider.health
	check(controller.evaluate_ability(warden, raider, "power_strike").valid(), "Legal ability preview")
	check(controller.submit_player_command(power), "Power Strike accepted")
	check(raider.health == before - 7 and not warden.action_available and not warden.attack_available, "Power damage and shared action committed once")
	check(not controller.submit_command(power) and not controller.submit_command(AttackCommand.new(warden.stable_id, raider.stable_id)), "Repeated input during resolution rejected")
	await wait_action()
	var ready_turn: int = warden.cooldown_ready_turn["power_strike"]
	for frame in range(30):
		await process_frame
	check(warden.cooldown_ready_turn["power_strike"] == ready_turn and warden.owner_turn == 1, "Elapsed time never advances cooldown")
	check(count("ability") == 1 and count("attack") == 1, "Single authoritative use and damage event")
	check(not controller.submit_command(AttackCommand.new(warden.stable_id, raider.stable_id)), "Ability blocks basic attack for rest of turn")
	check(not controller.submit_command(UseAbilityCommand.new(warden.stable_id, warden.stable_id, "mend")), "Ability blocks other abilities")
	check(controller.evaluate_move(warden, Vector3(-4, 0, 6)).valid(), "Movement remains available after ability")
	for owner_index in range(2):
		cycle(warden)
		check(warden.action_available and not controller.evaluate_ability(warden, raider, "power_strike").valid(), "Cooldown blocks subsequent owner turn %d" % (owner_index + 1))
		check(not controller.submit_command(power) and warden.action_available, "Cooldown rejection preserves new action")
	cycle(warden)
	check(controller.evaluate_ability(warden, raider, "power_strike").valid(), "Available at start following two blocked owner turns")
	check(warden.ability_by_id("power_strike") == raider.ability_by_id("power_strike") and raider.cooldown_ready_turn.is_empty(), "Shared ability definition has independent cooldowns")
	# Actual movement on both sides of an ability shares the normal movement budget.
	await fresh()
	check(controller.submit_command(MoveCommand.new(warden.stable_id, Vector3(-4, 0, 6.5))), "Move before ability")
	await wait_action()
	check(controller.submit_command(power), "Ability after movement")
	await wait_action()
	check(controller.submit_command(MoveCommand.new(warden.stable_id, Vector3(-4, 0, 6))), "Move after ability")
	await wait_action()
	check(absf(warden.movement_remaining - 5.0) < 0.02, "Movement on both sides charges only its actual one metre")
	# Range and LOS failures use the same preview and submission geometry.
	await fresh()
	raider.global_position = Vector3(5, 0, 7)
	await physics_frame
	check(not controller.evaluate_ability(warden, raider, "power_strike").valid() and not controller.submit_command(power), "Out-of-range ability rejected")
	warden.global_position = Vector3(2.4, 0, 0.3)
	raider.global_position = Vector3(0.6, 0, 1.5)
	await physics_frame
	await physics_frame
	check(controller.evaluate_ability(warden, raider, "power_strike").error.contains("obstructed") and not controller.submit_command(power), "Wall blocks ability through shared geometry")
	check(warden.action_available and warden.cooldown_ready_turn.is_empty(), "Range and obstruction rejection spends nothing")
	# Reverse action order: basic attack excludes all abilities.
	await fresh()
	check(controller.submit_command(AttackCommand.new(warden.stable_id, raider.stable_id)), "Basic attack still works")
	await wait_action()
	check(not controller.submit_command(power) and warden.cooldown_ready_turn.is_empty(), "Basic attack blocks ability without starting cooldown")
	# Mend, including self and friendly targets, no resurrection/full-health use.
	await fresh()
	var mend := UseAbilityCommand.new(warden.stable_id, warden.stable_id, "mend")
	check(not controller.submit_command(mend), "Full-health Mend rejected")
	warden.set_health(19)
	check(controller.evaluate_ability(warden, warden, "mend").valid(), "Self-heal preview legal")
	check(controller.submit_command(mend), "Mend supports self")
	check(warden.health == 20 and count("heal") == 1 and events[-1].data.healing == 1, "Healing clamped, actual amount logged once")
	await wait_action()
	await fresh()
	scout.global_position = Vector3(-5, 0, 7)
	scout.set_health(4)
	await physics_frame
	await physics_frame
	check(controller.submit_command(UseAbilityCommand.new(warden.stable_id, scout.stable_id, "mend")), "Mend supports injured friendly")
	check(scout.health == 10, "Friendly healing magnitude")
	await wait_action()
	await fresh()
	raider.set_health(4)
	check(controller.evaluate_ability(warden, raider, "mend").error.contains("friendly") and not controller.submit_command(UseAbilityCommand.new(warden.stable_id, raider.stable_id, "mend")), "Mend rejects injured enemy with correct reason")
	scout.set_health(0)
	check(not controller.submit_command(UseAbilityCommand.new(warden.stable_id, scout.stable_id, "mend")) and warden.action_available and warden.cooldown_ready_turn.is_empty(), "Mend cannot resurrect or spend on invalid targets")
	# Actual shot applies independent runtime slow; movement allocation waits for future turn.
	await fresh("hero-02")
	scout.global_position = Vector3(-4, 0, 7)
	warden.global_position = Vector3(-8, 0, -8)
	raider.global_position = Vector3(2, 0, 7)
	await physics_frame
	await physics_frame
	var shot := UseAbilityCommand.new(scout.stable_id, raider.stable_id, "crippling_shot")
	check(controller.evaluate_ability(scout, raider, "crippling_shot").valid(), "Shared ranged ability preview legal")
	before = raider.health
	check(controller.submit_command(shot), "Crippling Shot accepted")
	check(raider.health == before - 2 and raider.statuses.has("slowed") and count("status_apply") == 1, "Reduced damage and slow applied once")
	check(raider.movement_remaining == 6.0, "Application does not retroactively change granted movement")
	await wait_action()
	controller.submit_command(EndTurnCommand.new(scout.stable_id))
	controller.submit_command(EndTurnCommand.new(warden.stable_id))
	check(controller.scheduler.active_unit() == raider and raider.movement_remaining == 3.0 and raider.action_available, "First future turn receives half base movement and full action")
	check(raider.definition.movement_allowance == 6.0 and raider.definition.initiative == 14, "Base stats and initiative never modified")
	var slow := load("res://definitions/slowed.tres") as StatusEffectDefinition
	var movement_before := raider.movement_remaining
	raider.apply_status(slow)
	check(raider.statuses.size() == 1 and raider.movement_remaining == movement_before and count("status_refresh") == 1, "Refresh does not stack or change current movement")
	cycle(raider)
	check(raider.movement_remaining == 3.0 and (raider.statuses["slowed"] as StatusEffectInstance).future_turns == 1, "Refresh grants first additional affected turn")
	cycle(raider)
	check(raider.movement_remaining == 3.0 and raider.statuses.has("slowed"), "Second refreshed turn remains slowed until its end")
	controller.submit_command(EndTurnCommand.new(raider.stable_id))
	check(raider.statuses.is_empty() and count("status_expire") == 1, "Expires exactly after second affected turn end")
	while controller.scheduler.active_unit() != raider:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(raider.movement_remaining == 6.0, "Next allocation restored from base without repeated multiplication")
	# No-refresh exact duration, shared status definition isolation and death skipping.
	await fresh()
	raider.apply_status(slow)
	for frame in range(30):
		await process_frame
	check((raider.statuses["slowed"] as StatusEffectInstance).future_turns == 2, "Elapsed time never advances status duration")
	sentinel.apply_status(slow)
	check(raider.statuses["slowed"] != sentinel.statuses["slowed"], "Shared status configuration creates independent instances")
	controller.submit_command(EndTurnCommand.new(warden.stable_id))
	check(raider.movement_remaining == 3.0, "Unrefreshed first affected allocation")
	cycle(raider)
	check(raider.movement_remaining == 3.0, "Unrefreshed second affected allocation")
	controller.submit_command(EndTurnCommand.new(raider.stable_id))
	check(raider.statuses.is_empty(), "Unrefreshed duration exactly two turns")
	sentinel.set_health(0)
	check(sentinel.statuses.is_empty(), "Death clears runtime status and skipped turn is safe")
	# Stale precommit validation and restart during presentation.
	await fresh()
	var invalidate := func(state: CombatController.State) -> void:
		if state == CombatController.State.RESOLVING_ACTION:
			raider.global_position = Vector3(8, 0, 8)
	controller.state_changed.connect(invalidate)
	check(not controller.submit_command(power), "Ability revalidates after state notification")
	controller.state_changed.disconnect(invalidate)
	check(warden.action_available and warden.cooldown_ready_turn.is_empty() and controller.state == CombatController.State.AWAITING_COMMAND, "Late invalidation spends nothing and restores control")
	await fresh()
	check(controller.submit_command(power), "Start restart fixture")
	warden.apply_status(slow)
	await controller.restart_encounter()
	await wait_action()
	for unit in controller.units:
		check(unit.statuses.is_empty() and unit.cooldown_ready_turn.is_empty() and unit.health == unit.definition.maximum_health, "Restart restores clean runtime state")
	var connections := warden.runtime_event.get_connections().size()
	for iteration in range(3):
		await controller.restart_encounter()
	check(warden.runtime_event.get_connections().size() == connections, "Repeated restart does not duplicate runtime-event subscriptions")
	var presentation := encounter.get_node("CombatPresentation") as CombatPresentation
	check(presentation.effects.is_empty() and presentation.tracers.is_empty(), "Restart clears presentation")
	# Real player buttons, shortcut, preview and one command, including self picking.
	await fresh()
	warden.set_health(10)
	warden.global_position = Vector3(-4, 0, 3)
	await physics_frame
	await physics_frame
	var player := encounter.get_node("PlayerController") as PlayerController
	var hud: CanvasLayer = encounter.get_node("HUD")
	await process_frame
	check(hud.ability_buttons[1].visible and not hud.ability_buttons[1].disabled and hud.ability_buttons[1].tooltip_text.contains("shared action"), "Ability buttons explain cost and availability")
	hud.ability_buttons[1].pressed.emit()
	check(player.selected_ability_id == "mend" and player.attack_mode, "Ability button reuses targeting mode")
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	var screen := camera.unproject_position(warden.global_position + Vector3.UP * 1.3)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	player._process(0.0)
	check(player.hovered_target == warden and hud.attack_preview_label.text.contains("6 healing"), "Self-target preview displays actual healing")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = screen
	click.global_position = screen
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	check(warden.health == 16 and not warden.action_available and not controller.motor.running, "Ability click submits once without movement")
	await wait_action()
	await controller.restart_encounter()
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	player._unhandled_input(key)
	check(player.selected_ability_id == "power_strike", "1 shortcut selects first equipped ability")
	player.cancel_targeting()
	check(player.selected_ability_id.is_empty(), "Cancel clears selected ability")
	encounter.queue_free()
	await process_frame
	print("ABILITY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)



