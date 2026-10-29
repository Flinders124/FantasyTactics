class_name AITacticalContext
extends RefCounted
## Public, current-turn information only; the planner owns the shared query budget.
var combat: CombatController
var actor: CombatUnit
var policy: EnemyTacticalProfile
var opponents: Array[CombatUnit] = []
var allies: Array[CombatUnit] = []
var query_budget: Callable
var _positions: Dictionary = {}
var _incoming: Dictionary = {}
var _targets: Dictionary = {}
var _statuses: Dictionary = {}
var _point_keys: Dictionary = {}

func configure(controller: CombatController, unit: CombatUnit, profile: EnemyTacticalProfile, foes: Array[CombatUnit], friends: Array[CombatUnit], budget: Callable) -> void:
	combat=controller
	actor=unit
	policy=profile
	opponents=foes
	allies=friends
	query_budget=budget
	_positions.clear()
	_incoming.clear()
	_targets.clear()
	_statuses.clear()
	_point_keys.clear()

func _allowed() -> bool:
	return query_budget.is_valid() and bool(query_budget.call())

func _key(origin: Vector3) -> String:
	var snapped := origin.snapped(Vector3.ONE*.001)
	if not _point_keys.has(snapped): _point_keys[snapped]=str(snapped)
	return _point_keys[snapped]

func objective_value(origin: Vector3) -> float:
	var objective := combat.objectives
	var value := objective.position_value(origin)
	if objective.definition.kind==ObjectiveDefinition.Kind.ELIMINATION: return 0
	if objective.definition.kind==ObjectiveDefinition.Kind.EXTRACTION:
		if actor.faction==CombatUnit.Faction.HERO: return value
		# Intercept the observable route to the exit as well as guarding the exit.
		var intercept := INF
		for foe in opponents:
			intercept=minf(intercept,origin.distance_to(foe.ground_anchor().lerp(objective.center,.65)))
		return value*.5-minf(intercept,40)*objective.definition.positioning_weight*.5 if is_finite(intercept) else value
	if not objective.contains(origin): return value
	var heroes := 0
	var enemies := 0
	for unit in combat.units:
		if unit==actor or not is_instance_valid(unit) or not unit.is_alive() or not objective.contains(unit.ground_anchor()): continue
		if unit.faction==CombatUnit.Faction.HERO: heroes+=1
		else: enemies+=1
	var urgency := 1.0+float(objective.progress)/maxi(1,objective.definition.required_rounds)
	if actor.faction==CombatUnit.Faction.HERO and heroes==0:
		value+=policy.objective_commitment_weight*urgency
	elif actor.faction==CombatUnit.Faction.ENEMY and enemies==0 and heroes>0:
		value+=policy.objective_commitment_weight*urgency
	return value

func _warning_damage(origin: Vector3, ignore: Array[String]=[], subject: CombatUnit=null) -> int:
	if combat.pending_telegraphs.is_empty(): return 0
	if subject==null: subject=actor
	var damage := 0
	var excluded: Array[RID] = []
	for unit in combat.units:
		if is_instance_valid(unit): excluded.append(unit.get_rid())
	var ids := combat.pending_telegraphs.keys()
	ids.sort()
	for id: String in ids:
		if ignore.has(id): continue
		var caster := combat.find_unit(id)
		if caster==null or not caster.is_alive(): continue
		var warning: Dictionary=combat.pending_telegraphs[id]
		var ability := caster.ability_by_id(warning.ability_id)
		if ability==null or ability.effect!=AbilityDefinition.Effect.DAMAGE or not subject.area_markers_valid(): continue
		var flag := 4 if caster==subject else (2 if caster.faction==subject.faction else 1)
		if (ability.affected_factions & flag)==0: continue
		var offset := origin-subject.global_position
		var point: Vector3=warning.point
		if point.distance_to(subject.ground_anchor()+offset)>ability.area_radius+AreaTargetingService.BOUNDARY_EPSILON: continue
		if not _allowed(): break
		if combat.area_targeting._clear_line(subject.get_world_3d().direct_space_state,point+Vector3.UP*ability.blast_origin_offset,subject.target_point()+offset,ability.area_obstruction_mask,excluded): damage+=ability.magnitude
	return damage

