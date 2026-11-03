class_name CampaignItemDefinition
extends Resource
@export var stable_id: String = ""
@export var display_name: String = ""
@export var slot: String = "weapon"
@export var compatible_heroes: PackedStringArray = []
@export var cost: int = 0
@export_multiline var description: String = ""
@export var modifiers: Dictionary = {}

@export_range(1,4) var minimum_level: int=1
@export_enum("common","rare","legendary") var rarity: String="common"
@export var icon_id: String=""
@export var icon_variants: PackedStringArray=[]
@export_enum("armoury","trader") var vendor: String="armoury"
