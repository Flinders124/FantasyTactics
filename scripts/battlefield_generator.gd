class_name BattlefieldGenerator
extends Node

var total_placement_tries: int = 0
var validation_error: String = ""

func make_layout(seed_value: int, settings: BattlefieldSettings, attempt: int, fallback: bool = false, objective: ObjectiveDefinition = null, enemy_count: int = 2) -> BattlefieldLayout:
	if enemy_count < 2 or enemy_count > 4: return null
	if fallback:
		var preset_id := settings.preset_id if settings!=null else "open_courtyard"
		settings=BattlefieldSettings.new()
		settings.preset_id=preset_id
	if settings == null or not settings.valid():
		if not fallback:
			return null
		var requested_preset := settings.preset_id if settings!=null else "open_courtyard"
		settings = BattlefieldSettings.new()
		settings.preset_id=requested_preset
	if fallback and objective!=null and objective.kind==ObjectiveDefinition.Kind.EXTRACTION:
		settings=settings.duplicate(true) as BattlefieldSettings
		settings.arena_size.x=maxf(settings.arena_size.x,(objective.minimum_exit_travel+settings.boundary_margin+settings.spawn_zone_size.x*.5+objective.radius)/.74+1.0)
	var layout := BattlefieldLayout.new()
	layout.preset_id=settings.preset_id
	layout.generator_version=settings.generator_version
	if objective!=null:
		layout.objective_id=objective.stable_id
		if objective.kind!=ObjectiveDefinition.Kind.ELIMINATION:
			layout.objective_radius=objective.radius
			layout.objective_center=Vector3(settings.arena_size.x*.24,0,0) if objective.kind==ObjectiveDefinition.Kind.EXTRACTION else Vector3.ZERO
	layout.original_seed = seed_value
	layout.attempt = attempt
	layout.used_fallback = fallback
	layout.arena_size = settings.arena_size
	layout.hero_zone = Rect2(Vector2(-settings.arena_size.x * 0.5 + settings.boundary_margin, -settings.spawn_zone_size.y * 0.5), settings.spawn_zone_size)
	layout.enemy_zone = Rect2(Vector2(settings.arena_size.x * 0.5 - settings.boundary_margin - settings.spawn_zone_size.x, -settings.spawn_zone_size.y * 0.5), settings.spawn_zone_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + (attempt - 1) * 104729 + (0 if settings.preset_id=="open_courtyard" else hash(settings.preset_id)&0x7fffffff)
	for zone in [layout.hero_zone, layout.enemy_zone]:
		for side in [-1.0, 1.0]:
			var center: Vector2 = zone.get_center()
			var jitter := Vector2.ZERO if fallback else Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2))
			layout.spawns.append(Vector3(center.x + jitter.x, 0, center.y + side * zone.size.y * 0.3 + jitter.y))
	# Keep the original four positions and RNG stream intact for existing seeds.
	for extra in range(enemy_count - 2):
		var center := layout.enemy_zone.get_center()
		layout.spawns.append(Vector3(center.x + (-1.0 if extra == 0 else 1.0) * layout.enemy_zone.size.x * .28, 0, center.y))
	for index in range(4, layout.spawns.size()):
		for other in range(index):
			var separation := settings.opposing_separation if (index < 2) != (other < 2) else settings.spawn_spacing
			if layout.spawns[index].distance_to(layout.spawns[other]) < separation: return null
	if settings.preset_id!="open_courtyard":
		# Authored route topology with seeded, bounded perturbations. Horizontal
		# centre and both perimeter routes interconnect; central approaches stay open.
		var lane := settings.preset_id=="ruined_lanes"
		for x in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				var jitter := 0.0 if fallback else rng.randf_range(-.3,.3)
				var size := Vector3(1.25,2.2,4.1) if lane else Vector3(1.7,2.3,1.7)
				var center := Vector3(x*settings.arena_size.x*.20,size.y*.5,z*(settings.arena_size.y*.30+jitter))
				layout.obstacle_centers.append(center)
				layout.obstacle_sizes.append(size)
		return layout if _structural_clearance(layout,settings) else null
	if fallback: return layout # Open Courtyard's canonical fallback.

	var arena := Rect2(-settings.arena_size * 0.5 + Vector2.ONE * settings.boundary_margin, settings.arena_size - Vector2.ONE * settings.boundary_margin * 2)
	var occupied: Array[Rect2] = []
	for obstacle in range(settings.obstacle_count):
		var placed: bool = false
		for trial in range(clampi(settings.placement_attempts, 1, 200)):
			total_placement_tries += 1
			layout.placement_tries += 1
			var size := Vector2(rng.randf_range(settings.obstacle_min_size.x, settings.obstacle_max_size.x), rng.randf_range(settings.obstacle_min_size.y, settings.obstacle_max_size.y))
			var center := Vector2(rng.randf_range(arena.position.x + size.x * 0.5, arena.end.x - size.x * 0.5), rng.randf_range(arena.position.y + size.y * 0.5, arena.end.y - size.y * 0.5))
			var rect := Rect2(center - size * 0.5, size)
			if layout.objective_radius>0 and rect.grow(settings.clearance).intersects(Rect2(Vector2(layout.objective_center.x,layout.objective_center.z)-Vector2.ONE*layout.objective_radius,Vector2.ONE*layout.objective_radius*2),true): continue
			if not arena.encloses(rect) or rect.intersects(layout.hero_zone.grow(settings.clearance), true) or rect.intersects(layout.enemy_zone.grow(settings.clearance), true):
				continue
			if occupied.any(func(other: Rect2) -> bool: return rect.grow(settings.clearance * 0.5).intersects(other.grow(settings.clearance * 0.5), true)):
				continue
			var height := rng.randf_range(settings.obstacle_height.x, settings.obstacle_height.y)
			layout.obstacle_centers.append(Vector3(center.x, height * 0.5, center.y))
			layout.obstacle_sizes.append(Vector3(size.x, height, size.y))
			occupied.append(rect)
			placed = true
			break
		if not placed:
			return null
	return layout

