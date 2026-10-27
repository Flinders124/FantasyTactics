extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var encounter: Node3D = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	await process_frame
	var controller := encounter.get_node("CombatController") as CombatController
	var player := encounter.get_node("PlayerController") as PlayerController
	var motor := encounter.get_node("MovementMotor") as MovementMotor
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	var hero := controller.find_unit("hero-01")
	var target := controller.find_unit("enemy-01")
	var scout := controller.find_unit("hero-02")
	key(KEY_T)
	check(player.attack_mode, "T activates explicit attack targeting")
	var screen := camera.unproject_position(target.global_position + Vector3.UP * 1.3)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(player.hovered_target == target and target.target_indicator.visible, "Hovered enemy highlighted")
	var hud: CanvasLayer = encounter.get_node("HUD")
	check(hud.attack_preview_label.text.contains("Out of melee range"), "Target preview shows rejection reason")
	var health_before := target.health
	click(screen, true)
	click(screen, false)
	check(target.health == health_before and hero.attack_available and not motor.running, "Invalid attack click cannot issue movement")
	screen = camera.unproject_position(scout.global_position + Vector3.UP * 1.3)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(player.hovered_target == scout and hud.attack_preview_label.text.contains("hostile"), "Friendly target highlighted invalid")
	key(KEY_ESCAPE)
	check(not player.attack_mode and not scout.target_indicator.visible and hud.attack_preview_label.text.is_empty(), "Escape clears target and preview")
	var attack_button: Button = hud.attack_button
	var button_center := attack_button.get_global_rect().get_center()
	pointer(button_center)
	await process_frame
	click(button_center, true)
	click(button_center, false)
	check(player.attack_mode and not motor.running, "HUD Attack button enters targeting without movement")
	# Ground clicks in attack mode must not fall through to movement.
	screen = camera.unproject_position(Vector3(-3, 0, 3))
	pointer(screen)
	await process_frame
	click(screen, true)
	click(screen, false)
	check(not motor.running and hero.attack_available, "Ground click in targeting mode never moves")
	target.global_position = hero.global_position + Vector3(2, 0, 0)
	await physics_frame
	screen = camera.unproject_position(target.global_position + Vector3.UP * 1.3)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(player.hovered_target == target and hud.attack_preview_label.text.contains("4 damage"), "Valid target displays damage preview")
	health_before = target.health
	click(screen, true)
	click(screen, false)
	check(controller.state == CombatController.State.RESOLVING_ACTION and not player.attack_mode, "Attack click submits and clears targeting")
	for repeat in range(4):
		click(screen, true)
		click(screen, false)
	check(target.health == health_before - 4 and not motor.running, "Repeated targeting input cannot duplicate damage or move")
	for frame in range(120):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			break
	check(not target.target_indicator.visible and not hero.attack_available, "Completed attack clears highlight and spends allowance")
	# Exercise actual restart button, not just the controller method.
	var restart_button: Button = hud.restart_button
	button_center = restart_button.get_global_rect().get_center()
	pointer(button_center)
	await process_frame
	click(button_center, true)
	click(button_center, false)
	for frame in range(120):
		await process_frame
		if controller.state == CombatController.State.AWAITING_COMMAND:
			break
	check(target.health == target.definition.maximum_health and hero.attack_available and hero.global_position == Vector3(-4, 0, 3), "Restart HUD restores playable encounter")
	encounter.queue_free()
	await process_frame
	print("TARGETING RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
