class_name AttackDefinition
extends Resource

enum Type { MELEE, RANGED }
@export var attack_type: Type = Type.MELEE
@export var display_name: String = "Melee Strike"
@export_range(0.0, 100.0) var maximum_range: float = 1.5
@export_range(0.0, 100.0) var minimum_range: float = 0.0
@export_range(1, 999) var damage: int = 4
@export_flags_3d_physics var obstruction_mask: int = 1

# Load compatibility for existing .tres files and external melee callers.
@export_storage var melee_range: float:
	get:
		return maximum_range
	set(value):
		maximum_range = value

func type_label() -> String:
	return "Ranged" if attack_type == Type.RANGED else "Melee"

func range_label() -> String:
	return "%.2f–%.2f m" % [minimum_range, maximum_range]
