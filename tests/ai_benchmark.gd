extends "res://tests/tactics_tests.gd"
# Opt-in wall-clock benchmark; no combat commands or balance changes.
func run() -> void:
	encounter=load("res://scenes/combat_encounter.tscn").instantiate()
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	for frame in 1600:
		if encounter.navigation_ready:break
		await process_frame
	controller=encounter.get_node("CombatController");ai=encounter.get_node("EnemyController")
	warden=controller.find_unit("hero-01");scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01");sentinel=controller.find_unit("enemy-02")
	var samples: Array[Dictionary]=[]
	for scenario in ["clear_shot","injured_support"]:
		await prepare_range()
		if scenario=="injured_support":
			sentinel.set_health(9);raider.set_health(8);raider.position=Vector3(-2,0,7)
			await physics_frame;await physics_frame
		var times: Array[float]=[]
		var chunks: Array[float]=[]
		var last: Dictionary={}
		for iteration in 60:
			var planner:=EnemyTactics.new()
			planner.begin(controller,sentinel)
			for chunk in 128:
				if planner.done:break
				planner.step()
			check(planner.done,"Benchmark remains bounded")
			last=planner.report()
			if iteration>=10:
				times.append(last.compute_ms);chunks.append(last.max_chunk_ms)
		times.sort();chunks.sort()
		samples.append({"scenario":scenario,"samples":50,"median_ms":times[25],"p95_ms":times[47],"max_ms":times[-1],"max_chunk_ms":chunks[-1],"median_chunk_ms":chunks[25],"p95_chunk_ms":chunks[47],"path_queries":last.path_queries,"action_queries":last.action_queries,"chosen":planner_summary(last)})
	encounter.queue_free();await process_frame;await physics_frame
	check(RegressionReport.write_json("ai-benchmark.json",{"failures":failures,"engine":Engine.get_version_info().string,"samples":samples}),"Benchmark report")
	print("AI BENCHMARK RESULT: %d failures"%failures);quit(0 if failures==0 else 1)

func planner_summary(data: Dictionary) -> Dictionary:
	return {"target":data.target,"ability":data.ability,"moving":data.moving,"action_first":data.action_first}