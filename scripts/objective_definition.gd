class_name ObjectiveDefinition
extends Resource

enum Kind { ELIMINATION, HOLD_GROUND, EXTRACTION }
@export var stable_id: String = "elimination"
@export var display_name: String = "Elimination"
@export_multiline var description: String = "Defeat all enemies. Simultaneous elimination is a draw."
@export var kind: Kind = Kind.ELIMINATION
@export_range(1.5, 5.0) var radius: float = 2.8
@export_range(1, 10) var required_rounds: int = 3
@export_range(6.0, 25.0) var minimum_exit_travel: float = 12.0
@export var positioning_weight: float = 5.0

