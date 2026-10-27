class_name CampaignState
extends RefCounted
## Persistent plain-data state. No references to live encounters or UI.
const VERSION: int = 1
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
	for base in HeroCatalog.definitions():
		heroes[base.selection_id]={"id":base.selection_id,"experience":0,"level":1,"upgrades":[],"injury":{},"equipment":{},"medical_at":-1}
	for id: String in heroes:
		for item_id: String in [id+"_issue","watch_kit"]:
			var instance := create_item(item_id)
			heroes[id].equipment[item(item_id).slot]=instance
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
	for index in range(1 if final else clampi(rules.offers_per_board,2,3)):
		var recovery := not final and resolutions%2==1 and index==2
		var preset := rng.randi_range(0,2)
		var objective := 0 if recovery or final else (resolutions+index)%3
		var names: Array[String]=["Embers at the Gate","Keep the Lantern Lit","The Homeward Road"]
		offers.append({"id":"%08x-%03d-%d"%[seed_value,resolutions,index],"name":"The Last Beacon" if final else ("Gather the Herbwardens" if recovery else names[objective]),"seed":int(rng.randi()),"preset":preset,"objective":objective,"recovery":recovery,"final":final,"supplies":rules.recovery_supplies if recovery else rules.mission_supplies,"ignored":0 if recovery or final else rules.ignored_threat})
		var chosen: Dictionary=offers[-1]
		chosen.faction=FactionCatalog.ids()[mini(victories,2)] if not final else FactionCatalog.choose("random",chosen.seed)
		chosen.stage=mini(4,victories)
		chosen.elite=final or (victories>=3 and index==0)
		var faction:=FactionCatalog.find(chosen.faction)
		chosen.name=faction.display_name+" · "+chosen.name
		if chosen.elite: chosen.supplies+=faction.elite_supplies_bonus
		chosen.code=EncounterCode.encode(configuration_for(chosen,["knight","ranger"]))
func offer(id: String) -> Dictionary:
	for value in offers:
		if value.id==id: return value.duplicate(true)
	return {}
func deployment_error(id: String,party: PackedStringArray) -> String:
	if not ending.is_empty(): return "This campaign has ended."
	if not active.is_empty(): return "A mission is already committed."
	if offer(id).is_empty(): return "This mission offer is no longer available."
	if party.size()!=2 or party[0]==party[1] or not heroes.has(party[0]) or not heroes.has(party[1]): return "Choose exactly two distinct companions. Injured heroes may deploy."
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
	if not active.is_empty() or not ending.is_empty() or not heroes.has(id): return false
	var choice := upgrade(upgrade_id)
	if choice==null or choice.hero_id!=id or choice.required_level!=pending_level(id) or heroes[id].upgrades.has(upgrade_id): return false
	heroes[id].upgrades.append(upgrade_id)
	history.append("%s learned %s."%[HeroCatalog.find(id).display_name,choice.display_name])
	return true
func modifiers_for(id: String) -> Dictionary:
	var total: Dictionary={}
	for instance: String in heroes[id].equipment.values():
		CampaignStats.add(total,item(inventory[instance].definition_id).modifiers)
	for learned: String in heroes[id].upgrades: CampaignStats.add(total,upgrade(learned).modifiers)
	if not heroes[id].injury.is_empty(): CampaignStats.add(total,{"health":rules.injury_health,"movement":rules.injury_movement})
	return total
func preview_definition(id: String) -> UnitDefinition:
	return CampaignStats.derive(HeroCatalog.find(id),modifiers_for(id))
func prepare(id: String,party: PackedStringArray) -> EncounterConfiguration:
	if not deployment_error(id,party).is_empty(): return null
	return configuration_for(offer(id),party)
