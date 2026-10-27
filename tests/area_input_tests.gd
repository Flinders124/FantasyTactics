extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var player: PlayerController
var hud: CanvasLayer
var camera: Camera3D
var scout: CombatUnit
var warden: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
const POINT: Vector3 = Vector3(0, 0, 3)

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

func click(position: Vector2) -> void:
	pointer(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func fresh() -> void:
	await controller.restart_encounter()
	for turn in range(3):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	scout.global_position = Vector3(-4, 0, 3)
	warden.global_position = Vector3(-1, 0, 3)
	raider.global_position = Vector3(1, 0, 3)
	sentinel.global_position = Vector3(9, 0, -9)
	await physics_frame
	await physics_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	player = encounter.get_node("PlayerController") as PlayerController
	hud = encounter.get_node("HUD")
	camera = encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	scout = controller.find_unit("hero-02")
	warden = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	await fresh()
	key(KEY_3)
	check(player.selected_ability_id == "fireburst" and hud.ability_buttons[2].button_pressed, "Third-slot shortcut selects Fireburst")
	var screen := camera.unproject_position(POINT)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(player.area_marker.visible and player.area_highlighted.has(raider) and player.area_highlighted.has(warden), "World radius and all affected-unit highlights match area query")
	check(warden.health_label.text.contains("ALLY HIT") and raider.health_label.text.contains("HIT") and hud.attack_preview_label.text.contains("FRIENDLY FIRE"), "Shapes/text and HUD explicitly warn about friendly damage")
	click(screen)
	check(player.ground_selected and scout.action_available and scout.cooldown_ready_turn.is_empty() and warden.health == 20, "First click selects only, with no spending or damage")
	var selected := player.selected_ground
	click(Vector2(30, 490)) # Non-actionable help-panel background.
	await process_frame
	check(player.ground_selected and player.selected_ground == selected and warden.health == 20 and scout.action_available, "UI click cannot select or confirm a ground target")
	key(KEY_ESCAPE)
	check(not player.ground_selected and not player.area_marker.visible and player.area_highlighted.is_empty() and scout.action_available and scout.cooldown_ready_turn.is_empty(), "Escape cancels selection and highlights without resources")
	# Buttons also select mode without casting; second WORLD click commits once.
	var center: Vector2 = hud.ability_buttons[2].get_global_rect().get_center()
	click(center)
	check(player.selected_ability_id == "fireburst" and not player.ground_selected, "Ability button does not leak a selection into world")
	pointer(screen)
	await process_frame
	click(screen)
	check(player.ground_selected, "Select a fresh point after UI button")
	click(screen)
	check(controller.state == CombatController.State.RESOLVING_ACTION and warden.health == 17 and raider.health == 13 and not scout.action_available, "Separate confirmation submits exactly one area command")
	click(screen)
	check(warden.health == 17 and raider.health == 13 and not controller.motor.running, "Repeated click during effect cannot duplicate damage or move")
	check(not player.ground_selected and not player.area_marker.visible and player.area_highlighted.is_empty(), "Commit clears targeting previews")
	await fresh()
	key(KEY_3)
	click(screen)
	raider.set_health(0)
	pointer(screen)
	await process_frame
	player._process(0.0)
	check(not player.area_highlighted.has(raider) and not hud.attack_preview_label.text.contains("Raider"), "Relevant state change recomputes affected units and removes dead target")
	# Invalidating cast range between selection and confirmation must spend nothing.
	scout.global_position = Vector3(-10, 0, -8)
	player._process(0.0)
	check(hud.attack_preview_label.text.contains("Out of cast range") and player.area_highlighted.is_empty(), "Locked-point preview revalidates current caster state")
	click(screen)
	check(scout.action_available and scout.cooldown_ready_turn.is_empty() and not player.ground_selected and warden.health == 20, "Invalid confirmation rejects and clears pending selection")
	await fresh()
	key(KEY_3)
	click(screen)
	await controller.restart_encounter()
	check(player.selected_ability_id.is_empty() and not player.ground_selected and not player.area_marker.visible and player.area_highlighted.is_empty(), "Restart during targeting clears all pending point/indicator state")
	# Hero inputs cannot activate enemy's Fireburst while its turn is awaiting.
	controller.submit_command(EndTurnCommand.new(warden.stable_id))
	controller.submit_command(EndTurnCommand.new(raider.stable_id))
	check(not controller.submit_player_command(UseAbilityCommand.on_ground(sentinel.stable_id, "fireburst", POINT)), "Player cannot use enemy area ability")
	key(KEY_3)
	check(player.selected_ability_id.is_empty(), "No actionable enemy-turn area preview")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		for panel in hud.layout_panels:
			var rect: Rect2 = panel.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= resolution.x + 1 and rect.end.y <= resolution.y + 1, "Three-slot interface fits " + str(resolution))
	encounter.queue_free()
	await process_frame
	print("AREA INPUT RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
