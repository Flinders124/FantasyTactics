class_name CombatController
extends Node

signal state_changed(state: State)
signal selection_changed(unit: CombatUnit)
signal encounter_updated
signal feedback_changed(message: String)
signal turn_started(unit: CombatUnit, serial: int)
signal action_completed(actor_id: String, action: String, reason: String)
signal combat_event(kind: String, data: Dictionary)
signal encounter_reset
enum State { SETUP, TURN_START, AWAITING_COMMAND, RESOLVING_ACTION, TURN_END, VICTORY, DEFEAT, DRAW }
var _finalizing_outcome: bool = false
var survival_enabled: bool = false
var retreat_center: Vector3 = Vector3.ZERO
var retreat_radius: float = 2.8
var guidance_paused: bool = false
var player_command_policy: Callable
var objectives: ObjectiveController = ObjectiveController.new()
var outcome_reason: String = ""
var completed_rounds: int = 0
var result_summary: Dictionary = {}
var state: State = State.SETUP
var units: Array[CombatUnit] = []
var scheduler: TurnManager
var navigation: NavigationService
var motor: MovementMotor
@export_range(0.05, 1.0) var attack_resolution_seconds: float = 0.22
var _attack_remaining: float = -1.0
var _spawn_transforms: Dictionary = {}
var turn_serial: int = 0
var _attacking_actor_id: String = ""
var _damage_in_progress: bool = false
var _pending_deaths: Array[CombatUnit] = []
var _moving_actor_id: String = ""
var _submitting_command: bool = false
var _lifecycle_epoch: int = 0
var area_targeting: AreaTargetingService = AreaTargetingService.new()
var pending_telegraphs: Dictionary = {}
var _event_serial: int = 0
var _presentation_action_serial: int = 0
var _recent_transitions: Array[Dictionary] = []

func _ready() -> void:
	var warnings:=EliteWarnings.new()
	add_child(warnings)
	warnings.bind(self)

func _publish_event(kind: String, payload: Dictionary) -> void:
	# Immutable resolved snapshots; IDs are monotonic even across in-place restart.
	# Presentation may deduplicate delivery without owning damage/completion.
	_event_serial+=1
	var data := payload.duplicate()
	data.event_id="%d:%d"%[get_instance_id(),_event_serial]
	data.event_sequence=_event_serial
	data.action_id="%d:%d"%[get_instance_id(),_presentation_action_serial]
	for key: String in ["actor","target"]:
		var unit := find_unit(str(data.get(key+"_id","")))
		if unit!=null:
			data[key+"_position"]=unit.global_position
			data[key+"_role"]=unit.definition.visual_id
	combat_event.emit(kind,data)

class AttackPreview extends RefCounted:
	var distance: float = 0.0
	var error: String = ""
	func valid() -> bool:
		return error.is_empty()

func find_unit(id: String) -> CombatUnit:
	for unit in units:
		if is_instance_valid(unit) and unit.stable_id == id:
			return unit
	return null

func evaluate_attack(actor: CombatUnit, target: CombatUnit) -> AttackPreview:
	return _evaluate_attack(actor, target, State.AWAITING_COMMAND)

func _action_error(actor: CombatUnit, expected_state: State) -> String:
	if state != expected_state:
		return "Encounter ended" if state in [State.VICTORY, State.DEFEAT, State.DRAW] else "Wait for the current action to finish"
	if actor == null or actor != scheduler.active_unit() or not actor.is_alive():
		return "Only the active living unit can act"
	if not actor.action_available:
		return "No action remaining"
	return ""

func _evaluate_attack(actor: CombatUnit, target: CombatUnit, expected_state: State) -> AttackPreview:
	var result := AttackPreview.new()
	var error := _action_error(actor, expected_state)
	if not error.is_empty():
		result.error = error
		return result
	if target == null or not units.has(target) or not target.is_alive():
		result.error = "Choose a living target"
	elif target.faction == actor.faction:
		result.error = "Target must be hostile"
	else:
		return evaluate_attack_position(actor, target, actor.global_position)
	return result

func evaluate_melee_position(actor: CombatUnit, target: CombatUnit, origin: Vector3) -> AttackPreview:
	# Compatibility wrapper: all attacks now use the same geometry helper.
	return evaluate_attack_position(actor, target, origin)

func evaluate_attack_position(actor: CombatUnit, target: CombatUnit, origin: Vector3, override: AttackDefinition = null, friendly: bool = false, target_position: Vector3 = Vector3.INF, allow_downed: bool = false) -> AttackPreview:
	# Identical calculations for previews, hypothetical AI positions and execution.
	var result := AttackPreview.new()
	if actor == null or not actor.is_alive() or target == null or not units.has(target) or (not target.is_alive() and not (allow_downed and target.is_downed() and target.carried_by == null)):
		result.error = "Choose living units"
	elif (actor.faction == target.faction) != friendly:
		result.error = "Target must be friendly" if friendly else "Target must be hostile"
	elif override == null and actor.definition.basic_attack == null:
		result.error = "No basic attack is defined"
	elif not actor.attack_markers_valid() or not target.attack_markers_valid():
		result.error = "Missing attack or target marker"
	else:
		var attack := override if override != null else actor.definition.basic_attack
		var from := actor.attack_origin_at(origin)
		var target_at := target_position if target_position.is_finite() else target.global_position
		var to := target.target_point()+target_at-target.global_position
		if not from.is_finite() or not to.is_finite() or not is_finite(attack.minimum_range) or not is_finite(attack.maximum_range) or attack.minimum_range < 0.0 or attack.maximum_range < attack.minimum_range or attack.damage <= 0 or attack.obstruction_mask == 0:
			result.error = "Invalid attack configuration"
			return result
		var ranged := attack.attack_type == AttackDefinition.Type.RANGED
		result.distance = from.distance_to(to) if ranged else maxf(0.0, NavigationService.planar(origin - target_at).length() - actor.collision_radius() - target.collision_radius())
		if result.distance < attack.minimum_range - 0.000001:
			result.error = "Too close"
		elif result.distance > attack.maximum_range + 0.000001:
			result.error = "Out of range" if ranged else "Out of melee range"
		elif actor != target:
			var ray := PhysicsRayQueryParameters3D.create(from, to, attack.obstruction_mask)
			var excluded: Array[RID] = [actor.get_rid()]
			if target_position.is_finite(): excluded.append(target.get_rid())
			ray.exclude=excluded
			ray.hit_from_inside = true
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider != target:
				result.error = "Line of sight blocked" if ranged else "Melee attack is obstructed"
	return result

