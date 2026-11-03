extends SceneTree
var failures: Array[String] = []
var report: Dictionary = {}
var phase: int = 1
var report_root: String
var flow: SceneFlow
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	if OS.get_environment("OATH_TEST_ISOLATED")!="1":
		push_error("Set isolated APPDATA/LOCALAPPDATA and OATH_TEST_ISOLATED=1 before running export smoke.");quit(1);return
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or not args[0].is_valid_int() or int(args[0])<1 or int(args[0])>4:
		push_error("Expected phase 1..4 and absolute report directory.");quit(1);return
	phase=int(args[0]); report_root=args[1]
	if not report_root.is_absolute_path() or DirAccess.make_dir_recursive_absolute(report_root)!=OK:
		push_error("Cannot prepare export smoke report directory.");quit(1);return
	var marker := FileAccess.open(report_root.path_join("native-%d-started.txt"%phase),FileAccess.WRITE)
	if marker==null:push_error("Cannot write export smoke marker.");quit(1);return
	marker.store_string("Harness initialized"); marker.close()
	call_deferred("run")
func read_report(number: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(report_root.path_join("native-%d.json"%number)))
func ready_encounter() -> CombatEncounter:
	for frame in range(3600):
		if flow.combat!=null and flow.combat.navigation_ready:
			flow.combat.guide.close()
			flow.combat.set_guidance_paused(false)
			return flow.combat
		await process_frame
	check(false,"Navigation ready timeout")
	return null
func action_wait(combat: CombatController) -> void:
	for frame in range(1000):
		if combat.state!=CombatController.State.RESOLVING_ACTION: return
		await process_frame
	check(false,"Action timeout")
func hero_turn(combat: CombatController,actor: CombatUnit) -> void:
	var plan := EnemyTactics.new()
	plan.begin(combat,actor)
	while not plan.done:
		plan.step()
		await process_frame
	var choice := plan.best
	if choice.action!=null and (not choice.moving or choice.action_first):
		combat.submit_player_command(choice.action.command(actor.stable_id))
		await action_wait(combat)
	if combat.state!=CombatController.State.AWAITING_COMMAND: return
	if choice.moving:
		combat.submit_player_command(MoveCommand.new(actor.stable_id,choice.destination))
		await action_wait(combat)
	if combat.state!=CombatController.State.AWAITING_COMMAND: return
	if actor.action_available:
		var fresh := EnemyTactics.new()
		fresh.begin(combat,actor,false,true)
		if fresh.best.action!=null:
			combat.submit_player_command(fresh.best.action.command(actor.stable_id))
			await action_wait(combat)
	if combat.state==CombatController.State.AWAITING_COMMAND:
		combat.submit_player_command(EndTurnCommand.new(actor.stable_id))
