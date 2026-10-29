extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var config:=EncounterConfiguration.new()
	config.faction_id="ashfang"; config.campaign_stage=3; config.battlefield_seed=17
	config.difficulty=EncounterOptions.difficulties()[1]
	config.generator_settings=EncounterOptions.presets()[4]
	config.resolved_enemy_ids=MissionCatalog.compose(MissionCatalog.find("bowline"),config.faction_id,config.difficulty.stable_id,3,17)
	config.enemies.clear()
	for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true))
	var code:=EncounterCode.encode(config)
	var selection:=PartySelection.new()
	check(selection.import_code(code),"Purposeful-composition code imports")
	var replay:=selection.configuration(99)
	check(replay!=null and replay.resolved_enemy_ids==config.resolved_enemy_ids,"Start after importing code retains frozen purposeful roster")
	check(replay!=null and replay.generator_settings.preset_id==config.generator_settings.preset_id,"Start retains selected new layout")
	selection.seed_text="18"; selection.edited()
	var varied:=selection.configuration(18)
	check(varied!=null and varied.resolved_enemy_ids==FactionCatalog.roster("ashfang","standard",3,false,18),"Explicit new seed produces a new standard variation")
	var bowline:=MissionCatalog.compose(MissionCatalog.find("bowline"),"hollow","hard",1,17)
	check(bowline.has("hollow_archer"),"Ranged-heavy templates select archers rather than filling ranged slots with casters")
	var state: CampaignState = LegacyCampaignFixture.new(17,"standard")
	state.offers[0].template.version=99
	var rejected:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
	check(rejected.state==null and rejected.error.contains("mission template"),"Unsupported template metadata gives a readable rejection without runtime errors")
	print("MISSION REPLAY RESULT: %d failures"%failures); quit(0 if failures==0 else 1)