func _resolve_attack(actor: CombatUnit, target: CombatUnit) -> bool:
	var preview := evaluate_attack(actor, target)
	if not preview.valid():
		feedback_changed.emit(preview.error)
		return false
	var serial := turn_serial
	_set_state(State.RESOLVING_ACTION)
	# Revalidate after state notifications, immediately before spending resources.
	preview = _evaluate_attack(actor, target, State.RESOLVING_ACTION)
	if not preview.valid() or serial != turn_serial:
		if state == State.RESOLVING_ACTION and serial == turn_serial:
			_set_state(State.AWAITING_COMMAND)
		feedback_changed.emit(preview.error if not preview.valid() else "Turn changed")
		return false
	var attack := actor.definition.basic_attack
	var from := actor.attack_origin_at(actor.global_position)
	var to := target.target_point()
	_attack_remaining = clampf(attack_resolution_seconds, 0.05, 1.0)
	_attacking_actor_id = actor.stable_id
	_presentation_action_serial+=1
	actor.spend_action()
	actor.play_attack_effect(false, target.global_position)
	# Rules execute once here. Presentation has no damage or completion callbacks.
	var health_before := target.health
	_damage_in_progress = true
	_deal_damage(target, attack.damage)
	_damage_in_progress = false
	_publish_event("attack", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "target_id": target.stable_id, "target": target.definition.display_name, "attack_type": attack.type_label(), "attack_name": attack.display_name, "origin": from, "target_point": to, "damage": attack.damage, "health_lost": health_before - target.health})
	for dead in _pending_deaths:
		_record_death(dead)
	_pending_deaths.clear()
	feedback_changed.emit("%s attacks %s: %d damage" % [actor.definition.display_name, target.definition.display_name, actor.definition.basic_attack.damage])
	_check_outcome(true)
	encounter_updated.emit()
	return true

func _process(delta: float) -> void:
	if state == State.RESOLVING_ACTION and _attack_remaining >= 0.0:
		_attack_remaining -= delta
		if _attack_remaining <= 0.0:
			var actor_id := _attacking_actor_id
			_attack_remaining = -1.0
			if not _check_outcome():
				_set_state(State.AWAITING_COMMAND)
				encounter_updated.emit()
			action_completed.emit(actor_id, "attack", "Attack resolved")

func restart_encounter() -> void:
	if scheduler == null or state == State.SETUP:
		return
	_lifecycle_epoch += 1
	var ticket := _lifecycle_epoch
	# Signals raised by spending or damage may request a restart. Finish that
	# synchronous transaction first so an area batch cannot modify fresh units.
	if _submitting_command:
		await get_tree().process_frame
		if ticket != _lifecycle_epoch or not is_inside_tree():
			return
	turn_serial += 1
	_set_state(State.SETUP)
	_reset_presentation()
	if motor != null:
		motor.stop("Restarting encounter")
	selection_changed.emit(null)
	for unit in units:
		if ticket != _lifecycle_epoch:
			return
		unit.global_transform = _spawn_transforms[unit.stable_id]
		unit.reset_for_encounter()
	feedback_changed.emit("")
	# Let deferred collider restoration synchronize before accepting commands.
	await get_tree().process_frame
	if ticket != _lifecycle_epoch or not is_inside_tree():
		return
	await get_tree().physics_frame
	if ticket != _lifecycle_epoch or not is_inside_tree():
		return
	setup(units.duplicate(), scheduler, false)

func _reset_presentation() -> void:
	pending_telegraphs.clear()
	_moving_actor_id = ""
	_pending_deaths.clear()
	encounter_reset.emit()

func configure_movement(service: NavigationService, movement_motor: MovementMotor) -> void:
	navigation = service
	motor = movement_motor
	motor.progress.connect(func() -> void:
		# Inclusion feedback may update during travel; success is still sampled
		# only by the authoritative completed-action/round boundary.
		objectives.refresh(units)
		encounter_updated.emit())
	motor.completed.connect(_movement_completed)

func evaluate_move(actor: CombatUnit, destination: Vector3, enforce_budget: bool = true, expected_state: State = State.AWAITING_COMMAND) -> NavigationService.Route:
	var route := NavigationService.Route.new()
	if state != expected_state:
		route.error = "Wait for the current action to finish"
	elif actor == null or actor != scheduler.active_unit() or not actor.is_alive():
		route.error = "Only the active living unit can move"
	elif navigation == null or motor == null:
		route.error = "Movement is unavailable"
	else:
		route = navigation.query_path(actor.global_position, destination)
		if route.valid():
			if _destination_occupied(actor, destination):
				route.error = "Destination is occupied"
			elif route.distance <= motor.arrival_tolerance:
				route.error = "Choose a different destination"
			elif enforce_budget and route.distance > actor.movement_remaining + 0.000001:
				route.error = "Not enough movement"
	return route

