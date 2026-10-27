extends SceneTree

var failures: int = 0
var encounter: Node3D
var controller: CombatController
var scout: CombatUnit
var warden: CombatUnit
var raider: CombatUnit
var sentinel: CombatUnit
var presentation: CombatPresentation
var damage_events: int = 0
var health_events: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_for_action() -> void:
	for frame in range(600):
		await process_frame
		if controller.state != CombatController.State.RESOLVING_ACTION:
			return
	check(false, "Ranged action exceeded watchdog")

func fresh_scout() -> void:
	await controller.restart_encounter()
	for turn in range(3):
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(controller.scheduler.active_unit() == scout, "Ranged hero receives normal initiative turn")
	warden.global_position = Vector3(-9, 0, -9)
	scout.global_position = Vector3(-4, 0, 7)
	raider.global_position = Vector3(2, 0, 7)
	sentinel.global_position = Vector3(9, 0, -9)
	await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	presentation = encounter.get_node("CombatPresentation") as CombatPresentation
	scout = controller.find_unit("hero-02")
	warden = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	sentinel = controller.find_unit("enemy-02")
	check(controller.units.size() == 4 and scout.role_label() == "Ranged" and sentinel.role_label() == "Ranged" and warden.role_label() == "Melee" and raider.role_label() == "Melee", "Two melee and two ranged roles in original four-unit encounter")
	check(scout.character.role == "ranger" and warden.character.role == "knight", "Roles use distinct skinned character assets")
	check((load("res://definitions/melee.tres") as AttackDefinition).maximum_range == 1.5, "Legacy melee_range resource loads unchanged")
	await fresh_scout()
	var shot := AttackCommand.new(scout.stable_id, raider.stable_id)
	var before := raider.health
	for distance in [2.0, 8.0]:
		raider.global_position = scout.global_position + Vector3(distance, 0, 0)
		await physics_frame
		var preview := controller.evaluate_attack(scout, raider)
		check(preview.valid() and absf(preview.distance - distance) < 0.0001, "Inclusive ranged boundary %.2f" % distance)
	raider.global_position = scout.global_position + Vector3(1.98, 0, 0)
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Too close" and not controller.submit_player_command(shot), "Minimum range rejected without firing")
	raider.global_position = scout.global_position + Vector3(8.02, 0, 0)
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Out of range" and not controller.submit_player_command(shot), "Maximum range rejected without firing")
	check(scout.attack_available and raider.health == before and is_equal_approx(scout.movement_remaining, 6.0), "Invalid range spends no health, attack or movement")
	# The actual marker-to-marker 3D distance, not ground-centre distance, controls range.
	raider.global_position = scout.global_position + Vector3(7.8, 0, 0)
	var target_marker := raider.get_node("TargetPoint") as Marker3D
	target_marker.position.y = 2.8
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Out of range", "Vertical marker separation contributes to ranged distance")
	target_marker.position.y = 0.8
	var origin_marker := scout.get_node("AttackOrigin") as Marker3D
	origin_marker.position.x = 0.25
	check(absf(controller.evaluate_attack(scout, raider).distance - 7.55) < 0.001, "Configured attack-origin offset used by range")
	var hypothetical := scout.global_position + Vector3(1, 0, 0)
	var planned := controller.evaluate_attack_position(scout, raider, hypothetical)
	var old_position := scout.global_position
	scout.global_position = hypothetical
	check(absf(controller.evaluate_attack(scout, raider).distance - planned.distance) < 0.001, "Hypothetical AI geometry matches execution geometry")
	scout.global_position = old_position
	origin_marker.position.x = 0.0
	# Optional minimum range can be zero; configuration is shared but never mutated by attacks.
	var original := scout.definition
	scout.definition = original.duplicate() as UnitDefinition
	scout.definition.basic_attack = original.basic_attack.duplicate() as AttackDefinition
	scout.definition.basic_attack.minimum_range = 0.0
	raider.global_position = scout.global_position + Vector3.RIGHT
	await physics_frame
	check(controller.evaluate_attack(scout, raider).valid(), "Zero minimum range disables close-range exclusion")
	scout.definition.basic_attack.minimum_range = 9.0
	check(not controller.submit_player_command(shot) and scout.attack_available, "Invalid range configuration cannot spend an attack")
	scout.definition = original
	var saved_origin_path := scout.attack_origin_path
	scout.attack_origin_path = ^"MissingMarker"
	check(controller.evaluate_attack(scout, raider).error.contains("marker") and not controller.submit_player_command(shot) and scout.attack_available, "Missing configurable marker rejected without crash or spending")
	scout.attack_origin_path = saved_origin_path
	# Walls and living intervening units all block the same first-hit query.
	raider.global_position = Vector3(2, 0, 7)
	var wall := StaticBody3D.new()
	wall.position = Vector3(-1, 1, 7)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2, 2)
	collision.shape = box
	wall.add_child(collision)
	encounter.add_child(wall)
	await physics_frame
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Line of sight blocked" and not controller.submit_player_command(shot), "Static geometry blocks shots")
	wall.queue_free()
	await physics_frame
	warden.global_position = Vector3(-1, 0, 7)
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Line of sight blocked" and not controller.submit_player_command(shot), "Friendly living unit blocks without friendly fire")
	check(warden.health == warden.definition.maximum_health and scout.attack_available, "Blocked shot causes no damage or attack spending")
	warden.set_health(0)
	await physics_frame
	check(controller.evaluate_attack(scout, raider).valid() and controller.evaluate_move(scout, warden.global_position).valid(), "Dead body blocks neither shot nor movement")
	sentinel.global_position = Vector3(-1, 0, 7)
	await physics_frame
	check(controller.evaluate_attack(scout, raider).error == "Line of sight blocked", "Another hostile living body also blocks")
	sentinel.global_position = Vector3(9, 0, -9)
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(scout.attack_origin_at(scout.global_position), raider.target_point(), 1)
	ray.exclude = [scout.get_rid()]
	var hit := scout.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == raider and controller.evaluate_attack(scout, raider).valid(), "Attacker excluded; intended target is valid first hit")
	# Revalidate after the state notification and before committing resources.
	var invalidate := func(state: CombatController.State) -> void:
		if state == CombatController.State.RESOLVING_ACTION:
			raider.global_position = scout.global_position + Vector3(9, 0, 0)
	controller.state_changed.connect(invalidate)
	check(not controller.submit_player_command(shot) and scout.attack_available and raider.health == before, "Late invalidation rejected before attack commitment")
	controller.state_changed.disconnect(invalidate)
	check(controller.state == CombatController.State.AWAITING_COMMAND, "Rejected precommit returns control")
	raider.global_position = Vector3(2, 0, 7)
	await physics_frame
	controller.combat_event.connect(func(kind: String, _data: Dictionary) -> void:
		if kind == "attack":
			damage_events += 1)
	raider.health_changed.connect(func(_unit: CombatUnit) -> void: health_events += 1)
	sentinel.begin_turn() # Isolation fixture: shares the same immutable ranged resource.
	check(controller.submit_player_command(shot), "Legal ranged AttackCommand accepted")
	check(raider.health == before - 4 and damage_events == 1 and health_events == 1 and not scout.attack_available and sentinel.attack_available, "One damage application and one independent attack spent")
	check(presentation.tracers.size() == 1, "Resolved ranged event creates presentation-only tracer")
	for repeat in range(5):
		check(not controller.submit_player_command(shot), "Repeated shot during resolution rejected")
	presentation.clear_tracers()
	presentation._process(1.0)
	await wait_for_action()
	check(raider.health == before - 4 and damage_events == 1 and health_events == 1, "Effect deletion/lifetime cannot duplicate or stall damage")
	check(not controller.submit_player_command(shot), "Second attack in same turn rejected")
	check(controller.submit_player_command(MoveCommand.new(scout.stable_id, scout.global_position + Vector3(0, 0, 1))), "Ranged unit may move after attacking")
	await wait_for_action()
	check(scout.movement_remaining < 5.1 and scout.movement_remaining > 4.9, "Attack preserves movement allowance")
	await fresh_scout()
	check(controller.submit_player_command(MoveCommand.new(scout.stable_id, scout.global_position + Vector3.RIGHT)), "Ranged unit may move before attacking")
	await wait_for_action()
	check(controller.submit_player_command(shot), "Post-move ranged shot accepted")
	await controller.restart_encounter()
	for frame in range(30):
		await process_frame
	check(presentation.tracers.is_empty() and presentation.world_effects.get_child_count() == 1 and presentation.oath_fx.active_count()==0 and raider.health == raider.definition.maximum_health and controller.scheduler.active_unit() == warden, "Restart during shot clears effects and stale completion")
	await fresh_scout()
	controller.submit_player_command(shot)
	raider.set_health(0)
	check(presentation.tracers.is_empty() and not controller.evaluate_attack(scout, raider).valid(), "Target death clears tracer and invalidates targeting")
	sentinel.set_health(0)
	check(controller.state == CombatController.State.VICTORY and presentation.tracers.is_empty(), "Encounter completion clears pending shot presentation")
	# Exercise the real targeting/input path with a ranged hero, not just direct commands.
	await fresh_scout()
	scout.global_position = Vector3(-4, 0, 3)
	raider.global_position = Vector3(2, 0, 3)
	await physics_frame
	await physics_frame
	var player := encounter.get_node("PlayerController") as PlayerController
	var camera := encounter.get_node("TacticalCamera/Camera3D") as Camera3D
	var screen := camera.unproject_position(raider.global_position + Vector3.UP * 1.3)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	player.set_mode(PlayerController.Mode.ATTACK)
	await process_frame
	player._process(0.0)
	var hud: CanvasLayer = encounter.get_node("HUD")
	check(hud.attack_preview_label.text.contains("Ranged") and hud.attack_preview_label.text.contains("2.00–8.00 m") and hud.attack_preview_label.text.contains("4 damage") and hud.attack_preview_label.text.contains("TARGET OK"), "Ranged preview shows type, exact range, damage and shared validity")
	before = raider.health
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	click.global_position = screen
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(raider.health == before - 4 and not scout.attack_available, "Ranged targeting click executes the previewed damage once")
	await wait_for_action()
	encounter.queue_free()
	await process_frame
	print("RANGED RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
