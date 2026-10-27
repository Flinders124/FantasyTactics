class_name EnemyController
extends Node

signal routine_started(actor_id: String, serial: int)
signal command_submitted(actor_id: String, kind: String, accepted: bool)
signal status_changed(message: String)
signal planning_progress(actor_id: String, serial: int)
signal decision_chosen(details: Dictionary)

enum Stage { IDLE, THINK, WAIT_NAVIGATION, PLANNING, EXECUTE, WAIT_MOVE, AFTER_MOVE, WAIT_ATTACK, AFTER_ACTION, FINISH }
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not value and is_node_ready():
			cancel()
@export_range(0.0, 0.5) var presentation_delay: float = 0.15
@export_range(4, 16) var candidates_per_ring: int = 12
const ENDPOINT_ATTEMPTS: int = 8
const COST_TIE_TOLERANCE: float = 0.0001
var tutorial_policy: bool = false
var controller: CombatController
var stage: Stage = Stage.IDLE
var actor_id: String = ""
var serial: int = -1
var epoch: int = 0
var move_attempted: bool = false
var attack_attempted: bool = false
var delay_timer: Timer
var _queued: bool = false
@export var diagnostics_enabled: bool = false
var planner: EnemyTactics
var last_diagnostics: Dictionary = {}
var decision_history: Array[Dictionary] = []
var turn_path_queries: int = 0
var turn_action_queries: int = 0
var planning_restarts: int = 0
var _revision: int = 0
var _planning_revision: int = 0
var _planning_positions: Dictionary = {}
var _planning_map_iteration: int = 0
var _planner_accounted: bool = false
var _last_started_serial: int = -1

class Approach extends RefCounted:
	var target_id: String = ""
	var route: NavigationService.Route
	var destination: Vector3 = Vector3.ZERO

func bind(combat: CombatController) -> void:
	assert(controller == null, "Bind EnemyController once; restart reuses connections")
	controller = combat
	delay_timer = Timer.new()
	delay_timer.one_shot = true
	add_child(delay_timer)
	delay_timer.timeout.connect(_on_delay_timeout)
	controller.turn_started.connect(_on_turn_started)
	controller.state_changed.connect(_on_state_changed)
	controller.action_completed.connect(_on_action_completed)
	controller.navigation.synchronization_finished.connect(_on_navigation_finished)
	controller.encounter_updated.connect(func() -> void: _revision+=1)

func cancel() -> void:
	_account_planner()
	epoch += 1
	stage = Stage.IDLE
	actor_id = ""
	serial = -1
	_queued = false
	planner=null
	if delay_timer != null:
		delay_timer.stop()
	status_changed.emit("")