func position_components(origin: Vector3, ignore: Array[String]=[]) -> Dictionary:
	var key := _key(origin)+str(ignore)
	if _positions.has(key): return _positions[key]
	var result := {"objective":objective_value(origin),"warnings":-float(_warning_damage(origin,ignore))*policy.warning_damage_weight,"protection":0.0,"support":0.0}
	for ability in actor.definition.abilities:
		if ability==null or ability.effect!=AbilityDefinition.Effect.HEAL or actor.cooldown_remaining(ability.stable_id)>0: continue
		for friend in allies:
			if friend==actor or mini(ability.magnitude,friend.definition.maximum_health-friend.health)<policy.minimum_healing: continue
			if not _allowed(): break
			if combat.evaluate_ability_position(actor,friend,origin,ability.stable_id).valid():
				result.support+=policy.support_access_weight
			else:
				result.support-=minf(10,maxf(0,origin.distance_to(friend.ground_anchor())-ability.maximum_range))*policy.support_access_weight
	if actor.definition.basic_attack!=null and actor.definition.basic_attack.attack_type==AttackDefinition.Type.MELEE:
		for friend in allies:
			if friend==actor or friend.definition.basic_attack==null or friend.definition.basic_attack.attack_type!=AttackDefinition.Type.RANGED: continue
			for foe in opponents:
				if ignore.has(foe.stable_id) or foe.definition.basic_attack==null or foe.definition.basic_attack.attack_type!=AttackDefinition.Type.MELEE: continue
				var start := NavigationService.planar(foe.global_position)
				var finish := NavigationService.planar(friend.global_position)
				if start.distance_to(finish)>foe.definition.movement_allowance+2: continue
				var closest := Geometry3D.get_closest_point_to_segment(NavigationService.planar(origin),start,finish)
				if closest.distance_to(start)<.5 or closest.distance_to(finish)<.5: continue
				result.protection+=maxf(0,1-origin.distance_to(closest)/2)*policy.protection_weight
	_positions[key]=result
	return result

func incoming_damage(unit: CombatUnit) -> int:
	if _incoming.has(unit.stable_id): return _incoming[unit.stable_id]
	var total := 0
	for foe in opponents:
		var strongest := 0
		if foe.definition.basic_attack!=null and _allowed() and combat.evaluate_attack_position(foe,unit,foe.global_position).valid(): strongest=foe.definition.basic_attack.damage
		for ability in foe.definition.abilities:
			if ability==null or ability.effect!=AbilityDefinition.Effect.DAMAGE or ability.targeting==AbilityDefinition.Target.GROUND or foe.cooldown_remaining(ability.stable_id)>0: continue
			if _allowed() and combat.evaluate_ability_position(foe,unit,foe.global_position,ability.stable_id).valid(): strongest=maxi(strongest,ability.magnitude)
		total+=strongest
	_incoming[unit.stable_id]=total
	return total

func target_components(target: CombatUnit, origin: Vector3) -> Dictionary:
	var key := target.stable_id+_key(origin)
	if _targets.has(key): return _targets[key]
	var threat := 0
	if target.definition.basic_attack!=null:
		for friend in allies:
			if _allowed() and combat.evaluate_attack_position(target,friend,target.global_position,null,false,origin if friend==actor else friend.global_position).valid(): threat=maxi(threat,target.definition.basic_attack.damage)
	var result := {"focus":float(target.definition.maximum_health-target.health)*policy.focus_fire_weight,"threat":float(threat)*policy.target_threat_weight}
	_targets[key]=result
	return result

func status_relevance(target: CombatUnit, origin: Vector3) -> float:
	var key := target.stable_id+_key(origin)
	if _statuses.has(key): return _statuses[key]
	var relevance := 0.0
	if target.definition.movement_allowance>0:
		var attack := target.definition.basic_attack
		var clear_shot := false
		if attack!=null:
			for friend in allies:
				if _allowed() and combat.evaluate_attack_position(target,friend,target.global_position,null,false,origin if friend==actor else friend.global_position).valid():
					clear_shot=true
					break
		if attack!=null and attack.attack_type==AttackDefinition.Type.MELEE:
			relevance=.15 if clear_shot else 1.0
		elif not clear_shot: relevance=.5
		var objective := combat.objectives
		if objective.definition.kind!=ObjectiveDefinition.Kind.ELIMINATION and not objective.contains(target.ground_anchor()): relevance=maxf(relevance,.75)
		if _warning_damage(target.global_position,[],target)>0: relevance=maxf(relevance,.75)
	_statuses[key]=relevance
	return relevance


