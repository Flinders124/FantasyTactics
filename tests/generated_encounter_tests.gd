extends "res://tests/playable_encounter_tests.gd"

var flow: SceneFlow

func attack_if_legal(actor: CombatUnit) -> bool:
	if not actor.action_available:
		return false
	for ability in actor.definition.abilities:
		if ability.effect == AbilityDefinition.Effect.HEAL:
			for friend in controller.units:
				if friend.faction == actor.faction and friend.health * 2 <= friend.definition.maximum_health and controller.evaluate_ability(actor, friend, ability.stable_id).valid():
					return controller.submit_player_command(UseAbilityCommand.new(actor.stable_id, friend.stable_id, ability.stable_id))
	var area := ai.choose_area(actor)
	if area != null:
		return controller.submit_player_command(UseAbilityCommand.on_ground(actor.stable_id, area.ability_id, area.point))
	for ability in actor.definition.abilities:
		if ability.effect == AbilityDefinition.Effect.DAMAGE and ability.targeting != AbilityDefinition.Target.GROUND and ability.magnitude > actor.definition.basic_attack.damage:
			for target in ai.living_targets(actor):
				if controller.evaluate_ability(actor, target, ability.stable_id).valid():
					return controller.submit_player_command(UseAbilityCommand.new(actor.stable_id, target.stable_id, ability.stable_id))
	return super.attack_if_legal(actor)

func start_case(seed_value: int, heroes: PackedStringArray) -> void:
	var config := EncounterConfiguration.new()
	config.battlefield_seed = seed_value
	config.hero_ids = heroes
	flow.start_configuration(config)
	(flow.combat.get_node("EnemyController") as EnemyController).enabled = false
	for frame in range(1600):
		await process_frame
		if flow.screen != "loading":
			break
	check(flow.screen == "combat", "Generated complete-encounter fixture is playable")
	flow.combat.guide.close() # Acknowledge the new blocking objective briefing.
	encounter = flow.combat
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	commands_per_turn.clear()
	serials.clear()
	positions.clear()
	distances.clear()
	ai.presentation_delay = 0.0
	controller.motor.movement_speed = 12.0
	ai.routine_started.connect(_on_routine)
	ai.command_submitted.connect(_on_command)
	controller.motor.progress.connect(_on_progress)
	controller.turn_started.connect(func(_unit: CombatUnit, _serial: int) -> void:
		if controller.scheduler.round_number > 60:
			check(false, "Generated scenario exceeds 60-round test policy limit")
			quit(1))
	ai.enabled = true
	if controller.scheduler.active_unit().faction == CombatUnit.Faction.ENEMY:
		controller.turn_started.emit(controller.scheduler.active_unit(), controller.turn_serial)

func run() -> void:
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	for seed_value in [7, 19]:
		await start_case(seed_value, PackedStringArray(["knight", "ranger"]))
		await simulate(true)
		check(terminal(), "Generated encounter completes with automatic enemies and real hero commands")
		print("Generated seed ", seed_value, " knight/ranger: ", CombatController.State.keys()[controller.state], " round ", controller.scheduler.round_number)
	await start_case(11, PackedStringArray(["mage", "cleric"]))
	await simulate(true)
	check(terminal(), "Mage/Cleric encounter completes using existing ability rules")
	print("Generated seed 11 mage/cleric: ", CombatController.State.keys()[controller.state], " round ", controller.scheduler.round_number)
	await start_case(7, PackedStringArray(["knight", "ranger"]))
	await simulate(false)
	check(controller.state == CombatController.State.DEFEAT, "Generated battlefield enemies defeat passive heroes automatically")
	print("Generated passive heroes: ", CombatController.State.keys()[controller.state], " round ", controller.scheduler.round_number)
	flow.show_title()
	for frame in range(10):
		await process_frame
	flow.queue_free()
	await process_frame
	print("GENERATED ENCOUNTER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

