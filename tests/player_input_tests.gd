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

func run() -> void:
	root.size = Vector2i(1280, 720)
	var encounter: Node3D = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	await process_frame
	var controller := encounter.get_node("CombatController") as CombatController
	var motor := encounter.get_node("MovementMotor") as MovementMotor
	var player := encounter.get_node("PlayerController") as PlayerController
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	var hero := controller.scheduler.active_unit()
	var start := hero.global_position
	var button: Button = encounter.get_node("HUD").button
	var button_center := button.get_global_rect().get_center()
	pointer(button_center)
	await process_frame
	click(button_center, true)
	click(button_center, false)
	await process_frame
	check(not motor.running and hero.global_position == start and is_equal_approx(hero.movement_remaining, 6.0), "HUD click does not issue world movement")
	check(controller.scheduler.active_unit().faction == CombatUnit.Faction.ENEMY, "HUD End Turn still works")
	for index in range(3):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	var destination := Vector3(-3, 0, 3)
	var screen := camera.unproject_position(destination)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(player.line.mesh != null and player.last_distance > 0.9, "Ground raycast produces path preview")
	click(screen, true)
	check(motor.running and controller.state == CombatController.State.RESOLVING_ACTION, "Ground click submits MoveCommand")
	click(screen, false)
	click(screen, true)
	click(screen, false)
	for frame in range(300):
		await physics_frame
		if not motor.running:
			break
	check(not motor.running and hero.global_position.distance_to(destination) < 0.02, "Click movement completes once without queueing")
	check(hero.movement_remaining > 4.98 and hero.movement_remaining < 5.02, "Input movement spends one route cost")
	encounter.queue_free()
	await process_frame
	print("PLAYER INPUT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
