extends "res://tests/ability_enemy_tests.gd"
var reports: Array[Dictionary] = []

func solve(actor: CombatUnit,label: String,movement: bool=true,actions: bool=true) -> EnemyTactics:
	var decision := EnemyTactics.new()
	decision.begin(controller,actor,movement,actions)
	for chunk in range(100):
		if decision.done: break
		decision.step()
	check(decision.done,"Bounded planning terminates: "+label)
	check(decision.path_queries<=decision.profile.max_path_queries and decision.action_queries<=decision.profile.max_action_queries and decision.evaluated+1<=decision.profile.max_candidates,"Query/candidate caps: "+label)
	var report := decision.report()
	report.scenario=label
	reports.append(report)
	return decision

func prepare_range() -> void:
	await fresh()
	sentinel.position=Vector3(0,0,7)
	warden.position=Vector3(2.1,0,7)
	scout.position=Vector3(9,0,-9)
	raider.position=Vector3(-9,0,-9)
	await physics_frame
	await physics_frame

func limits() -> void:
	check(commands.filter(func(command: Dictionary) -> bool: return command.kind=="move").size()<=1,"At most one movement command")
	check(commands.filter(func(command: Dictionary) -> bool: return command.kind=="attack").size()<=1,"At most one action command")
	check(commands.filter(func(command: Dictionary) -> bool: return command.kind=="end").size()==1,"Exactly one completed End Turn")
	check(ai.turn_path_queries<=144 and ai.turn_action_queries<=3072,"Bounded total turn queries including recovery")