func run() -> void:
	flow=load("res://scenes/main.tscn").instantiate() as SceneFlow
	root.add_child(flow)
	flow.campaign.store.path="user://stability-build-smoke/active.json"
	await process_frame
	var coordinator := flow.campaign as CampaignCoordinator
	check(flow.screen=="title","Native title initialized")
	if phase==1:
		flow.request_transition("new_encounter")
		check(flow.screen=="party","Skirmish entry opens party setup")
		flow.show_title()
		flow.request_transition("tutorial")
		var tutorial := await ready_encounter()
		check(tutorial!=null and tutorial.tutorial_mode,"Tutorial entry creates training")
		flow.show_title()
		flow.request_transition("new_campaign")
		coordinator.seed_text="17"; coordinator.difficulty_index=0
		flow.request_transition("campaign_begin")
		check(flow.screen=="headquarters","New campaign HQ: "+coordinator.store.last_message+" phase="+flow.screen)
		if coordinator.state==null:
			print(coordinator.store.last_message); quit(1); return
		var ids := coordinator.state.living_ids()
		check(coordinator.mutate("train_recruit",[ids[0]])==true,"Modern recruit training persists")
		check(coordinator.mutate("specialise",[ids[0],"knight"])==true,"Modern specialisation persists")
		coordinator.armoury_hero=ids[0]
		flow.request_transition("campaign_buy:reachguard")
		var instance: String=""
		for id: String in coordinator.state.inventory:
			if coordinator.state.inventory[id].definition_id=="reachguard": instance=id
		check(not instance.is_empty(),"Real HQ purchase succeeds")
		flow.request_transition("campaign_equip:"+instance)
		check(coordinator.state.owner_of(instance)==ids[0],"Purchased item equipped")
		flow.audio.set_preference("Music",0.23,false)
		check(flow.audio.save_preferences(),"Settings persist")
		report={"supplies":coordinator.state.supplies,"heroes":coordinator.state.heroes,"inventory":coordinator.state.inventory,"equipment":instance,"party_ids":Array(ids.slice(0,2)),"movement":coordinator.state.preview_definition(ids[0]).movement_allowance,"health":coordinator.state.preview_definition(ids[0]).maximum_health}
	elif phase==2:
		flow.request_transition("campaign_continue")
		check(flow.screen=="headquarters","Continue opens HQ")
		var expected := read_report(1)
		check(coordinator.state.supplies==expected.supplies,"Supplies persisted")
		check(coordinator.state.owner_of(expected.equipment)==expected.party_ids[0],"Equipment persisted")
		check(coordinator.state.preview_definition(expected.party_ids[0]).maximum_health==expected.health,"Derived health persisted")
		check(is_equal_approx(flow.audio.volumes.Music,0.23),"Settings reload")
		coordinator.selected=PackedStringArray(expected.party_ids)
		coordinator.prepare(coordinator.state.offers[0].id)
		flow.request_transition("campaign_deploy")
		var scene := await ready_encounter()
		check(scene!=null,"Mission navigation")
		var combat := scene.get_node("CombatController") as CombatController
		report={"active":coordinator.state.active.duplicate(true),"signature":scene.configuration.layout.geometry_signature(),"seed":scene.configuration.battlefield_seed,"enemy_ids":Array(scene.configuration.resolved_enemy_ids),"party":Array(scene.configuration.hero_ids),"code":EncounterCode.encode(scene.configuration)}
		var actor := combat.scheduler.active_unit()
		check(actor.faction==CombatUnit.Faction.HERO,"Hero starts deployment")
		# Close during a real scheduled enemy turn after legal hero End Turn commands.
		for frame in range(600):
			if combat.state==CombatController.State.AWAITING_COMMAND:
				actor=combat.scheduler.active_unit()
				if actor.faction==CombatUnit.Faction.ENEMY:
					report.interrupted="enemy_turn"; break
				combat.submit_player_command(EndTurnCommand.new(actor.stable_id))
			await process_frame
		check(report.has("interrupted"),"Close while enemy turn active")
	elif phase==3:
		var expected := read_report(2)
		flow.request_transition("campaign_continue")
		var scene := await ready_encounter()
		check(scene!=null,"Interrupted Continue navigation")
		check(scene.configuration.battlefield_seed==expected.seed,"Same deployment seed")
		check(scene.configuration.layout.geometry_signature()==expected.signature,"Same generated layout")
		check(Array(scene.configuration.hero_ids)==expected.party,"Same hero roster")
		check(Array(scene.configuration.resolved_enemy_ids)==expected.enemy_ids,"Same enemy roster")
		check(EncounterCode.encode(scene.configuration)==expected.code,"Same frozen configuration")
		var combat := scene.get_node("CombatController") as CombatController
		for unit in combat.scheduler.order:
			check(unit.health==unit.definition.maximum_health,"Fresh health: "+unit.stable_id)
			check(unit.cooldown_ready_turn.is_empty() and unit.statuses.is_empty(),"Fresh cooldown/status: "+unit.stable_id)
		var active := combat.scheduler.active_unit()
		check(is_equal_approx(active.movement_remaining,active.movement_granted) and active.action_available,"Fresh active turn resources")
		var enemy := scene.get_node("EnemyController") as EnemyController
		enemy.presentation_delay=0
		var last_serial := -1
		for frame in range(24000):
			if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=last_serial:
				var actor := combat.scheduler.active_unit()
				if actor.faction==CombatUnit.Faction.HERO:
					last_serial=combat.turn_serial
					await hero_turn(combat,actor)
			await process_frame
		check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW],"Actual encounter completed")
		check(coordinator.save_phase=="debrief","Result autosaved as debrief")
		report={"snapshot":coordinator.state.snapshot(),"actual_combat":true,"outcome":CombatController.State.keys()[combat.state],"rounds":combat.completed_rounds}
		coordinator.show_debrief()
		check(flow.screen=="campaign_debrief","Result opens debrief")
	elif phase==4:
		var before := FileAccess.get_file_as_string(coordinator.store.path)
		flow.request_transition("campaign_continue")
		check(flow.screen=="campaign_debrief","Continue restores debrief")
		var expected := read_report(3)
		check(JSON.stringify(coordinator.state.snapshot())==JSON.stringify(CampaignSaveCodec.normalize(expected.snapshot)),"Debrief restore changes no rewards/stats")
		check(FileAccess.get_file_as_string(coordinator.store.path)==before,"Debrief restore does not rewrite save")
		check(is_equal_approx(flow.audio.volumes.Music,0.23),"Settings survive four processes")
		report={"readonly_debrief":true,"supplies":coordinator.state.supplies,"resolutions":coordinator.state.resolutions,"processed":coordinator.state.processed}
	report.phase=phase; report.failures=failures; report.userdata=OS.get_user_data_dir()
	var file := FileAccess.open(report_root.path_join("native-%d.json"%phase),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_PHASE_%d failures=%d"%[phase,failures.size()])
	if flow.combat!=null: flow.combat.shutdown()
	flow.queue_free()
	for frame in range(8): await process_frame
	quit(0 if failures.is_empty() else 1)




