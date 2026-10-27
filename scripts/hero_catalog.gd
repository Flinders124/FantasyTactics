class_name HeroCatalog
extends RefCounted

const PATHS: PackedStringArray = ["res://definitions/hero.tres", "res://definitions/scout.tres", "res://definitions/mage.tres", "res://definitions/cleric.tres"]

static func definitions() -> Array[UnitDefinition]:
	var result: Array[UnitDefinition] = []
	for path in PATHS:
		result.append(load(path) as UnitDefinition)
	return result

static func find(id: String) -> UnitDefinition:
	for definition in definitions():
		if definition.selection_id == id:
			return definition
	return null