func _on_state_changed(state: CombatController.State) -> void:
	if state==CombatController.State.SETUP:
		decision_history.clear()
		last_diagnostics.clear()
	if state in [CombatController.State.SETUP, CombatController.State.TURN_START, CombatController.State.TURN_END, CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
		cancel()

func _on_turn_started(unit: CombatUnit, turn_number: int) -> void:
	if turn_number!=controller.turn_serial or unit!=controller.scheduler.active_unit(): return
	if _last_started_serial==turn_number:
		return
	cancel()
	if not enabled or unit.faction != CombatUnit.Faction.ENEMY or not unit.is_alive():
		return
	_last_started_serial=turn_number
	actor_id = unit.stable_id
	serial = turn_number
	move_attempted = false
	attack_attempted = false
	turn_path_queries=0
	turn_action_queries=0
	planning_restarts=0
	stage = Stage.THINK
	status_changed.emit("%s considers its turn" % unit.definition.display_name)
	routine_started.emit(actor_id, serial)
	_schedule()

func _current_actor() -> CombatUnit:
	if not enabled or serial != controller.turn_serial or stage == Stage.IDLE:
		return null
	var actor := controller.find_unit(actor_id)
	if actor == null or not actor.is_alive() or actor != controller.scheduler.active_unit() or actor.faction != CombatUnit.Faction.ENEMY:
		return null
	return actor

func _schedule() -> void:
	if _queued or stage == Stage.IDLE:
		return
	_queued = true
	if presentation_delay > 0.0:
		delay_timer.start(clampf(presentation_delay, 0.001, 0.5))
	else:
		_run_queued.call_deferred(epoch)

func _on_delay_timeout() -> void:
	_run_queued(epoch)

func _run_queued(ticket: int) -> void:
	if ticket != epoch:
		return
	_queued = false
	if controller.guidance_paused: return
	var actor := _current_actor()
	if actor == null:
		cancel()
		return
	if controller.state != CombatController.State.AWAITING_COMMAND:
		return # Only completion/turn signals resume decisions; never poll actions.
	match stage:
		Stage.THINK:
			if tutorial_policy:
				status_changed.emit("Training opponent holds position and ends its turn.")
				stage=Stage.FINISH
				_schedule()
				return
			if not controller.navigation.ready_for_queries and not controller.navigation.synchronization_complete:
				stage = Stage.WAIT_NAVIGATION
				return
			_begin_plan(actor)
		Stage.EXECUTE:
			_execute_plan(actor)
		Stage.AFTER_MOVE:
			# A fresh current-position evaluation, never the pre-move target snapshot.
			var choice := EnemyTactics.new()
			choice.begin(controller,actor,false,not attack_attempted)
			turn_action_queries+=choice.action_queries
			if choice.best.action==null or not _submit_action(actor,choice.best.action):
				stage = Stage.FINISH
				_schedule()
		Stage.AFTER_ACTION:
			if not move_attempted and actor.movement_remaining>.05:
				_begin_plan(actor)
			else:
				stage=Stage.FINISH
				_schedule()
		Stage.FINISH:
			var id := actor_id
			status_changed.emit("%s ends turn" % actor.definition.display_name)
			var accepted := controller.submit_command(EndTurnCommand.new(id))
			command_submitted.emit(id, "end", accepted)
			# End Turn is guaranteed legal for a valid awaiting actor. A rejection
			# caused by a concurrent state change cancels this stale routine.
			if not accepted:
				cancel()

func _begin_plan(actor: CombatUnit) -> void:
	_account_planner()
	planner=EnemyTactics.new()
	_planner_accounted=false
	planner.begin(controller,actor,not move_attempted,not attack_attempted)
	_planning_revision=_revision
	_planning_positions.clear()
	for unit in controller.units:
		if is_instance_valid(unit): _planning_positions[unit.stable_id]=unit.global_position
	_planning_map_iteration=NavigationServer3D.map_get_iteration_id(controller.navigation.map) if controller.navigation.map.is_valid() else 0
	stage=Stage.PLANNING

func _account_planner() -> void:
	if planner!=null and not _planner_accounted:
		turn_path_queries+=planner.path_queries
		turn_action_queries+=planner.action_queries
		_planner_accounted=true

func _decision_is_fresh() -> bool:
	if _revision!=_planning_revision or not controller.navigation.ready_for_queries: return false
	if NavigationServer3D.map_get_iteration_id(controller.navigation.map)!=_planning_map_iteration: return false
	for unit in controller.units:
		if not is_instance_valid(unit) or not _planning_positions.has(unit.stable_id) or unit.global_position!=_planning_positions[unit.stable_id]: return false
	return true

func _recover_plan(actor: CombatUnit) -> void:
	if planning_restarts<1:
		planning_restarts+=1
		_begin_plan(actor)
	else:
		_account_planner()
		stage=Stage.AFTER_MOVE # Current legal action or End Turn; no further search.
		_schedule()

func _process(_delta: float) -> void:
	if stage!=Stage.PLANNING: return
	var actor := _current_actor()
	if actor==null or controller.state!=CombatController.State.AWAITING_COMMAND:
		cancel()
		return
	if not _decision_is_fresh() and controller.navigation.ready_for_queries:
		_recover_plan(actor)
		return
	var ticket := epoch
	planner.step() # At most profile.positions_per_frame endpoints this frame.
	planning_progress.emit(actor_id,serial)
	if ticket!=epoch or _current_actor()==null or planner==null: return
	if not _decision_is_fresh() and controller.navigation.ready_for_queries: return
	if planner.done:
		_account_planner()
		last_diagnostics=planner.report()
		last_diagnostics.actor_id=actor_id
		last_diagnostics.turn=serial
		last_diagnostics.turn_path_queries=turn_path_queries
		last_diagnostics.turn_action_queries=turn_action_queries
		last_diagnostics.restarts=planning_restarts
		last_diagnostics.seed=0
		var config: EncounterConfiguration = get_parent().get("configuration")
		if config!=null: last_diagnostics.seed=config.battlefield_seed
		decision_history.append(last_diagnostics.duplicate(true))
		if decision_history.size()>8: decision_history.pop_front()
		if diagnostics_enabled and OS.is_debug_build(): print("AI_DECISION ",JSON.stringify(last_diagnostics))
		decision_chosen.emit(last_diagnostics.duplicate(true))
		if ticket!=epoch or _current_actor()==null: return
		stage=Stage.EXECUTE
		_schedule()

func _execute_plan(actor: CombatUnit) -> void:
	if planner==null:
		stage=Stage.AFTER_MOVE
		_schedule()
		return
	if not _decision_is_fresh() and controller.navigation.ready_for_queries:
		_recover_plan(actor)
		return
	var plan := planner.best
	if plan.action!=null and (not plan.moving or plan.action_first):
		if not _submit_action(actor,plan.action):
			stage=Stage.FINISH
			_schedule()
	elif plan.moving and not move_attempted:
		move_attempted=true
		stage=Stage.WAIT_MOVE
		var id := actor_id
		var ticket := epoch
		status_changed.emit("%s moves"%actor.definition.display_name)
		if ticket!=epoch or _current_actor()==null: return
		var accepted := controller.submit_command(MoveCommand.new(id,plan.destination))
		command_submitted.emit(id,"move",accepted)
		if not accepted and _current_actor()!=null:
			stage=Stage.AFTER_MOVE
			_schedule()
	else:
		stage=Stage.FINISH
		_schedule()

func _submit_action(actor: CombatUnit,choice: EnemyTactics.Action) -> bool:
	if attack_attempted or choice==null: return false
	attack_attempted=true
	stage=Stage.WAIT_ATTACK
	var id := actor_id
	var ticket := epoch
	var message := "%s attacks %s"%[actor.definition.display_name,choice.target_id]
	if not choice.ability_id.is_empty():
		message="%s uses %s"%[actor.definition.display_name,actor.ability_by_id(choice.ability_id).display_name]
	status_changed.emit(message)
	if ticket!=epoch or _current_actor()==null: return true
	var accepted := controller.submit_command(choice.command(id))
	command_submitted.emit(id,"attack",accepted)
	if not accepted and _current_actor()!=null:
		stage=Stage.FINISH
		_schedule()
	return true

func _on_navigation_finished(_success: bool) -> void:
	if stage == Stage.WAIT_NAVIGATION and _current_actor() != null:
		stage = Stage.THINK
		_schedule()

func _on_action_completed(id: String, action: String, _reason: String) -> void:
	if id != actor_id or _current_actor() == null:
		return
	if action == "move" and stage == Stage.WAIT_MOVE:
		stage = Stage.AFTER_MOVE
		_schedule()
	elif action == "attack" and stage == Stage.WAIT_ATTACK:
		stage = Stage.AFTER_ACTION
		_schedule()

func living_targets(actor: CombatUnit) -> Array[CombatUnit]:
	var heroes: Array[CombatUnit] = []
	for unit in controller.units:
		if unit.is_alive() and unit.faction != actor.faction:
			heroes.append(unit)
	heroes.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool: return a.stable_id < b.stable_id)
	return heroes

