class_name CampaignState
extends RefCounted
## Persistent plain-data state. No references to live encounters or UI.
const VERSION: int = 2
const INTRODUCTORY_ENEMIES: PackedStringArray = ["ashfang_raider", "ashfang_bowhunter"]
var next_hero: int=1
var roster_rules: Resource=load("res://definitions/roster_rules.tres")
var campaign_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var rules: CampaignDefinition
var seed_value: int
var difficulty_id: String
var heroes: Dictionary={}
var offers: Array[Dictionary]=[]
var active: Dictionary={}
var processed: Dictionary={}
var history: Array[String]=[]
var victories: int=0
var resolutions: int=0
var threat: int=0
var supplies: int=0
var ending: String=""
var last_debrief: Dictionary={}
var inventory: Dictionary={}
var next_item: int=1
var used_operations: Dictionary={}
func _init(seed_number: int=1,difficulty: String="standard",definition: CampaignDefinition=null,restoring: bool=false) -> void:
	rules=definition if definition!=null else load("res://definitions/campaign/lantern_watch.tres") as CampaignDefinition
	seed_value=seed_number&0xffffffff; difficulty_id=difficulty
	if restoring: return # Load frozen records without creating offers or starter inventory.
	threat=rules.threat_start; supplies=rules.starting_supplies
	for index in range(int(roster_rules.starter_count)): _add_recruit()
	history.append("The Lantern Watch assembles. Progress saves between encounters.")
	generate_offers()
func difficulty() -> DifficultyDefinition:
	for option in EncounterOptions.difficulties():
		if option.stable_id==difficulty_id: return option
	return EncounterOptions.difficulties()[1]
func generate_offers() -> void:
	if not ending.is_empty():
		offers.clear(); return
	if not active.is_empty(): return
	offers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed=(seed_value ^ 0x4d495353 ^ (resolutions*104729))&0x7fffffffffffffff
	var final := victories>=rules.victories_required-1
	var used_layouts: PackedStringArray=[]
	var previous := str(last_debrief.get("mission",{}).get("template",{}).get("id",""))
	for index in range(1 if final else clampi(rules.offers_per_board,2,3)):
		var recovery := not final and resolutions%2==1 and index==2
		var elite := final or (victories>=3 and index==0)
		var objective := 0 if recovery or elite else (resolutions+index)%3
		var mission_seed := int(rng.randi())
		var faction_id := FactionCatalog.ids()[mini(victories,2)] if not final else FactionCatalog.choose("random",mission_seed)
		var stage := mini(4,victories)
		var template := MissionCatalog.choose(EncounterOptions.objectives()[objective].stable_id,faction_id,stage,recovery,elite,final,mission_seed,previous)
		if template==null:
			push_error("No valid mission template for objective=%d faction=%s stage=%d seed=%d"%[objective,faction_id,stage,mission_seed])
			offers.clear(); return
		var layout_id := MissionCatalog.choose_layout(template,mission_seed,used_layouts)
		used_layouts.append(layout_id)
		var faction := FactionCatalog.find(faction_id)
		var chosen := {"id":"%08x-%03d-%d"%[seed_value,resolutions,index],"name":faction.display_name+" · "+template.display_name,"seed":mission_seed,"preset":MissionCatalog.preset_index(layout_id),"objective":objective,"recovery":recovery,"final":final,"supplies":(rules.recovery_supplies if recovery else rules.mission_supplies)+(faction.elite_supplies_bonus if elite else 0),"ignored":0 if recovery or final else rules.ignored_threat,"faction":faction_id,"stage":stage,"elite":elite,"template":template.metadata()}
		var config := configuration_for(chosen,PackedStringArray(heroes.keys().slice(0,2)))
		# Freeze the tested recruit opening only when creating a new offer; never rewrite saved codes.
		if config!=null and victories==0 and not heroes.values().any(func(hero: Dictionary) -> bool: return bool(hero.get("legacy_specialist",false))):
			config.resolved_enemy_ids=INTRODUCTORY_ENEMIES.duplicate()
			config.enemies.clear()
			for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
		if config!=null and not rules.enemy_count_caps.is_empty() and not heroes.values().any(func(hero: Dictionary) -> bool: return bool(hero.get("legacy_specialist",false))):
			var limit := maxi(2,rules.enemy_count_caps[mini(victories,rules.enemy_count_caps.size()-1)])
			if config.resolved_enemy_ids.size()>limit:
				config.resolved_enemy_ids=config.resolved_enemy_ids.slice(0,limit)
				config.enemies=config.enemies.slice(0,limit)
		if config==null or not config.validation_error().is_empty():
			push_error("Mission template %s produced an invalid encounter, seed=%d"%[template.stable_id,mission_seed])
			offers.clear(); return
		# Frozen board codes describe the mission, independently of the current roster.
		config.hero_ids=PackedStringArray(["knight","ranger"])
		config.hero_overrides.clear(); config.campaign_hero_ids.clear(); config.deployment_id=""; config.survival_enabled=false
		chosen.code=EncounterCode.encode(config)
		offers.append(chosen)
