class_name StatusEffectDefinition
extends Resource

@export var stable_id: String = "slowed"
@export var display_name: String = "Slowed"
@export_multiline var description: String = "Movement allocation reduced by 50% for two future turns."
@export_range(1, 10) var affected_turns: int = 2
@export_range(0.0, 1.0) var movement_multiplier: float = 0.5