func evaluate_approach(actor: CombatUnit, target: CombatUnit, destination: Vector3) -> NavigationService.Route:
	var route := evaluate_move(actor, destination, false)
	if route.valid():
		var shot := evaluate_attack_position(actor, target, destination)
		if not shot.valid():
			route.error = shot.error
	return route

func _destination_occupied(actor: CombatUnit, destination: Vector3) -> bool:
	# Shrink height slightly so the floor does not count as an occupant.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.58
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, NavigationService.planar(destination) + Vector3.UP * 0.81)
	query.exclude = [actor.get_rid()]
	query.collision_mask = 1
	return not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _movement_completed(reason: String) -> void:
	var actor_id := motor.actor.stable_id if is_instance_valid(motor.actor) else ""
	if not _moving_actor_id.is_empty() and state != State.SETUP:
		var actor := find_unit(_moving_actor_id)
		if actor != null:
			_publish_event("move", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "distance": motor.travelled_distance, "reason": reason})
	_moving_actor_id = ""
	if state == State.RESOLVING_ACTION and not _check_outcome(true):
		_set_state(State.AWAITING_COMMAND)
	feedback_changed.emit(reason)
	encounter_updated.emit()
	action_completed.emit(actor_id, "move", reason)

func setup(roster: Array[CombatUnit], manager: TurnManager, reset_presentation: bool = true) -> void:
	_lifecycle_epoch += 1
	_set_state(State.SETUP)
	if reset_presentation:
		_reset_presentation()
	_finalizing_outcome=false
	units.assign(roster)
	scheduler = manager
	var ids: Dictionary = {}
	for unit in units:
		unit.set_active(false)
		unit.survival_enabled = survival_enabled and unit.faction==CombatUnit.Faction.HERO
		assert(not unit.stable_id.is_empty() and not ids.has(unit.stable_id), "Unit IDs must be unique and nonempty")
		ids[unit.stable_id] = true
		if not _spawn_transforms.has(unit.stable_id):
			_spawn_transforms[unit.stable_id] = unit.global_transform
		if not unit.runtime_event.is_connected(_on_runtime_event.bind(unit)):
			unit.runtime_event.connect(_on_runtime_event.bind(unit))
		if not unit.health_changed.is_connected(_on_health_changed):
			unit.health_changed.connect(_on_health_changed)
		if not unit.resources_changed.is_connected(_on_resources_changed):
			unit.resources_changed.connect(_on_resources_changed)
		if not unit.died.is_connected(_on_unit_died):
			unit.died.connect(_on_unit_died)
	objectives.survival_enabled=survival_enabled
	objectives.reset(units)
	outcome_reason=""
	completed_rounds=0
	result_summary.clear()
	if not scheduler.round_completed.is_connected(_round_completed): scheduler.round_completed.connect(_round_completed)
	scheduler.configure(units)
	_start_next_turn()

func _set_state(next: State) -> void:
	if next != State.RESOLVING_ACTION:
		_attack_remaining = -1.0
		_attacking_actor_id = ""
	if OS.is_debug_build():
		_recent_transitions.append({"from": State.keys()[state], "to": State.keys()[next], "turn": turn_serial, "epoch": _lifecycle_epoch})
		if _recent_transitions.size() > 24: _recent_transitions.pop_front()
	state = next
	state_changed.emit(state)

func _round_completed(round_number: int) -> void:
	if state in [State.SETUP,State.VICTORY,State.DEFEAT,State.DRAW]: return
	completed_rounds=maxi(completed_rounds,round_number)
	if objectives.definition.kind==ObjectiveDefinition.Kind.HOLD_GROUND and round_number<=objectives.last_checked_round: return
	var ticket := _lifecycle_epoch
	_damage_in_progress=true
	for unit in units: unit.on_round_end(round_number)
	_damage_in_progress=false
	for dead in _pending_deaths: _record_death(dead)
	_pending_deaths.clear()
	objectives.round_end(round_number,units)
	if ticket!=_lifecycle_epoch: return
	if objectives.definition.kind==ObjectiveDefinition.Kind.HOLD_GROUND:
		_publish_event("objective", {"message":"Round %d: %s"%[round_number,objectives.summary()]})
	_check_outcome()

func _check_outcome(completed_action: bool = false) -> bool:
	if _finalizing_outcome or state in [State.VICTORY, State.DEFEAT, State.DRAW]: return true
	var ticket := _lifecycle_epoch
	var proposal := objectives.proposed_outcome(units,completed_action)
	if ticket!=_lifecycle_epoch: return true
	if proposal.is_empty(): return false
	_finalizing_outcome=true
	_damage_in_progress=true
	if survival_enabled:
		if proposal.result=="victory" and objectives.definition.kind==ObjectiveDefinition.Kind.EXTRACTION:
			# Reaching the exit is itself the objective's atomic success boundary.
			# Mark carriers and companions safe before ordinary recovery settlement.
			for unit in units:
				if unit.faction==CombatUnit.Faction.HERO and unit.is_alive(): unit.set_extracted()
		for unit in units:
			if unit.faction==CombatUnit.Faction.HERO:
				unit.finalize_survival(proposal.result=="victory" or proposal.result=="draw")
	_damage_in_progress=false
	for dead in _pending_deaths: _record_death(dead)
	_pending_deaths.clear()
	if ticket!=_lifecycle_epoch:
		_finalizing_outcome=false
		return true
	pending_telegraphs.clear()
	outcome_reason=proposal.reason
	if scheduler!=null: scheduler.halted=true
	for unit in units: unit.set_active(false)
	var defeated_heroes: PackedStringArray=[]
	var defeated_enemies: PackedStringArray=[]
	for unit in units:
		if unit.is_alive() or unit.life_state==CombatUnit.LifeState.EXTRACTED: continue
		if unit.faction==CombatUnit.Faction.HERO: defeated_heroes.append(unit.definition.display_name)
		else: defeated_enemies.append(unit.definition.display_name)
	result_summary={"completed_rounds":completed_rounds,"ended_round":scheduler.round_number,"defeated_heroes":defeated_heroes,"defeated_enemies":defeated_enemies,"reason":outcome_reason}
	var result: String=proposal.result
	_set_state(State.DRAW if result=="draw" else (State.VICTORY if result=="victory" else State.DEFEAT))
	_publish_event("result", {"victory":result=="victory","draw":result=="draw","reason":outcome_reason,"completed_rounds":completed_rounds,"defeated_heroes":defeated_heroes,"defeated_enemies":defeated_enemies})
	if motor!=null: motor.stop("Encounter ended")
	selection_changed.emit(null)
	encounter_updated.emit()
	_finalizing_outcome=false
	return true

