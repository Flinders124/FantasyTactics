class_name OptionalGoalDefinition
extends Resource
@export var stable_id: String=""
@export var display_name: String=""
@export_multiline var description: String=""
@export_enum("cache","swift","together") var rule: String="cache"
@export_range(0,20) var supplies: int=6
@export_range(.5,2) var radius: float=1.2
@export_range(1,10) var round_limit: int=4
