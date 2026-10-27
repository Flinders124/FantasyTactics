extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func record(state: CampaignState,outcome: String="victory",down: String="") -> CampaignMissionResult:
	var people: Dictionary={}
	for id: String in state.active.party: people[id]={"health":0 if id==down else 10,"maximum_health":10}
	return CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":outcome,"abandoned":false,"reason":"Development scenario","heroes":people,"rounds":3,"tactical_result":outcome.to_upper()})
func plain(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for child: Variant in value.values():
			if not plain(child): return false
	elif value is Array:
		for child: Variant in value:
			if not plain(child): return false
	return true
func run() -> void:
	var state := CampaignState.new(17,"standard")
	var identical := CampaignState.new(17,"standard")
	check(state.offers==identical.offers,"Seed reproduces frozen offers")
	var initial := state.snapshot()
	state.generate_offers()
	check(state.offers==initial.offers,"Refreshing board cannot reroll offers")
	check(not state.deployment_error(state.offers[0].id,["knight","knight"]).is_empty(),"Two distinct heroes required")
	for first in range(4):
		for second in range(first+1,4):
			var ids: Array=state.heroes.keys()
			var config := state.prepare(state.offers[0].id,PackedStringArray([ids[first],ids[second]]))
			check(config!=null and config.validation_error().is_empty() and config.hero_overrides.size()==2,"All six deployments validate")
	var base_health := HeroCatalog.find("knight").maximum_health
	var config := state.commit(state.offers[0].id,["knight","ranger"])
	check(config!=null and state.commit(state.offers[0].id,["mage","cleric"])==null,"Mission commits once")
	config.hero_overrides[0].maximum_health+=1
	check(HeroCatalog.find("knight").maximum_health==base_health,"Deployment definitions are private")
	var outcome := record(state)
	check(outcome._record.is_read_only() and outcome._record.heroes.is_read_only(),"Mission result boundary is deeply immutable")
	check(state.resolve(outcome) and not state.resolve(outcome) and state.victories==1,"Result/rewards cannot process twice")
	for mission in range(4):
		check(state.commit(state.offers[0].id,["knight","ranger"])!=null,"Next mission playable")
		check(state.resolve(record(state)),"Next result accepted")
	check(state.ending=="victory" and state.offers.is_empty(),"Fifth successful final mission gives one campaign victory")
	var wounded := CampaignState.new(11,"standard")
	wounded.commit(wounded.offers[0].id,["knight","ranger"])
	wounded.resolve(record(wounded,"failure","knight"))
	check(wounded.heroes.knight.injury.remaining==3 and wounded.threat==6,"New severe injury skips immediate recovery; failure and ignored threats resolve once")
	var adjusted := wounded.preview_definition("knight")
	check(adjusted.maximum_health==base_health-3 and adjusted.movement_allowance==5.5,"Injury affects private allocation stats, not base definitions")
	wounded.commit(wounded.offers[0].id,["mage","cleric"]); wounded.resolve(record(wounded))
	check(wounded.heroes.knight.injury.remaining==1,"Resting hero recovers two steps")
	wounded.commit(wounded.offers[0].id,["knight","ranger"]); wounded.resolve(record(wounded))
	check(wounded.heroes.knight.injury.is_empty(),"Deploying injury recovers one step without a deadlock")
	var losing := CampaignState.new(11,"standard")
	for attempt in range(3):
		if not losing.ending.is_empty(): break
		losing.commit(losing.offers[0].id,["knight","ranger"]); losing.resolve(record(losing,"failure","knight"))
	check(losing.ending=="defeat" and losing.threat==10 and losing.offers.is_empty(),"Bounded threat produces one clean campaign defeat")
	var learner := CampaignState.new(23,"standard")
	learner.commit(learner.offers[0].id,["knight","ranger"]); learner.resolve(record(learner,"victory","knight"))
	check(learner.heroes.knight.experience==25 and learner.heroes.knight.level==2 and learner.pending_level("knight")==2,"Incapacitated participants retain success/participation XP")
	check(learner.learn("knight","knight_2_0") and not learner.learn("knight","knight_2_1") and not learner.learn("ranger","knight_2_0"),"Training spends one permanent choice per level on its owner")
	check(learner.preview_definition("knight").maximum_health==base_health and HeroCatalog.find("knight").maximum_health==base_health,"Flat injury and upgrade combine once without mutating base")
	check(learner.preview_definition("ranger").maximum_health==HeroCatalog.find("ranger").maximum_health,"Shared hero state remains independent")
	var outfitter := CampaignState.new(29,"standard")
	check(outfitter.inventory.size()==8,"Each hero owns two distinct starting items")
	var funds := outfitter.supplies
	var coat := outfitter.purchase("stoneweave","one")
	check(not coat.is_empty() and outfitter.purchase("stoneweave","one").is_empty() and outfitter.supplies==funds-14,"Purchase is transactional and duplicate request rejected")
	var projected := outfitter.projected_definition("knight","stoneweave")
	check(outfitter.equip("knight",coat) and outfitter.preview_definition("knight").maximum_health==projected.maximum_health,"Equipment preview matches stat derivation")
	check(outfitter.equip("ranger",coat) and not outfitter.heroes.knight.equipment.values().has(coat) and outfitter.owner_of(coat)=="ranger","One owned instance transfers safely between heroes")
	check(not outfitter.equip("mage",outfitter.heroes.knight.equipment.weapon),"Weapons enforce role compatibility")
	check(outfitter.unequip("ranger","garb") and outfitter.preview_definition("ranger").maximum_health==HeroCatalog.find("ranger").maximum_health,"Unequip restores usable base stats")
	outfitter.heroes.knight.injury={"name":"Severe injury","remaining":3}
	check(outfitter.medical("knight") and not outfitter.medical("knight") and outfitter.heroes.knight.injury.remaining==2,"Treatment spends once and has a per-interval limit")
	var mage_base := HeroCatalog.find("mage")
	var original_fingerprint := EncounterCode.fingerprint(mage_base)
	var tuned := CampaignStats.derive(mage_base,{"offense":2,"cooldown:fireburst":-1})
	check(tuned.abilities[0].magnitude==mage_base.abilities[0].magnitude+2 and tuned.abilities[0].area_radius==mage_base.abilities[0].area_radius and tuned.abilities[0].cooldown_turns==1,"Offense scales damage, explicit cooldown scales timing, area radius stays fixed")
	check(EncounterCode.fingerprint(mage_base)==original_fingerprint,"Derived attack and ability resources never mutate external definitions")
	var healer_base := HeroCatalog.find("cleric")
	var healer := CampaignStats.derive(healer_base,{"offense":2})
	check(healer.abilities[0].magnitude==healer_base.abilities[0].magnitude,"Offensive modifiers do not change healing")
	var final_rules := load("res://definitions/campaign/lantern_watch.tres").duplicate(true) as CampaignDefinition
	final_rules.victory_threat=20
	var last := CampaignState.new(33,"hard",final_rules)
	last.victories=4; last.generate_offers()
	var final_config := last.commit(last.offers[0].id,["knight","ranger"])
	check(final_config.difficulty.enemy_health_multiplier>last.difficulty().enemy_health_multiplier and final_config.difficulty.stable_id=="hard","Final challenge derives stronger enemies without changing campaign difficulty")
	last.resolve(record(last))
	check(last.ending=="victory" and last.threat==10 and last.offers.is_empty(),"Final victory has unambiguous precedence over simultaneous threat cap")
	var combined := CampaignState.new(4,"standard")
	combined.heroes.ranger.injury={"name":"Severe injury","remaining":3}
	combined.heroes.knight.injury={"name":"Severe injury","remaining":3}
	combined.resolutions=1; combined.generate_offers()
	combined.commit(combined.offers[2].id,["knight","ranger"]); combined.resolve(record(combined))
	check(combined.heroes.knight.injury.remaining==1,"Recovery mission adds one recovery step to deployed pre-existing injuries")
	check(plain(combined.snapshot()) and JSON.parse_string(JSON.stringify(combined.snapshot())).version==1,"Run snapshot is Resource-free versioned data")
	var frozen := outfitter.commit(outfitter.offers[0].id,["knight","ranger"])
	check(frozen!=null and not outfitter.equip("knight",coat) and outfitter.purchase("trail_mantle").is_empty() and not outfitter.medical("knight"),"Committed deployment blocks headquarters mutations")
	for case: Array in [[19,1],[20,2],[49,2],[50,3],[89,3],[90,4]]:
		var threshold := CampaignState.new(31,"standard")
		threshold.heroes.knight.experience=int(case[0])-10
		threshold.commit(threshold.offers[0].id,["knight","ranger"]); threshold.resolve(record(threshold,"failure"))
		check(threshold.heroes.knight.experience==case[0] and threshold.heroes.knight.level==case[1],"XP threshold boundary derives exactly the expected level")
	var strained := CampaignState.new(19,"standard")
	for repeat in range(2):
		strained.commit(strained.offers[0].id,["knight","ranger"])
		var half := record(strained).snapshot(); half.heroes.knight.health=5
		strained.resolve(CampaignMissionResult.new(half))
		check(strained.heroes.knight.injury.remaining==2 and strained.heroes.knight.injury.name=="Battle strain" and strained.preview_definition("knight").maximum_health==base_health-3,"Half-health strain refreshes two future resolutions without stacked penalties")
	var minimum := CampaignStats.derive(HeroCatalog.find("knight"),{"health":-999,"movement":-999,"offense":-999,"healing":-999})
	check(minimum.maximum_health==1 and minimum.movement_allowance==1 and minimum.basic_attack.damage==1 and minimum.abilities[1].magnitude==1,"Stat minima preserve a usable injured loadout")
	var flow := (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.request_transition("new_campaign"); check(flow.screen=="campaign_creation","Title campaign entry opens creation")
	flow.campaign.seed_text="17"; flow.request_transition("campaign_begin")
	check(flow.screen=="headquarters" and flow.campaign.state.heroes.size()==4,"Headquarters starts four-hero run")
	var id: String=flow.campaign.state.offers[0].id
	flow.request_transition("campaign_prepare:"+id)
	check(flow.screen=="campaign_preparation","Mission preparation is integrated")
	flow.campaign.state=null; flow.show_title(); flow.queue_free(); await process_frame
	print("CAMPAIGN RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
