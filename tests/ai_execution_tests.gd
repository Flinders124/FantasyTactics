extends "res://tests/enemy_tests.gd"
## Real controller lifecycle with controlled completion-boundary fault injection.
func memory(id: String) -> Dictionary:
	if ai.has_method("memory_snapshot"): return ai.call("memory_snapshot",id)
	return {"positions":[],"failed_endpoints":[]}

func next_enemy_without_frames() -> void:
	ai.cancel()
	for step in range(8):
		var unit := controller.scheduler.active_unit()
		check(controller.submit_command(EndTurnCommand.new(unit.stable_id)),"Fixture advances through real turns")
		if controller.scheduler.active_unit()==enemy: return
	check(false,"Fixture reaches enemy turn")

func run() -> void:
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	for frame in range(1600):
		if encounter.navigation_ready: break
		await physics_frame
	check(encounter.navigation_ready,"Execution fixture navigation ready")
	controller = encounter.get_node("CombatController") as CombatController
	ai = encounter.get_node("EnemyController") as EnemyController
	hero = controller.find_unit("hero-01")
	scout = controller.find_unit("hero-02")
	enemy = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	ai.presentation_delay = 0.0
	ai.command_submitted.connect(_record)
	ai.routine_started.connect(func(_id: String, serial: int) -> void: routines.append(serial))
	if encounter.guide!=null: encounter.guide.close()
	ai.enabled = true
	begin_enemy()
	var first_position := enemy.global_position
	controller.turn_started.emit(enemy,controller.turn_serial)
	check(routines.size()==1,"Duplicate turn signal launches exactly one routine")
	check(memory(enemy.stable_id).positions.size()==1,"Turn start stores one actual actor position despite duplicate signal")
	for turn in range(4):
		enemy.global_position += Vector3(0.1,0,0)
		next_enemy_without_frames()
	var history: Array = memory(enemy.stable_id).positions
	check(history.size()==3,"Recent start positions retain at most last three turns")
	if history.size()==3:
		check(history[-1]==enemy.global_position and history[0]!=first_position,"History retains latest real start positions")
	# Freeze execution but preserve its planner, then inject a physical failure completion.
	ai._begin_plan(enemy)
	ai.planner.best.destination = enemy.global_position+Vector3(1,0,0)
	ai.stage = EnemyController.Stage.WAIT_MOVE
	ai._on_action_completed(enemy.stable_id,"move","Movement blocked; travelled distance spent")
	var blocked: Array = memory(enemy.stable_id).failed_endpoints
	check(blocked.size()==1,"Physical blocked completion remembers the failed endpoint")
	if blocked.size()==1:
		check(blocked[0].distance_to(enemy.global_position+Vector3(1,0,0))<0.001,"Failure memory stores attempted destination")
	ai._begin_plan(enemy)
	check(memory(enemy.stable_id).failed_endpoints.size()==1,"Unchanged world preserves failure suppression")
	enemy.global_position += Vector3(0.2,0,0)
	ai._begin_plan(enemy)
	check(memory(enemy.stable_id).failed_endpoints.size()==1,"Sub-threshold actor motion preserves failed endpoint")
	enemy.global_position += Vector3(0.4,0,0)
	ai._begin_plan(enemy)
	check(memory(enemy.stable_id).failed_endpoints.is_empty(),"Actor movement over half metre invalidates failure")
	for index in range(5):
		ai._begin_plan(enemy)
		ai.planner.best.destination = enemy.global_position+Vector3(index+1,0,0)
		ai.stage = EnemyController.Stage.WAIT_MOVE
		ai._on_action_completed(enemy.stable_id,"move","Movement blocked; travelled distance spent")
	check(memory(enemy.stable_id).failed_endpoints.size()==3,"Failed endpoint records remain bounded to three")
	hero.global_position += Vector3(0.1,0,0)
	ai._begin_plan(enemy)
	check(memory(enemy.stable_id).failed_endpoints.is_empty(),"Changed unit occupancy permits reconsidering failed endpoint")
	ai._begin_plan(enemy)
	ai.planner.best.moving = true
	ai.planner.best.action = null
	ai.planner.best.destination = Vector3(999,0,999)
	ai.move_attempted = false
	ai._execute_plan(enemy)
	check(count("move",false)==1 and memory(enemy.stable_id).failed_endpoints.size()==1,"Rejected real movement command records endpoint without retry")
	ai._begin_plan(enemy)
	var old_iteration := NavigationServer3D.map_get_iteration_id(controller.navigation.map)
	NavigationServer3D.map_force_update(controller.navigation.map)
	if NavigationServer3D.map_get_iteration_id(controller.navigation.map)!=old_iteration:
		check(memory(enemy.stable_id).failed_endpoints.is_empty(),"Navigation revision invalidates endpoint failures")
	ai._begin_plan(enemy)
	var cursor := ai.planner.cursor
	controller.guidance_paused = true
	ai._process(0.016)
	check(ai.planner!=null and ai.planner.cursor==cursor,"Guidance pause prevents planner advancement")
	controller.guidance_paused = false
	var stale_epoch := ai.epoch
	var submitted_before := commands.size()
	ai.cancel()
	ai._run_queued(stale_epoch)
	ai._on_action_completed(enemy.stable_id,"move","Movement blocked; travelled distance spent")
	check(commands.size()==submitted_before and ai.stage==EnemyController.Stage.IDLE,"Cancelled epoch ignores queued work and late completion")
	await controller.restart_encounter()
	check(memory(enemy.stable_id).positions.is_empty() and memory(enemy.stable_id).failed_endpoints.is_empty(),"Restart clears tactical memories")
	routines.clear()
	begin_enemy()
	check(routines.size()==1,"Restart permits enemy routine at reused turn serial")
	ai._begin_plan(enemy)
	enemy.set_health(0)
	submitted_before = commands.size()
	ai._process(0.016)
	ai._on_action_completed(enemy.stable_id,"move","Movement blocked; travelled distance spent")
	check(commands.size()==submitted_before and ai.actor_id!=enemy.stable_id,"Dead actor cannot submit from old plan or late completion")
	controller.shutdown()
	check(memory(enemy.stable_id).positions.is_empty() and memory(enemy.stable_id).failed_endpoints.is_empty(),"Shutdown clears memory")
	encounter.free()
	print("AI EXECUTION RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
