extends "res://tests/ai_simulation_tests.gd"
## Real campaign offers, real combat rules; only fixture presentation is sped up.
var mission_details: Dictionary={}
func _initialize() -> void:
	var methods: Array[Dictionary]=load("res://tests/ai_simulation_tests.gd").get_script_method_list()
	if not methods.any(func(method: Dictionary) -> bool: return method.name=="mission_configuration"):
		push_error("Shared simulation must use authored mission configurations")
		print("MISSION SIMULATION RESULT: 1 failures"); quit(1); return
	super._initialize()
func mission_configuration(index: int) -> EncounterConfiguration:
	var difficulty:=EncounterOptions.difficulties()[int(index/5)%3].stable_id
	var state: CampaignState = LegacyCampaignFixture.new(8100+index,difficulty)
	var stage:=index%5
	for previous in range(stage):
		state.commit(state.offers[0].id,["knight","ranger"])
		var people: Dictionary={}
		for id: String in state.active.party: people[id]={"health":20,"maximum_health":20}
		var result:=CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Mission simulation stage fixture","heroes":people,"rounds":2,"tactical_result":"VICTORY"})
		check(state.resolve(result),"Campaign stage fixture resolves through real result pipeline")
	var offer:=state.offers[int(index/15)%state.offers.size()]
	mission_details=offer.template.duplicate(true)
	mission_details.campaign_seed=state.seed_value
	return state.prepare(offer.id,PackedStringArray(PAIRS[index%6]))
func dispose(encounter: CombatEncounter) -> void:
	check(not encounter.configuration.deployment_id.is_empty(),"Simulation used authored campaign mission rather than generic fixture")
	if not results.is_empty(): results[-1].reproduction["template"]=mission_details.duplicate(true)
	await super.dispose(encounter)
