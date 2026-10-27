extends "res://tests/objective_encounter_tests.gd"
## Deterministic real-command stress: -- --long --encounters=N --stress-seed=N --report=PATH
var case_results: Array[Dictionary] = []
var reproduction: Dictionary = {}
var checked_commands: int = 0
var retained_definitions: Array[UnitDefinition] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("%s REPRO=%s" % [message, JSON.stringify(reproduction)])

func run() -> void:
	var run_started_usec := Time.get_ticks_usec()
	for enemy_id in EnemyCatalog.ids(): retained_definitions.append(EnemyCatalog.find(enemy_id))
	var cases := 6
	var base_seed := 1701
	var start_case := 0
	for argument in OS.get_cmdline_user_args():
		if argument in ["--stress-long", "--long"]: cases = 60
		if argument.begins_with("--stress-cases=") or argument.begins_with("--encounters=") or argument.begins_with("--iterations="): cases = maxi(1,int(argument.get_slice("=",1)))
		if argument.begins_with("--stress-seed="): base_seed = int(argument.get_slice("=",1))
		if argument.begins_with("--start-case="): start_case = maxi(0,int(argument.get_slice("=",1)))
	var pairs := [["knight","ranger"],["knight","mage"],["knight","cleric"],["ranger","mage"],["ranger","cleric"],["mage","cleric"]]
	for case_index in range(start_case,start_case+cases):
		var case_started_usec := Time.get_ticks_usec()
		var config := EncounterConfiguration.new()
		config.hero_ids = PackedStringArray(pairs[case_index % 6])
		config.faction_id = FactionCatalog.ids()[case_index % 3]
		config.battlefield_seed = base_seed + case_index
		config.campaign_stage = case_index % 5
		config.difficulty = EncounterOptions.difficulties()[case_index % 3]
		config.generator_settings = EncounterOptions.presets()[case_index % 3].duplicate(true)
		config.resolve_roster()
		reproduction = {"case":case_index,"campaign_stage":config.campaign_stage,"seed":config.battlefield_seed,"heroes":config.hero_ids,"faction":config.faction_id,"enemies":config.resolved_enemy_ids,"difficulty":config.difficulty.stable_id,"preset":config.generator_settings.preset_id}
		var before := failures
		var scene := await prepare(config)
		check(scene.navigation_ready, "Navigation ready within fixture bound")
		if not scene.navigation_ready:
			await dispose(scene)
			break
		var combat := scene.get_node("CombatController") as CombatController
		var enemy := scene.get_node("EnemyController") as EnemyController
		enemy.presentation_delay = 0.0
		combat.motor.movement_speed = 80.0
		combat.attack_resolution_seconds = 0.05
		if scene.guide != null: scene.guide.close()
		var counts := {}
		var serials := {}
		enemy.routine_started.connect(func(id: String, serial: int) -> void: serials[id] = serial)
		enemy.command_submitted.connect(func(id: String, kind: String, accepted: bool) -> void:
			var key := "%s:%s" % [serials.get(id,-1),kind]
			counts[key] = int(counts.get(key,0)) + 1
			checked_commands += 1
			check(int(counts[key]) <= 1,"Enemy command executes at most once per turn")
			if kind == "end": check(accepted,"Enemy End Turn accepted"))
		for unit in combat.units:
			if (case_index + unit.stable_id.hash()) % 2 == 0:
				unit.apply_status(load("res://definitions/slowed.tres"))
		enemy.enabled = true
		# prepare() disables AI before initial initiative; deliver the retained start.
		var initial := combat.scheduler.active_unit()
		if initial != null and initial.faction == CombatUnit.Faction.ENEMY:
			combat.turn_started.emit(initial,combat.turn_serial)
		var last_serial := -1
		var idle_frames := 0
		for frame in range(30000):
			if combat.encounter_has_ended() or failures > before: break
			if combat.turn_serial > 240:
				reproduction["snapshot"] = combat.diagnostic_snapshot()
				check(false,"Battle exceeded 240 turn budget; preserve stalemate reproduction")
				break
			if combat.turn_serial != last_serial:
				idle_frames = 0
			else: idle_frames += 1
			if idle_frames > 2400:
				reproduction["snapshot"] = combat.diagnostic_snapshot()
				reproduction["ai_stage"] = EnemyController.Stage.keys()[enemy.stage]
				check(false,"Turn exceeded 2400 frame watchdog")
				break
			if combat.state == CombatController.State.AWAITING_COMMAND:
				var actor := combat.scheduler.active_unit()
				if actor.faction == CombatUnit.Faction.HERO and last_serial != combat.turn_serial:
					last_serial = combat.turn_serial
					await hero_turn(combat,actor)
				elif actor.faction == CombatUnit.Faction.ENEMY:
					last_serial = combat.turn_serial
			await process_frame
		reproduction["snapshot"] = combat.diagnostic_snapshot()
		reproduction["units"] = combat.units.map(func(unit: CombatUnit) -> Dictionary: return {"id":unit.stable_id,"health":unit.health,"position":str(unit.global_position),"owner_turn":unit.owner_turn,"action":unit.action_available,"movement":unit.movement_remaining})
		reproduction["ai_diagnostics"] = enemy.last_diagnostics.duplicate(true)
		check(combat.encounter_has_ended(),"Battle reaches explicit result; failures are never silently restarted")
		case_results.append({"reproduction":reproduction.duplicate(true),"result":CombatController.State.keys()[combat.state],"rounds":combat.completed_rounds,"failures":failures-before,"duration_usec":Time.get_ticks_usec()-case_started_usec})
		print("COMBAT STRESS CASE ",JSON.stringify(case_results[-1]))
		await dispose(scene)
		case_results[-1]["post_cleanup"]={"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
		if failures > before: break
	var report_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stress-report=") or argument.begins_with("--report="): report_path = argument.substr(argument.find("=")+1)
	var data := {"failures":failures,"cases":case_results,"enemy_commands":checked_commands,"duration_usec":Time.get_ticks_usec()-run_started_usec,"requested_cases":cases,"start_case":start_case,"base_seed":base_seed}
	if report_path.is_empty():
		check(RegressionReport.write_json("combat-stress.json",data),"Stress report is writable")
	else:
		var absolute := ProjectSettings.globalize_path(report_path)
		check(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) == OK,"Stress report directory is writable")
		var report := FileAccess.open(absolute,FileAccess.WRITE)
		check(report != null,"Stress report is writable")
		if report != null: report.store_string(JSON.stringify(data,"\t"))
	print("COMBAT STRESS RESULT: %d failures; %d cases; %d enemy commands" % [failures,case_results.size(),checked_commands])
	quit(0 if failures == 0 else 1)