func build(region: NavigationRegion3D, layout: BattlefieldLayout, settings: BattlefieldSettings = null) -> void:
	for child in region.get_children():
		child.free()
	var width := layout.arena_size.x
	var depth := layout.arena_size.y
	CourtyardKit.ground(region,layout.arena_size)
	CourtyardKit.boundary(region, "NorthBoundary", Vector3(0, 0.4, -depth * 0.5 - 0.25), Vector3(width + 1, 0.8, 0.5))
	CourtyardKit.boundary(region, "SouthBoundary", Vector3(0, 0.4, depth * 0.5 + 0.25), Vector3(width + 1, 0.8, 0.5))
	CourtyardKit.boundary(region, "WestBoundary", Vector3(-width * 0.5 - 0.25, 0.4, 0), Vector3(0.5, 0.8, depth))
	CourtyardKit.boundary(region, "EastBoundary", Vector3(width * 0.5 + 0.25, 0.4, 0), Vector3(0.5, 0.8, depth))
	for index in range(layout.obstacle_centers.size()):
		CourtyardKit.blocker(region,"Obstacle%d" % index,layout.obstacle_centers[index],layout.obstacle_sizes[index],CourtyardKit.obstacle_kind(layout,index))
	var old := region.get_parent().get_node_or_null("CourtyardDressing")
	if old!=null: old.free()
	var dressing := CourtyardDressing.new()
	dressing.name="CourtyardDressing"
	region.get_parent().add_child(dressing)
	dressing.build(layout,settings if settings!=null else BattlefieldSettings.new())

static func add_box(parent: Node3D, box_name: String, center: Vector3, size: Vector3, color: Color, ground: bool = false) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 11 if ground else 9
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	parent.add_child(body)