func offer(id: String) -> Dictionary:
	for value in offers:
		if value.id==id: return value.duplicate(true)
	return {}
func deployment_error(id: String,party: PackedStringArray) -> String:
	if not ending.is_empty(): return "This campaign has ended."
	if not active.is_empty(): return "A mission is already committed."
	if offer(id).is_empty(): return "This mission offer is no longer available."
	if party.size()!=2 or party[0]==party[1] or not living_ids().has(party[0]) or not living_ids().has(party[1]): return "Choose exactly two distinct companions. Injured heroes may deploy."
	return ""
func upgrade(id: String) -> CampaignUpgradeDefinition:
	for value in rules.upgrades:
		if value.stable_id==id: return value as CampaignUpgradeDefinition
	return null
func pending_level(id: String) -> int:
	for level in range(2,int(heroes[id].level)+1):
		var spent := false
		for learned: String in heroes[id].upgrades:
			if upgrade(learned).required_level==level: spent=true
		if not spent: return level
	return 0
func learn(id: String,upgrade_id: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id): return false
	var choice := upgrade(upgrade_id)
	if choice==null or choice.hero_id!=blueprint_id(id) or choice.required_level!=pending_level(id) or heroes[id].upgrades.has(upgrade_id): return false
	heroes[id].upgrades.append(upgrade_id)
	history.append("%s learned %s."%[hero_name(id),choice.display_name])
	return true
func modifiers_for(id: String) -> Dictionary:
	var total: Dictionary={}
	for instance: String in heroes[id].equipment.values():
		CampaignStats.add(total,item(inventory[instance].definition_id).modifiers)
	for learned: String in heroes[id].upgrades: CampaignStats.add(total,upgrade(learned).modifiers)
	if not heroes[id].injury.is_empty(): CampaignStats.add(total,{"health":rules.injury_health,"movement":rules.injury_movement})
	return total
func preview_definition(id: String) -> UnitDefinition:
	var definition := CampaignStats.derive(HeroCatalog.find(blueprint_id(id)),modifiers_for(id))
	definition.display_name=hero_name(id)
	return definition
func prepare(id: String,party: PackedStringArray) -> EncounterConfiguration:
	if not deployment_error(id,party).is_empty(): return null
	return configuration_for(offer(id),party)
func configuration_for(chosen: Dictionary,party: PackedStringArray) -> EncounterConfiguration:
	var config := EncounterConfiguration.new()
	if chosen.has("code"):
		var decoded := EncounterCode.decode(chosen.code)
		if decoded.configuration==null: return null
		config=decoded.configuration
	config.hero_ids=PackedStringArray()
	for id in party: config.hero_ids.append(blueprint_id(id))
	config.campaign_hero_ids=party.duplicate()
	config.survival_enabled=true
	config.deployment_id=chosen.id
	config.hero_overrides.clear()
	for hero_id in party: config.hero_overrides.append(preview_definition(hero_id))
	if chosen.has("code"): return config
	config.faction_id=chosen.get("faction","legacy")
	config.campaign_stage=int(chosen.get("stage",0))
	config.elite_encounter=bool(chosen.get("elite",false))
	config.battlefield_seed=chosen.seed
	config.generator_settings=EncounterOptions.presets()[chosen.preset].duplicate(true) as BattlefieldSettings
	config.objective=EncounterOptions.objectives()[chosen.objective].duplicate(true) as ObjectiveDefinition
	config.difficulty=difficulty().duplicate(true) as DifficultyDefinition
	if chosen.final:
		config.difficulty.enemy_health_multiplier=minf(1.5,config.difficulty.enemy_health_multiplier*rules.final_enemy_multiplier)
		config.difficulty.enemy_damage_multiplier=minf(1.5,config.difficulty.enemy_damage_multiplier*rules.final_enemy_multiplier)
	config.resolve_roster()
	if chosen.has("template"):
		var template := MissionCatalog.find(str(chosen.template.id))
		config.resolved_enemy_ids=MissionCatalog.compose(template,config.faction_id,config.difficulty.stable_id,config.campaign_stage,config.battlefield_seed)
		config.enemies.clear()
		for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
	return config
