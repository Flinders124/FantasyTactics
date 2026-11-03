class_name CampaignDefinition
extends Resource
## Reusable tuning only; all run data lives in CampaignState.
@export var version: int = 1
@export var display_name: String = "The Lantern Watch"
@export var victories_required: int = 5
@export var offers_per_board: int = 3
@export var starting_supplies: int = 30
@export var threat_start: int = 2
@export var threat_maximum: int = 10
@export var victory_threat: int = -1
@export var failure_threat: int = 2
@export var ignored_threat: int = 1
@export var maximum_ignored_threat: int = 2
@export var enemy_count_caps: PackedInt32Array = []
@export var mission_supplies: int = 22
@export var recovery_supplies: int = 14
@export var failure_supplies: int = 4
@export var participation_xp: int = 10
@export var success_xp: int = 15
@export var xp_thresholds: PackedInt32Array = [0,20,50,90]
@export var severe_duration: int = 3
@export var strain_duration: int = 2
@export var injury_health: int = -3
@export var injury_movement: float = -0.5
@export var medical_cost: int = 12
@export var final_enemy_multiplier: float = 1.15

@export var upgrades: Array[Resource] = []
@export var items: Array[Resource] = []
