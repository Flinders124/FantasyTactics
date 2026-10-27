extends "res://tests/area_tests.gd"

func warning(actor: CombatUnit) -> AbilityDefinition:
	var ability := actor.ability_by_id("test_warning")
	if ability==null:
		ability=actor.ability_by_id("fireburst").duplicate(true) as AbilityDefinition
		ability.telegraphed=true
		ability.stable_id="test_warning"
		actor.definition=actor.definition.duplicate(true)
		actor.definition.abilities.append(ability)
	return ability

func prepare_warning(actor: CombatUnit) -> AbilityDefinition:
	var ability := warning(actor)
	check(controller.submit_command(UseAbilityCommand.on_ground(actor.stable_id,ability.stable_id,POINT)),"Prepare accepted")
	await wait_action()
	return ability

func next_owner(actor: CombatUnit) -> void:
	check(controller.submit_command(EndTurnCommand.new(actor.stable_id)),"Preparing owner ends turn")
	for turn in range(8):
		if controller.encounter_has_ended() or controller.scheduler.active_unit()==actor: return
		check(controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id)),"Intervening actor ends turn")
	check(false,"Next owner start occurs within bounded schedule")

func run() -> void:
	encounter=load("res://scenes/combat_encounter.tscn").instantiate()
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	while not encounter.navigation_ready: await physics_frame
	controller=encounter.get_node("CombatController")
	ai=encounter.get_node("EnemyController")
	scout=controller.find_unit("hero-02")
	warden=controller.find_unit("hero-01")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	controller.combat_event.connect(func(kind: String,data: Dictionary) -> void: events.append({"kind":kind,"data":data}))
	controller.state_changed.connect(func(value: CombatController.State) -> void:
		if value in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: result_states.append(value))
	await fresh()
	var before := raider.health
	var ability := await prepare_warning(scout)
	check(raider.health==before,"Preparation does no damage")
	check(not scout.action_available and scout.cooldown_remaining(ability.stable_id)==0,"Prepare spends action; cooldown waits for resolution")
	var prepared := controller.pending_telegraphs.duplicate(true)
	var owner_turn := scout.owner_turn
	encounter.set_guidance_paused(true)
	for frame in range(12): await process_frame
	check(scout.owner_turn==owner_turn and controller.pending_telegraphs==prepared,"Pause preserves owner turn and prepared area")
	check(not controller.submit_command(EndTurnCommand.new(scout.stable_id)),"Pause blocks turn advancement")
	encounter.set_guidance_paused(false)
	check(scout.owner_turn==owner_turn and controller.pending_telegraphs==prepared,"Resume does not advance warning")
	check(controller.submit_command(MoveCommand.new(scout.stable_id,Vector3(-4,0,7))),"Preparing caster may still move")
	await wait_action()
	check(controller.pending_telegraphs[scout.stable_id].point==POINT,"Warning remains at committed point after movement")
	await next_owner(scout)
	check(raider.health==before-ability.magnitude and count("telegraph_resolve")==1,"Next owner start resolves exactly once at locked point")
	check(not scout.action_available and scout.movement_remaining>0,"Resolution consumes action and preserves movement")
	check(controller.pending_telegraphs.is_empty(),"Resolution removes warning")
	check(scout.cooldown_remaining(ability.stable_id)==3,"Resolution begins cooldown")
	check(not controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id,"fireburst",POINT)),"Resolution prevents a second action")
	for blocked in range(2):
		await next_owner(scout)
		check(not controller.evaluate_ground_ability(scout,POINT,ability.stable_id).valid(),"Cooldown blocks subsequent owner turn %d"%(blocked+1))
	await next_owner(scout)
	check(controller.evaluate_ground_ability(scout,POINT,ability.stable_id).valid(),"Cooldown permits ability after two blocked owner turns")
	check(count("telegraph_resolve")==1,"Later turns never repeat completed warning")
	await fresh()
	ability=await prepare_warning(scout)
	var escaped_health := raider.health
	raider.position=Vector3(8,0,7)
	scout.position=POINT+Vector3(0,0,1)
	var caster_health := scout.health
	var ally_health := warden.health
	await physics_frame
	await next_owner(scout)
	check(raider.health==escaped_health,"Target escaping committed area avoids damage")
	check(scout.health==caster_health-ability.magnitude and warden.health==ally_health-ability.magnitude,"Resolution damages caster and allies currently inside area")
	await fresh()
	await prepare_warning(scout)
	scout.set_health(0)
	check(controller.pending_telegraphs.is_empty() and count("telegraph_cancel")==1,"Caster death cancels warning once")
	for turn in range(5):
		if controller.encounter_has_ended(): break
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(count("telegraph_resolve")==0,"Cancelled warning never resolves on later turns")
	await fresh()
	await prepare_warning(scout)
	await controller.restart_encounter()
	check(controller.pending_telegraphs.is_empty() and scout.cooldown_ready_turn.is_empty(),"Restart clears pending warning and cooldown")
	events.clear()
	for turn in range(8): controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(count("telegraph_resolve")==0,"Restart prevents stale resolution callbacks")
	await fresh("enemy-02")
	sentinel.position=Vector3(-5,0,7)
	raider.position=Vector3(8,0,-8)
	scout.position=Vector3(-8,0,-8)
	await physics_frame
	await prepare_warning(sentinel)
	ai.presentation_delay=0
	ai.enabled=true
	await next_owner(sentinel)
	for frame in range(500):
		if controller.scheduler.active_unit()!=sentinel: break
		await process_frame
	ai.enabled=false
	check(controller.scheduler.active_unit()!=sentinel,"AI completes resolution turn")
	var extra_actions := 0
	for event in events:
		if event.data.get("actor_id","")==sentinel.stable_id and event.kind in ["attack","ability"]: extra_actions+=1
	check(count("telegraph_resolve")==1 and extra_actions==0,"AI uses no additional action after automatic resolution")
	await fresh()
	await prepare_warning(scout)
	scout.position=POINT+Vector3(0,0,1)
	sentinel.position=POINT+Vector3(-1,0,0)
	for unit in controller.units: unit.set_health(1)
	await physics_frame
	await next_owner(scout)
	check(controller.state==CombatController.State.DRAW,"One simultaneous blast may defeat both factions")
	check(count("death")==4 and count("result")==1 and result_states==[CombatController.State.DRAW],"Multiple deaths publish one final draw outcome")
	check(controller.pending_telegraphs.is_empty(),"Terminal outcome clears warnings")
	await controller.restart_encounter()
	check(not controller.encounter_has_ended() and controller.pending_telegraphs.is_empty(),"Restart recovers cleanly after terminal blast")
	await fresh()
	ability=await prepare_warning(scout)
	var cancelled_health := raider.health
	var preparing_turn := scout.owner_turn
	controller.state_changed.connect(func(next: CombatController.State) -> void:
		if next==CombatController.State.RESOLVING_ACTION and scout.owner_turn>preparing_turn:
			controller.shutdown())
	await next_owner(scout)
	check(controller.state==CombatController.State.SETUP,"Shutdown cancels prepared resolution")
	check(raider.health==cancelled_health and count("telegraph_resolve")==0,"Cancelled prepared resolution deals no damage or event")
	check(scout.action_available and scout.cooldown_remaining(ability.stable_id)==0,"Cancelled prepared resolution spends no action or cooldown")
	encounter.queue_free()
	await process_frame
	print("TELEGRAPH RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