func _start_next_turn() -> void:
	if _check_outcome():
		return
	turn_serial += 1
	var serial := turn_serial
	var ticket := _lifecycle_epoch
	_set_state(State.TURN_START)
	if not _turn_is_current(ticket, serial):
		return
	var unit := scheduler.advance()
	if not _turn_is_current(ticket, serial) or unit == null or not unit.is_alive():
		return
	unit.begin_turn()
	if not _turn_is_current(ticket, serial):
		return
	if pending_telegraphs.has(unit.stable_id):
		_resolve_telegraph(unit)
		if not _turn_is_current(ticket,serial): return
		if not unit.is_alive():
			_set_state(State.TURN_END)
			_start_next_turn()
			return
	unit.set_active(true)
	selection_changed.emit(unit)
	if not _turn_is_current(ticket, serial):
		return
	_set_state(State.AWAITING_COMMAND)
	if not _turn_is_current(ticket, serial):
		return
	encounter_updated.emit()
	if not _turn_is_current(ticket, serial):
		return
	_publish_event("turn", {"actor_id": unit.stable_id, "actor": unit.definition.display_name, "round": scheduler.round_number})
	if _turn_is_current(ticket, serial):
		turn_started.emit(unit, serial)

func _turn_is_current(ticket: int, serial: int) -> bool:
	return ticket == _lifecycle_epoch and serial == turn_serial and state not in [State.SETUP, State.VICTORY, State.DEFEAT, State.DRAW]

func submit_player_command(command: CombatCommand) -> bool:
	var active := scheduler.active_unit() if scheduler != null else null
	if command == null or active == null or active.faction != CombatUnit.Faction.HERO or active.stable_id != command.actor_id:
		feedback_changed.emit("Enemy turn — player combat input is disabled")
		return false
	if player_command_policy.is_valid():
		var restriction: String = player_command_policy.call(command)
		if not restriction.is_empty():
			feedback_changed.emit(restriction)
			return false
	return submit_command(command)

func submit_command(command: CombatCommand) -> bool:
	if guidance_paused:
		feedback_changed.emit("Close the briefing or help to continue.")
		return false
	# In addition to state gating, reject synchronous reentry from UI/signals.
	# In particular End Turn emits notifications before advancing the scheduler.
	if _submitting_command:
		return false
	_submitting_command = true
	var accepted := _submit_command(command)
	_submitting_command = false
	return accepted

func _submit_command(command: CombatCommand) -> bool:
	if state != State.AWAITING_COMMAND or command == null:
		feedback_changed.emit("Wait for the current action to finish")
		return false
	var active := scheduler.active_unit()
	if active == null or not active.is_alive() or command.actor_id != active.stable_id:
		feedback_changed.emit("Only the active living unit can act")
		return false
	if command is RescueCommand:
		return _resolve_rescue(active, find_unit(command.target_id), command.kind)
	if command is UseAbilityCommand:
		var ability := active.ability_by_id(command.ability_id)
		if ability == null:
			feedback_changed.emit("Ability not equipped")
			return false
		var error: String = command.target_data_error(ability.targeting == AbilityDefinition.Target.GROUND)
		if not error.is_empty():
			feedback_changed.emit(error)
			return false
		if ability.targeting == AbilityDefinition.Target.GROUND:
			return _resolve_area(active,command.ground_position,command.ability_id,command.require_safe_area)
		return _resolve_ability(active, find_unit(command.target_id), command.ability_id)
	if command is AttackCommand:
		var target := find_unit(command.target_id)
		return _resolve_attack(active, target)
	if command is MoveCommand:
		var route := evaluate_move(active, command.destination)
		if not route.valid():
			feedback_changed.emit(route.error)
			return false
		var serial := turn_serial
		var ticket := _lifecycle_epoch
		_set_state(State.RESOLVING_ACTION)
		feedback_changed.emit("%s moves" % active.definition.display_name)
		route = evaluate_move(active, command.destination, true, State.RESOLVING_ACTION)
		if not _turn_is_current(ticket, serial) or not route.valid():
			if _turn_is_current(ticket, serial) and state == State.RESOLVING_ACTION:
				_set_state(State.AWAITING_COMMAND)
			feedback_changed.emit(route.error if not route.valid() else "Turn changed")
			return false
		_moving_actor_id = active.stable_id
		_presentation_action_serial+=1
		motor.start(active, route.path)
		return true
	if not command is EndTurnCommand:
		return false
	# Any notification may cancel this turn by shutting down or restarting.
	var ticket := _lifecycle_epoch
	var serial := turn_serial
	feedback_changed.emit("")
	if not _turn_is_current(ticket, serial): return false
	_set_state(State.RESOLVING_ACTION)
	if not _turn_is_current(ticket, serial): return false
	_set_state(State.TURN_END)
	if not _turn_is_current(ticket, serial): return false
	active.end_turn()
	if not _turn_is_current(ticket, serial): return false
	active.set_active(false)
	_start_next_turn()
	return true