func hero_turn(combat: CombatController, actor: CombatUnit) -> void:
	var serial := combat.turn_serial
	var plan := EnemyTactics.new()
	plan.begin(combat,actor)
	for planning_frame in range(128):
		if plan.done: break
		plan.step()
		await process_frame
	check(plan.done,"Hero planner completes within bounded step count")
	if not plan.done: return
	var choice := plan.best
	if choice.action != null and (not choice.moving or choice.action_first):
		combat.submit_player_command(choice.action.command(actor.stable_id))
		await action_wait(combat)
	if combat.state != CombatController.State.AWAITING_COMMAND or serial != combat.turn_serial: return
	if choice.moving:
		combat.submit_player_command(MoveCommand.new(actor.stable_id,choice.destination))
		await action_wait(combat)
	if combat.state != CombatController.State.AWAITING_COMMAND or serial != combat.turn_serial: return
	if actor.action_available:
		var fresh := EnemyTactics.new()
		fresh.begin(combat,actor,false,true)
		if fresh.best.action != null:
			combat.submit_player_command(fresh.best.action.command(actor.stable_id))
			await action_wait(combat)
	if combat.state == CombatController.State.AWAITING_COMMAND and serial == combat.turn_serial:
		check(combat.submit_player_command(EndTurnCommand.new(actor.stable_id)),"Hero End Turn accepted")