func choose_approach(actor: CombatUnit) -> Approach:
	if actor.definition.basic_attack == null or not actor.attack_markers_valid() or not controller.navigation.ready_for_queries:
		return null
	var best: Approach
	var sample_count := clampi(candidates_per_ring, 4, 16)
	# Stable hero order, ring order, then angle index break equal-cost ties.
	for hero in living_targets(actor):
		if not hero.attack_markers_valid():
			continue
		var contact := actor.collision_radius() + hero.collision_radius()
		var attack := actor.definition.basic_attack
		var reach := attack.maximum_range
		var radii: Array[float] = []
		var center := NavigationService.planar(hero.global_position)
		if attack.attack_type == AttackDefinition.Type.RANGED:
			# Translate 3D marker range into horizontal rings; the shared validator
			# remains authoritative for every sampled position, including offsets.
			var height := actor.attack_origin_at(actor.global_position).y - hero.target_point().y
			var outer := sqrt(maxf(0.0, reach * reach - height * height))
			var inner := sqrt(maxf(0.0, attack.minimum_range * attack.minimum_range - height * height))
			center = NavigationService.planar(hero.target_point() - (actor.attack_origin_at(actor.global_position) - actor.global_position))
			radii = [maxf(0.0, outer - 0.12), (inner + outer) * 0.5, maxf(contact + 0.12, inner + 0.12)]
		else:
			radii = [contact + maxf(0.0, reach - 0.12), contact + minf(0.15, reach * 0.5)]
		for radius in radii:
			for index in range(sample_count):
				var angle := TAU * float(index) / float(sample_count)
				var destination := center + Vector3(cos(angle), 0, sin(angle)) * radius
				var route := controller.evaluate_approach(actor, hero, destination)
				if route.valid() and (best == null or route.distance < best.route.distance - COST_TIE_TOLERANCE):
					best = Approach.new()
					best.target_id = hero.stable_id
					best.route = route
					best.destination = destination
	return best