func _on_health_changed(unit: CombatUnit) -> void:
	if state in [State.SETUP, State.VICTORY, State.DEFEAT, State.DRAW]:
		return
	if _damage_in_progress:
		return # Publish encounter updates only after all committed damage.
	if motor != null and motor.running and (not unit.is_alive() and unit == motor.actor):
		motor.stop("Movement cancelled: actor died")
	if _check_outcome(true):
		return
	if unit == scheduler.active_unit() and not unit.is_alive():
		_set_state(State.TURN_END)
		unit.set_active(false)
		_start_next_turn()
	else:
		encounter_updated.emit()

func _on_resources_changed(_unit: CombatUnit) -> void:
	if scheduler != null and not _damage_in_progress:
		encounter_updated.emit()

func _on_unit_died(unit: CombatUnit) -> void:
	if pending_telegraphs.erase(unit.stable_id):
		_publish_event("telegraph_cancel", {"actor_id":unit.stable_id,"actor":unit.definition.display_name})
	if state == State.SETUP:
		return
	if _damage_in_progress:
		_pending_deaths.append(unit)
	else:
		_record_death(unit)

func _record_death(unit: CombatUnit) -> void:
	_publish_event("death", {"actor_id": unit.stable_id, "actor": unit.definition.display_name})

func _on_runtime_event(kind: String, data: Dictionary, unit: CombatUnit) -> void:
	data["actor_id"] = unit.stable_id
	data["actor"] = unit.definition.display_name
	_publish_event(kind, data)

func _ability_error(actor: CombatUnit, id: String, expected_state: State) -> String:
	var error := _action_error(actor, expected_state)
	if not error.is_empty():
		return error
	var ability := actor.ability_by_id(id)
	if ability == null or id.is_empty():
		return "Ability not equipped"
	if actor.cooldown_remaining(id) > 0:
		return "Cooldown: %d owner turn start(s) until ready" % actor.cooldown_remaining(id)
	if ability.magnitude <= 0 or ability.cooldown_turns < 0:
		return "Invalid ability configuration"
	if ability.targeting != AbilityDefinition.Target.GROUND and (ability.effect in [AbilityDefinition.Effect.HEAL, AbilityDefinition.Effect.WARD, AbilityDefinition.Effect.TOW]) != (ability.targeting == AbilityDefinition.Target.FRIENDLY):
		return "Invalid ability configuration"
	return ""

func evaluate_ability(actor: CombatUnit, target: CombatUnit, id: String, expected_state: State = State.AWAITING_COMMAND) -> AttackPreview:
	return evaluate_ability_position(actor,target,actor.global_position if actor!=null else Vector3.ZERO,id,expected_state)

func evaluate_ability_position(actor: CombatUnit, target: CombatUnit, origin: Vector3, id: String, expected_state: State = State.AWAITING_COMMAND) -> AttackPreview:
	var result := AttackPreview.new()
	result.error = _ability_error(actor, id, expected_state)
	if not result.valid():
		return result
	var ability := actor.ability_by_id(id)
	if ability.targeting == AbilityDefinition.Target.GROUND:
		result.error = "Select a ground point for this ability"
	elif target == null or (not target.is_alive() and not (target.is_downed() and target.carried_by==null and ability.effect in [AbilityDefinition.Effect.HEAL, AbilityDefinition.Effect.TOW])):
		result.error = "Choose a living or recoverable friendly target"
	elif ability.effect == AbilityDefinition.Effect.HEAL and target.is_downed() and _destination_occupied(target,target.global_position):
		result.error = "Make room around the companion before reviving"
	elif ability.effect == AbilityDefinition.Effect.HEAL and target.health >= target.definition.maximum_health:
		result.error = "Target already at full health"
	else:
		result = evaluate_attack_position(actor,target,origin,ability,ability.targeting==AbilityDefinition.Target.FRIENDLY,origin if actor==target else Vector3.INF,ability.effect in [AbilityDefinition.Effect.HEAL, AbilityDefinition.Effect.TOW])
		if result.valid() and ability.effect in [AbilityDefinition.Effect.PULL, AbilityDefinition.Effect.TOW]:
			var destination := displacement_endpoint(actor,target,origin,ability.displacement_distance)
			if not destination.is_finite(): result.error = "No clear space to pull target"
		if result.valid() and ability.effect==AbilityDefinition.Effect.WARD and target.ward_remaining>=ability.magnitude and target.ward_future_turns>=2:
			result.error = "Target already has an equally strong ward"
		return result
	return result

func evaluate_ground_ability(actor: CombatUnit, point: Vector3, id: String, expected_state: State = State.AWAITING_COMMAND) -> AreaTargetingService.Result:
	return evaluate_ground_ability_position(actor,point,actor.global_position if actor!=null else Vector3.ZERO,id,expected_state)

func evaluate_ground_ability_position(actor: CombatUnit, point: Vector3, origin: Vector3, id: String, expected_state: State = State.AWAITING_COMMAND) -> AreaTargetingService.Result:
	var result := AreaTargetingService.Result.new()
	result.error = _ability_error(actor, id, expected_state)
	if not result.valid():
		return result
	return area_targeting.query(actor,actor.ability_by_id(id),point,units,navigation,origin)

