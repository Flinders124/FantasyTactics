class_name EnemyTactics
extends RefCounted
## One bounded decision for this game's basic attacks, Mend, Slowed and Fireburst.
## No world mutation, randomness, future commands or cross-turn cache.
const EPSILON: float = .0001
const MAX_PATH_SEGMENTS: int = 128
class Action extends RefCounted:
	var target_id: String = ""
	var ability_id: String = ""
	var ground: bool = false
	var point: Vector3
	var score: float = 0
	var breakdown: Dictionary = {}
	var defeats: Array[String] = []
	func command(id: String) -> CombatCommand:
		if ground:
			var request := UseAbilityCommand.on_ground(id,ability_id,point)
			request.require_safe_area=true
			return request
		return AttackCommand.new(id,target_id) if ability_id.is_empty() else UseAbilityCommand.new(id,target_id,ability_id)
	func key() -> String:
		return target_id+":"+ability_id

class Plan extends RefCounted:
	var destination: Vector3
	var action: Action
	var action_first: bool = false
	var moving: bool = false
	var score: float = 0
	var breakdown: Dictionary = {}
	var candidate_index: int = 0
	func summary() -> Dictionary:
		return {"target":action.target_id if action!=null else "","ability":action.ability_id if action!=null else "","area":action.ground if action!=null else false,"destination":str(destination),"moving":moving,"action_first":action_first,"score":score,"breakdown":breakdown}

var controller: CombatController
var actor: CombatUnit
var profile: EnemyTacticalProfile
var foes: Array[CombatUnit] = []
var friends: Array[CombatUnit] = []
var abilities: Array[AbilityDefinition] = []
var points: Array[Vector3] = []
var raw: Array[Dictionary] = []
var route_cache: Dictionary = {}
var position_cache: Dictionary = {}
var danger_cache: Dictionary = {}
var rejected: Dictionary = {}
var current_action: Action
var best: Plan
var cursor: int = 0
var evaluated: int = 0
var path_queries: int = 0
var action_queries: int = 0
var planning_usec: int = 0
var max_chunk_usec: int = 0
var frames: int = 0
var done: bool = false
var allow_move: bool = true
var allow_action: bool = true
var _positions_seen: Dictionary = {}
var _endpoints_seen: Dictionary = {}

static func profile_for(unit: CombatUnit) -> EnemyTacticalProfile:
	return profile_for_definition(unit.definition)

static func profile_for_definition(definition: UnitDefinition) -> EnemyTacticalProfile:
	if definition.tactical_profile!=null: return definition.tactical_profile
	return load("res://definitions/tactics_ranged.tres" if definition.basic_attack!=null and definition.basic_attack.attack_type==AttackDefinition.Type.RANGED else "res://definitions/tactics_melee.tres") as EnemyTacticalProfile

func begin(combat: CombatController,unit: CombatUnit,movement: bool=true,actions: bool=true) -> void:
	var start := Time.get_ticks_usec()
	controller=combat
	actor=unit
	profile=profile_for(unit)
	allow_move=movement and unit.movement_remaining>.05 and controller.navigation.ready_for_queries
	allow_action=actions and unit.action_available
	for candidate in controller.units:
		if not is_instance_valid(candidate) or not candidate.is_alive(): continue
		if candidate.faction==unit.faction: friends.append(candidate)
		else: foes.append(candidate)
	foes.sort_custom(func(a: CombatUnit,b: CombatUnit) -> bool: return a.stable_id<b.stable_id)
	friends.sort_custom(func(a: CombatUnit,b: CombatUnit) -> bool: return a.stable_id<b.stable_id)
	for ability in unit.definition.abilities:
		if ability!=null: abilities.append(ability)
	abilities.sort_custom(func(a: AbilityDefinition,b: AbilityDefinition) -> bool: return a.stable_id<b.stable_id)
	points=area_points(foes)
	current_action=action_at(unit.global_position)
	best=Plan.new()
	best.destination=NavigationService.planar(unit.global_position)
	best.action=current_action
	best.score=current_action.score if current_action!=null else 0.0
	best.breakdown=current_action.breakdown.duplicate() if current_action!=null else {}
	_positions_seen[_key(best.destination)]=true
	if allow_move: _generate()
	done=raw.is_empty()
	var elapsed := Time.get_ticks_usec()-start
	planning_usec+=elapsed
	max_chunk_usec=maxi(max_chunk_usec,elapsed)

