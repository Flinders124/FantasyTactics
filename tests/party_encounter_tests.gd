extends "res://tests/generated_encounter_tests.gd"

func run() -> void:
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	var ids: PackedStringArray = ["knight", "ranger", "mage", "cleric"]
	for first in range(ids.size()):
		for second in range(first + 1, ids.size()):
			var party_ids := PackedStringArray([ids[first],ids[second]])
			await start_case(7,party_ids)
			check(controller.units[0].definition == HeroCatalog.find(ids[first]) and controller.units[1].definition == HeroCatalog.find(ids[second]), "Selected definitions match spawned heroes")
			check(controller.navigation.ready_for_queries and flow.combat.navigation_ready, "Every party starts after navigation is ready")
			await simulate(true)
			check(terminal(), "Every pair reaches an encounter result")
			print("PARTY ", ids[first],"/",ids[second],": ",CombatController.State.keys()[controller.state]," round ",controller.scheduler.round_number)
	flow.show_title()
	for frame in range(12):
		await process_frame
	check(flow.retired.is_empty(),"All six party encounters retire cleanly")
	flow.free()
	await process_frame
	print("PARTY ENCOUNTER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
