class_name PlayerController
extends Node3D

signal route_previewed(destination: Vector3, distance: float, valid: bool)
signal preview_changed(distance: float, affordable: bool, message: String)
signal attack_preview_changed(target_name: String, distance: float, valid: bool, message: String)
signal area_preview_changed(message: String, valid: bool)
signal targeting_changed(enabled: bool)
signal mode_changed(mode: Mode)
enum Mode { NONE, MOVE, ATTACK }
var controller: CombatController
var camera: Camera3D
var line: MeshInstance3D
var destination_marker: MeshInstance3D
var destination_label: Label3D
var marker_material: StandardMaterial3D
var marker_ring: TorusMesh
var invalid_marker: ImmediateMesh
var selected_ability_id: String = ""
var mode: Mode = Mode.NONE
var attack_mode: bool:
	get:
		return mode == Mode.ATTACK
var last_message: String = ""
var last_distance: float = -1.0
var hovered_target: CombatUnit
var hovered_unit: CombatUnit
var ground_selected: bool = false
var selected_ground: Vector3 = Vector3.ZERO
var area_marker: MeshInstance3D
var area_ring: TorusMesh
var area_material: StandardMaterial3D
var area_label: Label3D
var area_highlighted: Array[CombatUnit] = []

func bind(combat: CombatController, view: Camera3D) -> void:
	controller = combat
	camera = view
	line = MeshInstance3D.new()
	add_child(line)
	destination_marker = MeshInstance3D.new()
	marker_ring = TorusMesh.new()
	marker_ring.inner_radius = 0.22
	marker_ring.outer_radius = 0.3
	invalid_marker = CombatUnit.outline_mesh(true)
	marker_material = StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	destination_marker.material_override = marker_material
	add_child(destination_marker)
	destination_label = Label3D.new()
	destination_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	destination_label.position = Vector3(0, 0.2, 0)
	destination_label.pixel_size = 0.012
	destination_label.font_size = 40
	destination_label.no_depth_test = true
	destination_marker.add_child(destination_label)
	destination_marker.visible = false
	area_marker = MeshInstance3D.new()
	area_ring = TorusMesh.new()
	area_marker.mesh = area_ring
	area_material = StandardMaterial3D.new()
	area_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	area_marker.material_override = area_material
	add_child(area_marker)
	area_label = Label3D.new()
	area_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area_label.font_size = 32
	area_label.pixel_size = 0.01
	area_label.position = Vector3(0, 0.25, 0)
	area_label.no_depth_test = true
	area_marker.add_child(area_label)
	area_marker.visible = false
	controller.state_changed.connect(_on_combat_state_changed)
	controller.selection_changed.connect(func(_unit: CombatUnit) -> void: cancel_targeting())
	controller.encounter_updated.connect(_check_lost_target)

func _can_command() -> bool:
	var active := controller.scheduler.active_unit() if controller.scheduler != null else null
	return not controller.guidance_paused and controller.state == CombatController.State.AWAITING_COMMAND and active != null and active.is_alive() and active.faction == CombatUnit.Faction.HERO

func _on_combat_state_changed(state: CombatController.State) -> void:
	if state == CombatController.State.AWAITING_COMMAND and _can_command():
		set_mode(Mode.MOVE)
	else:
		cancel_targeting()
		_set_hover(null)

func set_mode(next: Mode) -> void:
	if next != Mode.NONE and not _can_command():
		return
	_clear_area_preview(true)
	selected_ability_id = ""
	mode = next
	_clear()
	preview_changed.emit(0.0, false, "")
	_highlight(null, false)
	attack_preview_changed.emit("", 0.0, false, "")
	targeting_changed.emit(attack_mode)
	mode_changed.emit(mode)

func toggle_attack_targeting() -> void:
	if attack_mode and selected_ability_id.is_empty():
		cancel_targeting()
		return
	if not _can_command():
		return
	var active := controller.scheduler.active_unit()
	if not active.attack_available:
		controller.feedback_changed.emit("No action remaining")
		return
	set_mode(Mode.ATTACK)
	attack_preview_changed.emit("", 0.0, false, "Hover a unit to inspect your equipped attack. Esc cancels.")

func select_ability(id: String) -> void:
	if not _can_command():
		return
	set_mode(Mode.ATTACK)
	selected_ability_id = id
	mode_changed.emit(mode)

func cancel_targeting() -> void:
	set_mode(Mode.NONE)

func _set_hover(unit: CombatUnit) -> void:
	if hovered_unit != null and hovered_unit != unit:
		hovered_unit.set_hovered(false)
	hovered_unit = unit
	if unit != null:
		unit.set_hovered(true)

func _highlight(target: CombatUnit, valid: bool) -> void:
	if hovered_target != null and hovered_target != target:
		hovered_target.set_target_highlight(false, false)
	hovered_target = target
	if target != null:
		target.set_target_highlight(true, valid)

func _check_lost_target() -> void:
	if hovered_target != null and not hovered_target.is_alive():
		_highlight(null, false)
		attack_preview_changed.emit("", 0.0, false, "Target no longer alive. Choose another target.")
	if hovered_unit != null and not hovered_unit.is_alive():
		_set_hover(null)