func run() -> void:
	encounter=(load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	for frame in range(1600):
		await process_frame
		if encounter.navigation_ready: break
	controller=encounter.get_node("CombatController") as CombatController
	ai=encounter.get_node("EnemyController") as EnemyController
	warden=controller.find_unit("hero-01")
	scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	for unit in controller.units: unit.definition=unit.definition.duplicate() as UnitDefinition
	controller.motor.movement_speed=12
	controller.motor.blocked_timeout=.15
	ai.presentation_delay=0
	ai.command_submitted.connect(func(id: String,kind: String,accepted: bool) -> void: commands.append({"id":id,"kind":kind,"accepted":accepted}))
	controller.combat_event.connect(func(kind: String,data: Dictionary) -> void:
		if kind=="ability": uses.append(data.ability))
	# Pure scoring: effective HP, cooldown opportunity and nonstacking status value.
	var profile := load("res://definitions/tactics_melee.tres") as EnemyTacticalProfile
	check(profile.damage_components(7,3)==profile.damage_components(4,3),"Overkill has no extra damage value")
	check(profile.status_value(2)==0 and profile.status_value(1)<profile.status_value(0),"Existing future Slowed turns reduce status utility")
	check(profile.healing_components(6,19,20,0).is_empty(),"Tiny healing is not meaningful")
	await fresh("enemy-01")
	raider.position=Vector3(0,0,7)
	warden.position=Vector3(0,0,5.5)
	scout.position=Vector3(4.5,0,7)
	scout.set_health(4)
	sentinel.position=Vector3(-9,0,-9)
	await physics_frame
	await physics_frame
	var decision := solve(raider,"farther defeat over nearby durable target")
	check(decision.best.moving and decision.best.action!=null and decision.best.action.target_id==scout.stable_id and decision.best.action.ability_id.is_empty(),"Move to secure defeat with basic attack instead of wasting Power Strike")
	var repeat := solve(raider,"identical state repeat")
	check(repeat.best.summary()==decision.best.summary(),"Identical public state yields identical complete plan")
	begin()
	await wait_turn(raider)
	check(not scout.is_alive() and warden.health==20,"Chosen farther defeat executes through commands")
	limits()
	await fresh("enemy-01")
	raider.position=Vector3(2.4,0,.3)
	warden.position=Vector3(.6,0,1.5)
	scout.position=Vector3(-9,0,-9)
	sentinel.position=Vector3(9,0,-9)
	await physics_frame
	await physics_frame
	check(not controller.evaluate_attack(raider,warden).valid(),"Nearest opponent is obstructed")
	decision=solve(raider,"wall around nearest opponent")
	check(decision.best.moving and decision.best.action!=null,"Wall produces reachable move-then-action option")
	if decision.best.action!=null:
		var target := controller.find_unit(decision.best.action.target_id)
		check(controller.evaluate_ability_position(raider,target,decision.best.destination,decision.best.action.ability_id).valid() if not decision.best.action.ability_id.is_empty() else controller.evaluate_attack_position(raider,target,decision.best.destination).valid(),"Planned endpoint shares real obstruction validation")
	await prepare_range()
	warden.position=Vector3(1,0,7)
	await physics_frame
	sentinel.definition.tactical_profile=load("res://definitions/tactics_ranged.tres") as EnemyTacticalProfile
	decision=solve(sentinel,"adjacent ranged enemy")
	check(decision.best.moving and decision.best.action!=null and decision.best.destination.distance_to(warden.position)>2.5,"Ranged enemy seeks useful clear distance rather than adjacency")
	begin()
	await wait_turn(sentinel)
	check(sentinel.position.distance_to(warden.position)>2.0 and warden.health<20,"Ranged reposition and legal shot execute")
	limits()
	sentinel.definition.tactical_profile=load("res://definitions/tactics_support.tres") as EnemyTacticalProfile
	await prepare_range()
	# Isolate the action-first tie: Slowed can now legitimately gain value after retreat.
	sentinel.cooldown_ready_turn["crippling_shot"] = sentinel.owner_turn+2
	decision=solve(sentinel,"act then reposition")
	check(decision.best.action!=null and decision.best.moving and decision.best.action_first,"Already legal shot can precede a useful retreat")
	begin()
	await wait_turn(sentinel)
	check(commands.size()>=3 and commands[0].kind=="attack" and commands[1].kind=="move","Action-then-move uses authoritative completions")
	limits()
	await fresh()
	sentinel.position=Vector3(-4,0,8.5)
	raider.position=Vector3(0,0,8.5)
	raider.set_health(4)
	warden.position=Vector3(0,0,7)
	scout.position=Vector3(-7,0,8.5)
	scout.set_health(4)
	await physics_frame
	await physics_frame
	decision=solve(sentinel,"endangered ally versus offensive defeat")
	check(decision.best.action!=null and decision.best.action.ability_id=="mend" and decision.best.action.target_id==raider.stable_id,"Support prioritizes meaningful healing of an ally facing lethal basic damage")
	begin()
	await wait_turn(sentinel)
	check(raider.health==10 and scout.health==4 and uses.has("Mend"),"Shared healing rules, capped benefit and action spending execute")
	limits()
	await fresh()
	sentinel.position=Vector3(-5,0,7)
	warden.position=Vector3(0,0,7)
	scout.position=Vector3(2,0,7)
	raider.position=Vector3(-9,0,-9)
	await physics_frame
	await physics_frame
	decision=solve(sentinel,"safe grouped opponents")
	check(decision.best.action!=null and decision.best.action.ground and decision.best.action.ability_id=="fireburst","Safe two-target Fireburst outweighs a single-target attack")
	var cast_from := sentinel.position if decision.best.action_first else decision.best.destination
	var blast := controller.evaluate_ground_ability_position(sentinel,decision.best.action.point,cast_from,"fireburst")
	check(blast.valid() and blast.hits.all(func(hit: AreaTargetingService.Hit) -> bool: return hit.unit.faction!=sentinel.faction),"Previewed area contains no ally/caster from actual hypothetical position")
	sentinel.definition.tactical_profile=load("res://definitions/tactics_spellcaster.tres") as EnemyTacticalProfile
	var caster := solve(sentinel,"spellcaster profile safe area")
	check(caster.best.action!=null and caster.best.action.ability_id=="fireburst","Editable spellcaster profile values multi-target ability use")
	sentinel.definition.tactical_profile=load("res://definitions/tactics_support.tres") as EnemyTacticalProfile
	raider.position=Vector3(.5,0,7)
	await physics_frame
	decision=solve(sentinel,"group with nearby ally")
	check(decision.best.action==null or decision.best.action.ability_id!="fireburst","Unsafe blast rejected across all candidate positions")
	# Revalidate the stricter AI safety request after state-change notifications,
	# without changing the normal player's friendly-fire rules.
	raider.position=Vector3(-9,0,-9)
	await physics_frame
	decision=solve(sentinel,"area state-change race")
	var unsafe_after_notification := func(state: CombatController.State) -> void:
		if state==CombatController.State.RESOLVING_ACTION: raider.position=Vector3(.5,0,7)
	controller.state_changed.connect(unsafe_after_notification)
	var before := warden.health
	check(not controller.submit_command(decision.best.action.command(sentinel.stable_id)),"Commit rejects an ally entering the blast after planning")
	controller.state_changed.disconnect(unsafe_after_notification)
	check(warden.health==before and sentinel.action_available and sentinel.cooldown_ready_turn.is_empty(),"Safety rejection spends neither health, action nor cooldown")
	await prepare_range()
	warden.position=Vector3(6,0,7)
	warden.apply_status(load("res://definitions/slowed.tres") as StatusEffectDefinition)
	await physics_frame
	decision=solve(sentinel,"redundant Slowed")
	check(decision.best.action!=null and decision.best.action.ability_id.is_empty(),"Do not spend Crippling Shot to refresh two future Slowed turns")
	sentinel.cooldown_ready_turn["crippling_shot"]=sentinel.owner_turn+2
	decision=solve(sentinel,"offensive ability on cooldown")
	check(decision.best.action!=null and decision.best.action.ability_id.is_empty() and decision.rejected.has("Cooldown: crippling_shot"),"Cooldown filters ability and preserves legal basic fallback")
	var limited := sentinel.definition.tactical_profile.duplicate() as EnemyTacticalProfile
	limited.max_candidates=8
	limited.max_raw_candidates=12
	limited.max_path_queries=16
	limited.max_action_queries=64
	limited.positions_per_frame=1
	sentinel.definition.tactical_profile=limited
	decision=solve(sentinel,"small editable search budget")
	check(decision.best.action!=null,"Low-budget search retains the current legal basic fallback")
	sentinel.definition.tactical_profile=load("res://definitions/tactics_support.tres") as EnemyTacticalProfile
	await fresh()
	warden.position=Vector3(40,0,40)
	scout.position=Vector3(-40,0,-40)
	await physics_frame
	decision=solve(sentinel,"no reachable opponents")
	check(not decision.best.moving and decision.best.action==null,"No reachable targets produce an End Turn plan")
	begin()
	await wait_turn(sentinel)
	check(commands.size()==1 and commands[0].kind=="end","Unreachable turn does not retry")
	limits()
	# A newly blocking collider after approval cannot cause another move command.
	await fresh()
	sentinel.position=Vector3(-4,0,7)
	warden.position=Vector3(9,0,7)
	scout.position=Vector3(9,0,-9)
	raider.position=Vector3(-9,0,-9)
	await physics_frame
	var barrier := StaticBody3D.new()
	var add_blocker := func(_id: String,kind: String,accepted: bool) -> void:
		if kind=="move" and accepted:
			var shape := BoxShape3D.new()
			shape.size=Vector3(.25,2,2)
			var collision := CollisionShape3D.new()
			collision.shape=shape
			barrier.add_child(collision)
			barrier.position=Vector3(-3.4,1,7)
			encounter.add_child(barrier)
	ai.command_submitted.connect(add_blocker)
	begin()
	await wait_turn(sentinel)
	ai.command_submitted.disconnect(add_blocker)
	check(not controller.motor.running and sentinel.movement_remaining>5.5,"Late obstruction recovers and charges only actual movement")
	limits()
	barrier.queue_free()
	await physics_frame
	# Public state changes during multi-frame planning invalidate the local cache.
	await prepare_range()
	var revised := [false]
	var revise := func(_id: String,_serial: int) -> void:
		if not revised[0]:
			revised[0]=true
			warden.set_health(3)
	ai.planning_progress.connect(revise)
	begin()
	await wait_turn(sentinel)
	ai.planning_progress.disconnect(revise)
	check(revised[0] and ai.planning_restarts==1 and not warden.is_alive(),"One bounded replan responds to changed public health")
	limits()
	await prepare_range()
	var cancelled := [false]
	var restart_plan := func(_id: String,_serial: int) -> void:
		if not cancelled[0]:
			cancelled[0]=true
			controller.restart_encounter()
	ai.planning_progress.connect(restart_plan)
	begin()
	for frame in range(90): await process_frame
	ai.planning_progress.disconnect(restart_plan)
	check(cancelled[0] and commands.is_empty() and ai.stage==EnemyController.Stage.IDLE and controller.scheduler.active_unit()==warden,"Restart mid-planning submits no stale commands")
	await prepare_range()
	begin()
	for frame in range(180):
		await process_frame
		if ai.stage==EnemyController.Stage.WAIT_ATTACK: break
	check(ai.stage==EnemyController.Stage.WAIT_ATTACK,"Action-resolution restart fixture reached")
	await controller.restart_encounter()
	for frame in range(60): await process_frame
	check(ai.stage==EnemyController.Stage.IDLE and controller.scheduler.active_unit()==warden and controller.units.all(func(unit: CombatUnit) -> bool: return unit.health==unit.definition.maximum_health),"Restart during action cannot leak damage or AI work into new turn")
	# Movement remains useful after an externally spent action; no extra attack.
	await fresh("enemy-01")
	raider.position=Vector3(-8,0,7)
	warden.position=Vector3(2,0,7)
	scout.position=Vector3(9,0,-9)
	sentinel.position=Vector3(-9,0,-9)
	raider.spend_action()
	await physics_frame
	decision=solve(raider,"movement-only spent action")
	check(decision.best.action==null and decision.best.moving,"Spent action does not prevent useful movement-only turn")
	begin()
	await wait_turn(raider)
	check(commands.filter(func(command: Dictionary) -> bool: return command.kind=="attack").is_empty(),"Movement-only turn never gains another action")
	limits()
	check(RegressionReport.write_json("tactics/decision-scenarios.json",reports),"Regression report written")
	encounter.shutdown()
	encounter.queue_free()
	await process_frame
	print("TACTICS RESULT: %d failures; %d bounded deterministic decision scenarios"%[failures,reports.size()])
	quit(0 if failures==0 else 1)
