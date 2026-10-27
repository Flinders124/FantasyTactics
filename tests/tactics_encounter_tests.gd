extends "res://tests/generated_encounter_tests.gd"
var decisions: Array[Dictionary] = []
var outcomes: Array[Dictionary] = []
var victories: int = 0

func observe_decision(data: Dictionary) -> void:
	check(data.path_queries<=48 and data.action_queries<=768 and data.evaluated_positions<=24,"Every runtime decision respects default query/candidate limits")
	check(data.turn_path_queries<=144 and data.turn_action_queries<=3072,"Turn totals stay bounded across replans")
	check(data.seed==flow.current_configuration.battlefield_seed and data.actor_id.begins_with("enemy-"),"Structured diagnostics identify current battlefield and actor")
	decisions.append(data.duplicate(true))

func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	var cases: Array[Dictionary] = [{"seed":7,"party":PackedStringArray(["knight","ranger"])},{"seed":19,"party":PackedStringArray(["knight","ranger"])},{"seed":23,"party":PackedStringArray(["mage","cleric"])},{"seed":31,"party":PackedStringArray(["knight","mage"])}]
	for scenario in cases:
		await start_case(scenario.seed,scenario.party)
		ai.decision_chosen.connect(observe_decision)
		await simulate(true)
		check(terminal(),"Complete generated tactical encounter finishes")
		var state: String = CombatController.State.keys()[controller.state]
		if controller.state==CombatController.State.VICTORY: victories+=1
		outcomes.append({"seed":scenario.seed,"party":scenario.party,"outcome":state,"round":controller.scheduler.round_number})
		print("TACTICAL ENCOUNTER ",scenario.seed," ",scenario.party,": ",state," round ",controller.scheduler.round_number)
	check(victories>0,"At least one full generated encounter reaches victory against improved enemies")
	var max_compute := 0.0
	var max_chunk := 0.0
	for data in decisions:
		max_compute=maxf(max_compute,data.compute_ms)
		max_chunk=maxf(max_chunk,data.max_chunk_ms)
	check(RegressionReport.write_json("tactics/encounter-decisions.json",{"outcomes":outcomes,"decision_count":decisions.size(),"max_compute_ms":max_compute,"max_chunk_ms":max_chunk,"decisions":decisions}),"Regression report written")
	flow.show_title()
	for frame in range(12): await process_frame
	check(flow.retired.is_empty(),"Tactical encounters retire all old controllers and effects")
	flow.queue_free()
	await process_frame
	print("TACTICS ENCOUNTER RESULT: %d failures; %d decisions; max total %.3f ms, max chunk %.3f ms"%[failures,decisions.size(),max_compute,max_chunk])
	quit(0 if failures==0 else 1)
