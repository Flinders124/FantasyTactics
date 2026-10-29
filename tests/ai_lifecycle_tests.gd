extends "res://tests/ai_positioning_tests.gd"
func run() -> void:
	await fixture()
	await fresh()
	for iteration in 3:
		var planner: EnemyTactics=EnemyTactics.new()
		planner.begin(controller,sentinel)
		for step_index in 128:
			if planner.done:break
			planner.step()
		check(planner.done,"Disposable planner finishes")
		var observer: WeakRef=weakref(planner)
		planner=null
		check(observer.get_ref()==null,"Query budget callback cannot retain its owning planner")
	encounter.shutdown();encounter.queue_free();await process_frame;await physics_frame
	print("AI LIFECYCLE RESULT: %d failures"%failures);quit(0 if failures==0 else 1)