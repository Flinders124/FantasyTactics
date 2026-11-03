extends "res://tests/campaign_tests.gd"
func run() -> void:
	var started:=Time.get_ticks_usec()
	check(ResourceLoader.exists("res://scripts/mission_template.gd"),"Editable mission template resource exists")
	check(ResourceLoader.exists("res://scripts/mission_catalog.gd"),"Deterministic mission catalog exists")
	var catalog := MissionCatalog.all()
	check(catalog.size()==9,"Nine authored templates load")
	var ids: PackedStringArray=[]
	var compositions:=0
	for template in catalog:
		check(template!=null and template.validation_error().is_empty(),"Valid template: "+str(template.stable_id))
		check(not ids.has(template.stable_id),"Template IDs unique"); ids.append(template.stable_id)
		for faction in FactionCatalog.ids():
			for difficulty in EncounterOptions.difficulties():
				for stage in range(template.minimum_stage,template.maximum_stage+1):
					var first:=MissionCatalog.compose(template,faction,difficulty.stable_id,stage,17)
					var second:=MissionCatalog.compose(template,faction,difficulty.stable_id,stage,17)
					check(first==second and FactionCatalog.valid_roster(first,faction,difficulty.stable_id,stage,template.elite),"Composition deterministic, bounded, within budget")
					for id in first:
						check(EnemyCatalog.find(id).is_elite or EnemyCatalog.find(id).introduction_stage<=maxi(stage,FactionCatalog.find(faction).introduction_stage),"Regular introduction stage respected")
					compositions+=1
	var invalid:=catalog[0].duplicate(true) as MissionTemplate
	invalid.layout_ids=["missing"]
	check(invalid.validation_error().contains("Unknown battlefield"),"Missing layout rejected clearly")
	invalid=catalog[0].duplicate(true); invalid.objective_id="protect_unsupported"
	check(invalid.validation_error().contains("Unsupported mission objective"),"Unsupported objective rejected")
	invalid=catalog[0].duplicate(true); invalid.role_pattern=["dragon","front"]
	check(invalid.validation_error().contains("Unknown composition role"),"Unknown role rejected")
	invalid=catalog[0].duplicate(true); invalid.faction_ids=["missing"]
	check(invalid.validation_error().contains("Unknown enemy faction"),"Missing faction reference rejected")
	invalid=catalog[0].duplicate(true); invalid.version=99
	check(invalid.validation_error().contains("version"),"Unsupported template version rejected")
	var state: CampaignState = LegacyCampaignFixture.new(17,"standard")
	var identical: CampaignState = LegacyCampaignFixture.new(17,"standard")
	check(state.offers==identical.offers and state.offers.size()==3,"Seed reproduces three complete offers")
	var frozen:=state.offers.duplicate(true)
	state.generate_offers(); check(state.offers==frozen,"Board refresh does not reroll")
	var seen: PackedStringArray=[]
	for offer in state.offers:
		check(offer.has("template") and MissionCatalog.metadata_valid(offer.template),"New offer freezes template metadata")
		check(not seen.has(offer.template.id),"Board offers different templates"); seen.append(offer.template.id)
		var config:=state.prepare(offer.id,["knight","ranger"])
		check(config!=null and config.validation_error().is_empty(),"Template offer prepares legal encounter")
		var replay:=EncounterCode.decode(EncounterCode.encode(config)).configuration
		check(replay!=null and replay.resolved_enemy_ids==config.resolved_enemy_ids and replay.generator_settings.preset_id==config.generator_settings.preset_id,"Encounter-code replay freezes roster/layout")
	var saved:=CampaignSaveCodec.encode(state,"headquarters")
	var restored:=CampaignSaveCodec.decode(saved)
	check(restored.state!=null and restored.state.offers==state.offers,"New offers survive save roundtrip without reroll")
	var template:=MissionCatalog.find(state.offers[0].template.id)
	var old_description:=template.description
	template.description="Edited authoring description"
	var after_edit:=CampaignSaveCodec.decode(saved)
	check(after_edit.state!=null and after_edit.state.offers==frozen,"Template authoring edits do not rewrite frozen offers")
	template.description=old_description
	state.offers[0].template.version=99
	var rejected:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
	check(rejected.state==null and rejected.error.contains("mission template"),"Future template version rejected transactionally with a readable reason")
	state.offers=frozen
	var config:=state.commit(state.offers[0].id,["knight","ranger"])
	check(config!=null,"Mission commits")
	var interrupted:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"in_progress"))
	check(interrupted.state!=null,"Interrupted template mission checkpoint loads")
	if interrupted.state!=null:
		var resumed:=CampaignSaveCodec.resume(interrupted.state)
		check(resumed!=null and resumed.resolved_enemy_ids==config.resolved_enemy_ids and resumed.battlefield_seed==config.battlefield_seed,"Interrupted mission resumes frozen initial configuration")
	var result:=record(state)
	check(state.resolve(result) and not state.resolve(result) and state.victories==1,"Template rewards process exactly once")
	check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"debrief")).state!=null,"Template result/debrief persists")
	# Shipped v1 fixture remains the compatibility authority, not a regenerated board.
	var legacy:=CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/legacy_campaign_v1.json"))
	check(legacy.state!=null,"Existing shipped v1 campaign remains supported")
	if legacy.state!=null:
		var old:=legacy.state.offers.duplicate(true)
		var again:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(legacy.state,legacy.phase))
		check(again.state!=null and again.state.offers==old,"Legacy offer records preserved byte-for-value on resave")
	print("MISSION TEMPLATE RESULT: %d failures; %d composition cases; %.2f ms"%[failures,compositions,float(Time.get_ticks_usec()-started)/1000]); quit(0 if failures==0 else 1)
