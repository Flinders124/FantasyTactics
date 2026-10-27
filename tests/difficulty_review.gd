extends "res://tests/difficulty_encounter_tests.gd"
var flow: SceneFlow
var prefix: String
var camera_checked: bool = false

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix+"-"+label+".png"))

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await process_frame

func ready_flow() -> void:
	for frame in range(1600):
		if flow.screen!="loading": break
		await process_frame
	check(flow.screen=="combat","Rendered setup becomes playable")

func camera_during_ai(_id: String,_serial: int) -> void:
	if camera_checked: return
	camera_checked=true
	var rig := flow.combat.get_node("TacticalCamera") as TacticalCamera
	var before := rig.distance
	var zoom := InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_WHEEL_UP
	zoom.pressed=true
	rig._unhandled_input(zoom)
	check(rig.distance<before,"Camera remains responsive during difficulty planning")

func run() -> void:
	root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	prefix="res://../verification/difficulty/review-%d"%root.size.x
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	await capture("title") # Let containers finish layout before real clicks.
	await click(flow.menu.new_button.get_global_rect().get_center())
	await capture("setup-empty")
	await click(flow.menu.cards["knight"].get_global_rect().get_center())
	await click(flow.menu.cards["ranger"].get_global_rect().get_center())
	flow.menu.seed_input.text="bad"
	flow.menu.seed_input.text_changed.emit("bad")
	await capture("invalid-seed")
	check(flow.menu.start_button.disabled,"Rendered invalid seed disables Start")
	flow.menu.seed_input.text="7"
	flow.menu.seed_input.text_changed.emit("7")
	for level in range(3):
		flow.menu.difficulty_selector.select(level)
		flow.menu.difficulty_selector.item_selected.emit(level)
		await capture("setup-"+EncounterOptions.difficulties()[level].stable_id)
		check(flow.menu.start_button.get_global_rect().end.y<=root.size.y,"Setup footer fits resolution")
		for card in flow.menu.cards.values(): check(card.get_global_rect().end.y<=root.size.y and card.get_global_rect().end.x<=root.size.x,"Four hero cards fit")
		# Desktop clipboard was unavailable in this automation session. Exercise
		# the real selectable-text fallback and import, without claiming native copy.
		flow.menu.use_native_clipboard=false
		flow.menu.settings_scroll.ensure_control_visible(flow.menu.copy_code_button)
		await process_frame
		await process_frame
		if level==1: await capture("setup-sharing")
		var copy := flow.menu.copy_code_button
		check(copy.get_global_rect().end.y<root.size.y,"Share controls visible without horizontal clipping")
		await click(copy.get_global_rect().get_center())
		var code := flow.menu.code_input.text
		check(code.begins_with("FT1.") and EncounterCode.decode(code).configuration!=null,"Selectable code produces valid setup")
		flow.menu.code_input.text=code
		await click(flow.menu.import_code_button.get_global_rect().get_center())
		check(flow.party.ready() and flow.party.difficulty_index==level,"Import preserves selected difficulty")
		await click(flow.menu.start_button.get_global_rect().get_center())
		await ready_flow()
		var combat := flow.combat.get_node("CombatController") as CombatController
		var enemy := flow.combat.get_node("EnemyController") as EnemyController
		enemy.presentation_delay=0
		enemy.planning_progress.connect(camera_during_ai)
		var hud: CanvasLayer=flow.combat.get_node("HUD")
		hud.use_native_clipboard=false
		check(hud.root.get_node("InitiativeBar").get_global_rect().end.y<=hud.root.get_node("AbilitiesPanel").get_global_rect().position.y,"Code/difficulty info does not overlap abilities")
		await capture("battle-"+flow.current_configuration.difficulty.stable_id)
		var before := combat.scheduler.active_unit().movement_remaining
		await click(hud.code_button.get_global_rect().get_center())
		check(combat.scheduler.active_unit().movement_remaining==before and not combat.motor.running,"Combat code click cannot issue world movement")
		var accepted := EncounterCode.decode(hud.code_overlay.field.text)
		check(accepted.configuration!=null and accepted.configuration.requested_attempt==flow.current_configuration.layout.attempt,"Combat code includes accepted attempt")
		check(hud.code_overlay.visible,"Code fallback overlay opens")
		await capture("code-"+flow.current_configuration.difficulty.stable_id)
		await click(hud.code_overlay.close_button.get_global_rect().get_center())
		var serial := -1
		for frame in range(24000):
			if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=serial and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO:
				serial=combat.turn_serial
				await hero_turn(combat,combat.scheduler.active_unit())
			await process_frame
		check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW],"Rendered encounter completes at each difficulty")
		check(hud.overlay.visible and hud.overlay_summary.text.contains(flow.current_configuration.difficulty.display_name),"Result explains difficulty and outcome")
		outcomes.append({"difficulty":flow.current_configuration.difficulty.stable_id,"outcome":CombatController.State.keys()[combat.state],"round":combat.scheduler.round_number,"completed_rounds":combat.completed_rounds})
		await capture("result-"+flow.current_configuration.difficulty.stable_id)
		# Cancel an actual action effect through Retry, then cancel a planning turn.
		flow.request_transition("retry")
		await ready_flow()
		combat=flow.combat.get_node("CombatController") as CombatController
		(flow.combat.get_node("EnemyController") as EnemyController).enabled=false
		var actor := combat.scheduler.active_unit()
		var target := combat.units[2]
		target.global_position=actor.global_position+Vector3(1.5,0,0)
		await physics_frame
		await physics_frame
		check(combat.submit_player_command(AttackCommand.new(actor.stable_id,target.stable_id)),"Resolution cancellation fixture uses valid attack")
		flow.request_transition("retry")
		await ready_flow()
		combat=flow.combat.get_node("CombatController") as CombatController
		check(combat.units.all(func(unit: CombatUnit) -> bool: return unit.health==unit.definition.maximum_health),"Retry during effect restores fresh scaled health")
		combat.submit_player_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
		for frame in range(60):
			if (flow.combat.get_node("EnemyController") as EnemyController).stage==EnemyController.Stage.PLANNING: break
			await process_frame
		flow.request_transition("change_setup")
		await process_frame
		await process_frame
		check(flow.party.difficulty_index==level and flow.party.ready(),"Change Setup retains the full draft")
	check(camera_checked,"Enemy planning camera check actually ran")
	flow.show_title()
	await process_frame
	flow.queue_free()
	await process_frame
	var file := FileAccess.open(prefix+"-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"camera_checked":camera_checked,"outcomes":outcomes},"\t"))
	print("DIFFICULTY VISUAL RESULT: %d failures; setup, selectable code/import, full encounters, restart effects/planning"%failures)
	quit(0 if failures==0 else 1)
