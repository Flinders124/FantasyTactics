extends "res://tests/objective_encounter_tests.gd"
var ai_records: Array[Dictionary]=[]

func run() -> void:
	for level in range(3):
		var config := EncounterConfiguration.new()
		config.battlefield_seed=7
		config.difficulty=EncounterOptions.difficulties()[level].duplicate(true) as DifficultyDefinition
		config.resolve_roster()
		var scene := await prepare(config)
		var combat := scene.get_node("CombatController") as CombatController
		var enemy := scene.get_node("EnemyController") as EnemyController
		enemy.enabled=true
		enemy.presentation_delay=0
		enemy.decision_chosen.connect(func(record: Dictionary) -> void:
			var profile := combat.find_unit(record.actor_id).definition.tactical_profile
			check(record.path_queries<=profile.max_path_queries and record.action_queries<=profile.max_action_queries,"Difficulty search respects strict query budget")
			ai_records.append(record.duplicate(true)))
		var counts: Dictionary={}
		enemy.command_submitted.connect(func(_id: String,kind: String,_accepted: bool) -> void:
			var key := str(combat.turn_serial)+kind
			counts[key]=int(counts.get(key,0))+1
			if kind!="end": check(counts[key]<=1,"At most one move and action per enemy turn"))
		var serial := -1
		for frame in range(24000):
			if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=serial and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO:
				serial=combat.turn_serial
				await hero_turn(combat,combat.scheduler.active_unit())
			await process_frame
		check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW] and enemy.stage==EnemyController.Stage.IDLE,"Every difficulty reaches result and cancels AI")
		outcomes.append({"difficulty":config.difficulty.stable_id,"result":CombatController.State.keys()[combat.state],"round":combat.scheduler.round_number,"reason":combat.outcome_reason})
		print("DIFFICULTY PLAY ",outcomes[-1])
		await dispose(scene)
	check(RegressionReport.write_json("difficulty/encounters.json",{"outcomes":outcomes,"decisions":ai_records}),"Regression report written")
	print("DIFFICULTY ENCOUNTER RESULT: %d failures; provisional bot comparisons, not player balance evidence"%failures)
	quit(0 if failures==0 else 1)
