extends "res://tests/tactics_tests.gd"

func fixture() -> void:
	encounter=load("res://scenes/combat_encounter.tscn").instantiate()
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	for frame in 1600:
		if encounter.navigation_ready:break
		await process_frame
	check(encounter.navigation_ready,"Tactical fixture navigation ready")
	controller=encounter.get_node("CombatController")
	ai=encounter.get_node("EnemyController")
	warden=controller.find_unit("hero-01");scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01");sentinel=controller.find_unit("enemy-02")
	for unit in controller.units:unit.definition=unit.definition.duplicate(true)

func run() -> void:
	await fixture()
	await fresh("hero-02")
	scout.position=Vector3(-2,0,7);sentinel.position=Vector3(3,0,7)
	warden.position=Vector3(-9,0,-9);raider.position=Vector3(9,0,-9)
	await physics_frame;await physics_frame
	check(controller.evaluate_attack(scout,sentinel).valid(),"Ranger has a legal basic shot")
	var decision:=solve(scout,"stationary ranged healer",false,true)
	check(decision.best.action!=null and decision.best.action.ability_id.is_empty(),"Do not trade useful damage for irrelevant Slowed against an established ranged opponent")
	decision=solve(scout,"good firing position")
	check(decision.best.action!=null and not decision.best.moving,"A useful clear firing position does not cause needless movement")
	check(EnemyTactics.profile_for_definition(HeroCatalog.find("cleric")).role==EnemyTacticalProfile.Role.SUPPORT,"Cleric shares support policy when driven in AI simulations")
	check(EnemyTactics.profile_for_definition(HeroCatalog.find("mage")).role==EnemyTacticalProfile.Role.SPELLCASTER,"Mage shares spellcaster policy when driven in AI simulations")
	await fresh("hero-02")
	scout.position=Vector3(-2,0,7);raider.position=Vector3(3,0,7)
	warden.position=Vector3(3,0,8);sentinel.position=Vector3(9,0,-9)
	await physics_frame;await physics_frame
	check(controller.evaluate_attack_position(raider,warden,raider.position).valid(),"Melee target already threatens another adjacent ally without movement")
	decision=solve(scout,"melee already engaging ally",false,true)
	check(decision.best.action!=null and decision.best.action.ability_id.is_empty(),"Do not waste Slowed when melee can already attack a different ally")
	await fresh("enemy-01")
	raider.position=Vector3(-6,0,7);warden.position=Vector3(7,0,7)
	scout.position=Vector3(2,0,7);sentinel.position=Vector3(-9,0,-9)
	await physics_frame;await physics_frame
	decision=EnemyTactics.new();decision.begin(controller,raider,false,false)
	var route:=decision._route(Vector3(5,0,7))
	check(route!=null and route.valid() and route.distance>raider.movement_remaining,"A distant living blocker beyond this turn's endpoint does not reject safe prefix progress")
	scout.position=Vector3(-3,0,7)
	await physics_frame;await physics_frame
	decision=EnemyTactics.new();decision.begin(controller,raider,false,false)
	route=decision._route(Vector3(5,0,7))
	check(route!=null and not route.valid(),"A living blocker on the executed prefix still prevents crossing")
	encounter.queue_free();await process_frame;await physics_frame
	check(RegressionReport.write_json("positioning.json",{"failures":failures,"decisions":reports}),"Tactical scenario report")
	print("AI POSITIONING RESULT: %d failures"%failures);quit(0 if failures==0 else 1)