extends "res://tests/generated_encounter_tests.gd"

var prefix: String
var output_directory: String = "res://../verification/stability"

func snapshot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix + "-" + label + ".png"))

func pointer(position: Vector2) -> void:
	root.warp_mouse(position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(position: Vector2) -> void:
	pointer(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func ready_flow() -> void:
	for frame in range(1600):
		await process_frame
		if flow.screen != "loading":
			break
	assert(flow.screen == "combat")

func run() -> void:
	var resolution := Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280, 720)
	root.size = resolution
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	prefix = output_directory+"/flow-%d" % resolution.x
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.initial_seed_override = 7
	await snapshot("title")
	click(flow.menu.new_button.get_global_rect().get_center())
	await snapshot("party")
	click(flow.menu.cards["knight"].get_global_rect().get_center())
	assert(flow.party.selected.size() == 1 and flow.menu.start_button.disabled)
	click(flow.menu.cards["ranger"].get_global_rect().get_center())
	assert(flow.party.ready())
	click(flow.menu.cards["mage"].get_global_rect().get_center())
	assert(flow.party.selected.size() == 2)
	click(flow.menu.cards["ranger"].get_global_rect().get_center())
	assert(flow.party.selected.size() == 1)
	click(flow.menu.cards["ranger"].get_global_rect().get_center())
	await snapshot("selected")
	click(flow.menu.start_button.get_global_rect().get_center())
	assert(flow.screen == "loading")
	await snapshot("loading")
	await ready_flow()
	controller = flow.combat.get_node("CombatController") as CombatController
	ai = flow.combat.get_node("EnemyController") as EnemyController
	var signature := flow.current_configuration.layout.signature()
	await snapshot("battlefield")
	var actor := controller.scheduler.active_unit()
	var camera := flow.combat.get_node("TacticalCamera/Camera3D") as Camera3D
	var destination := actor.position + Vector3(2, 0, 0)
	var screen_position := camera.unproject_position(destination)
	pointer(screen_position)
	await process_frame
	await snapshot("move-preview")
	click(screen_position)
	assert(controller.motor.running)
	var rig := flow.combat.get_node("TacticalCamera") as TacticalCamera
	var yaw_before := rig.yaw
	var orbit := InputEventMouseButton.new()
	orbit.button_index = MOUSE_BUTTON_RIGHT
	orbit.pressed = true
	Input.parse_input_event(orbit.duplicate())
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = screen_position
	motion.global_position = screen_position
	motion.relative = Vector2(40, 0)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	orbit.pressed = false
	Input.parse_input_event(orbit.duplicate())
	Input.flush_buffered_events()
	assert(rig.yaw != yaw_before)
	await wait_for_action()
	assert(actor.position.distance_to(destination) < 0.02)
	controller.submit_player_command(EndTurnCommand.new(actor.stable_id))
	for frame in range(120):
		await process_frame
		if controller.motor.running:
			break
	assert(controller.motor.running and controller.motor.actor.faction == CombatUnit.Faction.ENEMY)
	var hud: CanvasLayer = flow.combat.get_node("HUD")
	click(hud.restart_button.get_global_rect().get_center())
	await ready_flow()
	assert(flow.current_configuration.layout.signature() == signature)
	assert(flow.combat.get_node("CombatController").scheduler.active_unit().stable_id == "hero-01")
	await snapshot("retry")
	await start_case(7, PackedStringArray(["knight", "ranger"]))
	await simulate(true)
	assert(controller.state == CombatController.State.VICTORY)
	await snapshot("victory")
	hud = flow.combat.get_node("HUD")
	click(hud.result_flow_buttons["new_battlefield"].get_global_rect().get_center())
	await ready_flow()
	assert(flow.current_configuration.battlefield_seed != 7 and flow.current_configuration.hero_ids == PackedStringArray(["knight", "ranger"]))
	await snapshot("new-battlefield")
	await start_case(11, PackedStringArray(["mage", "cleric"]))
	await snapshot("mage-cleric")
	await simulate(true)
	assert(terminal())
	await start_case(7, PackedStringArray(["knight", "ranger"]))
	await simulate(false)
	assert(controller.state == CombatController.State.DEFEAT)
	await snapshot("defeat")
	# Actual lethal Fireburst on generated clear spawn ground; staged health/placement.
	await start_case(11, PackedStringArray(["mage", "cleric"]))
	ai.enabled = false
	while controller.scheduler.active_unit().faction == CombatUnit.Faction.ENEMY:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	var center := flow.current_configuration.layout.hero_zone.get_center()
	var point := Vector3(center.x, 0, center.y)
	var offsets: Array[Vector3] = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
	for index in range(4):
		controller.units[index].position = point + offsets[index]
		controller.units[index].set_health(3)
	await physics_frame
	await physics_frame
	assert(controller.submit_player_command(UseAbilityCommand.on_ground("hero-01", "fireburst", point)))
	assert(controller.state == CombatController.State.DRAW)
	await snapshot("draw")
	hud = flow.combat.get_node("HUD")
	click(hud.result_flow_buttons["change_party"].get_global_rect().get_center())
	await snapshot("change-party")
	assert(flow.party.selected == PackedStringArray(["mage", "cleric"]))
	click(flow.menu.back_button.get_global_rect().get_center())
	assert(flow.screen == "title")
	for frame in range(10):
		await process_frame
	assert(flow.retired.is_empty())
	print("Rendered title/selection/generated combat/replay/results at ", resolution, " failures ", failures)
	flow.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
