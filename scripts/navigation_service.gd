class_name NavigationService
extends Node

signal synchronization_finished(success: bool)
var synchronization_complete: bool = false

class Route extends RefCounted:
	var path: PackedVector3Array = PackedVector3Array()
	var distance: float = 0.0
	var error: String = ""
	func valid() -> bool:
		return error.is_empty()

@export var endpoint_tolerance: float = 0.08
var map: RID
var ready_for_queries: bool = false
var _sync_epoch: int = 0

func cancel_synchronization() -> void:
	_sync_epoch += 1
	ready_for_queries = false

func synchronize(region: NavigationRegion3D) -> void:
	_sync_epoch += 1
	var ticket := _sync_epoch
	ready_for_queries = false
	synchronization_complete = false
	# The synchronous bake still defers assignment of its result.
	await get_tree().process_frame
	if ticket != _sync_epoch or not is_inside_tree():
		return
	await get_tree().process_frame
	if ticket != _sync_epoch or not is_inside_tree():
		return
	await get_tree().physics_frame
	if ticket != _sync_epoch or not is_inside_tree():
		return
	await get_tree().physics_frame
	if ticket != _sync_epoch or not is_inside_tree():
		return
	map = region.get_navigation_map()
	# Verify geometry is queryable, not merely that the initially empty map has an iteration.
	for attempt in range(120):
		NavigationServer3D.map_force_update(map)
		if _region_is_queryable(region):
			ready_for_queries = true
			synchronization_complete = true
			synchronization_finished.emit(true)
			return
		await get_tree().process_frame
		if ticket != _sync_epoch or not is_inside_tree():
			return
		await get_tree().physics_frame
		if ticket != _sync_epoch or not is_inside_tree():
			return
	push_error("Navigation synchronization timed out (polygons=%d, baking=%s, map iteration=%d, region iteration=%d)" % [region.navigation_mesh.get_polygon_count(), region.is_baking(), NavigationServer3D.map_get_iteration_id(map), NavigationServer3D.region_get_iteration_id(region.get_rid())])
	synchronization_complete = true
	synchronization_finished.emit(false)

func _region_is_queryable(region: NavigationRegion3D) -> bool:
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var mesh := region.navigation_mesh
	# A boundary vertex is an ambiguous closest-point probe (especially directly
	# after replacing a region). Probe interiors of a bounded set of polygons.
	for index in range(mini(8, mesh.get_polygon_count())):
		var polygon := mesh.get_polygon(index)
		if polygon.is_empty():
			continue
		var center := Vector3.ZERO
		for vertex in polygon:
			center += mesh.vertices[vertex]
		center = region.global_transform * (center / polygon.size())
		if NavigationServer3D.map_get_closest_point_owner(map, center) == region.get_rid():
			return true
	return false


static func point_at_distance(path: PackedVector3Array, distance: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	var remaining := maxf(0.0, distance)
	for index in range(1, path.size()):
		var length := path[index - 1].distance_to(path[index])
		if remaining <= length and length > 0.000001:
			return path[index - 1].lerp(path[index], remaining / length)
		remaining -= length
	return path[-1]

static func path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total

static func planar(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)

func query_path(origin: Vector3, destination: Vector3) -> Route:
	var route := Route.new()
	if not ready_for_queries:
		route.error = "Navigation is synchronizing"
		return route
	if not origin.is_finite() or not destination.is_finite():
		route.error = "Invalid destination"
		return route
	var start := NavigationServer3D.map_get_closest_point(map, origin)
	var target := NavigationServer3D.map_get_closest_point(map, destination)
	if planar(start).distance_to(planar(origin)) > endpoint_tolerance or planar(target).distance_to(planar(destination)) > endpoint_tolerance or absf(target.y - destination.y) > 0.65:
		route.error = "Destination is outside the walkable ground"
		return route
	var raw := NavigationServer3D.map_get_path(map, start, target, true)
	if raw.is_empty() or planar(raw[-1]).distance_to(planar(destination)) > endpoint_tolerance:
		route.error = "Destination is unreachable (partial path rejected)"
		return route
	route.path.append(planar(origin))
	for point in raw:
		var flat := planar(point)
		if flat.distance_to(route.path[-1]) > 0.0001:
			route.path.append(flat)
	# Keep the exact requested endpoint; do not silently accept a nearby partial route.
	if route.path[-1].distance_to(planar(destination)) > 0.0001:
		route.path.append(planar(destination))
	route.distance = path_length(route.path)
	return route
