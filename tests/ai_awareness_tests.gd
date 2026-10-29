extends "res://tests/ability_enemy_tests.gd"

func solve(actor: CombatUnit) -> EnemyTactics:
	var result := EnemyTactics.new()
	result.begin(controller,actor,false,true)
	return result

func context_for(unit: CombatUnit, budget: Callable) -> AITacticalContext:
	var result := AITacticalContext.new()
	var foes: Array[CombatUnit]=[]
	var friends: Array[CombatUnit]=[]
	for other in controller.units:
		if not other.is_alive(): continue
		if other.faction==unit.faction: friends.append(other)
		else: foes.append(other)
	result.configure(controller,unit,EnemyTactics.profile_for(unit),foes,friends,budget)
	return result

func complete_plan(unit: CombatUnit) -> EnemyTactics:
	var result := EnemyTactics.new()
	result.begin(controller,unit)
	for frame in range(128):
		if result.done: break
		result.step()
	check(result.done and result.action_queries<=result.profile.max_action_queries and result.path_queries<=result.profile.max_path_queries,"Warning decisions terminate within shared query caps")
	return result

func run() -> void:
	encounter=load("res://scenes/combat_encounter.tscn").instantiate()
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	while not encounter.navigation_ready: await physics_frame
	controller=encounter.get_node("CombatController")
	ai=encounter.get_node("EnemyController")
	warden=controller.find_unit("hero-01")
	scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	for unit in controller.units: unit.definition=unit.definition.duplicate(true)
	await fresh()
	sentinel.position=Vector3(-4,0,7)
	warden.position=Vector3(1,0,7)
	scout.position=Vector3(1,0,9)
	raider.position=Vector3(-1,0,8)
	raider.set_health(6)
	warden.definition.basic_attack=load("res://definitions/ranged.tres")
	scout.definition.basic_attack=load("res://definitions/ranged.tres")
	await physics_frame
	await physics_frame
	var plan := solve(sentinel)
	check(plan._danger(raider)==8,"Healing danger sums two legal hostile attacks")
	var clear_value := plan._position(sentinel.position)
	controller.pending_telegraphs[scout.stable_id]={"ability_id":"fireburst","point":sentinel.ground_anchor(),"prepared_turn":scout.owner_turn}
	plan=solve(sentinel)
	check(plan._position(sentinel.position)<clear_value-20,"Hostile committed blast makes holding position materially dangerous")
	controller.pending_telegraphs.clear()
	var support_policy := EnemyTactics.profile_for(sentinel).duplicate() as EnemyTacticalProfile
	support_policy.distance_weight=0
	support_policy.exposure_weight=0
	support_policy.crowding_weight=0
	sentinel.definition.tactical_profile=support_policy
	plan=solve(sentinel)
	check(plan._position(sentinel.position)>plan._position(Vector3(-8,0,7))+3,"Support preserves access to a meaningfully wounded friend")
	controller.objectives.definition=ObjectiveDefinition.new()
	controller.objectives.definition.kind=ObjectiveDefinition.Kind.HOLD_GROUND
	controller.objectives.definition.positioning_weight=0
	controller.objectives.definition.required_rounds=2
	controller.objectives.center=warden.ground_anchor()
	controller.objectives.radius=1
	controller.objectives.progress=1
	var profile := EnemyTactics.profile_for(warden).duplicate() as EnemyTacticalProfile
	profile.distance_weight=0
	profile.exposure_weight=0
	profile.crowding_weight=0
	warden.definition.tactical_profile=profile
	plan=solve(warden)
	check(plan._position(warden.position)>plan._position(warden.position+Vector3(0,0,1.5))+10,"Last holding hero preserves imminent objective progress")
	controller.objectives.definition.kind=ObjectiveDefinition.Kind.ELIMINATION
	var calls: Array[int] = [0]
	var budget := func() -> bool:
		calls[0]+=1
		return calls[0]<=128
	var context := context_for(sentinel,budget)
	check(context.incoming_damage(raider)==8,"Context sums independent hostile damage")
	var used: int = calls[0]
	context.incoming_damage(raider)
	check(calls[0]==used,"Repeated incoming estimate uses decision-local cache")
	check(context.status_relevance(scout,sentinel.position)==0,"Stationary ranged target with a clear shot gets no movement-denial bonus")
	var support := context.position_components(sentinel.position)
	check(support.support>0,"Support values access to a meaningfully injured friend")
	controller.pending_telegraphs[scout.stable_id]={"ability_id":"fireburst","point":sentinel.ground_anchor(),"prepared_turn":scout.owner_turn}
	context=context_for(sentinel,budget)
	check(context.position_components(sentinel.position).warnings<0,"Hostile warning applies exact blast damage utility")
	var ignoring: Array[String]=[scout.stable_id]
	check(context.position_components(sentinel.position,ignoring).warnings==0,"Defeated warning caster is omitted from post-action position")
	var ability := scout.ability_by_id("fireburst")
	ability.affected_factions=2
	context=context_for(sentinel,budget)
	check(context.position_components(sentinel.position).warnings==0,"Warning faction mask can exclude the actor")
	ability.affected_factions=7
	context=context_for(sentinel,budget)
	var outside := sentinel.position+Vector3(ability.area_radius+.05,0,0)
	check(context.position_components(outside).warnings==0,"Warning radius uses ground anchor without inflating by unit radius")
	var blocked_context := context_for(sentinel,func() -> bool: return false)
	check(blocked_context.incoming_damage(raider)==0,"Exhausted query budget performs no speculative attack validation")
	var wall := StaticBody3D.new()
	wall.collision_layer=8
	wall.collision_mask=0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(.8,.15,.8)
	shape.shape=box
	wall.add_child(shape)
	wall.position=sentinel.ground_anchor()+Vector3.UP*.6
	encounter.add_child(wall)
	await physics_frame
	await physics_frame
	context=context_for(sentinel,budget)
	check(context.position_components(sentinel.position).warnings==0,"Static blast obstruction protects the hypothetical actor")
	wall.queue_free()
	await physics_frame
	controller.pending_telegraphs.clear()
	warden.definition.basic_attack=load("res://definitions/melee.tres")
	context=context_for(raider,budget)
	var protected: float = context.position_components(Vector3(-1,0,7)).protection
	var exposed: float = context.position_components(Vector3(-1,0,11)).protection
	check(protected>exposed,"Melee ally values screening a ranged friend from approaching melee")
	check(context.position_components(Vector3(-6,0,7)).protection==0,"Standing behind the vulnerable ally earns no screening credit")
	controller.objectives.definition.kind=ObjectiveDefinition.Kind.HOLD_GROUND
	controller.objectives.center=warden.ground_anchor()
	controller.objectives.radius=1
	context=context_for(sentinel,budget)
	check(context.objective_value(warden.position)>context.objective_value(warden.position+Vector3(0,0,2))+10,"Enemy contesting a hero-held objective prevents imminent progress")
	controller.pending_telegraphs.clear()
	var tiny_heal := sentinel.ability_by_id("mend")
	var heal_amount := tiny_heal.magnitude
	tiny_heal.magnitude=1
	context=context_for(sentinel,budget)
	check(context.position_components(sentinel.position).support==0,"Support access requires meaningful effective healing")
	tiny_heal.magnitude=heal_amount
	var limited := EnemyTactics.profile_for(sentinel).duplicate() as EnemyTacticalProfile
	limited.max_candidates=8
	limited.max_raw_candidates=12
	limited.max_path_queries=16
	limited.max_action_queries=64
	sentinel.definition.tactical_profile=limited
	var bounded := EnemyTactics.new()
	bounded.begin(controller,sentinel)
	for frame in range(128):
		if bounded.done: break
		bounded.step()
	check(bounded.done and bounded.action_queries<=64 and bounded.path_queries<=16 and bounded.evaluated+1<=8,"Context physics checks share the planner's smallest query budget")
	await fresh()
	controller.objectives.definition.kind=ObjectiveDefinition.Kind.ELIMINATION
	sentinel.definition.tactical_profile=load("res://definitions/tactics_support.tres").duplicate()
	sentinel.position=Vector3(-4,0,7)
	raider.position=Vector3(8,0,-8)
	warden.position=Vector3(1,0,7)
	scout.position=Vector3(1,0,9)
	warden.definition.basic_attack=load("res://definitions/ranged.tres")
	sentinel.movement_remaining=2.2
	var second_warning := scout.ability_by_id("fireburst").duplicate(true) as AbilityDefinition
	second_warning.stable_id="fixture_warning"
	warden.definition.abilities.append(second_warning)
	controller.pending_telegraphs[scout.stable_id]={"ability_id":"fireburst","point":sentinel.ground_anchor()+Vector3(.5,0,0),"prepared_turn":scout.owner_turn}
	controller.pending_telegraphs[warden.stable_id]={"ability_id":second_warning.stable_id,"point":sentinel.ground_anchor()-Vector3(.5,0,0),"prepared_turn":warden.owner_turn}
	await physics_frame
	await physics_frame
	var overlapping := complete_plan(sentinel)
	var repeat := complete_plan(sentinel)
	check(overlapping.best.summary()==repeat.best.summary(),"Repeated public state selects the same destination, target and action")
	context=context_for(sentinel,func() -> bool: return true)
	var initial_risk: float=context.position_components(sentinel.position).warnings
	var chosen_risk: float=context.position_components(overlapping.best.destination).warnings
	check(initial_risk==-72 and chosen_risk==-36,"Overlapping warnings sum damage and select the least dangerous reachable zone")
	check(overlapping.best.moving and controller.evaluate_move(sentinel,overlapping.best.destination).valid(),"Reduced-risk warning escape is a legal executable movement")
	check(overlapping.best.action!=null and overlapping.best.action.target_id==repeat.best.action.target_id,"Warning escape retains a stable legal target decision")
	sentinel.movement_remaining=0
	var trapped := complete_plan(sentinel)
	check(not trapped.best.moving and trapped.best.action!=null,"Zero movement retains a legal action when every reachable position is warned")
	if trapped.best.action!=null:
		var trapped_target := controller.find_unit(trapped.best.action.target_id)
		var action_valid := false
		if trapped.best.action.ground:
			action_valid=controller.evaluate_ground_ability_position(sentinel,trapped.best.action.point,sentinel.position,trapped.best.action.ability_id).valid()
		elif not trapped.best.action.ability_id.is_empty():
			action_valid=controller.evaluate_ability_position(sentinel,trapped_target,sentinel.position,trapped.best.action.ability_id).valid()
		else:
			action_valid=controller.evaluate_attack_position(sentinel,trapped_target,sentinel.position).valid()
		check(action_valid,"Trapped actor's selected action passes authoritative validation")
	sentinel.spend_action()
	var exhausted := complete_plan(sentinel)
	check(not exhausted.best.moving and exhausted.best.action==null,"Zero movement and spent action yield an End Turn plan without retries")
	check(controller.submit_command(EndTurnCommand.new(sentinel.stable_id)),"Trapped actor can legally end its turn")
	controller.pending_telegraphs.clear()
	encounter.shutdown()
	encounter.queue_free()
	await process_frame
	print("AI AWARENESS RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)