func _resolve_ability(actor: CombatUnit, target: CombatUnit, id: String) -> bool:
	var preview := evaluate_ability(actor, target, id)
	if not preview.valid():
		feedback_changed.emit(preview.error)
		return false
	var serial := turn_serial
	_set_state(State.RESOLVING_ACTION)
	preview = evaluate_ability(actor, target, id, State.RESOLVING_ACTION)
	if not preview.valid() or serial != turn_serial:
		if state == State.RESOLVING_ACTION and serial == turn_serial:
			_set_state(State.AWAITING_COMMAND)
		feedback_changed.emit(preview.error if not preview.valid() else "Turn changed")
		return false
	var ability := actor.ability_by_id(id)
	_attack_remaining = clampf(attack_resolution_seconds, 0.05, 1.0)
	_attacking_actor_id = actor.stable_id
	_presentation_action_serial+=1
	actor.spend_action()
	actor.start_cooldown(ability)
	actor.play_attack_effect(ability.effect in [AbilityDefinition.Effect.HEAL,AbilityDefinition.Effect.WARD,AbilityDefinition.Effect.PULL,AbilityDefinition.Effect.TOW], target.global_position)
	var before := target.health
	_damage_in_progress = true
	if ability.effect == AbilityDefinition.Effect.HEAL:
		target.heal(ability.magnitude)
	elif ability.effect == AbilityDefinition.Effect.WARD:
		target.apply_ward(ability.magnitude)
	elif ability.effect in [AbilityDefinition.Effect.DAMAGE, AbilityDefinition.Effect.PULL]:
		_deal_damage(target, ability.magnitude)
	if ability.effect in [AbilityDefinition.Effect.PULL, AbilityDefinition.Effect.TOW] and target.is_surviving():
		var destination := displacement_endpoint(actor,target,actor.global_position,ability.displacement_distance)
		if destination.is_finite():
			# A swept capsule validates the entire short forced motion. Rules commit
			# synchronously; presentation never owns completion or damage.
			if target.is_alive(): target.move_and_collide(destination-target.global_position, false, 0.0001)
			else: target.global_position=destination
			_publish_event("displace", {"actor_id":actor.stable_id,"target_id":target.stable_id,"message":"%s pulls %s" % [actor.definition.display_name,target.definition.display_name]})
	_damage_in_progress = false
	_publish_event("ability", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "target_id": target.stable_id, "target": target.definition.display_name, "ability": ability.display_name,"ability_id":id})
	if ability.effect == AbilityDefinition.Effect.HEAL:
		_publish_event("heal", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "target_id": target.stable_id, "target": target.definition.display_name, "healing": target.health - before,"ability_id":id})
	elif ability.effect in [AbilityDefinition.Effect.DAMAGE, AbilityDefinition.Effect.PULL]:
		_publish_event("attack", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "target_id": target.stable_id, "target": target.definition.display_name, "attack_type": ability.type_label(), "attack_name": ability.display_name, "origin": actor.attack_origin_at(actor.global_position), "target_point": target.target_point(), "damage": ability.magnitude, "health_lost": before - target.health,"ability_id":id})
	if target.is_alive() and ability.applied_status != null and ability.effect!=AbilityDefinition.Effect.WARD:
		target.apply_status(ability.applied_status)
	for dead in _pending_deaths:
		_record_death(dead)
	_pending_deaths.clear()
	feedback_changed.emit("%s uses %s on %s" % [actor.definition.display_name, ability.display_name, target.definition.display_name])
	_check_outcome(true)
	encounter_updated.emit()
	return true


func _resolve_area(actor: CombatUnit, point: Vector3, id: String, require_safe: bool=false) -> bool:
	var preview := evaluate_ground_ability(actor, point, id)
	if require_safe and preview.valid() and not _safe_area(actor,preview,id): preview.error="Area is no longer safe or lacks two hostiles"
	if not preview.valid():
		feedback_changed.emit(preview.error)
		return false
	var serial := turn_serial
	_set_state(State.RESOLVING_ACTION)
	# Snapshot fresh targets AND final health values after the last notifications.
	preview = evaluate_ground_ability(actor, point, id, State.RESOLVING_ACTION)
	if require_safe and preview.valid() and not _safe_area(actor,preview,id): preview.error="Area is no longer safe or lacks two hostiles"
	if not preview.valid() or serial != turn_serial:
		if state == State.RESOLVING_ACTION and serial == turn_serial:
			_set_state(State.AWAITING_COMMAND)
		feedback_changed.emit(preview.error if not preview.valid() else "Turn changed")
		return false
	var ability := actor.ability_by_id(id)
	_attack_remaining = clampf(attack_resolution_seconds, 0.05, 1.0)
	_attacking_actor_id = actor.stable_id
	_presentation_action_serial+=1
	actor.spend_action()
	if ability.telegraphed:
		pending_telegraphs[actor.stable_id]={"ability_id":id,"point":point,"prepared_turn":actor.owner_turn}
		actor.play_attack_effect(true,point)
		_publish_event("telegraph_prepare", {"actor_id":actor.stable_id,"actor":actor.definition.display_name,"ability":ability.display_name,"point":point,"radius":ability.area_radius})
		feedback_changed.emit("WARNING: %s prepares %s. Leave the marked area before its next turn."%[actor.definition.display_name,ability.display_name])
		encounter_updated.emit()
		return true
	actor.start_cooldown(ability)
	actor.play_attack_effect(true, point)
	_damage_in_progress = true
	for hit in preview.hits:
		_deal_damage(hit.unit, ability.magnitude)
	_damage_in_progress = false
	_publish_event("area", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "ability": ability.display_name, "point": point, "radius": ability.area_radius, "damage": ability.magnitude, "count": preview.hits.size()})
	for hit in preview.hits:
		_publish_event("area_hit", {"actor_id": actor.stable_id, "actor": actor.definition.display_name, "target_id": hit.unit.stable_id, "target": hit.unit.definition.display_name, "damage": ability.magnitude, "health_lost": hit.health_lost(), "friendly": hit.unit.faction == actor.faction})
	for dead in _pending_deaths:
		_record_death(dead)
	_pending_deaths.clear()
	feedback_changed.emit("%s uses %s: %d unit(s) hit" % [actor.definition.display_name, ability.display_name, preview.hits.size()])
	if not _check_outcome(true) and not actor.is_alive():
		# A self-kill with survivors must advance once, after the entire batch.
		_set_state(State.TURN_END)
		actor.set_active(false)
		_start_next_turn()
	encounter_updated.emit()
	return true