func stopping_route(actor: CombatUnit, approach: Approach) -> NavigationService.Route:
	if approach == null or move_attempted or actor.movement_remaining <= 0.05:
		return null
	var distance := minf(approach.route.distance, maxf(0.0, actor.movement_remaining - 0.02))
	for attempt in range(ENDPOINT_ATTEMPTS):
		var endpoint := NavigationService.point_at_distance(approach.route.path, distance * (1.0 - float(attempt) / ENDPOINT_ATTEMPTS))
		# Requery the actual path; a prefix's nominal distance alone is insufficient.
		var route := controller.evaluate_move(actor, endpoint)
		if route.valid() and route.distance > 0.05:
			return route
	return null

class AreaChoice extends RefCounted:
	var ability_id: String
	var point: Vector3
	var score: int = 0

func choose_area(actor: CombatUnit) -> AreaChoice:
	const MAX_POINTS: int = 12
	var max_radius: float = 0.0
	for ability in actor.definition.abilities:
		if ability != null and ability.targeting == AbilityDefinition.Target.GROUND and is_finite(ability.area_radius):
			max_radius = maxf(max_radius, ability.area_radius)
	if max_radius <= 0.0:
		return null
	var targets := living_targets(actor)
	var points: Array[Vector3] = []
	for target in targets:
		if target.area_markers_valid() and points.size() < MAX_POINTS:
			points.append(target.ground_anchor())
	for first in range(targets.size()):
		for second in range(first + 1, targets.size()):
			if points.size() >= MAX_POINTS:
				break
			if targets[first].area_markers_valid() and targets[second].area_markers_valid() and targets[first].ground_anchor().distance_to(targets[second].ground_anchor()) <= max_radius * 2.0 + AreaTargetingService.BOUNDARY_EPSILON:
				points.append(targets[first].ground_anchor().lerp(targets[second].ground_anchor(), 0.5))
	var best: AreaChoice
	for ability in actor.definition.abilities:
		if ability == null or ability.targeting != AbilityDefinition.Target.GROUND:
			continue
		for point in points:
			var preview := controller.evaluate_ground_ability(actor, point, ability.stable_id)
			if not preview.valid():
				continue
			var score: int = 0
			var hostile_count: int = 0
			var friendly_fire: bool = false
			for hit in preview.hits:
				if hit.unit.faction == actor.faction:
					score -= hit.health_lost()
					friendly_fire = true
				else:
					score += hit.health_lost()
					hostile_count += 1
			if friendly_fire or hostile_count < 2 or score <= 0:
				continue
			# Equipped ability, stable target and pair order break equal scores.
			if best == null or score > best.score:
				best = AreaChoice.new()
				best.ability_id = ability.stable_id
				best.point = point
				best.score = score
	return best

