class_name DifficultyDefinition
extends Resource
## Immutable tuning. Derived enemy definitions are local to one encounter.
@export var stable_id: String = "standard"
@export var display_name: String = "Standard"
@export_multiline var description: String = "Established balance: Raider and Sentinel, unchanged stats and tactical search."
@export var configuration_version: int = 1
@export_range(.5,1.5) var enemy_health_multiplier: float = 1.0
@export_range(.5,1.5) var enemy_damage_multiplier: float = 1.0
@export var elimination_roster: PackedStringArray = ["raider","sentinel"]
@export var hold_roster: PackedStringArray = ["raider","sentinel"]
@export var extraction_roster: PackedStringArray = ["raider","sentinel"]
@export var alternate_roster: PackedStringArray = []
# Zero preserves each equipped profile's established limits.
@export_range(0,40) var candidate_limit: int = 0
@export_range(0,80) var raw_candidate_limit: int = 0
@export_range(0,96) var path_query_limit: int = 0
@export_range(0,1600) var action_query_limit: int = 0
@export_range(0,12) var ring_samples: int = 0
const ROSTER_STREAM: int = 0x524f53544552

func valid() -> bool:
	if stable_id not in ["easy","standard","hard"] or configuration_version!=1: return false
	if not is_finite(enemy_health_multiplier) or enemy_health_multiplier<.5 or enemy_health_multiplier>1.5: return false
	if not is_finite(enemy_damage_multiplier) or enemy_damage_multiplier<.5 or enemy_damage_multiplier>1.5: return false
	for roster in [elimination_roster,hold_roster,extraction_roster]:
		if not valid_roster(roster): return false
	if not alternate_roster.is_empty() and not valid_roster(alternate_roster): return false
	return (candidate_limit==0 or candidate_limit>=8 and candidate_limit<=40) and (raw_candidate_limit==0 or raw_candidate_limit>=12 and raw_candidate_limit<=80) and (path_query_limit==0 or path_query_limit>=16 and path_query_limit<=96) and (action_query_limit==0 or action_query_limit>=64 and action_query_limit<=1600) and (ring_samples==0 or ring_samples>=4 and ring_samples<=12)

static func valid_roster(ids: PackedStringArray) -> bool:
	return ids.size()>=2 and ids.size()<=4 and Array(ids).all(func(id: String) -> bool: return EnemyCatalog.find(id)!=null)

func roster_for(objective_id: String, seed_value: int) -> PackedStringArray:
	var selected := elimination_roster
	if objective_id=="hold_ground": selected=hold_roster
	elif objective_id=="extraction": selected=extraction_roster
	var choices: Array[PackedStringArray]=[selected]
	if not alternate_roster.is_empty(): choices.append(alternate_roster)
	var rng := RandomNumberGenerator.new()
	rng.seed=(seed_value ^ ROSTER_STREAM)&0x7fffffffffffffff
	return choices[rng.randi_range(0,choices.size()-1)].duplicate()

func adjusted(base: UnitDefinition) -> UnitDefinition:
	var result := base.duplicate(true) as UnitDefinition
	result.maximum_health=maxi(1,int(floor(float(base.maximum_health)*enemy_health_multiplier+.5)))
	if base.basic_attack!=null:
		result.basic_attack=base.basic_attack.duplicate(true) as AttackDefinition
		result.basic_attack.damage=scaled_damage(base.basic_attack.damage)
	result.abilities=[]
	for original in base.abilities:
		var ability := original.duplicate(true) as AbilityDefinition
		if ability.effect==AbilityDefinition.Effect.DAMAGE:
			ability.magnitude=scaled_damage(original.magnitude)
			ability.damage=scaled_damage(original.damage)
			if ability.magnitude!=original.magnitude: ability.description="%s: %d fixed damage. %sCooldown blocks the next %d owner turns."%[ability.display_name,ability.magnitude,("Applies %s for %d turns. "%[ability.applied_status.display_name,ability.applied_status.affected_turns]) if ability.applied_status!=null else ("Area affects allies and caster. " if ability.targeting==AbilityDefinition.Target.GROUND else ""),ability.cooldown_turns]
		result.abilities.append(ability)
	# Duplicate even when two enemies share a base; never edit catalog profiles.
	if base.tactical_profile!=null: result.tactical_profile=base.tactical_profile.duplicate(true) as EnemyTacticalProfile
	elif candidate_limit>0: result.tactical_profile=EnemyTactics.profile_for_definition(base).duplicate(true) as EnemyTacticalProfile
	if result.tactical_profile!=null:
		for pair in [["max_candidates",candidate_limit],["max_raw_candidates",raw_candidate_limit],["max_path_queries",path_query_limit],["max_action_queries",action_query_limit],["ring_samples",ring_samples]]:
			if int(pair[1])>0: result.tactical_profile.set(pair[0],pair[1])
	return result

func scaled_damage(value: int) -> int:
	return maxi(1,int(floor(float(value)*enemy_damage_multiplier+.5)))

func roster_summary(ids: PackedStringArray) -> String:
	var lines: PackedStringArray=[]
	for id in ids:
		var base := EnemyCatalog.find(id)
		if base==null: return "Invalid enemy roster"
		lines.append("%s: %d HP / %d basic damage"%[base.display_name,maxi(1,int(floor(base.maximum_health*enemy_health_multiplier+.5))),scaled_damage(base.basic_attack.damage)])
	return "\n".join(lines)
