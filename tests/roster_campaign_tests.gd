extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state := CampaignState.new(423)
	check(state.heroes.size()==4,"four individual starters")
	var ids := state.living_ids()
	check(ids[0]=="hero-0001" and state.blueprint_id(ids[0])=="recruit","individual identity differs from recruit blueprint")
	var recruits := state.prepare(state.offers[0].id,PackedStringArray(ids.slice(0,2)))
	check(recruits!=null and recruits.validation_error().is_empty() and recruits.hero_ids==PackedStringArray(["recruit","recruit"]),"two distinct recruits share a valid blueprint")
	check(EncounterCode.decode(EncounterCode.encode(recruits)).configuration!=null,"duplicate recruit classes roundtrip encounter code")
	check(recruits.hero_overrides[0]!=recruits.hero_overrides[1] and recruits.hero_overrides[0].display_name!=recruits.hero_overrides[1].display_name,"private named hero definitions")
	check(not state.specialise(ids[0],"knight"),"level one cannot specialise")
	state.supplies=100
	check(state.train_recruit(ids[0]),"basic training available")
	check(not state.train_recruit(ids[0]),"basic training once")
	check(state.specialise(ids[0],"aegisbearer"),"approved class selectable")
	check(not state.specialise(ids[0],"chainbinder"),"class selection permanent")
	var new_id := state.recruit("one")
	check(not new_id.is_empty() and state.recruit("one").is_empty(),"recruit operations idempotent")
	var config := state.commit(state.offers[0].id,PackedStringArray([ids[0],ids[1]]))
	check(config!=null and config.survival_enabled and config.hero_ids[1]=="recruit","campaign configuration carries blueprint and individual identity")
	var people: Dictionary={}
	people[ids[0]]={"health":0,"maximum_health":10,"survival":"dead","death_cause":"bled out"}
	people[ids[1]]={"health":5,"maximum_health":10,"survival":"extracted","death_cause":""}
	var result := CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":"failure","abandoned":true,"reason":"Retreated","heroes":people,"rounds":4,"tactical_result":"ABANDONED"})
	var xp: int=state.heroes[ids[0]].experience
	check(state.resolve(result),"survival result accepted")
	check(state.heroes[ids[0]].dead and state.heroes[ids[0]].experience==xp,"death persists without XP")
	check(not state.resolve(result),"duplicate result rejected")
	check(not state.living_ids().has(ids[0]),"dead hero excluded from deployment")
	var saved := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"debrief"))
	check(saved.state!=null,"permanent death debrief roundtrip: "+saved.error)
	var depleted := CampaignState.new(94)
	depleted.supplies=0
	var party := PackedStringArray(depleted.living_ids().slice(0,2))
	depleted.commit(depleted.offers[0].id,party)
	var lost: Dictionary={}
	for id: String in party: lost[id]={"health":0,"maximum_health":10,"survival":"dead","death_cause":"bled out"}
	for id: String in depleted.living_ids():
		if not party.has(id): depleted.heroes[id].dead=true
	depleted.resolve(CampaignMissionResult.new({"version":2,"mission_id":depleted.active.id,"outcome":"failure","abandoned":false,"reason":"Defeat","heroes":lost,"rounds":5,"tactical_result":"FAILURE"}))
	check(depleted.ending=="defeat","depleted unfunded roster ends explicitly")
	var ended := CampaignSaveCodec.decode(CampaignSaveCodec.encode(depleted,"complete"))
	check(ended.state!=null,"roster defeat saves below maximum threat: "+ended.error)
	var recovery := CampaignState.new(12)
	var last := recovery.living_ids()[0]
	for other in recovery.living_ids():
		if other!=last: recovery.heroes[other].dead=true
	recovery.supplies=20
	check(recovery.purchase("broadwatch").is_empty() and recovery.supplies==20,"Essential replacement supplies cannot be spent on gear")
	check(not recovery.recruit("replacement").is_empty() and recovery.living_ids().size()==2,"Replacement remains affordable and deployable")
	print("Roster campaign RESULT: %d failures" % failures); quit(1 if failures else 0)