func _unit_under_pointer(screen_position: Vector2 = Vector2.INF) -> CombatUnit:
	var mouse := screen_position if screen_position.is_finite() else get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 300.0, 5)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider is CombatUnit and hit.collider.is_alive():
		return hit.collider as CombatUnit
	return null

func _process(_delta: float) -> void:
	if controller == null:
		return
	if controller.state in [CombatController.State.SETUP, CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW] or get_viewport().gui_get_hovered_control() != null:
		_clear()
		_clear_area_preview()
		_highlight(null, false)
		_set_hover(null)
		attack_preview_changed.emit("", 0.0, false, "")
		return
	_set_hover(_unit_under_pointer())
	if not _can_command() or mode == Mode.NONE:
		_clear()
		_clear_area_preview()
		_highlight(null, false)
		attack_preview_changed.emit("", 0.0, false, "")
		return
	var active := controller.scheduler.active_unit()
	if attack_mode:
		if _ground_ability() != null:
			_process_ground_preview()
			return
		var preview := controller.evaluate_attack(active, hovered_unit) if selected_ability_id.is_empty() else controller.evaluate_ability(active, hovered_unit, selected_ability_id)
		_highlight(hovered_unit, preview.valid())
		var attack := active.definition.basic_attack
		var description := "%s · %s · %d damage" % [attack.type_label(), attack.range_label(), attack.damage] if attack != null else "Unarmed"
		if not selected_ability_id.is_empty():
			var ability := active.ability_by_id(selected_ability_id)
			if ability != null:
				var amount := mini(ability.magnitude, hovered_unit.definition.maximum_health - hovered_unit.health) if ability.effect == AbilityDefinition.Effect.HEAL and hovered_unit != null else ability.magnitude
				description = "%s · %s · %d %s%s" % [ability.display_name, ability.range_label(), amount, "healing" if ability.effect == AbilityDefinition.Effect.HEAL else "damage", " + %s (%d future turns)" % [ability.applied_status.display_name, ability.applied_status.affected_turns] if ability.applied_status != null else ""]
		var message := "%s\n%s" % [description, preview.error if not preview.valid() else ("Click target to use ability." if not selected_ability_id.is_empty() else "Clear attack. Click target to strike.")]
		attack_preview_changed.emit(hovered_unit.definition.display_name if hovered_unit != null else "", preview.distance, preview.valid(), message)
		return
	var hit := _ground_hit()
	if hit.is_empty():
		_clear()
		_feedback(0.0, false, "Point at walkable ground")
		return
	var route := controller.evaluate_move(active, hit.position)
	route_previewed.emit(hit.position,route.distance,route.valid())
	_draw(route.path, route.valid())
	_show_destination(hit.position, route.valid(), route.distance)
	_feedback(route.distance, route.valid(), route.error if not route.valid() else "Click destination to move. Cost follows the full route.")

func _unhandled_input(event: InputEvent) -> void:
	if controller == null:
		return
	for index in range(3):
		if ControlBindings.pressed(event,"ability_"+str(index+1)):
			if _can_command():
				var abilities := controller.scheduler.active_unit().definition.abilities
				if index<abilities.size(): select_ability(abilities[index].stable_id)
			get_viewport().set_input_as_handled()
			return
	var consumed := true
	if ControlBindings.pressed(event,"move"): set_mode(Mode.MOVE)
	elif ControlBindings.pressed(event,"attack"): toggle_attack_targeting()
	elif ControlBindings.pressed(event,"cancel"): cancel_targeting()
	elif ControlBindings.pressed(event,"end_turn"):
		if _can_command(): controller.submit_player_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	else: consumed=false
	if consumed:
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	if ControlBindings.pressed(event,"world") and _can_command():
		var screen_point: Vector2=event.position if event is InputEventMouseButton else get_viewport().get_mouse_position()
		var active := controller.scheduler.active_unit()
		if attack_mode:
			if _ground_ability() != null:
				_ground_click(screen_point)
				get_viewport().set_input_as_handled()
				return
			var target := _unit_under_pointer(screen_point)
			if target != null:
				if selected_ability_id.is_empty():
					controller.submit_player_command(AttackCommand.new(active.stable_id, target.stable_id))
				else:
					controller.submit_player_command(UseAbilityCommand.new(active.stable_id, target.stable_id, selected_ability_id))
			else:
				controller.feedback_changed.emit("Choose a living hostile target")
		elif mode == Mode.MOVE:
			var hit := _ground_hit(screen_point)
			if not hit.is_empty():
				controller.submit_player_command(MoveCommand.new(active.stable_id, hit.position))
		else:
			controller.feedback_changed.emit("Choose Move [M] or Attack [T] first")
		get_viewport().set_input_as_handled()

func _ground_hit(screen_position: Vector2 = Vector2.INF) -> Dictionary:
	# Button events may be buffered while the mouse keeps moving. Hover uses the
	# live pointer, but a committed command must use the actual click position.
	var mouse := screen_position if screen_position.is_finite() else get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 300.0, 2)
	return get_world_3d().direct_space_state.intersect_ray(ray)

