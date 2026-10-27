class_name EnemyTacticalProfile
extends Resource
## Read-only reusable policy. One utility point is roughly a tenth of one HP.
enum Role { MELEE, RANGED, SUPPORT, SPELLCASTER }
@export var role: Role = Role.MELEE
@export var damage_weight: float = 10.0
@export var defeat_bonus: float = 45.0
@export var healing_weight: float = 6.0
@export var critical_healing_bonus: float = 24.0
@export var danger_healing_bonus: float = 36.0
@export var minimum_healing: int = 3
@export var critical_health_ratio: float = .5
@export var status_weight: float = 25.0
@export var multi_target_bonus: float = 6.0
@export var cooldown_weight: float = 1.25
@export var movement_cost_weight: float = .35
@export var exposure_weight: float = .15
@export var distance_weight: float = .75
@export var crowding_weight: float = 1.5
@export var adjacency_penalty: float = 6.0
@export var preferred_distance: float = .8
@export var minimum_reposition_gain: float = .75
@export_range(8,40) var max_candidates: int = 24
@export_range(12,80) var max_raw_candidates: int = 48
@export_range(16,96) var max_path_queries: int = 48
@export_range(64,1600) var max_action_queries: int = 768
@export_range(1,4) var positions_per_frame: int = 2
@export_range(4,12) var ring_samples: int = 8

func damage_components(amount: int, health: int) -> Dictionary:
	return {"damage":float(mini(amount,health))*damage_weight,"defeat":defeat_bonus if amount>=health and health>0 else 0.0}

func healing_components(amount: int, health: int, maximum: int, threatened_damage: int) -> Dictionary:
	var effective := mini(amount,maximum-health)
	if effective<minimum_healing: return {}
	return {"healing":float(effective)*healing_weight,"critical_heal":critical_healing_bonus if float(health)/maxi(1,maximum)<=critical_health_ratio else 0.0,"danger_heal":danger_healing_bonus if threatened_damage>=health else 0.0}

func status_value(future_turns: int, duration: int=2) -> float:
	return status_weight*clampf(float(duration-future_turns)/maxi(1,duration),0,1)
