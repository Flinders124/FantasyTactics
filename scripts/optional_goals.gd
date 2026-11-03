class_name OptionalGoals
extends RefCounted
const IDS: PackedStringArray=["cache","swift","together"]
static func find(id: String) -> OptionalGoalDefinition:
 return load("res://definitions/optional/"+id+".tres") as OptionalGoalDefinition if IDS.has(id) else null
static func pick(seed_value: int) -> String:
 var rng := RandomNumberGenerator.new();rng.seed=(seed_value^0x424f4e55)&0x7fffffffffffffff
 return IDS[int(rng.randi())%IDS.size()]
static func briefing(id: String) -> String:
 var goal := find(id)
 return "" if goal==null else "OPTIONAL · %s: %s Bonus: +%d Supplies on victory (campaign only). No penalty for skipping."%[goal.display_name,goal.description,goal.supplies]
static func valid_report(value: Variant,id: String,outcome: String,abandoned: bool=false) -> bool:
 var goal := find(id)
 if goal==null or not value is Dictionary or value.size()!=3:return false
 if not value.has("id") or not value.has("completed") or not value.has("reward") or value.id!=id or not value.completed is bool:return false
 if not (value.reward is int or value.reward is float) or not is_finite(float(value.reward)) or value.reward<0 or value.reward>20 or float(value.reward)!=floor(float(value.reward)):return false
 if (abandoned or outcome!="victory") and value.completed:return false
 return int(value.reward)==(goal.supplies if value.completed else 0)
