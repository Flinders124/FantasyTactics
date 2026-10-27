extends "res://tests/flow_tests.gd"
func fresh(enabled: bool=false) -> void:
	var config := EncounterConfiguration.new(); config.battlefield_seed=7
	flow.start_configuration(config)
	flow.combat.get_node("EnemyController").enabled=enabled
	await wait_ready(); await drain()
func wait_action(combat: CombatController) -> void:
	for frame in range(1000):
		if combat.state!=CombatController.State.RESOLVING_ACTION: return
		await process_frame
	check(false,"Paused action failed to resume within watchdog")
func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	var audio := flow.audio
	audio.preferences=SettingsSchema.defaults(); audio.apply_preferences(false)
	var panel := audio.panel
	# Opening settings during async navigation setup must not strand loading.
	var loading_config := EncounterConfiguration.new(); loading_config.battlefield_seed=7
	flow.start_configuration(loading_config); flow.combat.get_node("EnemyController").enabled=false
	panel.open()
	for frame in range(30): await process_frame
	check(paused and panel.visible and flow.combat!=null,"Settings remains responsive while encounter setup is pending")
	panel.close(); await wait_ready(); await drain()
	check(not paused and flow.combat.navigation_ready,"Resume completes navigation/setup without a stale pause")
	await fresh()
	var scene := flow.combat
	var combat := scene.get_node("CombatController") as CombatController
	while combat.scheduler.active_unit().stable_id!="hero-02": combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	var caster := combat.find_unit("hero-02")
	var point := caster.global_position+Vector3.FORWARD*3
	combat.find_unit("enemy-01").global_position=point
	combat.find_unit("enemy-02").global_position=point+Vector3.RIGHT
	await physics_frame; await physics_frame
	var hits: Array[String]=[]
	combat.combat_event.connect(func(kind: String,data: Dictionary) -> void:
		if kind=="area_hit": hits.append(data.target_id))
	check(combat.submit_player_command(UseAbilityCommand.on_ground(caster.stable_id,"fireburst",point)),"Area action commits before pause")
	var presentation := scene.get_node("CombatPresentation") as CombatPresentation
	check(presentation.blasts.size()==1,"Resolved area effect exists for pause test")
	panel.open()
	var healths: Array[int]=[]
	for unit in combat.units: healths.append(unit.health)
	var age: float=presentation.blasts[0].age
	var timer := combat._attack_remaining
	for frame in range(30): await process_frame
	check(presentation.blasts[0].age==age and combat._attack_remaining==timer,"Pause freezes area presentation and action timer")
	for index in range(combat.units.size()): check(combat.units[index].health==healths[index],"Atomic damage is not repeated while paused")
	scene.show_help()
	panel.close()
	check(paused and combat.guidance_paused,"Settings cannot release another overlay's pause ownership")
	scene.guide.close(); check(not paused,"Only the last pause owner resumes combat")
	await wait_action(combat)
	check(hits.size()>=2,"Area hits remain one committed set")
	var unique: Dictionary={}
	for id in hits: unique[id]=true
	check(unique.size()==hits.size(),"Each area target receives damage once across pause/resume")
	for index in range(combat.units.size()): check(combat.units[index].health==healths[index],"Resume never reapplies area damage")
	await fresh(true)
	combat=flow.combat.get_node("CombatController")
	var enemy := flow.combat.get_node("EnemyController") as EnemyController
	enemy.presentation_delay=0
	combat.submit_player_command(EndTurnCommand.new("hero-01"))
	for frame in range(180):
		if enemy.stage==EnemyController.Stage.PLANNING: break
		await process_frame
	check(enemy.stage==EnemyController.Stage.PLANNING,"Enemy reaches bounded tactical planning")
	panel.open()
	var serial := combat.turn_serial
	var stage := enemy.stage
	for frame in range(30): await process_frame
	check(enemy.stage==stage and combat.turn_serial==serial,"Pause freezes enemy planning and turn progression")
	panel.close()
	for frame in range(1600):
		if combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO: break
		await process_frame
	check(combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO,"Enemy planning resumes and finishes its turn")
	# Stop an enemy in committed attack resolution, not only the planner.
	await fresh()
	combat=flow.combat.get_node("CombatController")
	enemy=flow.combat.get_node("EnemyController")
	combat.find_unit("enemy-02").set_health(0) # Development harness isolates one attacker.
	combat.find_unit("enemy-01").global_position=combat.find_unit("hero-01").global_position+Vector3.RIGHT*1.5
	await physics_frame; await physics_frame
	enemy.enabled=true; enemy.presentation_delay=0
	var attacks: Array[String]=[]
	combat.combat_event.connect(func(kind: String,data: Dictionary) -> void:
		if kind=="attack" and data.actor_id=="enemy-01": attacks.append(data.event_id))
	combat.submit_player_command(EndTurnCommand.new("hero-01"))
	for frame in range(500):
		if combat.state==CombatController.State.RESOLVING_ACTION and not attacks.is_empty(): break
		await process_frame
	check(attacks.size()==1,"Enemy commits exactly one attack before pause")
	panel.open(); var hp := combat.find_unit("hero-01").health
	for frame in range(30): await process_frame
	check(attacks.size()==1 and combat.find_unit("hero-01").health==hp,"Paused enemy resolution cannot duplicate damage")
	panel.close()
	for frame in range(1600):
		if combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO: break
		await process_frame
	check(attacks.size()==1 and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO,"Enemy completes same turn after resume")
	# Restart during a paused atomic action's presentation, not only an idle pause.
	await fresh()
	combat=flow.combat.get_node("CombatController")
	while combat.scheduler.active_unit().stable_id!="hero-02": combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	caster=combat.find_unit("hero-02"); point=caster.global_position+Vector3.FORWARD*3
	check(combat.submit_player_command(UseAbilityCommand.on_ground(caster.stable_id,"fireburst",point)),"Area action active before paused restart")
	check(combat.state==CombatController.State.RESOLVING_ACTION and not flow.combat.get_node("CombatPresentation").blasts.is_empty(),"Restart fixture contains an unfinished area effect")
	var retired: WeakRef = weakref(flow.combat)
	panel.open(); flow.request_transition("retry"); await wait_ready(); await drain()
	check(retired.get_ref()==null,"Paused action scene retires instead of completing into the replacement")
	check(not paused and not panel.visible and not audio.editing,"Restart owns no stale settings pause or capture")
	check(flow.combat.get_node("CombatPresentation").blasts.is_empty(),"Restart clears old area effects")
	flow.show_title(); flow.queue_free(); await process_frame
	print("SETTINGS LIFECYCLE RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
