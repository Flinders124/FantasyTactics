class_name CampaignStats
extends RefCounted
## Flat additions, then a single clamp. Never alters the source Resource graph.
static func add(total: Dictionary,values: Dictionary) -> void:
	for key: String in values: total[key]=float(total.get(key,0))+float(values[key])
static func derive(base: UnitDefinition,modifiers: Dictionary) -> UnitDefinition:
	var result := base.duplicate(true) as UnitDefinition
	# External resources inside arrays are not reliably detached by UnitDefinition.duplicate.
	result.basic_attack=base.basic_attack.duplicate(true) as AttackDefinition
	result.abilities=[]
	for ability in base.abilities: result.abilities.append(ability.duplicate(true) as AbilityDefinition)
	result.maximum_health=clampi(roundi(base.maximum_health+float(modifiers.get("health",0))),1,99)
	result.movement_allowance=clampf(base.movement_allowance+float(modifiers.get("movement",0)),1.0,9.0)
	var offense: float=float(modifiers.get("offense",0))
	result.basic_attack.damage=clampi(roundi(base.basic_attack.damage+offense+float(modifiers.get("basic_damage",0))),1,20)
	result.basic_attack.maximum_range=clampf(base.basic_attack.maximum_range+float(modifiers.get("basic_range",0)),result.basic_attack.minimum_range+.1,12.0)
	for index in range(result.abilities.size()):
		var ability := result.abilities[index]
		var original := base.abilities[index]
		ability.magnitude=clampi(roundi(original.magnitude+float(modifiers.get("healing",0) if ability.effect==AbilityDefinition.Effect.HEAL else offense)),1,20)
		if ability.effect==AbilityDefinition.Effect.DAMAGE: ability.damage=ability.magnitude
		ability.cooldown_turns=clampi(original.cooldown_turns+roundi(float(modifiers.get("cooldown:"+ability.stable_id,0))),0,5)
		ability.description="%s: %d fixed %s. Cooldown blocks the next %d owner turns.%s%s"%[ability.display_name,ability.magnitude,"healing" if ability.effect==AbilityDefinition.Effect.HEAL else "damage",ability.cooldown_turns," Applies "+ability.applied_status.display_name if ability.applied_status!=null else ""," Area affects allies and caster." if ability.targeting==AbilityDefinition.Target.GROUND else ""]
	return result
