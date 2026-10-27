class_name EncounterOptions
extends RefCounted
static func presets() -> Array[BattlefieldSettings]:
	return [load("res://definitions/presets/open_courtyard.tres") as BattlefieldSettings,load("res://definitions/presets/ruined_lanes.tres") as BattlefieldSettings,load("res://definitions/presets/central_plaza.tres") as BattlefieldSettings]
static func objectives() -> Array[ObjectiveDefinition]:
	return [load("res://definitions/objectives/elimination.tres") as ObjectiveDefinition,load("res://definitions/objectives/hold_ground.tres") as ObjectiveDefinition,load("res://definitions/objectives/extraction.tres") as ObjectiveDefinition]

static func difficulties() -> Array[DifficultyDefinition]:
	return [load("res://definitions/difficulties/easy.tres") as DifficultyDefinition,load("res://definitions/difficulties/standard.tres") as DifficultyDefinition,load("res://definitions/difficulties/hard.tres") as DifficultyDefinition]
