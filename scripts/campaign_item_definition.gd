class_name CampaignItemDefinition
extends Resource
@export var stable_id: String = ""
@export var display_name: String = ""
@export var slot: String = "weapon"
@export var compatible_heroes: PackedStringArray = []
@export var cost: int = 0
@export_multiline var description: String = ""
@export var modifiers: Dictionary = {}
