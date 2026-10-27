class_name FactionDefinition
extends Resource

@export var stable_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 4) var introduction_stage: int = 0
@export var regular_ids: PackedStringArray = []
@export var elite_id: String = ""
# Alternating front/ranged templates; IDs remain editable in the resource.
@export var opening_template: PackedStringArray = []
@export var reinforcement_template: PackedStringArray = []
@export var elite_support: PackedStringArray = []
@export_range(2, 12) var easy_budget: int = 4
@export_range(2, 12) var standard_budget: int = 5
@export_range(2, 12) var hard_budget: int = 6
@export_range(0, 2) var later_stage_budget: int = 1

func budget(difficulty_id: String, stage: int) -> int:
	var base := standard_budget
	if difficulty_id == "easy": base = easy_budget
	elif difficulty_id == "hard": base = hard_budget
	return base + (later_stage_budget if stage >= 2 else 0)

@export var elite_supplies_bonus: int = 6

@export var primary_color: Color = Color("542b20")
@export var accent_color: Color = Color("b44c25")