func commit(id: String,party: PackedStringArray) -> EncounterConfiguration:
	var config := prepare(id,party)
	if config==null or not config.validation_error().is_empty(): return null
	active=offer(id); active.party=Array(party); active.configuration_seed=config.battlefield_seed
	active.encounter={"seed":config.battlefield_seed,"preset":config.generator_settings.preset_id,"generator_version":config.generator_settings.generator_version,"objective":config.objective.stable_id,"difficulty":difficulty_id,"difficulty_version":config.difficulty.configuration_version,"health_multiplier":config.difficulty.enemy_health_multiplier,"damage_multiplier":config.difficulty.enemy_damage_multiplier,"enemy_ids":Array(config.resolved_enemy_ids),"code":EncounterCode.encode(config)}
	history.append("Deployed %s to %s."%[", ".join(party),active.name])
	return config
func resolve(record: CampaignMissionResult) -> bool:
	var data := record.snapshot()
	if active.is_empty() or data.get("version") not in [1,2] or data.get("mission_id")!=active.id or processed.has(data.mission_id): return false
	if data.get("outcome") not in ["victory","failure"] or not data.get("heroes") is Dictionary: return false
	if data.heroes.size()!=active.party.size(): return false
	for id: String in active.party:
		if not data.heroes.has(id) or not data.heroes[id] is Dictionary: return false
		var hero: Dictionary=data.heroes[id]
		if not hero.has("health") or not hero.has("maximum_health") or not EncounterCode._whole(hero.maximum_health,1,99) or not EncounterCode._whole(hero.health,0,hero.maximum_health): return false
		if data.version==2 and (hero.get("survival","") not in ["recovered","extracted","dead"] or not hero.get("death_cause") is String): return false
		if data.version==2 and hero.survival in ["active","downed","stabilised"]: return false
	processed[data.mission_id]=true
	var mission := active.duplicate(true)
	active.clear(); resolutions+=1
	if data.outcome=="victory": victories+=1
	last_debrief={"mission":mission,"result":data,"lines":[data.reason],"ending":""}
	var lines: Array=last_debrief.lines
	for id: String in mission.party:
		heroes[id].missions_completed=int(heroes[id].get("missions_completed",0))+1
		if str(data.heroes[id].get("survival","recovered"))=="dead":
			heroes[id].dead=true; heroes[id].death_cause=str(data.heroes[id].get("death_cause","Lost on mission"))
			heroes[id].injury={}
			lines.append("%s died: %s. Remembered by the Watch."%[hero_name(id),heroes[id].death_cause])
			continue
		var earned_xp: int=rules.participation_xp+(rules.success_xp if data.outcome=="victory" else 0)
		heroes[id].experience+=earned_xp
		for index in range(rules.xp_thresholds.size()):
			if heroes[id].experience>=rules.xp_thresholds[index]: heroes[id].level=index+1
		lines.append("%s +%d XP → level %d (%d XP).%s"%[hero_name(id),earned_xp,heroes[id].level,heroes[id].experience," Training choice available." if pending_level(id)>0 else ""])
	var earned: int=mission.supplies if data.outcome=="victory" else rules.failure_supplies
	supplies+=earned
	lines.append("Supplies +%d"%earned)
	var ignored: int=0
	for unchosen in offers:
		if unchosen.id!=mission.id:
			ignored+=int(unchosen.ignored)
			lines.append("Unresolved: %s (+%d threat)."%[unchosen.name,unchosen.ignored])
	if ignored>rules.maximum_ignored_threat: lines.append("Unresolved mission threat capped at %d for this board."%rules.maximum_ignored_threat)
	ignored=mini(ignored,maxi(0,rules.maximum_ignored_threat))
	var threat_before := threat
	threat=clampi(threat+(rules.victory_threat if data.outcome=="victory" else rules.failure_threat)+ignored,0,rules.threat_maximum)
	lines.append("Threat %d → %d: mission %+d, unresolved offers +%d"%[threat_before,threat,rules.victory_threat if data.outcome=="victory" else rules.failure_threat,ignored])
	# Only injuries which existed BEFORE this result recover. New injuries follow.
	for id: String in heroes:
		var hero: Dictionary=heroes[id]
		if hero.get("dead",false) or hero.injury.is_empty(): continue
		var recovery: int=(1 if mission.party.has(id) else 2)+(1 if mission.recovery and data.outcome=="victory" else 0)
		hero.injury.remaining=maxi(0,int(hero.injury.remaining)-recovery)
		lines.append("%s recovered %d step(s): %d remaining"%[hero_name(id),recovery,hero.injury.remaining])
		if hero.injury.remaining==0: hero.injury={}
	for id: String in mission.party:
		if heroes[id].get("dead",false): continue
		var result: Dictionary=data.heroes[id]
		var duration: int=rules.severe_duration if int(result.health)<=0 else (rules.strain_duration if float(result.health)<=float(result.maximum_health)*.5 else 0)
		if duration>0:
			var previous: int=int(heroes[id].injury.get("remaining",0))
			heroes[id].injury={"name":"Severe injury" if int(result.health)<=0 else "Battle strain","remaining":maxi(duration,previous)}
			lines.append("%s: %s (%d subsequent mission resolutions; %d max HP, %.1f m movement)"%[hero_name(id),heroes[id].injury.name,heroes[id].injury.remaining,rules.injury_health,rules.injury_movement])
	if data.outcome=="victory" and mission.final: ending="victory"
	elif threat>=rules.threat_maximum or (living_ids().size()<2 and supplies<(2-living_ids().size())*int(roster_rules.recruit_cost)): ending="defeat"
	if not ending.is_empty():
		last_debrief.ending=ending
		lines.append("The last beacon is rekindled. Campaign victory." if ending=="victory" else "The Watch can no longer sustain a deployment. Campaign defeat.")
	history.append("%s: %s."%[mission.name,data.tactical_result])
	for line: String in lines: history.append(line)
	while history.size()>60: history.pop_front()
	generate_offers()
	return true