static func area_points(targets: Array[CombatUnit]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for target in targets:
		if target.area_markers_valid() and result.size()<12: result.append(target.ground_anchor())
	for first in range(targets.size()):
		for second in range(first+1,targets.size()):
			if result.size()>=12: return result
			if targets[first].area_markers_valid() and targets[second].area_markers_valid():
				result.append(targets[first].ground_anchor().lerp(targets[second].ground_anchor(),.5))
	return result

func _key(point: Vector3) -> String:
	return str(point.snapped(Vector3.ONE*.001))

func _reject(reason: String) -> void:
	rejected[reason]=int(rejected.get(reason,0))+1

func _query_allowed() -> bool:
	if action_queries>=clampi(profile.max_action_queries,64,1600):
		_reject("Action-query cap")
		return false
	action_queries+=1
	return true

func _total(parts: Dictionary) -> float:
	var result := 0.0
	for value in parts.values(): result+=float(value)
	return result

func _action_better(candidate: Action,previous: Action) -> bool:
	return previous==null or candidate.score>previous.score+EPSILON or (absf(candidate.score-previous.score)<=EPSILON and candidate.key()<previous.key())

func _danger(unit: CombatUnit) -> int:
	if danger_cache.has(unit.stable_id): return danger_cache[unit.stable_id]
	var damage := 0
	for foe in foes:
		if foe.definition.basic_attack!=null and _query_allowed() and controller.evaluate_attack_position(foe,unit,foe.global_position).valid():
			damage=maxi(damage,foe.definition.basic_attack.damage)
	danger_cache[unit.stable_id]=damage
	return damage

func action_at(origin: Vector3) -> Action:
	if not allow_action: return null
	var result: Action
	if actor.definition.basic_attack!=null:
		for target in foes:
			if not _query_allowed(): break
			var preview := controller.evaluate_attack_position(actor,target,origin)
			if not preview.valid():
				_reject(preview.error)
				continue
			var choice := Action.new()
			choice.target_id=target.stable_id
			choice.breakdown=profile.damage_components(actor.definition.basic_attack.damage,target.health)
			choice.score=_total(choice.breakdown)
			if actor.definition.basic_attack.damage>=target.health: choice.defeats.append(target.stable_id)
			if _action_better(choice,result): result=choice
	for ability in abilities:
		if actor.cooldown_remaining(ability.stable_id)>0:
			_reject("Cooldown: "+ability.stable_id)
			continue
		if ability.targeting==AbilityDefinition.Target.GROUND:
			for point in points:
				if not _query_allowed(): break
				var preview := controller.evaluate_ground_ability_position(actor,point,origin,ability.stable_id)
				if not preview.valid():
					_reject(preview.error)
					continue
				var choice := Action.new()
				choice.ground=true
				choice.point=point
				choice.ability_id=ability.stable_id
				choice.breakdown={"damage":0.0,"defeat":0.0,"multiple":0.0,"cooldown":-profile.cooldown_weight*ability.cooldown_turns}
				var hostile_count := 0
				var unsafe := false
				for hit in preview.hits:
					if hit.unit.faction==actor.faction:
						unsafe=true
						break
					hostile_count+=1
					if choice.target_id.is_empty(): choice.target_id=hit.unit.stable_id
					var parts := profile.damage_components(ability.magnitude,hit.health_before)
					choice.breakdown.damage+=parts.damage
					choice.breakdown.defeat+=parts.defeat
					if hit.health_after==0: choice.defeats.append(hit.unit.stable_id)
				if unsafe or hostile_count<(1 if ability.telegraphed else 2):
					_reject("Unsafe blast" if unsafe else "Area needs two hostiles")
					continue
				choice.breakdown.multiple=float(hostile_count-1)*profile.multi_target_bonus
				if ability.telegraphed: choice.breakdown["warning_delay"]=-1.0
				choice.score=_total(choice.breakdown)
				if _action_better(choice,result): result=choice
			continue
		var targets := friends if ability.effect==AbilityDefinition.Effect.HEAL else foes
		for target in targets:
			if not _query_allowed(): break
			var preview := controller.evaluate_ability_position(actor,target,origin,ability.stable_id)
			if not preview.valid():
				_reject(preview.error)
				continue
			var choice := Action.new()
			choice.target_id=target.stable_id
			choice.ability_id=ability.stable_id
			if ability.effect==AbilityDefinition.Effect.HEAL:
				choice.breakdown=profile.healing_components(ability.magnitude,target.health,target.definition.maximum_health,_danger(target))
				if choice.breakdown.is_empty():
					_reject("Healing below meaningful threshold")
					continue
			else:
				choice.breakdown=profile.damage_components(ability.magnitude,target.health)
				if ability.magnitude>=target.health: choice.defeats.append(target.stable_id)
				elif ability.applied_status!=null and target.definition.movement_allowance>0 and ability.applied_status.movement_multiplier<1:
					var future := 0
					if target.statuses.has(ability.applied_status.stable_id): future=target.statuses[ability.applied_status.stable_id].future_turns
					choice.breakdown.status=profile.status_value(future,ability.applied_status.affected_turns)
			choice.breakdown.cooldown=-profile.cooldown_weight*ability.cooldown_turns
			choice.score=_total(choice.breakdown)
			if _action_better(choice,result): result=choice
	return result

func _add_raw(point: Vector3,target: CombatUnit,attack: AttackDefinition) -> void:
	if raw.size()>=clampi(profile.max_raw_candidates,12,80) or not point.is_finite(): return
	var key := _key(point)
	if _positions_seen.has(key): return
	_positions_seen[key]=true
	raw.append({"point":NavigationService.planar(point),"target":target,"attack":attack})

func _generate() -> void:
	if controller.objectives.definition.kind==ObjectiveDefinition.Kind.EXTRACTION:
		for foe in foes: _add_raw(foe.ground_anchor().lerp(controller.objectives.center,.65),null,null)
	for point in controller.objectives.tactical_points(): _add_raw(point,null,null)
	# Interleave stable targets/angles so one target cannot monopolize the cap.
	var count := clampi(profile.ring_samples,4,12)
	var attacks: Array[AttackDefinition] = []
	if actor.definition.basic_attack!=null: attacks.append(actor.definition.basic_attack)
	for ability in abilities:
		if ability.targeting!=AbilityDefinition.Target.GROUND and actor.cooldown_remaining(ability.stable_id)==0 and ability.effect==AbilityDefinition.Effect.DAMAGE:
			attacks.append(ability)
	for angle_index in range(count):
		for ring_index in range(2):
			for target in foes:
				for attack in attacks:
					var contact := actor.collision_radius()+target.collision_radius()
					var ranged := attack.attack_type==AttackDefinition.Type.RANGED
					var height := actor.attack_origin_at(actor.global_position).y-target.target_point().y
					var outer := sqrt(maxf(0,attack.maximum_range*attack.maximum_range-height*height)) if ranged else contact+attack.maximum_range
					var preferred := clampf(profile.preferred_distance,attack.minimum_range+.15,attack.maximum_range-.15) if ranged else contact+profile.preferred_distance
					var radius := maxf(contact+.12,outer-.12) if ring_index==0 else maxf(contact+.12,preferred)
					var center := target.global_position
					if ranged: center=target.target_point()-(actor.attack_origin_at(actor.global_position)-actor.global_position)
					var nearest := atan2(actor.global_position.z-center.z,actor.global_position.x-center.x)
					var angle := nearest+TAU*float(angle_index)/count
					_add_raw(center+Vector3(cos(angle),0,sin(angle))*radius,target,attack)
				# Healing positions share the same bounded rings and path budget.
				for ability in abilities:
					if ability.effect!=AbilityDefinition.Effect.HEAL or actor.cooldown_remaining(ability.stable_id)>0: continue
					for friend in friends:
						if friend==actor or friend.definition.maximum_health-friend.health<profile.minimum_healing: continue
						var angle := atan2(actor.global_position.z-friend.global_position.z,actor.global_position.x-friend.global_position.x)+TAU*float(angle_index)/count
						_add_raw(friend.global_position+Vector3(cos(angle),0,sin(angle))*maxf(.9,ability.maximum_range-.2),friend,ability)

func _route(point: Vector3) -> NavigationService.Route:
	var key := _key(point)
	if route_cache.has(key): return route_cache[key]
	if path_queries>=clampi(profile.max_path_queries,16,96):
		_reject("Path-query cap")
		return null
	path_queries+=1
	var route := controller.evaluate_move(actor,point,false)
	if route.valid() and controller.warned_position(actor,point): route.error="Friendly elite warning"
	if route.valid():
		if route.path.size()>MAX_PATH_SEGMENTS:
			route.error="Path complexity cap"
		else:
			for unit in controller.units:
				if unit==actor or not is_instance_valid(unit) or not unit.is_alive(): continue
				var clearance := actor.collision_radius()+unit.collision_radius()+.025
				for index in range(1,route.path.size()):
					var closest := Geometry3D.get_closest_point_to_segment(NavigationService.planar(unit.global_position),route.path[index-1],route.path[index])
					if closest.distance_to(NavigationService.planar(unit.global_position))<clearance:
						route.error="Path crosses a living unit"
						break
				if not route.valid(): break
	route_cache[key]=route
	if not route.valid(): _reject(route.error)
	return route

func _position(origin: Vector3,ignore: Array[String]=[]) -> float:
	var key := _key(origin)+str(ignore)
	if position_cache.has(key): return position_cache[key]
	var nearest := INF
	var value := controller.objectives.position_value(origin)
	var ranged := actor.definition.basic_attack!=null and actor.definition.basic_attack.attack_type==AttackDefinition.Type.RANGED
	for foe in foes:
		if ignore.has(foe.stable_id): continue
		var distance := NavigationService.planar(origin-foe.global_position).length()
		var gap := maxf(0,distance-actor.collision_radius()-foe.collision_radius())
		nearest=minf(nearest,distance if ranged else gap)
		if ranged and gap<1.5: value-=profile.adjacency_penalty
		if foe.definition.basic_attack!=null and _query_allowed() and controller.evaluate_attack_position(foe,actor,foe.global_position,null,false,origin).valid():
			value-=float(foe.definition.basic_attack.damage)*profile.exposure_weight
	if is_finite(nearest): value-=minf(20,absf(nearest-profile.preferred_distance))*profile.distance_weight
	for friend in friends:
		if friend!=actor and origin.distance_to(friend.global_position)<1.2: value-=profile.crowding_weight
	position_cache[key]=value
	return value

func _consider(destination: Vector3,route: NavigationService.Route,action: Action,first: bool,index: int,progress: float=0) -> void:
	var defeated: Array[String] = []
	if action!=null: defeated.assign(action.defeats)
	var gain := _position(destination,defeated)-_position(actor.global_position,defeated)
	if action_queries>=clampi(profile.max_action_queries,64,1600): return
	var cost := route.distance*profile.movement_cost_weight
	var no_action_gain := action!=null and current_action!=null and action.score<=current_action.score+EPSILON
	if gain-cost+progress<profile.minimum_reposition_gain and (action==null or no_action_gain): return
	var plan := Plan.new()
	plan.destination=destination
	plan.action=action
	plan.action_first=first
	plan.moving=true
	plan.candidate_index=index
	plan.breakdown=action.breakdown.duplicate() if action!=null else {}
	var objective_gain := controller.objectives.position_value(destination)-controller.objectives.position_value(actor.global_position)
	plan.breakdown.objective=objective_gain
	plan.breakdown.position=gain-objective_gain
	plan.breakdown.movement=-cost
	plan.breakdown.progress=progress
	plan.score=(action.score if action!=null else 0.0)+gain-cost+progress
	var previous_key := best.action.key() if best.action!=null else "~"
	var key := action.key() if action!=null else "~"
	var tie := absf(plan.score-best.score)<=EPSILON
	if plan.score>best.score+EPSILON or (tie and (key<previous_key or (key==previous_key and (index<best.candidate_index or (index==best.candidate_index and first and not best.action_first))))): best=plan

func step() -> void:
	if done: return
	var start := Time.get_ticks_usec()
	frames+=1
	for batch in range(clampi(profile.positions_per_frame,1,4)):
		if cursor>=raw.size() or evaluated>=clampi(profile.max_candidates,8,40)-1 or path_queries>=clampi(profile.max_path_queries,16,96) or action_queries>=clampi(profile.max_action_queries,64,1600):
			done=true
			break
		var item: Dictionary = raw[cursor]
		cursor+=1
		var route := _route(item.point)
		if route==null or not route.valid(): continue
		var full_cost := route.distance
		var progress := 0.0
		if route.distance>actor.movement_remaining-.02:
			# Only pursue reachable legal attack/heal destinations, never a target centre.
			if not _query_allowed(): continue
			var full_valid := item.target==null or controller.evaluate_attack_position(actor,item.target,item.point,item.attack,item.target.faction==actor.faction).valid()
			if not full_valid: continue
			var endpoint := NavigationService.point_at_distance(route.path,maxf(0,actor.movement_remaining-.02))
			route=_route(endpoint) # Requery actual route; a prefix alone is not approval.
			if route==null or not route.valid() or route.distance>actor.movement_remaining+0.000001: continue
			progress=maxf(0,route.distance-(full_cost-route.distance)*.08)
		if route.distance<=.05: continue
		var endpoint: Vector3 = route.path[-1]
		var endpoint_key := _key(endpoint)
		if _endpoints_seen.has(endpoint_key): continue
		_endpoints_seen[endpoint_key]=true
		evaluated+=1
		var next_action := action_at(endpoint)
		_consider(endpoint,route,next_action,false,cursor,progress if allow_action and next_action==null and current_action==null else 0.0)
		if current_action!=null: _consider(endpoint,route,current_action,true,cursor)
	var elapsed := Time.get_ticks_usec()-start
	planning_usec+=elapsed
	max_chunk_usec=maxi(max_chunk_usec,elapsed)

func report() -> Dictionary:
	var result := best.summary()
	result.profile=EnemyTacticalProfile.Role.keys()[profile.role]
	result.objective=controller.objectives.definition.stable_id
	result.path_queries=path_queries
	result.action_queries=action_queries
	result.evaluated_positions=evaluated+1
	result.raw_candidates=raw.size()
	result.frames=frames
	result.compute_ms=float(planning_usec)/1000.0
	result.max_chunk_ms=float(max_chunk_usec)/1000.0
	result.rejections=rejected.duplicate()
	return result
