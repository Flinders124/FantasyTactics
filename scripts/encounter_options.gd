class_name EncounterOptions
extends RefCounted
const PRESET_IDS: PackedStringArray=["open_courtyard","ruined_lanes","central_plaza","narrow_approach","split_courtyard"]
static func presets() -> Array[BattlefieldSettings]:
	var result: Array[BattlefieldSettings]=[]
	for id in PRESET_IDS: result.append(load("res://definitions/presets/"+id+".tres") as BattlefieldSettings)
	return result
static func objectives() -> Array[ObjectiveDefinition]:
	return [load("res://definitions/objectives/elimination.tres") as ObjectiveDefinition,load("res://definitions/objectives/hold_ground.tres") as ObjectiveDefinition,load("res://definitions/objectives/extraction.tres") as ObjectiveDefinition]

static func difficulties() -> Array[DifficultyDefinition]:
	return [load("res://definitions/difficulties/easy.tres") as DifficultyDefinition,load("res://definitions/difficulties/standard.tres") as DifficultyDefinition,load("res://definitions/difficulties/hard.tres") as DifficultyDefinition]
