extends "res://tests/generation_tests.gd"
## Test-only AI-v-AI: -- --long/--encounters=N --start-case=N --seed=1740.
const PAIRS := [["knight","ranger"],["knight","mage"],["knight","cleric"],["ranger","mage"],["ranger","cleric"],["mage","cleric"]]
var results: Array[Dictionary] = []
var reproduction: Dictionary = {}
var metrics: Dictionary = {}
var commands: Dictionary = {}
var positions: Dictionary = {}
var case_epoch: int = 0
var active_turn: Dictionary = {}
var warning_actor: String = ""
var retained: Array[UnitDefinition] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("%s REPRO=%s" % [message,JSON.stringify(reproduction)])

func record_command(combat: CombatController, id: String, kind: String, accepted: bool, command_serial: int=-1) -> void:
	metrics.commands += 1
	if not accepted: metrics.command_rejections += 1
	# End Turn signals the next actor synchronously: use the captured actor turn.
	var submitted_serial: int = command_serial if command_serial>=0 else int(metrics.actor_serials.get(id,-1))
	var key := "%d:%s:%s" % [case_epoch,id,submitted_serial]
	if not commands.has(key): commands[key] = {}
	commands[key][kind] = int(commands[key].get(kind,0))+1
	check(int(commands[key][kind])<=1,"One %s submission per actor/turn/epoch" % kind)
	check(accepted,"AI command accepted: %s %s" % [id,kind])

func decision(data: Dictionary) -> void:
	metrics.decisions += 1
	for reason in data.get("rejections",{}):
		metrics.planner_rejections[reason] = int(metrics.planner_rejections.get(reason,0))+int(data.rejections[reason])
	metrics.decision_ms += float(data.get("compute_ms",0.0))
	metrics.max_decision_ms = maxf(metrics.max_decision_ms,float(data.get("compute_ms",0.0)))
	metrics.path_queries += int(data.get("path_queries",0))
	metrics.action_queries += int(data.get("action_queries",0))
	check(int(data.get("path_queries",0))<=96 and int(data.get("action_queries",0))<=1600,"Bounded decision query counts")
	check(int(data.get("evaluated_positions",0))<=40,"Bounded decision candidate count")
	if data.has("turn_path_queries"):
		check(data.turn_path_queries<=384 and data.turn_action_queries<=6400,"Bounded runtime turn totals")

func combat_event(combat: CombatController, kind: String, data: Dictionary) -> void:
	metrics.events[kind] = int(metrics.events.get(kind,0))+1
	if kind=="telegraph_resolve":
		var owner := combat.scheduler.active_unit()
		if owner!=null: start_turn(combat,owner)
		warning_actor = data.actor_id
	if kind in ["attack","area_hit"]:
		metrics.damage += int(data.get("health_lost",0))
		if kind=="area_hit" and data.actor_id==warning_actor: metrics.warning_damage += int(data.get("health_lost",0))
	if kind=="heal":
		metrics.effective_healing += int(data.healing)
		for unit in combat.units:
			if unit.stable_id==data.actor_id:
				var ability := unit.ability_by_id(data.ability_id)
				if ability!=null: metrics.overheal += maxi(0,ability.magnitude-int(data.healing))
	if kind in ["attack","ability","area","telegraph_prepare","telegraph_resolve","move"] and not active_turn.is_empty(): active_turn.activity = true
	if kind=="move":
		for unit in combat.units:
			if unit.stable_id!=data.actor_id: continue
			var history: Array[Vector3] = []
			if positions.has(unit.stable_id): history.assign(positions[unit.stable_id])
			for point in history:
				if point.distance_to(unit.global_position)<0.15:
					metrics.movement_repeats += 1
					break
			history.append(unit.global_position)
			if history.size()>4: history.pop_front()
			positions[unit.stable_id] = history

func finish_turn(combat: CombatController) -> void:
	if active_turn.is_empty(): return
	metrics.turns_completed += 1
	if not active_turn.activity: metrics.pass_turns += 1
	metrics.max_turn_ms = maxf(metrics.max_turn_ms,float(Time.get_ticks_usec()-int(active_turn.started))/1000.0)
	if combat.objectives.definition.kind!=ObjectiveDefinition.Kind.ELIMINATION:
		for unit in combat.units:
			if unit.stable_id==active_turn.actor and unit.is_alive() and combat.objectives.contains(unit.ground_anchor()):
				metrics.objective_participation["hero" if unit.faction==CombatUnit.Faction.HERO else "enemy"] += 1
	active_turn.clear()

