class_name MissionTemplate
extends Resource
## Authored mission constraints only. Offers freeze resolved values separately.
@export var stable_id: String = ""
@export var version: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var objective_id: String = "elimination"
@export var layout_ids: PackedStringArray = []
@export var faction_ids: PackedStringArray = ["ashfang","hollow","verdant"]
@export_enum("balanced","aggressive","ranged","defensive","elite") var style: String = "balanced"
@export var role_pattern: PackedStringArray = ["front","ranged","support","mobile"]
@export_range(0,4) var minimum_stage: int = 0
@export_range(0,4) var maximum_stage: int = 4
@export var recovery: bool = false
@export var elite: bool = false
@export var finale: bool = false

func validation_error() -> String:
	if stable_id.is_empty() or not stable_id.is_valid_identifier() or stable_id.length()>48: return "Template requires a stable identifier."
	if version!=1: return "Unsupported mission template version."
	if display_name.is_empty() or display_name.length()>55 or description.is_empty() or description.length()>600: return "Template requires a bounded name and briefing."
	if objective_id not in ["elimination","hold_ground","extraction"]: return "Unsupported mission objective: "+objective_id
	if minimum_stage<0 or maximum_stage>4 or minimum_stage>maximum_stage: return "Invalid campaign introduction range."
	if style not in ["balanced","aggressive","ranged","defensive","elite"]: return "Unknown encounter style."
	if layout_ids.is_empty() or faction_ids.is_empty(): return "Template requires compatible layouts and factions."
	var supported := EncounterOptions.PRESET_IDS
	for id in layout_ids:
		if not supported.has(id) or not ResourceLoader.exists("res://definitions/presets/"+id+".tres"): return "Unknown battlefield layout: "+id
	for id in faction_ids:
		if not FactionCatalog.FACTION_IDS.has(id) or not ResourceLoader.exists("res://definitions/factions/"+id+".tres"): return "Unknown enemy faction: "+id
	if role_pattern.size()<2 or role_pattern.size()>4: return "Use two to four bounded role slots."
	for role in role_pattern:
		if role not in ["front","mobile","ranged","support","caster"]: return "Unknown composition role: "+role
	if (elite and style!="elite") or (finale and not elite) or (recovery and (elite or finale)): return "Incompatible elite, finale or recovery constraints."
	return ""

func metadata() -> Dictionary:
	return {"id":stable_id,"version":version,"style":style,"briefing":description}
