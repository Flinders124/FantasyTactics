class_name AreaTargetingService
extends RefCounted

const BOUNDARY_EPSILON: float = 0.000001
const GROUND_TOLERANCE: float = 0.02
const GROUND_MASK: int = 2

class Hit extends RefCounted:
	var unit: CombatUnit
	var health_before: int
	var health_after: int
	func health_lost() -> int:
		return health_before - health_after

class Result extends RefCounted:
	var error: String = ""
	var distance: float = 0.0
	var point: Vector3 = Vector3.ZERO
	var hits: Array[Hit] = []
	func valid() -> bool:
		return error.is_empty()
	func safe_for(actor: CombatUnit) -> bool:
		return valid() and hits.size()>=2 and hits.all(func(hit: Hit) -> bool: return hit.unit.faction!=actor.faction)

func query(actor: CombatUnit, ability: AbilityDefinition, point: Vector3, roster: Array[CombatUnit], navigation: NavigationService, caster_position: Vector3 = Vector3.INF, blast_only: bool = false) -> Result:
	var result := Result.new()
	result.point = point
	if navigation == null or not navigation.ready_for_queries:
		result.error = "Navigation is synchronizing"
	elif not point.is_finite() or actor == null or not actor.is_alive() or not actor.attack_markers_valid():
		result.error = "Invalid ground cast or caster markers"
	elif ability == null or ability.targeting != AbilityDefinition.Target.GROUND or ability.effect != AbilityDefinition.Effect.DAMAGE or ability.applied_status != null or ability.magnitude <= 0 or not is_finite(ability.area_radius) or ability.area_radius <= 0.0 or not is_finite(ability.blast_origin_offset) or ability.blast_origin_offset <= 0.0 or ability.area_obstruction_mask == 0 or ability.affected_factions < 1 or ability.affected_factions > 7 or not is_finite(ability.maximum_range) or not is_finite(ability.minimum_range) or ability.minimum_range < 0.0 or ability.maximum_range < ability.minimum_range:
		result.error = "Invalid area ability configuration"
	if not result.valid():
		return result
	var space := actor.get_world_3d().direct_space_state
	var closest := NavigationServer3D.map_get_closest_point(navigation.map, point)
	var ground_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.7, point - Vector3.UP * 0.7, GROUND_MASK)
	var ground := space.intersect_ray(ground_ray)
	if NavigationService.planar(closest - point).length() > navigation.endpoint_tolerance or absf(closest.y - point.y) > 0.65 or ground.is_empty() or point.distance_to(ground.position) > GROUND_TOLERANCE:
		result.error = "Select navigable ground"
		return result
	var caster_at := caster_position if caster_position.is_finite() else actor.global_position
	var origin := actor.attack_origin_at(caster_at)
	result.distance = origin.distance_to(point)
	if not blast_only and result.distance < ability.minimum_range - BOUNDARY_EPSILON:
		result.error = "Too close"
	elif not blast_only and result.distance > ability.maximum_range + BOUNDARY_EPSILON:
		result.error = "Out of cast range"
	var blast_origin := point + Vector3.UP * ability.blast_origin_offset
	# Layer 4 contains only static arena geometry. Also exclude roster RIDs so
	# configurable masks cannot accidentally let bodies shield the blast.
	var excluded: Array[RID] = []
	for unit in roster:
		excluded.append(unit.get_rid())
	if not blast_only and result.valid() and not _clear_line(space, origin, blast_origin, ability.area_obstruction_mask, excluded):
		result.error = "Cast line blocked"
	if not result.valid():
		return result
	var candidates: Array[CombatUnit] = []
	var seen: Dictionary = {}
	for unit in roster:
		if (not unit.is_alive() and not unit.is_downed()) or seen.has(unit.stable_id):
			continue
		seen[unit.stable_id] = true
		candidates.append(unit)
	candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool: return a.stable_id < b.stable_id)
	for unit in candidates:
		var flag: int = 4 if unit == actor else (2 if unit.faction == actor.faction else 1)
		if (ability.affected_factions & flag) == 0 or not unit.area_markers_valid():
			continue
		var offset := caster_at-actor.global_position if unit==actor else Vector3.ZERO
		if point.distance_to(unit.ground_anchor()+offset) > ability.area_radius + BOUNDARY_EPSILON:
			continue
		if not _clear_line(space, blast_origin, unit.target_point()+offset, ability.area_obstruction_mask, excluded):
			continue
		var hit := Hit.new()
		hit.unit = unit
		hit.health_before = unit.health
		hit.health_after = maxi(0, unit.health - maxi(0,ability.magnitude-unit.ward_remaining))
		result.hits.append(hit)
	return result

func _clear_line(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, excluded: Array[RID]) -> bool:
	if from.distance_squared_to(to) <= BOUNDARY_EPSILON * BOUNDARY_EPSILON:
		return true
	var ray := PhysicsRayQueryParameters3D.create(from, to, mask, excluded)
	ray.hit_from_inside = true
	return space.intersect_ray(ray).is_empty()
