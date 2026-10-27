extends SceneTree

var failures: int = 0
var flow: SceneFlow

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_ready() -> void:
	for frame in range(1600):
		if flow.screen != "loading":
			check(flow.screen == "combat", "Flow reaches a prepared playable encounter")
			if flow.combat!=null and flow.combat.guide!=null: flow.combat.guide.close()
			return
		await process_frame
	check(false, "Flow preparation exceeded watchdog")

func drain() -> void:
	for frame in range(20):
		await process_frame
		if flow.retired.is_empty():
			await process_frame
			return
	check(false, "Old encounter failed to retire after cancellation")

func run() -> void:
	root.size = Vector2i(1280, 720)
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	check(flow.screen == "title" and flow.menu.new_button != null and flow.menu.quit_button != null and flow.combat == null, "Main scene launches title without combat controllers")
	flow.menu.new_button.pressed.emit()
	check(flow.screen == "party" and flow.menu.cards.size() == 4 and flow.menu.start_button.disabled, "New Encounter opens four choices, Start disabled")
	check(not flow.party.toggle("unknown"), "Unknown selection rejects")
	flow.party.toggle("mage")
	check(flow.party.selected.size() == 1 and flow.menu.start_button.disabled, "One selection cannot start")
	flow.party.toggle("cleric")
	check(flow.party.ready() and not flow.menu.start_button.disabled and flow.menu.selected_label.text == "Selected: 2 / 2", "Two distinct companions enable start")
	check(not flow.party.toggle("ranger") and flow.party.selected.size() == 2 and flow.menu.message.text.contains("deselect"), "Third selection rejects with explanation")
	flow.party.toggle("mage")
	check(flow.party.selected == PackedStringArray(["cleric"]) and flow.menu.start_button.disabled, "Selected card toggles off")
	flow.party.toggle("mage")
	var selected := flow.party.selected.duplicate()
	flow.menu.start_button.pressed.emit()
	check(flow.screen == "loading" and flow.combat.get_node("CombatController").state == CombatController.State.SETUP and not flow.combat.navigation_ready, "Loading starts with combat locked")
	check(not flow.combat.get_node("CombatController").submit_command(EndTurnCommand.new("hero-01")), "World commands reject during setup")
	await wait_ready()
	var controller := flow.combat.get_node("CombatController") as CombatController
	check(flow.current_configuration.hero_ids == selected and controller.units.size() == 2 + flow.current_configuration.enemies.size() and controller.units.filter(func(unit: CombatUnit) -> bool: return unit.faction == CombatUnit.Faction.HERO).size() == 2, "Selected IDs transfer without extra heroes")
	check(controller.units[0].definition == HeroCatalog.find("cleric") and controller.units[1].definition == HeroCatalog.find("mage"), "Selected stats/abilities match definitions")
	check(controller.units[0].health == HeroCatalog.find("cleric").maximum_health and controller.units[1].health == HeroCatalog.find("mage").maximum_health and controller.units[1].ability_by_id("fireburst") != null, "Fresh mutable state and abilities for selected roles")
	var seed_value := flow.current_configuration.battlefield_seed
	var signature := flow.current_configuration.layout.signature()
	var old: WeakRef = weakref(flow.combat)
	controller.units[0].set_health(4)
	controller.units[1].apply_status(load("res://definitions/slowed.tres") as StatusEffectDefinition)
	flow.request_transition("retry")
	await wait_ready()
	await drain()
	check(old.get_ref() == null and flow.current_configuration.battlefield_seed == seed_value and flow.current_configuration.layout.signature() == signature, "Retry frees old scene and preserves exact seed/layout")
	controller = flow.combat.get_node("CombatController") as CombatController
	check(controller.units.all(func(unit: CombatUnit) -> bool: return unit.health == unit.definition.maximum_health and unit.statuses.is_empty() and unit.cooldown_ready_turn.is_empty()), "Retry restores fresh health/status/cooldowns")
	flow.request_transition("new_battlefield")
	await wait_ready()
	check(flow.current_configuration.hero_ids == selected and flow.current_configuration.battlefield_seed != seed_value and flow.current_configuration.layout.signature() != signature, "New Battlefield preserves party and chooses a different seed")
	# All three outcomes expose all four transition options.
	var hud: CanvasLayer = flow.combat.get_node("HUD")
	controller = flow.combat.get_node("CombatController") as CombatController
	for result in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
		controller._set_state(result)
		check(hud.overlay.visible and hud.result_flow_buttons.size() == 4, "Each result has retry/new/party/menu")
	hud.result_flow_buttons["change_party"].pressed.emit()
	await drain()
	check(flow.screen == "party" and flow.party.selected == selected and flow.combat == null, "Change Party retains selections and frees combat")
	flow.menu.back_button.pressed.emit()
	check(flow.screen == "title", "Back returns to title")
	# Abort generation immediately, repeatedly: callbacks must not reopen old combat.
	for iteration in range(3):
		var config := EncounterConfiguration.new()
		config.battlefield_seed = 100 + iteration
		flow.start_configuration(config)
		var pending: WeakRef = weakref(flow.combat)
		flow.show_title()
		await drain()
		check(pending.get_ref() == null and flow.combat == null and flow.screen == "title", "Cancelled loading cannot resume stale encounter")
	# Selection/config snapshots never share mutable arrays/settings/layouts.
	var original := EncounterConfiguration.new()
	original.hero_ids = ["mage", "cleric"]
	var snapshot := original.snapshot() as EncounterConfiguration
	original.hero_ids[0] = "knight"
	original.generator_settings.obstacle_count = 0
	check(snapshot.hero_ids == PackedStringArray(["mage", "cleric"]) and snapshot.generator_settings.obstacle_count == 7, "Configuration snapshots isolate setup data")
	# Exit during an actual movement and discard targeting/effects/log connections.
	flow.start_configuration(snapshot)
	await wait_ready()
	controller = flow.combat.get_node("CombatController") as CombatController
	(flow.combat.get_node("EnemyController") as EnemyController).enabled = false
	while controller.scheduler.active_unit().faction == CombatUnit.Faction.ENEMY:
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	var actor := controller.scheduler.active_unit()
	var target := (flow.combat.get_node("EnemyController") as EnemyController).choose_approach(actor)
	if target != null:
		var endpoint := NavigationService.point_at_distance(target.route.path, minf(1, actor.movement_remaining))
		check(controller.submit_player_command(MoveCommand.new(actor.stable_id, endpoint)), "Movement fixture uses existing commands")
	var running: WeakRef = weakref(flow.combat)
	flow.show_party()
	await drain()
	check(running.get_ref() == null and flow.combat == null and flow.retired.is_empty(), "Leaving during action removes old motors/AI/controllers")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		check(flow.menu.start_button.get_global_rect().end.x <= resolution.x and flow.menu.start_button.get_global_rect().end.y <= resolution.y, "Selection footer fits supported resolution")
		for card in flow.menu.cards.values():
			check(card.get_global_rect().end.x <= resolution.x and card.get_global_rect().end.y <= resolution.y and card.size.y >= 190, "All four selection cards fit")
	flow.queue_free()
	await process_frame
	await process_frame
	print("FLOW RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
