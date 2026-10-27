class_name BattlefieldLayout
extends Resource

@export var preset_id: String = "open_courtyard"
@export var objective_id: String = "elimination"
@export var generator_version: int = 2
@export var objective_center: Vector3 = Vector3.ZERO
@export var objective_radius: float = 0.0
@export var original_seed: int = 0
@export var attempt: int = 1
@export var used_fallback: bool = false
@export var arena_size: Vector2
@export var hero_zone: Rect2
@export var enemy_zone: Rect2
@export var spawns: PackedVector3Array = []
@export var obstacle_centers: PackedVector3Array = []
@export var obstacle_sizes: PackedVector3Array = []
@export var placement_tries: int = 0

func signature() -> String:
	return str([preset_id, objective_id, generator_version, objective_center, objective_radius, original_seed, attempt, used_fallback, arena_size, hero_zone, enemy_zone, spawns, obstacle_centers, obstacle_sizes])

func geometry_signature() -> String:
	return str([preset_id, objective_id, generator_version, objective_center, objective_radius, arena_size, spawns, obstacle_centers, obstacle_sizes])
