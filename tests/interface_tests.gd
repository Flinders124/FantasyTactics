extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var player: PlayerController
var hud: CanvasLayer
var history: CombatLog
var presentation: CombatPresentation
var hero: CombatUnit

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

func wait_for_action() -> void:
	for frame in range(600):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Action timed out")

func passive_controls(node: Node) -> void:
	if node is Control:
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "World health UI ignores all mouse events")
	for child in node.get_children():
		passive_controls(child)

func run() -> void:
	root.size = Vector2i(1280, 720)
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	player = encounter.get_node("PlayerController") as PlayerController
	hud = encounter.get_node("HUD") as CanvasLayer
	history = encounter.get_node("CombatLog") as CombatLog
	presentation = encounter.get_node("CombatPresentation") as CombatPresentation
	hero = controller.find_unit("hero-01")
	var enemy := controller.find_unit("enemy-01")
	var scout := controller.find_unit("hero-02")
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	await process_frame
	check(history.entries.size() == 1 and history.entries[0].contains("Warden"), "One authoritative initial turn entry")
	check(hud.initiative_cards.size() == 4 and hud.round_label.text == "ROUND 1", "Living initiative and round visible")
	check(hud.label.text.contains("20 / 20") and hud.label.text.contains("6.00") and hud.label.text.contains("READY"), "Active panel shows health and action resources")
	check(player.mode == PlayerController.Mode.MOVE and hud.move_button.button_pressed, "Explicit Move mode visibly selected")
	var entry_count := history.entries.size()
	check(not controller.submit_player_command(AttackCommand.new(hero.stable_id, enemy.stable_id)), "Invalid attack rejected")
	for update in range(15):
		hud._refresh()
	check(history.entries.size() == entry_count, "Rejected commands and repeated refreshes do not create log entries")
	# Health overlays stay aligned, behind-camera hidden, and entirely passive.
	passive_controls(presentation.root)
	presentation._process(0.0)
	var bar: Control = presentation.bars[enemy.stable_id].panel
	pointer(bar.get_global_rect().get_center())
	await process_frame
	check(get_root().gui_get_hovered_control() == null, "Projected health bar does not intercept hover/click routing")
	var saved_transform := camera.global_transform
	camera.global_position = Vector3(0, 4, 20)
	camera.look_at(Vector3(0, 4, 30))
	presentation._process(0.0)
	check(not bar.visible, "Health bars hidden behind camera")
	camera.global_transform = saved_transform
	presentation._process(0.0)
	var projected := camera.unproject_position(enemy.global_position + Vector3.UP * 2.4)
	var anchor: Vector2 = presentation.bars[enemy.stable_id].anchor
	check(anchor.distance_to(projected) < 0.1, "Health bar leader anchored to world after camera movement")
	# Hover does not change actor; mode switch and Escape clear old previews.
	pointer(camera.unproject_position(scout.global_position + Vector3.UP * 1.3))
	await process_frame
	player._process(0.0)
	check(player.hovered_unit == scout and scout.hover_indicator.visible and controller.scheduler.active_unit() == hero, "Inactive-unit hover only inspects")
	player.toggle_attack_targeting()
	check(hud.attack_button.button_pressed and not hud.move_button.button_pressed, "Attack selected state is explicit")
	player.cancel_targeting()
	check(player.mode == PlayerController.Mode.NONE and player.line.mesh == null and not player.destination_marker.visible, "Escape/cancel clears previews and mode")
	player.set_mode(PlayerController.Mode.MOVE)
	var destination := Vector3(-3, 0, 3)
	pointer(camera.unproject_position(destination))
	await process_frame
	player._process(0.0)
	check(player.line.mesh != null and player.destination_marker.visible and absf(player.last_distance - 1.0) < 0.02, "Route, destination and true cost preview present")
	check(hud.preview_label.text.contains("AFFORDABLE"), "Preview explicitly states affordability")
	pointer(camera.unproject_position(Vector3.ZERO))
	await process_frame
	player._process(0.0)
	check(player.line.mesh == null and player.destination_label.text == "INVALID" and not player.last_message.is_empty(), "Unwalkable destination clears stale route and explains invalidity")
	check(controller.submit_player_command(MoveCommand.new(hero.stable_id, destination)), "Valid move accepted")
	check(not player.destination_marker.visible and player.line.mesh == null, "Action start clears movement preview immediately")
	await wait_for_action()
	check(history.entries.size() == entry_count + 1 and history.entries[-1].contains("1.00 m"), "Exactly one completed move entry with actual distance")
	# Attack → death → result ordering comes from rules, never UI update frequency.
	await controller.restart_encounter()
	controller.find_unit("enemy-02").set_health(0)
	enemy.set_health(1)
	enemy.global_position = hero.global_position + Vector3(2, 0, 0)
	await physics_frame
	player.toggle_attack_targeting()
	pointer(camera.unproject_position(enemy.global_position + Vector3.UP * 1.3))
	await process_frame
	player._process(0.0)
	check(hud.attack_preview_label.text.contains("4 damage") and enemy.target_indicator.visible, "Expected fixed damage and target indicator visible")
	check(controller.submit_player_command(AttackCommand.new(hero.stable_id, enemy.stable_id)), "Lethal attack accepted")
	check(history.entries[-3].contains("4 damage") and history.entries[-2].contains("defeated") and history.entries[-1].contains("VICTORY"), "Authoritative log ordered attack, death, result exactly once")
	check(hud.overlay.visible and hud.overlay_title.text == "VICTORY", "Victory overlay and restart visible")
	check(hud.initiative_cards.size() == 2 and not presentation.bars[enemy.stable_id].panel.visible and not enemy.target_indicator.visible, "Death immediately updates initiative, health and target displays")
	check(presentation.effects.size() > 0, "Damage and death feedback spawned without gating gameplay")
	entry_count = history.entries.size()
	controller.submit_player_command(AttackCommand.new(hero.stable_id, enemy.stable_id))
	hud._refresh()
	check(history.entries.size() == entry_count, "Terminal rejection cannot duplicate log/result")
	var reset_connections := controller.encounter_reset.get_connections().size()
	var unit_children := hero.get_child_count()
	for restart in range(3):
		await controller.restart_encounter()
		check(history.entries.size() == 1 and presentation.effects.is_empty() and not hud.overlay.visible and hud.initiative_cards.size() == 4, "Restart clears log/effects/overlay and restores four initiative cards")
	check(controller.encounter_reset.get_connections().size() == reset_connections and presentation.bars.size() == 4, "Restarts do not duplicate signals or health bars")
	check(hero.get_child_count() == unit_children and presentation.root.get_child_count() == 8, "Restarts do not duplicate world indicators, leaders or effects")
	# Log storage is bounded by real turn events, not fabricated UI messages.
	history.capacity = 8
	for turn in range(20):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(history.entries.size() == 8, "Combat log bounded after many real turn starts")
	await controller.restart_encounter()
	# Container geometry at both supported resolutions stays inside the viewport.
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		for panel in hud.layout_panels:
			var rect: Rect2 = panel.get_global_rect()
			check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= resolution.x + 1 and rect.end.y <= resolution.y + 1, "Panel fits target resolution: %s" % panel.name)
		check(hud.move_button.size.y >= 38 and hud.button.size.y >= 38, "Combat controls keep readable hit size")
	controller.find_unit("hero-02").set_health(0)
	hero.set_health(0)
	check(hud.overlay.visible and hud.overlay_title.text == "DEFEAT", "Defeat uses same overlay layout")
	encounter.queue_free()
	await process_frame
	print("INTERFACE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