func configuration_for(chosen: Dictionary,party: PackedStringArray) -> EncounterConfiguration:
	var config := EncounterConfiguration.new()
	if chosen.has("code"):
		var decoded := EncounterCode.decode(chosen.code)
		if decoded.configuration==null: return null
		config=decoded.configuration
	config.hero_ids=party.duplicate(); config.campaign_hero_ids=party.duplicate()
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
	if active.is_empty() or data.get("version")!=1 or data.get("mission_id")!=active.id or processed.has(data.mission_id): return false
	if data.get("outcome") not in ["victory","failure"] or not data.get("heroes") is Dictionary: return false
	for id: String in active.party:
		if not data.heroes.has(id): return false
	processed[data.mission_id]=true
	var mission := active.duplicate(true)
	active.clear(); resolutions+=1
	if data.outcome=="victory": victories+=1
	last_debrief={"mission":mission,"result":data,"lines":[data.reason],"ending":""}
	var lines: Array=last_debrief.lines
	for id: String in mission.party:
		var earned_xp: int=rules.participation_xp+(rules.success_xp if data.outcome=="victory" else 0)
		heroes[id].experience+=earned_xp
		for index in range(rules.xp_thresholds.size()):
			if heroes[id].experience>=rules.xp_thresholds[index]: heroes[id].level=index+1
		lines.append("%s +%d XP → level %d (%d XP).%s"%[HeroCatalog.find(id).display_name,earned_xp,heroes[id].level,heroes[id].experience," Training choice available." if pending_level(id)>0 else ""])
	var earned: int=mission.supplies if data.outcome=="victory" else rules.failure_supplies
	supplies+=earned
	lines.append("Supplies +%d"%earned)
	var ignored: int=0
	for unchosen in offers:
		if unchosen.id!=mission.id:
			ignored+=int(unchosen.ignored)
			lines.append("Unresolved: %s (+%d threat)."%[unchosen.name,unchosen.ignored])
	var threat_before := threat
	threat=clampi(threat+(rules.victory_threat if data.outcome=="victory" else rules.failure_threat)+ignored,0,rules.threat_maximum)
	lines.append("Threat %d → %d: mission %+d, unresolved offers +%d"%[threat_before,threat,rules.victory_threat if data.outcome=="victory" else rules.failure_threat,ignored])
	# Only injuries which existed BEFORE this result recover. New injuries follow.
	for id: String in heroes:
		var hero: Dictionary=heroes[id]
		if hero.injury.is_empty(): continue
		var recovery: int=(1 if mission.party.has(id) else 2)+(1 if mission.recovery and data.outcome=="victory" else 0)
		hero.injury.remaining=maxi(0,int(hero.injury.remaining)-recovery)
		lines.append("%s recovered %d step(s): %d remaining"%[HeroCatalog.find(id).display_name,recovery,hero.injury.remaining])
		if hero.injury.remaining==0: hero.injury={}
	for id: String in mission.party:
		var result: Dictionary=data.heroes[id]
		var duration: int=rules.severe_duration if int(result.health)<=0 else (rules.strain_duration if float(result.health)<=float(result.maximum_health)*.5 else 0)
		if duration>0:
			var previous: int=int(heroes[id].injury.get("remaining",0))
			heroes[id].injury={"name":"Severe injury" if int(result.health)<=0 else "Battle strain","remaining":maxi(duration,previous)}
			lines.append("%s: %s (%d subsequent mission resolutions; %d max HP, %.1f m movement)"%[HeroCatalog.find(id).display_name,heroes[id].injury.name,heroes[id].injury.remaining,rules.injury_health,rules.injury_movement])
	if data.outcome=="victory" and mission.final: ending="victory"
	elif threat>=rules.threat_maximum: ending="defeat"
	if not ending.is_empty():
		last_debrief.ending=ending
		lines.append("The last beacon is rekindled. Campaign victory." if ending=="victory" else "Threat reached its maximum. Campaign defeat.")
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
	if definition==null or definition.cost<=0 or supplies<definition.cost: return ""
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
	if not active.is_empty() or not ending.is_empty() or not heroes.has(id) or not inventory.has(instance): return false
	var definition := item(inventory[instance].definition_id)
	if not definition.compatible_heroes.has(id): return false
	var previous := owner_of(instance)
	if previous==id: return false
	if not previous.is_empty(): heroes[previous].equipment.erase(definition.slot)
	heroes[id].equipment[definition.slot]=instance
	history.append("%s equipped %s [%s]."%[HeroCatalog.find(id).display_name,definition.display_name,instance])
	return true
func unequip(id: String,slot: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not heroes.has(id) or not heroes[id].equipment.has(slot): return false
	heroes[id].equipment.erase(slot)
	history.append("%s removed %s; familiar fallback remains usable."%[HeroCatalog.find(id).display_name,slot])
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
	return CampaignStats.derive(HeroCatalog.find(id),total)
func medical(id: String) -> bool:
	if not active.is_empty() or not ending.is_empty() or not heroes.has(id): return false
	var record: Dictionary=heroes[id]
	if record.injury.is_empty() or record.medical_at==resolutions or supplies<rules.medical_cost: return false
	supplies-=rules.medical_cost; record.medical_at=resolutions
	record.injury.remaining-=1
	if record.injury.remaining<=0: record.injury={}
	history.append("Herbwardens treated %s: recovery advanced one step (-%d Supplies)."%[HeroCatalog.find(id).display_name,rules.medical_cost])
	return true

func snapshot() -> Dictionary:
	return {"version":VERSION,"campaign_id":campaign_id,"rules_version":rules.version,"seed":seed_value,"difficulty":difficulty_id,"heroes":heroes.duplicate(true),"offers":offers.duplicate(true),"active":active.duplicate(true),"processed":processed.duplicate(true),"history":history.slice(maxi(0,history.size()-60)),"victories":victories,"resolutions":resolutions,"threat":threat,"supplies":supplies,"ending":ending,"inventory":inventory.duplicate(true),"next_item":next_item,"used_operations":used_operations.duplicate(true),"last_debrief":last_debrief.duplicate(true)}