func start_turn(combat: CombatController, unit: CombatUnit) -> void:
	if active_turn.get("actor","")==unit.stable_id and active_turn.get("serial",-1)==combat.turn_serial: return
	finish_turn(combat)
	active_turn = {"actor":unit.stable_id,"serial":combat.turn_serial,"activity":false,"started":Time.get_ticks_usec()}
	metrics.actor_serials[unit.stable_id] = combat.turn_serial
	metrics.turns_started += 1

func current(combat: CombatController, actor: CombatUnit, serial: int, epoch: int) -> bool:
	return is_instance_valid(actor) and actor.is_alive() and combat.turn_serial==serial and int(combat.diagnostic_snapshot().epoch)==epoch and combat.scheduler.active_unit()==actor and not combat.encounter_has_ended()

func wait_action(combat: CombatController, actor: CombatUnit, serial: int, epoch: int) -> void:
	for frame in range(1200):
		if not current(combat,actor,serial,epoch) or combat.state!=CombatController.State.RESOLVING_ACTION: return
		await process_frame
	check(false,"Action exceeded 1200 frame watchdog")

func submit(combat: CombatController, actor: CombatUnit, command: CombatCommand, kind: String) -> void:
	var command_serial := combat.turn_serial
	var accepted := combat.submit_player_command(command)
	record_command(combat,actor.stable_id,kind,accepted,command_serial)

func plan_for(combat: CombatController, actor: CombatUnit, movement: bool) -> EnemyTactics:
	var plan := EnemyTactics.new()
	var memory: Array[Vector3] = []
	if positions.has(actor.stable_id): memory.assign(positions[actor.stable_id])
	var supports_memory := false
	for method in plan.get_method_list():
		if method.name=="begin": supports_memory = method.args.size()>=5
	if supports_memory: plan.callv("begin",[combat,actor,movement,true,memory])
	else: plan.begin(combat,actor,movement,true)
	return plan

func hero_turn(combat: CombatController, actor: CombatUnit) -> void:
	var serial := combat.turn_serial
	var epoch := int(combat.diagnostic_snapshot().epoch)
	var plan := plan_for(combat,actor,true)
	for frame in range(128):
		if plan.done or not current(combat,actor,serial,epoch): break
		plan.step()
		await process_frame
	check(plan.done,"Hero planner completed in 128 chunks")
	if not plan.done or not current(combat,actor,serial,epoch): return
	decision(plan.report())
	var choice := plan.best
	if choice.action!=null and (not choice.moving or choice.action_first):
		submit(combat,actor,choice.action.command(actor.stable_id),"action")
		await wait_action(combat,actor,serial,epoch)
	if not current(combat,actor,serial,epoch) or combat.state!=CombatController.State.AWAITING_COMMAND: return
	if choice.moving:
		submit(combat,actor,MoveCommand.new(actor.stable_id,choice.destination),"move")
		await wait_action(combat,actor,serial,epoch)
	if not current(combat,actor,serial,epoch) or combat.state!=CombatController.State.AWAITING_COMMAND: return
	if actor.action_available:
		var fresh := plan_for(combat,actor,false)
		check(fresh.done,"Action-only replan synchronous")
		decision(fresh.report())
		if fresh.best.action!=null:
			submit(combat,actor,fresh.best.action.command(actor.stable_id),"action")
			await wait_action(combat,actor,serial,epoch)
	if current(combat,actor,serial,epoch) and combat.state==CombatController.State.AWAITING_COMMAND:
		submit(combat,actor,EndTurnCommand.new(actor.stable_id),"end")