func validate_spawns(layout: BattlefieldLayout, navigation: NavigationService, world: World3D, settings: BattlefieldSettings, enemy_count: int = 2) -> bool:
	validation_error = ""
	if not navigation.ready_for_queries or enemy_count < 2 or enemy_count > 4 or layout.spawns.size() != 2 + enemy_count:
		validation_error = "Navigation is unavailable"
		return false
	if layout.used_fallback:
		var requested_preset := settings.preset_id if settings!=null else "open_courtyard"
		settings = BattlefieldSettings.new()
		settings.preset_id=requested_preset
	for index in range(layout.spawns.size()):
		var point := layout.spawns[index]
		var zone := layout.hero_zone if index < 2 else layout.enemy_zone
		if not zone.has_point(Vector2(point.x, point.z)) or not navigation.query_path(point, point).valid():
			validation_error = "Spawn is outside walkable ground"
			return false
		var shape := CapsuleShape3D.new()
		shape.radius = BattlefieldSettings.NAV_RADIUS
		shape.height = 1.58
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.81)
		query.collision_mask = 1
		if not world.direct_space_state.intersect_shape(query, 1).is_empty():
			validation_error = "Spawn lacks body clearance"
			return false
		for other in range(index):
			var separation := settings.opposing_separation if (index < 2) != (other < 2) else settings.spawn_spacing
			if point.distance_to(layout.spawns[other]) < separation or not navigation.query_path(point, layout.spawns[other]).valid():
				validation_error = "Spawns overlap or lack a connected route"
				return false
	return true

func validate_objective(layout: BattlefieldLayout, navigation: NavigationService, objective: ObjectiveDefinition) -> bool:
	if objective==null or objective.kind==ObjectiveDefinition.Kind.ELIMINATION: return true
	var center := layout.objective_center
	if not navigation.query_path(center,center).valid():
		validation_error="Objective zone is not navigable"
		return false
	for edge in range(8):
		var angle := TAU*float(edge)/8
		var rim := center+Vector3(cos(angle),0,sin(angle))*objective.radius
		if not navigation.query_path(rim,rim).valid():
			validation_error="Objective perimeter lacks walkable clearance"
			return false
	# Every spawn connects to the zone, and the whole reserved disc is clear.
	for index in range(layout.spawns.size()):
		var route := navigation.query_path(layout.spawns[index],center)
		if not route.valid():
			validation_error="Objective lacks a spawn connection"
			return false
		if objective.kind==ObjectiveDefinition.Kind.EXTRACTION and index<2 and route.distance-objective.radius<objective.minimum_exit_travel-.000001:
			validation_error="Exit travel is too short"
			return false
	for index in range(layout.obstacle_sizes.size()):
		var size := layout.obstacle_sizes[index]
		var pos := layout.obstacle_centers[index]
		var rect := Rect2(Vector2(pos.x-size.x*.5,pos.z-size.z*.5),Vector2(size.x,size.z)).grow(BattlefieldSettings.NAV_RADIUS)
		var nearest := Vector2(center.x,center.z).clamp(rect.position,rect.end)
		if nearest.distance_to(Vector2(center.x,center.z))<=objective.radius:
			validation_error="Objective lacks clearance"
			return false
	if objective.kind==ObjectiveDefinition.Kind.HOLD_GROUND:
		# Two opposite, separately navigable gates connect into the reserved zone.
		for side in [-1.0,1.0]:
			var gate: Vector3 = center+Vector3.RIGHT*side*(objective.radius+1.2)
			if not navigation.query_path(gate,center).valid():
				validation_error="Hold zone requires two approaches"
				return false
	return true


func _structural_clearance(layout: BattlefieldLayout,settings: BattlefieldSettings) -> bool:
	var arena := Rect2(-layout.arena_size*.5+Vector2.ONE*settings.boundary_margin,layout.arena_size-Vector2.ONE*settings.boundary_margin*2)
	var previous: Array[Rect2]=[]
	for index in range(layout.obstacle_sizes.size()):
		var size := layout.obstacle_sizes[index]
		var center := layout.obstacle_centers[index]
		var rect := Rect2(Vector2(center.x-size.x*.5,center.z-size.z*.5),Vector2(size.x,size.z))
		if not arena.encloses(rect) or rect.intersects(layout.hero_zone.grow(settings.clearance),true) or rect.intersects(layout.enemy_zone.grow(settings.clearance),true): return false
		for other in previous:
			if rect.grow(settings.clearance*.5).intersects(other.grow(settings.clearance*.5),true): return false
		previous.append(rect)
	return true