func _clear() -> void:
	line.mesh = null
	destination_marker.visible = false
	_feedback(0.0, false, "")

func _feedback(distance: float, affordable: bool, message: String) -> void:
	if message != last_message or not is_equal_approx(distance, last_distance):
		last_message = message
		last_distance = distance
		preview_changed.emit(distance, affordable, message)

func _show_destination(destination: Vector3, valid: bool, distance: float) -> void:
	destination_marker.visible = true
	destination_marker.position = NavigationService.planar(destination) + Vector3.UP * 0.06
	destination_marker.mesh = marker_ring if valid else invalid_marker
	marker_material.albedo_color = Color(0.3, 1, 0.7) if valid else Color.ORANGE_RED
	destination_label.text = "%.2f m" % distance if valid else "INVALID"

func _draw(path: PackedVector3Array, valid: bool) -> void:
	if path.size() < 2:
		line.mesh = null
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.3, 1, 0.7) if valid else Color.ORANGE_RED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index in range(1, path.size()):
		var start := path[index - 1] + Vector3.UP * 0.07
		var finish := path[index] + Vector3.UP * 0.07
		var direction := finish - start
		var side := Vector3(-direction.z, 0, direction.x).normalized() * 0.045
		for vertex in [start - side, start + side, finish + side, start - side, finish + side, finish - side]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	line.mesh = mesh


func _ground_ability() -> AbilityDefinition:
	if selected_ability_id.is_empty() or controller.scheduler == null:
		return null
	var active := controller.scheduler.active_unit()
	var ability := active.ability_by_id(selected_ability_id) if active != null else null
	return ability if ability != null and ability.targeting == AbilityDefinition.Target.GROUND else null

func _clear_area_preview(reset_selection: bool = false) -> void:
	for unit in area_highlighted:
		unit.set_area_highlight(false)
	area_highlighted.clear()
	if area_marker != null:
		area_marker.visible = false
	if reset_selection:
		ground_selected = false
		selected_ground = Vector3.ZERO
	area_preview_changed.emit("", false)

func _process_ground_preview() -> void:
	_clear()
	_highlight(null, false)
	_set_hover(null)
	var point := selected_ground
	if not ground_selected:
		var hit := _ground_hit()
		if hit.is_empty():
			_clear_area_preview()
			area_preview_changed.emit("Point at navigable ground. FRIENDLY FIRE ON.", false)
			return
		point = hit.position
	show_ground_preview(point)

func show_ground_preview(point: Vector3) -> void:
	_clear_area_preview()
	var ability := _ground_ability()
	if ability == null or not _can_command():
		return
	var actor := controller.scheduler.active_unit()
	var preview := controller.evaluate_ground_ability(actor, point, ability.stable_id)
	if not is_equal_approx(area_ring.outer_radius, ability.area_radius):
		area_ring.inner_radius = maxf(0.01, ability.area_radius - 0.05)
		area_ring.outer_radius = ability.area_radius
	area_marker.position = point + Vector3.UP * 0.06
	area_label.position = Vector3(0, 0.25, 0)
	area_marker.visible = point.is_finite()
	area_material.albedo_color = Color(1, 0.65, 0.15) if preview.valid() else Color.ORANGE_RED
	area_label.text = "LOCKED" if ground_selected else "SELECT"
	if not preview.valid():
		area_label.text = "INVALID"
	var names: PackedStringArray = []
	if preview.valid():
		for hit in preview.hits:
			var friendly := hit.unit.faction == actor.faction
			hit.unit.set_area_highlight(true, friendly, ability.magnitude)
			area_highlighted.append(hit.unit)
			names.append("%s −%d%s" % [hit.unit.definition.display_name, hit.health_lost(), " (ALLY)" if friendly else ""])
	var message := "%s · %.2f/%.2f m cast · %.2f m radius · %d damage\n%s\n! FRIENDLY FIRE ON: includes allies and caster." % [ability.display_name, preview.distance, ability.maximum_range, ability.area_radius, ability.magnitude, "Hits: " + (", ".join(names) if not names.is_empty() else "none") if preview.valid() else preview.error]
	message += "\n" + ("POINT LOCKED: click ground again to CONFIRM. Esc cancels." if ground_selected else "Click ground to SELECT a point. Esc cancels.")
	area_preview_changed.emit(message, preview.valid())

func _ground_click(screen_position: Vector2 = Vector2.INF) -> void:
	var ability := _ground_ability()
	var hit := _ground_hit(screen_position)
	if ability == null or hit.is_empty():
		return
	var actor := controller.scheduler.active_unit()
	if ground_selected:
		# Second world click confirms the locked point, never the cursor's new point.
		var point := selected_ground
		var command := UseAbilityCommand.on_ground(actor.stable_id, ability.stable_id, point)
		if not controller.submit_player_command(command):
			_clear_area_preview(true)
		return
	var preview := controller.evaluate_ground_ability(actor, hit.position, ability.stable_id)
	if not preview.valid():
		controller.feedback_changed.emit(preview.error)
		show_ground_preview(hit.position)
		return
	ground_selected = true
	selected_ground = hit.position
	show_ground_preview(selected_ground)



