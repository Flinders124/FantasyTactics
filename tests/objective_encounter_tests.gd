extends "res://tests/generation_tests.gd"
var outcomes: Array[Dictionary]=[]

func action_wait(combat: CombatController) -> void:
	for frame in range(1000):
		if combat.state!=CombatController.State.RESOLVING_ACTION: return
		await process_frame
	check(false,"Objective action timeout")

func hero_turn(combat: CombatController, actor: CombatUnit) -> void:
	var plan := EnemyTactics.new()
	plan.begin(combat,actor)
	while not plan.done:
		plan.step()
		await process_frame
	var choice := plan.best
	if choice.action!=null and (not choice.moving or choice.action_first):
		combat.submit_player_command(choice.action.command(actor.stable_id))
		await action_wait(combat)
	if combat.state!=CombatController.State.AWAITING_COMMAND: return
	if choice.moving:
		combat.submit_player_command(MoveCommand.new(actor.stable_id,choice.destination))
		await action_wait(combat)
	if combat.state!=CombatController.State.AWAITING_COMMAND: return
	if actor.action_available:
		var fresh := EnemyTactics.new()
		fresh.begin(combat,actor,false,true)
		if fresh.best.action!=null:
			combat.submit_player_command(fresh.best.action.command(actor.stable_id))
			await action_wait(combat)
	if combat.state==CombatController.State.AWAITING_COMMAND: combat.submit_player_command(EndTurnCommand.new(actor.stable_id))

func run() -> void:
	for kind in range(3):
		var config := EncounterConfiguration.new()
		config.generator_settings=EncounterOptions.presets()[kind].duplicate(true) as BattlefieldSettings
		config.objective=EncounterOptions.objectives()[kind]
		config.battlefield_seed=7
		var encounter := await prepare(config)
		check(encounter.navigation_ready,"Objective encounter ready")
		var combat := encounter.get_node("CombatController") as CombatController
		var enemy := encounter.get_node("EnemyController") as EnemyController
		enemy.enabled=true
		enemy.presentation_delay=0
		var last_serial := -1
		var turns := 0
		for frame in range(24000):
			if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=last_serial:
				var actor := combat.scheduler.active_unit()
				if actor.faction==CombatUnit.Faction.HERO:
					last_serial=combat.turn_serial
					turns+=1
					await hero_turn(combat,actor)
			await process_frame
		check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW],"Objective reaches result without stalled turns")
		outcomes.append({"objective":config.objective.stable_id,"preset":config.generator_settings.preset_id,"result":CombatController.State.keys()[combat.state],"reason":combat.outcome_reason,"round":combat.scheduler.round_number,"hero_turns":turns})
		print("OBJECTIVE PLAY ",outcomes[-1])
		check(enemy.stage==EnemyController.Stage.IDLE,"Outcome cancels objective AI")
		await dispose(encounter)
	check(RegressionReport.write_json("objectives/encounters.json",outcomes),"Regression report written")
	print("OBJECTIVE ENCOUNTER RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
