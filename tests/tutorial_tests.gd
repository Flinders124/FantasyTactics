extends "res://tests/objective_encounter_tests.gd"
var flow: SceneFlow
var test_settings: String = "user://tutorial_verification.cfg"
func ready_flow(close_briefing: bool=true) -> void:
	for frame in range(1600):
		if flow.screen!="loading": break
		await process_frame
	check(flow.screen=="combat" and flow.combat.navigation_ready,"Authored tutorial validates navigation/spawns before combat")
	if close_briefing: flow.combat.guide.close()
func teach_camera(scene: CombatEncounter) -> void:
	var rig := scene.get_node("TacticalCamera") as TacticalCamera
	Input.action_press("tactics_orbit")
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(12,3)
	rig._unhandled_input(motion)
	Input.action_release("tactics_orbit")
	Input.action_press("tactics_pan_right")
	rig._process(.1)
	Input.action_release("tactics_pan_right")
	var zoom := InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_WHEEL_UP
	zoom.pressed=true
	rig._unhandled_input(zoom)
	var focus := InputEventKey.new()
	focus.physical_keycode=KEY_F
	focus.pressed=true
	rig._unhandled_input(focus)
func run() -> void:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(test_settings+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings+suffix))
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.audio.settings_path=test_settings
	flow.audio.load_preferences()
	check(not flow.audio.tutorial_completed,"Missing preference safely defaults incomplete")
	var malformed := ConfigFile.new()
	malformed.set_value("tutorial","completed","not a boolean")
	malformed.save(test_settings)
	flow.audio.load_preferences()
	check(not flow.audio.tutorial_completed,"Malformed preference value safely defaults incomplete")
	flow.show_title()
	check(flow.menu.tutorial_suggestion.visible,"First launch gently suggests tutorial without blocking New Encounter")
	var base := EncounterCode.fingerprint(HeroCatalog.find("knight"))
	flow.start_tutorial()
	await ready_flow(false)
	var scene := flow.combat
	var combat := scene.get_node("CombatController") as CombatController
	var director := scene.tutorial
	check(paused and combat.guidance_paused,"Opening briefing pauses simulation")
	check(not combat.submit_command(EndTurnCommand.new("hero-01")),"Blocking briefing cannot advance combat")
	var turn := combat.turn_serial
	for frame in range(30): await process_frame
	check(combat.turn_serial==turn and director.step==TutorialDirector.Step.CAMERA,"No invisible combat progression or timer-based tutorial advancement")
	scene.guide.close()
	check(not paused,"Continue restores simulation")
	check(not combat.submit_player_command(AttackCommand.new("hero-01","enemy-01")),"Narrow tutorial restriction rejects premature input")
	teach_camera(scene)
	check(director.step==TutorialDirector.Step.PREVIEW,"Actual camera transforms complete all four camera observations")
	var route := combat.evaluate_move(combat.find_unit("hero-01"),TutorialEncounter.FIRST_DESTINATION)
	check(route.valid(),"Teaching route is legal")
	# Unit-level preview event carries a cost already calculated by the real navigation service.
	scene.get_node("PlayerController").route_previewed.emit(TutorialEncounter.FIRST_DESTINATION,route.distance,true)
	check(director.step==TutorialDirector.Step.MOVE,"Valid costed route preview advances to movement")
	# A newly introduced collision blocks execution without consuming the whole budget.
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(.25,2,2)
	collision.shape=shape
	blocker.add_child(collision)
	blocker.position=Vector3(-4.5,1,0)
	check(combat.submit_player_command(MoveCommand.new("hero-01",TutorialEncounter.FIRST_DESTINATION)),"Marked movement accepted before dynamic blocker")
	scene.add_child(blocker)
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.MOVE and combat.state==CombatController.State.AWAITING_COMMAND,"Blocked move returns control without falsely completing step")
	check(combat.find_unit("hero-01").movement_remaining>4.5,"Blocked movement charges only travelled distance")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	check(combat.submit_player_command(MoveCommand.new("hero-01",TutorialEncounter.FIRST_DESTINATION+Vector3.LEFT*.5)),"Visible marker edge is a legal retry after blockage")
	for repeat in range(8): check(not combat.submit_player_command(MoveCommand.new("hero-01",TutorialEncounter.FIRST_DESTINATION)),"Repeated resolution clicks do not queue movement")
	check(director.step==TutorialDirector.Step.MOVE,"Submitting movement does not complete tutorial step")
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.ATTACK,"Actual movement completion advances")
	var target := combat.find_unit("enemy-01")
	var health := target.health
	check(combat.submit_player_command(AttackCommand.new("hero-01","enemy-01")),"Teaching melee attack legal")
	check(director.step==TutorialDirector.Step.ATTACK,"Damage event alone waits for action completion")
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.MOVE_AGAIN and target.health==health-4,"Completed basic attack applies once and advances")
	check(not combat.find_unit("hero-01").action_available,"Basic attack spends shared action")
	check(combat.submit_player_command(MoveCommand.new("hero-01",TutorialEncounter.SECOND_DESTINATION)),"Post-attack movement uses remaining budget")
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.END_TURN,"Second movement completes before End Turn instruction")
	check(combat.submit_player_command(EndTurnCommand.new("hero-01")),"End Turn begins actual enemy observation")
	for frame in range(300):
		if director.step==TutorialDirector.Step.ABILITY: break
		await process_frame
	check(director.step==TutorialDirector.Step.ABILITY and director.observed_enemy,"Legal enemy End Turn advances initiative to Scout")
	var player := scene.get_node("PlayerController") as PlayerController
	player.select_ability("crippling_shot")
	player.cancel_targeting()
	check(director.step==TutorialDirector.Step.ABILITY and combat.find_unit("hero-02").action_available,"Cancelling targeting neither advances nor spends action")
	check(combat.submit_player_command(UseAbilityCommand.new("hero-02","enemy-02","crippling_shot")),"Scout ranged ability is legal in authored layout")
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.FINISH and combat.find_unit("hero-02").cooldown_remaining("crippling_shot")>0,"Ability completion teaches real cooldown")
	var serial := -1
	for frame in range(18000):
		if combat.state==CombatController.State.VICTORY: break
		if combat.state==CombatController.State.AWAITING_COMMAND and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
			serial=combat.turn_serial
			await hero_turn(combat,combat.scheduler.active_unit())
		await process_frame
	check(combat.state==CombatController.State.VICTORY and director.step==TutorialDirector.Step.COMPLETE,"Complete guided encounter reaches victory via normal commands")
	check(flow.audio.tutorial_completed,"Only final successful tutorial outcome marks completion")
	flow.audio.tutorial_completed=false
	flow.audio.load_preferences()
	check(flow.audio.tutorial_completed,"Completion persists in existing settings file")
	flow.audio.set_preference("Music",.4,false)
	flow.audio.load_preferences()
	check(flow.audio.tutorial_completed,"Later audio edits retain completion")
	flow.show_title()
	check(not flow.menu.tutorial_suggestion.visible,"Completed tutorial suggestion hidden; replay remains available")
	# Abandon/restart at early and later steps; old scenes cannot affect replacements.
	for cycle in range(5):
		flow.start_tutorial()
		await ready_flow()
		if cycle>0: teach_camera(flow.combat)
		var old: WeakRef = weakref(flow.combat)
		flow.request_transition("skip_tutorial" if cycle%2==0 else "tutorial")
		check(paused and flow.combat.guide.confirm_button.visible,"Skip/restart requires explicit abandon confirmation")
		if cycle==1:
			flow.combat.guide.close()
			check(not paused,"Cancelling abandon resumes tutorial")
			flow.request_transition("tutorial")
		flow.combat.guide.confirm_button.pressed.emit()
		var retired_scene := old.get_ref() as CombatEncounter
		if retired_scene!=null: check(retired_scene.tutorial.abandoned and not retired_scene.tutorial.panel.visible and not retired_scene.tutorial.visible,"Shutdown cannot revive old guidance through reset signals")
		if cycle%2==1:
			await ready_flow()
			check(flow.combat.tutorial.step==TutorialDirector.Step.CAMERA,"Restart creates fresh director state")
			flow.show_title()
		for frame in range(20): await process_frame
		check(old.get_ref()==null and not paused and flow.combat==null,"Five repeated transitions clear old director, rules, pauses and AI")
	flow.start_tutorial()
	await ready_flow()
	flow.combat.get_node("CombatController").find_unit("enemy-01").set_health(0)
	flow.combat.get_node("CombatController").encounter_updated.emit()
	check(flow.combat.tutorial.step==TutorialDirector.Step.RECOVERY,"Premature required target death offers safe full restart")
	flow.show_title()
	var config := EncounterConfiguration.new()
	config.battlefield_seed=7
	flow.start_configuration(config)
	await ready_flow()
	combat=flow.combat.get_node("CombatController")
	check(not flow.combat.tutorial_mode and not combat.player_command_policy.is_valid() and not flow.combat.get_node("EnemyController").tutorial_policy,"Normal skirmish has no tutorial policy or restrictions")
	check(combat.submit_player_command(EndTurnCommand.new("hero-01")),"Normal player turn works after tutorial exit")
	for frame in range(600):
		if combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO: break
		await process_frame
	check(combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO,"Normal tactical enemy turn still completes")
	check(EncounterCode.fingerprint(HeroCatalog.find("knight"))==base,"Shared hero definitions unchanged")
	flow.show_title()
	flow.queue_free()
	await process_frame
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(test_settings+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings+suffix))
	print("TUTORIAL RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)