func shutdown() -> void:
	_lifecycle_epoch += 1
	turn_serial += 1
	_set_state(State.SETUP)
	_reset_presentation()
	if motor != null:
		motor.stop("Leaving encounter")
	selection_changed.emit(null)

func encounter_has_ended() -> bool:
	return state in [State.VICTORY,State.DEFEAT,State.DRAW]

func _resolve_telegraph(actor: CombatUnit) -> void:
	var warning: Dictionary=pending_telegraphs[actor.stable_id]
	pending_telegraphs.erase(actor.stable_id)
	var ability:=actor.ability_by_id(warning.ability_id)
	if ability==null or not actor.is_alive(): return
	var ticket := _lifecycle_epoch
	var serial := turn_serial
	_set_state(State.RESOLVING_ACTION)
	if not _turn_is_current(ticket, serial): return
	actor.spend_action()
	actor.start_cooldown(ability)
	_presentation_action_serial+=1
	# The location is committed; caster movement cannot alter blast geometry.
	var blast:=area_targeting.query(actor,ability,warning.point,units,navigation,Vector3.INF,true)
	_publish_event("telegraph_resolve", {"actor_id":actor.stable_id,"actor":actor.definition.display_name,"ability":ability.display_name,"point":warning.point,"radius":ability.area_radius})
	if blast.valid():
		_damage_in_progress=true
		for hit in blast.hits: _deal_damage(hit.unit, ability.magnitude)
		_damage_in_progress=false
		_publish_event("area", {"actor_id":actor.stable_id,"actor":actor.definition.display_name,"ability":ability.display_name,"point":warning.point,"radius":ability.area_radius,"damage":ability.magnitude,"count":blast.hits.size()})
		for hit in blast.hits:
			_publish_event("area_hit", {"actor_id":actor.stable_id,"actor":actor.definition.display_name,"target_id":hit.unit.stable_id,"target":hit.unit.definition.display_name,"damage":ability.magnitude,"health_lost":hit.health_lost(),"friendly":hit.unit.faction==actor.faction})
		for dead in _pending_deaths: _record_death(dead)
		_pending_deaths.clear()
	else: feedback_changed.emit("Prepared blast dissipated: "+blast.error)
	_check_outcome(true)
	encounter_updated.emit()

func warned_position(actor: CombatUnit, point: Vector3, all_factions: bool = false) -> bool:
	for id: String in pending_telegraphs:
		var caster:=find_unit(id)
		if caster==null or not caster.is_alive() or (not all_factions and caster.faction!=actor.faction): continue
		var ability:=caster.ability_by_id(pending_telegraphs[id].ability_id)
		if ability!=null and point.distance_to(pending_telegraphs[id].point)<=ability.area_radius+actor.collision_radius(): return true
	return false

func _safe_area(actor: CombatUnit, preview: AreaTargetingService.Result, id: String) -> bool:
	var ability:=actor.ability_by_id(id)
	return preview.hits.size()>=(1 if ability!=null and ability.telegraphed else 2) and preview.hits.all(func(hit: AreaTargetingService.Hit) -> bool: return hit.unit.faction!=actor.faction)

func diagnostic_snapshot() -> Dictionary:
	if not OS.is_debug_build(): return {}
	var active := scheduler.active_unit() if scheduler != null else null
	var eligible: PackedStringArray=[]
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive(): eligible.append(unit.stable_id)
	var pending: String="move" if motor!=null and motor.running else ("attack" if _attack_remaining>=0 else "")
	return {"pending_action":pending,"awaited_completion":"MovementMotor.completed" if pending=="move" else ("action resolution timer" if pending=="attack" else "command or turn event"),"eligible_units":eligible,"round":scheduler.round_number if scheduler!=null else 0,"state": State.keys()[state], "actor": active.stable_id if active != null else "", "turn": turn_serial, "epoch": _lifecycle_epoch, "attack_remaining": _attack_remaining, "moving_actor": _moving_actor_id, "submitting": _submitting_command, "pending_telegraphs": pending_telegraphs.keys(), "recent_transitions": _recent_transitions.duplicate(true)}
# All damage funnels through unit runtime shields/life state, including area hits.
func _deal_damage(target: CombatUnit, amount: int) -> int:
	if target.is_alive(): target.downed_round=scheduler.round_number if scheduler!=null else 0
	return target.damage(amount)

