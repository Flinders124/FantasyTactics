class_name FactionCatalog
extends RefCounted

const FACTION_IDS: PackedStringArray = ["ashfang", "hollow", "verdant"]
const CHOICE_STREAM: int = 0x46414354
const ROSTER_STREAM: int = 0x46414352

static func ids() -> PackedStringArray:
	return FACTION_IDS.duplicate()

static func find(faction_id: String) -> FactionDefinition:
	if faction_id not in FACTION_IDS: return null
	return load("res://definitions/factions/" + faction_id + ".tres") as FactionDefinition

static func list() -> Array[FactionDefinition]:
	var result: Array[FactionDefinition] = []
	for faction_id in FACTION_IDS: result.append(find(faction_id))
	return result

static func descriptions() -> Dictionary:
	var result := {}
	for faction in list(): result[faction.stable_id] = faction.description
	return result

static func choose(faction_id: String, seed_value: int) -> String:
	if faction_id in FACTION_IDS: return faction_id
	if faction_id != "random": return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value ^ CHOICE_STREAM) & 0x7fffffffffffffff
	return FACTION_IDS[rng.randi_range(0, FACTION_IDS.size() - 1)]

static func roster(faction_id: String, difficulty_id: String, stage: int, elite: bool, seed_value: int) -> PackedStringArray:
	var faction := find(choose(faction_id, seed_value))
	if faction == null: return []
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value ^ ROSTER_STREAM) & 0x7fffffffffffffff
	var result: PackedStringArray = []
	var remaining := maxi(4,faction.budget(difficulty_id,stage)) if elite else faction.budget(difficulty_id,stage)
	if elite:
		var leader := EnemyCatalog.find(faction.elite_id)
		if leader == null: return []
		result.append(faction.elite_id)
		remaining = maxi(0, remaining - leader.encounter_cost)
		for support_id in faction.elite_support:
			if result.size() >= 3: break
			var support := EnemyCatalog.find(support_id)
			if support != null and support.encounter_cost <= remaining:
				result.append(support_id)
				remaining -= support.encounter_cost
		return result
	var template := faction.opening_template if rng.randi_range(0, 1) == 0 else faction.reinforcement_template
	for enemy_id in template:
		if result.size() >= 4: break
		var unit := EnemyCatalog.find(enemy_id)
		if unit == null or unit.is_elite or unit.encounter_cost > remaining or unit.introduction_stage>maxi(stage,faction.introduction_stage): continue
		result.append(enemy_id)
		remaining -= unit.encounter_cost
	return result

static func valid_roster(ids: PackedStringArray, faction_id: String, difficulty_id: String, stage: int, elite: bool) -> bool:
	var faction:=find(faction_id)
	if faction==null or ids.size()<2 or ids.size()>(3 if elite else 4): return false
	var cost: int=0
	var leaders: int=0
	var healers: int=0
	for id in ids:
		var unit:=EnemyCatalog.find(id)
		if unit==null or unit.faction_id!=faction_id: return false
		cost+=unit.encounter_cost
		if unit.is_elite: leaders+=1
		if unit.abilities.any(func(ability: AbilityDefinition) -> bool: return ability.effect==AbilityDefinition.Effect.HEAL): healers+=1
	return leaders==(1 if elite else 0) and healers<=1 and cost<=(maxi(4,faction.budget(difficulty_id,stage)) if elite else faction.budget(difficulty_id,stage))
