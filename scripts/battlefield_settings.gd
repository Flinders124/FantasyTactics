class_name BattlefieldSettings
extends Resource

@export var preset_id: String = "open_courtyard"
@export var display_name: String = "Open Courtyard"
@export var generator_version: int = 2
@export_range(0.0,2.0) var detail_density: float = 1.0


@export var arena_size: Vector2 = Vector2(28, 22)
@export_range(0, 30) var obstacle_count: int = 7
@export var obstacle_min_size: Vector2 = Vector2(1.25, 1.25)
@export var obstacle_max_size: Vector2 = Vector2(3, 4)
@export var obstacle_height: Vector2 = Vector2(1.5, 2.5)
@export_range(1.1, 4.0) var clearance: float = 1.5
@export_range(1.0, 4.0) var boundary_margin: float = 1.25
@export var spawn_zone_size: Vector2 = Vector2(4, 8)
@export_range(1.0, 4.0) var spawn_spacing: float = 2.0
@export_range(4.0, 20.0) var opposing_separation: float = 8.0
@export_range(1, 200) var placement_attempts: int = 40
@export_range(1, 8) var generation_attempts: int = 3
const NAV_RADIUS: float = 0.5
# Cosmetic settings are deliberately excluded from gameplay-layout validity.
@export var dressing_seed_offset: int = 0
@export_range(0.0,2.0) var vegetation_density: float = 1.0
@export_range(0.0,2.0) var rubble_density: float = 1.0

func valid() -> bool:
	return arena_size.is_finite() and arena_size.x >= 20 and arena_size.x <= 60 and arena_size.y >= 16 and arena_size.y <= 50 and obstacle_count >= 0 and obstacle_count <= 30 and obstacle_min_size.is_finite() and obstacle_max_size.is_finite() and obstacle_min_size.x > 0 and obstacle_min_size.y > 0 and obstacle_max_size.x >= obstacle_min_size.x and obstacle_max_size.y >= obstacle_min_size.y and obstacle_max_size.x < arena_size.x - 4 and obstacle_max_size.y < arena_size.y - 4 and obstacle_height.is_finite() and obstacle_height.x >= 0.5 and obstacle_height.y >= obstacle_height.x and is_finite(clearance) and clearance >= 1.1 and is_finite(boundary_margin) and boundary_margin >= 1.0 and boundary_margin <= 3.0 and spawn_zone_size.is_finite() and spawn_zone_size.x >= 3 and spawn_zone_size.x <= arena_size.x * 0.25 and spawn_zone_size.y >= 5 and spawn_zone_size.y <= arena_size.y - boundary_margin * 2 - 2 and is_finite(spawn_spacing) and spawn_spacing >= 1 and spawn_spacing <= spawn_zone_size.y * 0.5 and is_finite(opposing_separation) and opposing_separation >= 4 and arena_size.x - 2 * boundary_margin - spawn_zone_size.x - 1 >= opposing_separation