func displacement_endpoint(actor: CombatUnit, target: CombatUnit, origin: Vector3, distance: float) -> Vector3:
	if navigation==null or not navigation.ready_for_queries or target==actor or not is_finite(distance) or distance<=0 or distance>6: return Vector3.INF
	var direction := NavigationService.planar(origin-target.global_position)
	var length := minf(distance,maxf(0,direction.length()-actor.collision_radius()-target.collision_radius()-.12))
	if length<.1: return Vector3.INF
	var motion := direction.normalized()*length
	var shape := CapsuleShape3D.new()
	shape.radius=target.collision_radius()+.02
	shape.height=1.58
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,target.global_position+Vector3.UP*.81)
	query.motion=motion
	query.collision_mask=9
	query.exclude=[target.get_rid()]
	var fractions := target.get_world_3d().direct_space_state.cast_motion(query)
	var safe := maxf(0,fractions[0]-.02)
	if safe*length<.1: return Vector3.INF
	var endpoint := target.global_position+motion*safe
	var nearest := NavigationServer3D.map_get_closest_point(navigation.map,endpoint)
	if NavigationService.planar(nearest-endpoint).length()>.08: return Vector3.INF
	return endpoint

func evaluate_rescue(actor: CombatUnit, target: CombatUnit, kind: int, expected_state: State = State.AWAITING_COMMAND) -> AttackPreview:
	var preview := AttackPreview.new()
	if actor!=null and target!=null: preview.distance=maxf(0,actor.global_position.distance_to(target.global_position)-actor.collision_radius()-target.collision_radius())
	preview.error=_action_error(actor,expected_state)
	if not preview.valid(): return preview
	if not survival_enabled or actor.faction!=CombatUnit.Faction.HERO:
		preview.error="Rescue is available to campaign heroes"
	elif kind==RescueCommand.Kind.EXTRACT:
		var center := objectives.center if objectives.definition.kind==ObjectiveDefinition.Kind.EXTRACTION else retreat_center
		var radius := objectives.radius if objectives.definition.kind==ObjectiveDefinition.Kind.EXTRACTION else retreat_radius
		if actor.ground_anchor().distance_to(center)>radius+.000001: preview.error="Reach the marked extraction area first"
	elif kind==RescueCommand.Kind.DROP:
		if actor.carried_unit==null: preview.error="No companion is being carried"
		elif not rescue_drop_endpoint(actor).is_finite(): preview.error="No clear ground to set the companion down"
	elif kind not in [RescueCommand.Kind.STABILISE,RescueCommand.Kind.PICKUP]:
		preview.error="Unknown rescue command"
	elif target==null or not units.has(target) or target==actor or target.faction!=actor.faction or not target.is_downed() or target.carried_by!=null:
		preview.error="Choose a downed friendly companion on the ground"
	elif kind==RescueCommand.Kind.STABILISE and target.life_state==CombatUnit.LifeState.STABILISED:
		preview.error="Companion is already stabilised"
	elif kind==RescueCommand.Kind.PICKUP and actor.carried_unit!=null:
		preview.error="Already carrying a companion"
	elif preview.distance>1.5+.000001:
		preview.error="Move adjacent to the companion"
	else:
		var ray := PhysicsRayQueryParameters3D.create(actor.attack_origin_at(actor.global_position),target.target_point(),8,[actor.get_rid(),target.get_rid()])
		if not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): preview.error="Rescue is obstructed"
	return preview

func _resolve_rescue(actor: CombatUnit,target: CombatUnit,kind: int) -> bool:
	var preview := evaluate_rescue(actor,target,kind)
	if not preview.valid():
		feedback_changed.emit(preview.error)
		return false
	var serial := turn_serial
	_set_state(State.RESOLVING_ACTION)
	preview=evaluate_rescue(actor,target,kind,State.RESOLVING_ACTION)
	if not preview.valid() or serial!=turn_serial:
		if state==State.RESOLVING_ACTION: _set_state(State.AWAITING_COMMAND)
		return false
	actor.spend_action()
	match kind:
		RescueCommand.Kind.STABILISE: target.stabilise()
		RescueCommand.Kind.PICKUP: actor.pickup(target)
		RescueCommand.Kind.DROP:
			var endpoint := rescue_drop_endpoint(actor)
			var companion := actor.drop_carried()
			if companion!=null: companion.global_position=endpoint
		RescueCommand.Kind.EXTRACT: actor.set_extracted()
	_publish_event("rescue",{"actor_id":actor.stable_id,"target_id":target.stable_id if target!=null else actor.stable_id,"message":"%s: %s" % [actor.definition.display_name,RescueCommand.Kind.keys()[kind].capitalize()]})
	if not _check_outcome(true):
		if not actor.is_alive():
			_set_state(State.TURN_END)
			_start_next_turn()
		else: _set_state(State.AWAITING_COMMAND)
	encounter_updated.emit()
	action_completed.emit(actor.stable_id,"rescue","Rescue completed")
	return true

func abandon_encounter() -> void:
	if encounter_has_ended(): return
	_lifecycle_epoch+=1
	_damage_in_progress=true
	if survival_enabled:
		for unit in units:
			if unit.faction==CombatUnit.Faction.HERO: unit.finalize_survival(false)
	_damage_in_progress=false
	for dead in _pending_deaths: _record_death(dead)
	_pending_deaths.clear()
	pending_telegraphs.clear()
	if scheduler!=null: scheduler.halted=true
	_set_state(State.DEFEAT)
	outcome_reason="Mission abandoned. Only extracted companions survived."
	result_summary={"completed_rounds":completed_rounds,"reason":outcome_reason}
	if motor!=null: motor.stop("Mission abandoned")
	selection_changed.emit(null)
	encounter_updated.emit()

func rescue_drop_endpoint(actor: CombatUnit) -> Vector3:
	if navigation==null: return Vector3.INF
	for index in range(8):
		var angle := TAU*float(index)/8
		var point := actor.global_position+Vector3(cos(angle),0,sin(angle))*1.05
		var route := navigation.query_path(actor.global_position,point)
		if route.valid() and route.distance<1.5 and not _destination_occupied(actor,point): return point
	return Vector3.INF