func item(id: String) -> CampaignItemDefinition:
	for value in rules.items:
		if value.stable_id==id: return value as CampaignItemDefinition
	return null
func create_item(id: String) -> String:
	var instance := "gear-%04d"%next_item; next_item+=1
	inventory[instance]={"id":instance,"definition_id":id}
	return instance
func purchase(id: String,request_id: String="") -> String:
	if not active.is_empty() or not ending.is_empty() or used_operations.has(request_id) and not request_id.is_empty(): return ""
	var definition := item(id)
	if definition==null or definition.cost<=0 or not can_spend(definition.cost): return ""
	supplies-=definition.cost
	var instance := create_item(id)
	if not request_id.is_empty(): used_operations[request_id]=true
	history.append("Bought %s [%s] for %d Supplies."%[definition.display_name,instance,definition.cost])
	return instance
func owner_of(instance: String) -> String:
	for id: String in heroes:
		if heroes[id].equipment.values().has(instance): return id
	return ""
func equip(id: String,instance: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id) or not inventory.has(instance): return false
	var definition := item(inventory[instance].definition_id)
	if not definition.compatible_heroes.has(blueprint_id(id)): return false
	var previous := owner_of(instance)
	if previous==id: return false
	if not previous.is_empty(): heroes[previous].equipment.erase(definition.slot)
	heroes[id].equipment[definition.slot]=instance
	history.append("%s equipped %s [%s]."%[hero_name(id),definition.display_name,instance])
	return true
func unequip(id: String,slot: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id) or not heroes[id].equipment.has(slot): return false
	heroes[id].equipment.erase(slot)
	history.append("%s removed %s; familiar fallback remains usable."%[hero_name(id),slot])
	return true
func projected_definition(id: String,item_id: String) -> UnitDefinition:
	var definition := item(item_id)
	var total := modifiers_for(id)
	var current: String=heroes[id].equipment.get(definition.slot,"")
	if not current.is_empty():
		var inverse: Dictionary={}
		for key: String in item(inventory[current].definition_id).modifiers: inverse[key]=-float(item(inventory[current].definition_id).modifiers[key])
		CampaignStats.add(total,inverse)
	CampaignStats.add(total,definition.modifiers)
	return CampaignStats.derive(HeroCatalog.find(blueprint_id(id)),total)
func medical(id: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id): return false
	var record: Dictionary=heroes[id]
	if record.injury.is_empty() or record.medical_at==resolutions or not can_spend(rules.medical_cost): return false
	supplies-=rules.medical_cost; record.medical_at=resolutions
	record.injury.remaining-=1
	if record.injury.remaining<=0: record.injury={}
	history.append("Herbwardens treated %s: recovery advanced one step (-%d Supplies)."%[hero_name(id),rules.medical_cost])
	return true

