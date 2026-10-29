class_name HeroCatalog
extends RefCounted

const PATHS: PackedStringArray = ["res://definitions/hero.tres", "res://definitions/scout.tres", "res://definitions/mage.tres", "res://definitions/cleric.tres"]

static func definitions() -> Array[UnitDefinition]:
	var result: Array[UnitDefinition] = []
	for path in PATHS:
		result.append(load(path) as UnitDefinition)
	return result

static func find(id: String) -> UnitDefinition:
	# Resolve only the requested blueprint. Loading all seven graphs on every
	# validation/preview lookup repeatedly reparses unused, weakly cached assets.
	const BLUEPRINTS := {"knight":"hero","ranger":"scout","mage":"mage","cleric":"cleric","recruit":"recruit","aegisbearer":"aegisbearer","chainbinder":"chainbinder"}
	if not BLUEPRINTS.has(id): return null
	return load("res://definitions/%s.tres" % BLUEPRINTS[id]) as UnitDefinition

static func all_definitions() -> Array[UnitDefinition]:
	var result := definitions()
	for path in ["res://definitions/recruit.tres", "res://definitions/aegisbearer.tres", "res://definitions/chainbinder.tres"]:
		result.append(load(path) as UnitDefinition)
	return result
