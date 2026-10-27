class_name UnitDefinition
extends Resource

@export var selection_id: String = ""
@export var visual_id: String = ""
@export var role: String = ""
@export var display_name: String = "Unit"
@export_range(1, 999) var maximum_health: int = 10
@export var initiative: int = 10
@export_range(0.0, 100.0) var movement_allowance: float = 6.0
@export var basic_attack: AttackDefinition
@export var abilities: Array[AbilityDefinition] = []
@export var tactical_profile: EnemyTacticalProfile

@export var enemy_id: String = ""
@export var faction_id: String = ""
@export var role_icon: String = ""
@export var is_elite: bool = false
@export var encounter_cost: int = 1
@export var introduction_stage: int = 0
@export_multiline var strengths: String = ""
@export_multiline var weaknesses: String = ""
