@static_unload
class_name MissionCatalog
extends RefCounted
## Separate deterministic mission/composition stream; no live combat state.
const VERSION: int=1
const IDS: PackedStringArray=["raiding_party","bowline","courtyard_watch","lantern_defence","homeward_passage","split_extraction","herbwardens","elite_hunt","last_beacon"]
const STREAM: int=0x4d544d50
static func all() -> Array[MissionTemplate]:
	var result: Array[MissionTemplate]=[]
	for id in IDS: result.append(find(id))
	return result
static func find(id: String) -> MissionTemplate:
	if not IDS.has(id): return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree==null: return load("res://definitions/missions/"+id+".tres") as MissionTemplate
	if not tree.root.has_meta(&"_mission_template_definitions"):
		var definitions: Dictionary={}
		tree.root.set_meta(&"_mission_template_definitions",definitions)
		tree.root.tree_exiting.connect(func() -> void: definitions.clear(),CONNECT_ONE_SHOT)
	var cache: Dictionary=tree.root.get_meta(&"_mission_template_definitions")
	if not cache.has(id): cache[id]=load("res://definitions/missions/"+id+".tres") as MissionTemplate
	return cache[id] as MissionTemplate
static func choose(objective_id: String,faction_id: String,stage: int,recovery: bool,elite: bool,finale: bool,seed_value: int,previous: String="") -> MissionTemplate:
	var choices: Array[MissionTemplate]=[]
	for item in all():
		if item==null or not item.validation_error().is_empty(): continue
		if item.recovery!=recovery or item.elite!=elite or item.finale!=finale or item.objective_id!=objective_id: continue
		if stage<item.minimum_stage or stage>item.maximum_stage or not item.faction_ids.has(faction_id): continue
		choices.append(item)
	if choices.size()>1:
		choices=choices.filter(func(item: MissionTemplate) -> bool: return item.stable_id!=previous)
	if choices.is_empty(): return null
	var rng:=RandomNumberGenerator.new(); rng.seed=(seed_value^STREAM)&0x7fffffffffffffff
	return choices[rng.randi_range(0,choices.size()-1)]
static func metadata_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=4: return false
	for key in ["id","version","style","briefing"]:
		if not value.has(key): return false
	return value.id is String and find(value.id)!=null and (value.version is int or value.version is float) and value.version==VERSION and value.style is String and value.style in ["balanced","aggressive","ranged","defensive","elite"] and value.briefing is String and value.briefing.length()>0 and value.briefing.length()<=600
static func preset_index(id: String) -> int:
	var presets:=EncounterOptions.presets()
	for index in range(presets.size()):
		if presets[index].preset_id==id: return index
	return -1
static func choose_layout(template: MissionTemplate,seed_value: int,used: PackedStringArray) -> String:
	var choices:=template.layout_ids.duplicate()
	var fresh: PackedStringArray=[]
	for id in choices:
		if not used.has(id): fresh.append(id)
	if not fresh.is_empty(): choices=fresh
	var rng:=RandomNumberGenerator.new(); rng.seed=(seed_value^STREAM^0x4c41594f)&0x7fffffffffffffff
	return choices[rng.randi_range(0,choices.size()-1)]
static func _healer(unit: UnitDefinition) -> bool:
	return unit.abilities.any(func(ability: AbilityDefinition) -> bool: return ability.effect==AbilityDefinition.Effect.HEAL)
static func _role(unit: UnitDefinition,role: String) -> bool:
	if role=="support": return _healer(unit)
	if _healer(unit): return false
	if role=="ranged": return unit.role=="Archer" and unit.basic_attack.attack_type==AttackDefinition.Type.RANGED
	if role=="caster": return unit.role=="Caster"
	return unit.basic_attack.attack_type==AttackDefinition.Type.MELEE
static func compose(template: MissionTemplate,faction_id: String,difficulty_id: String,stage: int,seed_value: int) -> PackedStringArray:
	if template==null or not template.validation_error().is_empty() or not template.faction_ids.has(faction_id): return []
	if template.elite: return FactionCatalog.roster(faction_id,difficulty_id,stage,true,seed_value)
	var faction:=FactionCatalog.find(faction_id)
	var remaining:=faction.budget(difficulty_id,stage)
	var result: PackedStringArray=[]
	var healer_used:=false
	for role in template.role_pattern:
		var candidates: Array[UnitDefinition]=[]
		for id in faction.regular_ids:
			var unit:=EnemyCatalog.find(id)
			if unit==null or unit.is_elite or unit.introduction_stage>maxi(stage,faction.introduction_stage) or unit.encounter_cost>remaining or (_healer(unit) and healer_used): continue
			if _role(unit,role): candidates.append(unit)
		candidates.sort_custom(func(a: UnitDefinition,b: UnitDefinition) -> bool:
			if role=="front" and a.maximum_health!=b.maximum_health: return a.maximum_health>b.maximum_health
			if role=="mobile" and a.movement_allowance!=b.movement_allowance: return a.movement_allowance>b.movement_allowance
			return a.enemy_id<b.enemy_id)
		if candidates.is_empty(): continue
		var chosen:=candidates[0]
		result.append(chosen.enemy_id); remaining-=chosen.encounter_cost
		if _healer(chosen): healer_used=true
	# A scarce-role slot must never leave a one-unit mission. Use cheap legal roles.
	if result.size()<2:
		for id in faction.opening_template:
			var unit:=EnemyCatalog.find(id)
			if result.size()>=2: break
			if unit==null or unit.is_elite or unit.encounter_cost>remaining or unit.introduction_stage>maxi(stage,faction.introduction_stage) or (_healer(unit) and healer_used): continue
			result.append(id); remaining-=unit.encounter_cost
			if _healer(unit): healer_used=true
	return result if FactionCatalog.valid_roster(result,faction_id,difficulty_id,stage,false) else PackedStringArray()
