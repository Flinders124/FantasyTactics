extends "res://tests/objective_tests.gd"
var commands: Array[Dictionary]=[]

func run() -> void:
	for kind in [1,2]:
		await fixture(kind)
		controller.objectives.center=Vector3(-4,0,3) if kind==1 else Vector3(6,0,3)
		hero.position=Vector3(-9,0,-7)
		scout.position=Vector3(-7,0,-7)
		raider.position=Vector3(4,0,3) if kind==1 else Vector3(-4,0,3)
		sentinel.position=Vector3(8,0,-7)
		end()
		await physics_frame
		await physics_frame
		check(controller.scheduler.active_unit()==raider,"Enemy fixture is active")
		var planner := EnemyTactics.new()
		planner.begin(controller,raider)
		for frame in range(80):
			if planner.done: break
			planner.step()
		check(planner.done and planner.best.moving,"Objective AI chooses useful movement without a legal shot")
		var distance := raider.position.distance_to(controller.objectives.center)
		check(planner.best.destination.distance_to(controller.objectives.center)<distance-1,"Enemy moves toward hold zone or interception/exit area")
		check(planner.best.breakdown.get("objective",0)>0,"Objective contribution visible in diagnostics")
		var repeated := EnemyTactics.new()
		repeated.begin(controller,raider)
		while not repeated.done: repeated.step()
		check(planner.best.summary()==repeated.best.summary(),"Objective plans deterministic")
		var ai := encounter.get_node("EnemyController") as EnemyController
		commands.clear()
		ai.command_submitted.connect(func(id: String,kind_name: String,accepted: bool) -> void:
			if id=="enemy-01": commands.append({"kind":kind_name,"accepted":accepted}))
		ai.enabled=true
		ai.presentation_delay=0
		ai._on_turn_started(raider,controller.turn_serial)
		var serial := controller.turn_serial
		for frame in range(2400):
			if controller.turn_serial!=serial: break
			await process_frame
		ai.enabled=false
		check(controller.turn_serial!=serial and not controller.motor.running,"Objective enemy completes turn")
		check(commands.filter(func(command: Dictionary) -> bool: return command.kind=="move").size()==1 and commands.filter(func(command: Dictionary) -> bool: return command.kind=="attack").size()<=1,"Objective preserves one movement and one action")
		check(raider.position.distance_to(controller.objectives.center)<distance-1,"Objective move executed through validated command")
		check(ai.turn_path_queries<=144 and ai.turn_action_queries<=3072,"Objective query bounds preserved")
	encounter.queue_free()
	await process_frame
	print("OBJECTIVE TACTICS RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