func snapshot() -> Dictionary:
	return {"version":VERSION,"campaign_id":campaign_id,"rules_version":rules.version,"seed":seed_value,"difficulty":difficulty_id,"heroes":heroes.duplicate(true),"offers":offers.duplicate(true),"active":active.duplicate(true),"processed":processed.duplicate(true),"history":history.slice(maxi(0,history.size()-60)),"victories":victories,"resolutions":resolutions,"threat":threat,"supplies":supplies,"ending":ending,"inventory":inventory.duplicate(true),"next_item":next_item,"next_hero":next_hero,"used_operations":used_operations.duplicate(true),"last_debrief":last_debrief.duplicate(true)}


func hero_name(id: String) -> String:
	return str(heroes[id].get("name",id)) if heroes.has(id) else id
func blueprint_id(id: String) -> String:
	return str(heroes[id].get("specialisation","")) if not str(heroes[id].get("specialisation","")).is_empty() else "recruit"
func living_ids() -> PackedStringArray:
	var result: PackedStringArray=[]
	for id: String in heroes:
		if not heroes[id].get("dead",false): result.append(id)
	return result
func _add_recruit() -> String:
	while heroes.has("hero-%04d"%next_hero): next_hero+=1
	var id := "hero-%04d"%next_hero; next_hero+=1
	heroes[id]={"id":id,"name":recruit_name(next_hero-1),"specialisation":"","legacy_specialist":false,"dead":false,"death_cause":"","trained":false,"missions_completed":0,"experience":0,"level":1,"upgrades":[],"injury":{},"equipment":{},"medical_at":-1}
	for item_id: String in ["recruit_issue","watch_kit"]:
		var instance := create_item(item_id)
		heroes[id].equipment[item(item_id).slot]=instance
	return id
func recruit(operation_id: String="") -> String:
	if not active.is_empty() or not ending.is_empty() or supplies<int(roster_rules.recruit_cost) or (not operation_id.is_empty() and used_operations.has(operation_id)): return ""
	supplies-=int(roster_rules.recruit_cost)
	var id := _add_recruit()
	if not operation_id.is_empty(): used_operations[operation_id]=true
	history.append("%s joined the Watch."%hero_name(id))
	return id
func train_recruit(id: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id): return false
	var hero: Dictionary=heroes[id]
	if blueprint_id(id)!="recruit" or hero.level!=1 or hero.trained or not can_spend(int(roster_rules.training_cost)): return false
	supplies-=int(roster_rules.training_cost); hero.trained=true
	hero.experience=maxi(hero.experience,int(roster_rules.training_xp))
	for index in range(rules.xp_thresholds.size()):
		if hero.experience>=rules.xp_thresholds[index]: hero.level=index+1
	history.append("%s completed basic training."%hero_name(id))
	return true
func specialise(id: String,class_id: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not living_ids().has(id) or not SpecialisationCatalog.ids().has(class_id): return false
	if heroes[id].level<2 or blueprint_id(id)!="recruit": return false
	heroes[id].specialisation=class_id
	for slot: String in heroes[id].equipment.keys():
		var gear := item(inventory[heroes[id].equipment[slot]].definition_id)
		if not gear.compatible_heroes.has(class_id): heroes[id].equipment.erase(slot)
	history.append("%s became a %s."%[hero_name(id),HeroCatalog.find(class_id).display_name])
	return true

func recruit_name(sequence: int) -> String:
	const GIVEN := ["Elin","Tarin","Mara","Orin","Seren","Bryn","Nessa","Corin"]
	const FAMILY := ["Vale","Ashbrook","Reed","Stonewell","Moss","Greywick","Rowan","Fallow"]
	var first := (seed_value+sequence-1)%GIVEN.size()
	var last := (int(seed_value/8)+int((sequence-1)/8))%FAMILY.size()
	return "%s %s%s" % [GIVEN[first],FAMILY[last]," %d" % (int((sequence-1)/64)+1) if sequence>64 else ""]

func recruitment_reserve() -> int:
	return maxi(0,2-living_ids().size())*int(roster_rules.recruit_cost)

func can_spend(cost: int) -> bool:
	# Preserve a route back to a two-person deployment after roster losses.
	return cost>=0 and supplies-cost>=recruitment_reserve()
