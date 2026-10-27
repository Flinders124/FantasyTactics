extends "res://tests/attack_tests.gd"
var results: int = 0
var rounds: Array[int]=[]

func fixture(kind: int) -> void:
	if is_instance_valid(encounter): encounter.free()
	encounter=(load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	while not encounter.navigation_ready: await physics_frame
	controller=encounter.get_node("CombatController") as CombatController
	hero=controller.find_unit("hero-01")
	scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	controller.objectives.configure(EncounterOptions.objectives()[kind])
	controller.objectives.center=Vector3(-4,0,3)
	controller.objectives.reset(controller.units)
	hero.position=Vector3(-4,0,3)
	scout.position=Vector3(-3,0,3)
	raider.position=Vector3(6,0,-7)
	sentinel.position=Vector3(8,0,-7)
	results=0
	rounds.clear()
	controller.combat_event.connect(func(event: String,_data: Dictionary) -> void:
		if event=="result": results+=1)
	controller.scheduler.round_completed.connect(func(number: int) -> void: rounds.append(number))
	await physics_frame
	await physics_frame

func end() -> void:
	var actor := controller.scheduler.active_unit()
	check(controller.submit_command(EndTurnCommand.new(actor.stable_id)),"End Turn accepted during objective")

func run() -> void:
	await fixture(1)
	var objective := controller.objectives
	check(objective.contains(objective.center+Vector3.RIGHT*objective.radius),"Inclusive exact ground-anchor radius")
	check(not objective.contains(objective.center+Vector3.RIGHT*(objective.radius+.001)),"Outside tolerance rejected")
	for index in range(3):
		end()
		check(objective.progress==0,"Hold does not count partial round")
	end()
	check(objective.progress==1 and rounds==[1],"Round counted once after all scheduled living turns")
	objective.round_end(1,controller.units)
	check(objective.progress==1,"Duplicate round callback ignored")
	raider.position=objective.center+Vector3(0,0,1)
	objective.round_end(2,controller.units)
	check(objective.progress==0 and objective.control=="Contested","Living enemy resets progress")
	raider.position=Vector3(6,0,-7)
	objective.round_end(3,controller.units)
	hero.position=Vector3(-9,0,6)
	scout.position=Vector3(-9,0,8)
	objective.round_end(4,controller.units)
	check(objective.progress==0 and objective.control=="Empty","Empty zone resets progress")
	await fixture(1)
	objective=controller.objectives
	raider.set_health(0)
	sentinel.set_health(0)
	check(controller.state==CombatController.State.AWAITING_COMMAND,"Hold continues after every enemy dies")
	for index in range(6): end()
	check(controller.state==CombatController.State.VICTORY and objective.progress==3 and controller.scheduler.round_number==3 and results==1,"Three hero-only rounds win once; dead slots do not stall")
	check(rounds==[1,2,3],"Dead schedule slots preserve consecutive rounds")
	await controller.restart_encounter()
	check(controller.objectives.progress==0 and controller.objectives.last_checked_round==0 and controller.state==CombatController.State.AWAITING_COMMAND,"Restart clears progress and round callbacks")
	await fixture(1)
	controller.objectives.progress=3
	controller._damage_in_progress=true
	hero.set_health(0)
	scout.set_health(0)
	controller._damage_in_progress=false
	controller._check_outcome(true)
	check(controller.state==CombatController.State.DEFEAT and results==1,"Hold defeat precedes completed progress")
	await fixture(2)
	check(not controller._check_outcome(false),"Extraction cannot win before a completed action")
	check(controller.submit_command(MoveCommand.new(hero.stable_id,Vector3(-4,0,2.4))),"Extraction accepts actual final movement")
	await wait_for_action()
	check(controller.state==CombatController.State.VICTORY and results==1,"Both required living heroes inside after movement win once")
	await fixture(2)
	scout.position=Vector3(-9,0,7)
	check(not controller._check_outcome(true) and controller.objectives.heroes_inside==1,"Extraction reports one of two, no premature victory")
	raider.set_health(0)
	sentinel.set_health(0)
	check(controller.state==CombatController.State.AWAITING_COMMAND,"Extraction survives enemy elimination")
	controller._damage_in_progress=true
	hero.set_health(0)
	scout.position=controller.objectives.center
	check(results==0,"No extraction outcome during atomic damage batch")
	controller._damage_in_progress=false
	controller._check_outcome(true)
	check(controller.state==CombatController.State.DEFEAT and results==1,"One required hero death defeats extraction despite enemy elimination")
	controller._check_outcome(true)
	check(results==1,"Final result emitted exactly once")
	await fixture(0)
	controller._damage_in_progress=true
	for unit in controller.units: unit.set_health(0)
	controller._damage_in_progress=false
	controller._check_outcome(true)
	check(controller.state==CombatController.State.DRAW and results==1,"Elimination retains atomic simultaneous draw")
	encounter.queue_free()
	await process_frame
	print("OBJECTIVE RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
