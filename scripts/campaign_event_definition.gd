class_name CampaignEventDefinition
extends Resource
@export var stable_id: String=""
@export var revision: int=1
@export var display_name: String=""
@export_multiline var description: String=""
@export_enum("any","injured","specialist","loss") var eligibility: String="any"
## Choices: stable id, label, Supplies delta and existing-injury recovery steps.
@export var choices: Array[Dictionary]=[]