func metric_self_test() -> void:
	var scene := await prepare(EncounterConfiguration.new())
	var combat := scene.get_node("CombatController") as CombatController
	if scene.guide!=null: scene.guide.close()
	metrics = {"events":{},"actor_serials":{},"turns_started":0,"turns_completed":0,"pass_turns":0,"max_turn_ms":0.0,"objective_participation":{"hero":0,"enemy":0}}
	active_turn.clear()
	var previous := combat.scheduler.active_unit()
	start_turn(combat,previous)
	check(combat.submit_command(EndTurnCommand.new(previous.stable_id)),"Metric fixture advances owner through real command")
	var next := combat.scheduler.active_unit()
	# Elite automatic resolution precedes the public turn_started signal.
	combat_event(combat,"telegraph_resolve",{"actor_id":next.stable_id})
	check(metrics.turns_started==2 and metrics.turns_completed==1,"Automatic resolution opens its actual owner turn before turn_started")
	check(active_turn.get("actor","")==next.stable_id and active_turn.get("serial",-1)==combat.turn_serial,"Automatic resolution attributes activity to actor and serial")
	start_turn(combat,next)
	start_turn(combat,next)
	check(metrics.turns_started==2 and metrics.turns_completed==1,"Repeated public turn signal does not duplicate automatic turn record")
	finish_turn(combat)
	check(metrics.pass_turns==1,"Automatic resolution is activity; only preceding passive turn counts as pass")
	await dispose(scene)
	var hold := EncounterConfiguration.new()
	hold.objective = EncounterOptions.objectives()[1]
	scene = await prepare(hold)
	combat = scene.get_node("CombatController") as CombatController
	if scene.guide!=null: scene.guide.close()
	var survivor := combat.find_unit("hero-01")
	for unit in combat.units:
		if unit!=survivor: unit.set_health(0)
	survivor.global_position = combat.objectives.center
	active_turn.clear()
	commands.clear()
	metrics.commands = 0
	metrics.command_rejections = 0
	metrics.actor_serials.clear()
	combat.turn_started.connect(func(unit: CombatUnit, _serial: int) -> void: start_turn(combat,unit))
	start_turn(combat,survivor)
	var submitted_serial := combat.turn_serial
	submit(combat,survivor,EndTurnCommand.new(survivor.stable_id),"end")
	check(commands.has("%d:%s:%d" % [case_epoch,survivor.stable_id,submitted_serial]),"Synchronous same-actor next turn cannot change submitted command serial")
	for turn in range(8):
		if combat.encounter_has_ended(): break
		submit(combat,survivor,EndTurnCommand.new(survivor.stable_id),"end")
	check(combat.state==CombatController.State.VICTORY,"Single surviving hero hold turns reach victory without false duplicate command")
	await dispose(scene)
	print("AI METRIC SELF TEST RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
func mission_configuration(_index: int) -> EncounterConfiguration:
	return null

func run() -> void:
	if "--metric-self-test" in OS.get_cmdline_user_args():
		await metric_self_test()
		return
	var count := 6
	var start_case := 0
	var base_seed := 1701
	var exact_seed := -1
	var repro_1740 := false
	var report_name := "ai-simulations.json"
	for argument in OS.get_cmdline_user_args():
		if argument=="--long": count = 60
		if argument=="--repro-1740": repro_1740 = true; count = 1; start_case = 39; exact_seed = 1740
		if argument.begins_with("--encounters="): count = maxi(1,int(argument.get_slice("=",1)))
		if argument.begins_with("--start-case="): start_case = maxi(0,int(argument.get_slice("=",1)))
		if argument.begins_with("--stress-seed="): base_seed = int(argument.get_slice("=",1))
		if argument.begins_with("--seed="): exact_seed = int(argument.get_slice("=",1))
		if argument.begins_with("--report="): report_name = argument.substr(9)
	for id in EnemyCatalog.ids(): retained.append(EnemyCatalog.find(id))
	for index in range(start_case,start_case+count):
		case_epoch += 1
		commands.clear(); positions.clear(); active_turn.clear(); warning_actor = ""
		metrics = {"commands":0,"command_rejections":0,"planner_rejections":{},"decisions":0,"decision_ms":0.0,"max_decision_ms":0.0,"path_queries":0,"action_queries":0,"events":{},"damage":0,"warning_damage":0,"effective_healing":0,"overheal":0,"turns_started":0,"turns_completed":0,"pass_turns":0,"max_turn_ms":0.0,"movement_repeats":0,"objective_participation":{"hero":0,"enemy":0},"actor_serials":{}}
		var config := EncounterConfiguration.new()
		config.hero_ids = PackedStringArray(PAIRS[index%6])
		config.faction_id = FactionCatalog.ids()[(index+int(index/6))%3]
		config.campaign_stage = 4
		config.elite_encounter = (index+int(index/6))%2==1
		config.battlefield_seed = exact_seed if exact_seed>=0 else base_seed+index
		config.difficulty = EncounterOptions.difficulties()[(index+int(index/6))%3]
		config.generator_settings = EncounterOptions.presets()[int(index/3)%3].duplicate(true)
		config.objective = EncounterOptions.objectives()[(int(index/2)+int(index/6))%3]
		if repro_1740:
			config.faction_id = "ashfang"
			config.elite_encounter = false
			config.difficulty = EncounterOptions.difficulties()[0]
			config.generator_settings = EncounterOptions.presets()[0].duplicate(true)
			config.objective = EncounterOptions.objectives()[0]
		config.resolve_roster()
		var authored := mission_configuration(index)
		if authored!=null: config=authored
		reproduction = {"case":index,"seed":config.battlefield_seed,"heroes":config.hero_ids,"faction":config.faction_id,"elite":config.elite_encounter,"roster":config.resolved_enemy_ids,"difficulty":config.difficulty.stable_id,"objective":config.objective.stable_id,"preset":config.generator_settings.preset_id}
		var before := failures
		var scene := await prepare(config)
		check(scene.navigation_ready,"Fixture navigation ready")
		var combat := scene.get_node("CombatController") as CombatController
		var enemy := scene.get_node("EnemyController") as EnemyController
		enemy.presentation_delay = 0.0
		combat.motor.movement_speed = 80.0
		combat.attack_resolution_seconds = 0.05
		if scene.guide!=null: scene.guide.close()
		if repro_1740:
			for unit in combat.units:
				if (index+unit.stable_id.hash())%2==0: unit.apply_status(load("res://definitions/slowed.tres"))
		combat.turn_started.connect(func(unit: CombatUnit, _serial: int) -> void: start_turn(combat,unit))
		combat.combat_event.connect(func(kind: String, data: Dictionary) -> void: combat_event(combat,kind,data))
		enemy.command_submitted.connect(func(id: String, kind: String, accepted: bool) -> void: record_command(combat,id,"action" if kind in ["attack","ability"] else kind,accepted))
		enemy.decision_chosen.connect(decision)
		var initial := combat.scheduler.active_unit()
		enemy.enabled = true
		if initial!=null:
			if initial.faction==CombatUnit.Faction.ENEMY: combat.turn_started.emit(initial,combat.turn_serial)
			else: start_turn(combat,initial)
		var observed_serial := combat.turn_serial
		var idle_frames := 0
		var hero_serial := -1
		for frame in range(40000):
			if combat.encounter_has_ended() or failures>before: break
			if combat.turn_serial!=observed_serial: observed_serial = combat.turn_serial; idle_frames = 0
			else: idle_frames += 1
			if idle_frames>2400 or combat.turn_serial>240:
				reproduction.snapshot = combat.diagnostic_snapshot()
				check(false,"Simulation exceeded turn/frame watchdog")
				break
			if combat.state==CombatController.State.AWAITING_COMMAND:
				var actor := combat.scheduler.active_unit()
				if actor!=null and actor.faction==CombatUnit.Faction.HERO and hero_serial!=combat.turn_serial:
					hero_serial = combat.turn_serial
					await hero_turn(combat,actor)
			await process_frame
		finish_turn(combat)
		reproduction.snapshot = combat.diagnostic_snapshot()
		reproduction.ai_diagnostics = enemy.last_diagnostics.duplicate(true)
		check(combat.encounter_has_ended(),"Encounter reaches explicit result; never skip stalled cases")
		results.append({"reproduction":reproduction.duplicate(true),"metrics":metrics.duplicate(true),"outcome":CombatController.State.keys()[combat.state],"rounds":combat.completed_rounds,"failures":failures-before})
		print("AI SIMULATION CASE ",JSON.stringify(results[-1]))
		await dispose(scene)
		if failures>before: break
	check(results.size()==count,"Every requested encounter ran")
	check(RegressionReport.write_json(report_name,{"failures":failures,"requested":count,"completed":results.size(),"cases":results}),"Simulation report written")
	print("AI SIMULATION RESULT: %d failures; %d encounters" % [failures,results.size()])
	quit(0 if failures==0 else 1)
