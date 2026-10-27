class_name CampaignSaveCodec
extends RefCounted
## Untrusted JSON boundary. Never deserializes objects or loads paths from a save.
const VERSION: int=1
const MAX_BYTES: int=1048576
static var _content_hash: String=""
const FIELDS: PackedStringArray=["campaign_id","heroes","offers","active","processed","history","victories","resolutions","threat","supplies","ending","inventory","next_item","used_operations","last_debrief"]
class Decoded extends RefCounted:
	var state: CampaignState
	var phase: String=""
	var error: String="Invalid or incomplete campaign save."
	var saved_at: int=0

static func content_hash() -> String:
	if not _content_hash.is_empty(): return _content_hash
	var values: PackedStringArray=[]
	values.append(EncounterCode.fingerprint(load("res://definitions/campaign/lantern_watch.tres")))
	for definition in HeroCatalog.definitions(): values.append(EncounterCode.fingerprint(definition))
	for definition in EncounterOptions.difficulties(): values.append(EncounterCode.fingerprint(definition))
	for definition in EncounterOptions.presets(): values.append(EncounterCode.fingerprint(definition))
	for definition in EncounterOptions.objectives(): values.append(EncounterCode.fingerprint(definition))
	for id: String in ["raider","sentinel"]: values.append(EncounterCode.fingerprint(EnemyCatalog.find(id)))
	_content_hash="|".join(values).sha256_text()
	return _content_hash

static func encode(state: CampaignState,phase: String) -> String:
	if state==null: return ""
	var payload := JSON.stringify({"version":VERSION,"rules_id":"lantern_watch","content":content_hash(),"phase":phase,"saved_at":int(Time.get_unix_time_from_system()),"state":state.snapshot()})
	return JSON.stringify({"version":VERSION,"payload":payload,"sha256":payload.sha256_text()})

static func whole(value: Variant,minimum: int,maximum: int) -> bool:
	return EncounterCode._whole(value,minimum,maximum)

static func object(value: Variant,keys: PackedStringArray) -> bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

static func strings(value: Variant,limit: int,length: int=256) -> bool:
	if not value is Array or value.size()>limit: return false
	for entry in value:
		if not entry is String or entry.length()>length: return false
	return true

static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value: result[key]=normalize(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for entry: Variant in value: result.append(normalize(entry))
		return result
	if value is float and is_finite(value) and absf(value)<9007199254740991.0 and value==floor(value): return int(value)
	return value

static func apply_snapshot(state: CampaignState,data: Dictionary) -> void:
	for field in FIELDS:
		if field=="history": state.history.assign(data.history)
		elif field=="offers": state.offers.assign(data.offers.duplicate(true))
		else: state.set(field,data[field].duplicate(true) if data[field] is Dictionary or data[field] is Array else data[field])

static func decode(text: String) -> Decoded:
	var result := Decoded.new()
	if text.to_utf8_buffer().size()>MAX_BYTES: return result
	var parser := JSON.new()
	if parser.parse(text)!=OK or not parser.data is Dictionary: return result
	var envelope: Dictionary=parser.data
	if envelope.get("version")!=VERSION:
		result.error="Unsupported campaign save version. Use the matching game version; the file was not changed."
		return result
	if not object(envelope,["version","payload","sha256"]) or not envelope.payload is String or not envelope.sha256 is String: return result
	if envelope.payload.sha256_text()!=envelope.sha256:
		result.error="Campaign checksum failed. The file may be truncated or damaged."
		return result
	if parser.parse(envelope.payload)!=OK: return result
	var data: Variant=normalize(parser.data)
	if not object(data,["version","rules_id","content","phase","saved_at","state"]): return result
	if data.version!=VERSION or data.rules_id!="lantern_watch" or data.content!=content_hash():
		result.error="Campaign rules or definitions differ from this save. Use the matching game version; no file was changed."
		return result
	if not data.phase is String or data.phase not in ["headquarters","debrief","in_progress","complete"] or not whole(data.saved_at,0,4102444800): return result
	var snapshot: Variant=data.state
	var keys := FIELDS.duplicate(); keys.append_array(["version","rules_version","seed","difficulty"])
	if not object(snapshot,keys): return result
	if snapshot.version!=CampaignState.VERSION or not whole(snapshot.seed,0,4294967295) or not snapshot.difficulty is String or snapshot.difficulty not in ["easy","standard","hard"]: return result
	if not snapshot.campaign_id is String or snapshot.campaign_id.length()!=32 or not snapshot.campaign_id.is_valid_hex_number(): return result
	var candidate := CampaignState.new(snapshot.seed,snapshot.difficulty,null,true)
	if snapshot.rules_version!=candidate.rules.version: return result
	var error := validate_state(snapshot,candidate)
	if not error.is_empty(): result.error=error; return result
	if data.phase=="in_progress" and (snapshot.active.is_empty() or not snapshot.ending.is_empty()): return result
	if data.phase!="in_progress" and not snapshot.active.is_empty(): return result
	if data.phase=="complete" and (snapshot.ending.is_empty() or snapshot.last_debrief.is_empty()): return result
	if data.phase!="complete" and not snapshot.ending.is_empty(): return result
	if data.phase=="debrief" and snapshot.last_debrief.is_empty(): return result
	apply_snapshot(candidate,snapshot)
	result.state=candidate; result.phase=data.phase; result.saved_at=data.saved_at; result.error=""
	return result

static func validate_state(data: Dictionary,base: CampaignState) -> String:
	var invalid := "Campaign data has invalid values or missing definition references. No progress was loaded."
	if not whole(data.resolutions,0,10000) or not whole(data.victories,0,base.rules.victories_required) or data.victories>data.resolutions: return invalid
	if not whole(data.threat,0,base.rules.threat_maximum) or not whole(data.supplies,0,1000000) or data.ending not in ["","victory","defeat"]: return invalid
	if data.ending=="victory" and data.victories!=base.rules.victories_required: return invalid
	if data.ending=="defeat" and data.threat!=base.rules.threat_maximum: return invalid
	if data.ending=="" and (data.threat==base.rules.threat_maximum or data.victories==base.rules.victories_required): return invalid
	if not object(data.heroes,["knight","ranger","mage","cleric"]) or not data.inventory is Dictionary or data.inventory.size()>1000 or not whole(data.next_item,9,10000): return invalid
	var equipped: Dictionary={}
	for instance: Variant in data.inventory:
		if not instance is String or not instance.begins_with("gear-") or not instance.trim_prefix("gear-").is_valid_int(): return invalid
		var sequence: int=instance.trim_prefix("gear-").to_int()
		if sequence<1 or sequence>=data.next_item or instance!="gear-%04d"%sequence: return invalid
		var record: Variant=data.inventory[instance]
		if not object(record,["id","definition_id"]) or record.id!=instance or not record.definition_id is String or base.item(record.definition_id)==null: return invalid
	for id: String in data.heroes:
		var hero: Variant=data.heroes[id]
		if not object(hero,["id","experience","level","upgrades","injury","equipment","medical_at"]) or hero.id!=id: return invalid
		if not whole(hero.experience,0,1000000) or not whole(hero.level,1,4) or not whole(hero.medical_at,-1,data.resolutions): return invalid
		var level: int=1
		for index in range(base.rules.xp_thresholds.size()):
			if hero.experience>=base.rules.xp_thresholds[index]: level=index+1
		if hero.level!=level or not strings(hero.upgrades,3,64) or not hero.equipment is Dictionary or hero.equipment.size()>2 or not hero.injury is Dictionary: return invalid
		var learned: Dictionary={}
		for choice: String in hero.upgrades:
			var definition := base.upgrade(choice)
			if definition==null or definition.hero_id!=id or definition.required_level>level or learned.has(definition.required_level): return invalid
			learned[definition.required_level]=true
		for required in range(2,2+hero.upgrades.size()):
			if not learned.has(required): return invalid
		if not hero.injury.is_empty():
			if not object(hero.injury,["name","remaining"]) or hero.injury.name not in ["Severe injury","Battle strain"] or not whole(hero.injury.remaining,1,base.rules.severe_duration): return invalid
		for slot: Variant in hero.equipment:
			var instance: Variant=hero.equipment[slot]
			if slot not in ["weapon","garb"] or not instance is String or not data.inventory.has(instance) or equipped.has(instance): return invalid
			var item := base.item(data.inventory[instance].definition_id)
			if item.slot!=slot or not item.compatible_heroes.has(id): return invalid
			equipped[instance]=id
	if not data.offers is Array or data.offers.size()>3 or not data.active is Dictionary or not data.processed is Dictionary or data.processed.size()!=data.resolutions or not data.used_operations is Dictionary or data.used_operations.size()>1000: return invalid
	var processed_rounds: Dictionary={}
	for key: Variant in data.processed:
		if not key is String or not valid_mission_id(key,data.seed) or data.processed[key]!=true: return invalid
		var resolution: int=key.split("-")[1].to_int()
		if resolution>=data.resolutions or processed_rounds.has(resolution): return invalid
		processed_rounds[resolution]=true
	for key: Variant in data.used_operations:
		if not key is String or key.length()>128 or data.used_operations[key]!=true: return invalid
	if not strings(data.history,256,2048) or not data.last_debrief is Dictionary: return invalid
	var ids: Dictionary={}
	for offer: Variant in data.offers:
		if not valid_offer(offer,base,data.seed,data.resolutions) or ids.has(offer.id) or data.processed.has(offer.id): return invalid
		if offer.final!=(data.victories==base.rules.victories_required-1) or (offer.final and offer.recovery): return invalid
		ids[offer.id]=offer
	if data.ending.is_empty() and data.offers.size()!=(1 if data.victories==4 else 3): return invalid
	if not data.ending.is_empty() and not data.offers.is_empty(): return invalid
	if not data.active.is_empty():
		if not valid_offer(data.active,base,data.seed,data.resolutions,true) or not ids.has(data.active.id) or data.processed.has(data.active.id): return invalid
		for key: String in ids[data.active.id]:
			if data.active.get(key)!=ids[data.active.id][key]: return invalid
		if not strings(data.active.party,2,32) or data.active.party.size()!=2 or data.active.party[0]==data.active.party[1]: return invalid
		for id: String in data.active.party:
			if not data.heroes.has(id): return invalid
		if not valid_encounter(data.active,base): return invalid
	if not data.last_debrief.is_empty():
		var debrief: Dictionary=data.last_debrief
		if not object(debrief,["mission","result","lines","ending"]) or not debrief.mission is Dictionary or not debrief.result is Dictionary or not strings(debrief.lines,80,2048) or debrief.ending!=data.ending: return invalid
		var record: Dictionary=debrief.result
		if not object(record,["version","mission_id","outcome","abandoned","reason","heroes","rounds","tactical_result"]) or record.version!=1 or not record.mission_id is String or not data.processed.has(record.mission_id): return invalid
		if not record.abandoned is bool or record.outcome not in ["victory","failure"] or not record.reason is String or record.reason.length()>1024 or not record.tactical_result is String or record.tactical_result.length()>32 or not whole(record.rounds,0,10000): return invalid
		if not record.heroes is Dictionary or record.heroes.size()!=2 or not debrief.mission.has("party") or not strings(debrief.mission.party,2,32) or debrief.mission.party.size()!=2: return invalid
		if debrief.mission.get("id")!=record.mission_id or debrief.mission.party[0]==debrief.mission.party[1]: return invalid
		for id: Variant in record.heroes:
			var hero: Variant=record.heroes[id]
			if not data.heroes.has(id) or not debrief.mission.party.has(id) or not object(hero,["health","maximum_health"]) or not whole(hero.maximum_health,1,99) or not whole(hero.health,0,hero.maximum_health): return invalid
		if not valid_offer(debrief.mission,base,data.seed,data.resolutions-1,true) or not valid_encounter(debrief.mission,base): return invalid
	return ""

static func valid_mission_id(id: String,seed_value: int) -> bool:
	var pieces := id.split("-")
	return pieces.size()==3 and pieces[0]=="%08x"%seed_value and pieces[1].is_valid_int() and pieces[1].to_int()>=0 and pieces[1].to_int()<10000 and pieces[2] in ["0","1","2"]

static func valid_offer(offer: Variant,base: CampaignState,seed_value: int,resolution: int,committed: bool=false) -> bool:
	var keys: PackedStringArray=["id","name","seed","preset","objective","recovery","final","supplies","ignored","code"]
	if committed: keys.append_array(["party","configuration_seed","encounter"])
	if offer is Dictionary and offer.has("faction"): keys.append_array(["faction","stage","elite"])
	if not object(offer,keys) or not offer.id is String or not valid_mission_id(offer.id,seed_value): return false
	if offer.id.split("-")[1].to_int()!=resolution or not offer.name is String or offer.name.length()>100 or not offer.code is String: return false
	if not whole(offer.seed,0,4294967295) or not whole(offer.preset,0,2) or not whole(offer.objective,0,2) or not offer.recovery is bool or not offer.final is bool: return false
	var bonus: int=0
	if offer.has("faction"):
		if not offer.faction is String or FactionCatalog.find(offer.faction)==null or not whole(offer.stage,0,4) or not offer.elite is bool: return false
		if offer.elite: bonus=FactionCatalog.find(offer.faction).elite_supplies_bonus
	if offer.supplies!=(base.rules.recovery_supplies if offer.recovery else base.rules.mission_supplies)+bonus or offer.ignored!=(0 if offer.recovery or offer.final else base.rules.ignored_threat): return false
	var decoded := EncounterCode.decode(offer.code)
	if decoded.configuration==null: return false
	var config := decoded.configuration
	if offer.has("faction") and (config.faction_id!=offer.faction or config.campaign_stage!=offer.stage or config.elite_encounter!=offer.elite): return false
	if not offer.has("faction") and config.faction_id!="legacy": return false
	var expected_difficulty := base.difficulty().duplicate(true) as DifficultyDefinition
	if offer.final:
		expected_difficulty.enemy_health_multiplier=minf(1.5,expected_difficulty.enemy_health_multiplier*base.rules.final_enemy_multiplier)
		expected_difficulty.enemy_damage_multiplier=minf(1.5,expected_difficulty.enemy_damage_multiplier*base.rules.final_enemy_multiplier)
	if not same_properties(config.generator_settings,EncounterOptions.presets()[offer.preset],EncounterCode.SETTINGS): return false
	if not same_properties(config.objective,EncounterOptions.objectives()[offer.objective],EncounterCode.OBJECTIVE): return false
	return config.battlefield_seed==offer.seed and same_properties(config.difficulty,expected_difficulty,EncounterCode.DIFFICULTY)

static func same_properties(first: Resource,second: Resource,keys: PackedStringArray) -> bool:
	# Canonical JSON uses the same numeric precision as the stored encounter code.
	return JSON.stringify(EncounterCode.properties(first,keys))==JSON.stringify(EncounterCode.properties(second,keys))

static func valid_encounter(mission: Dictionary,base: CampaignState) -> bool:
	var info: Variant=mission.encounter
	var required: PackedStringArray=["seed","preset","generator_version","objective","difficulty","difficulty_version","health_multiplier","damage_multiplier","enemy_ids","code"]
	if not info is Dictionary: return false
	var keys := required.duplicate()
	if info.has("generation_attempt"): keys.append("generation_attempt")
	if info.has("layout_signature"): keys.append("layout_signature")
	if not object(info,keys) or not info.code is String: return false
	var decoded := EncounterCode.decode(info.code)
	if decoded.configuration==null: return false
	var config := decoded.configuration
	var offer := EncounterCode.decode(mission.code).configuration
	if offer==null or config.faction_id!=offer.faction_id or config.campaign_stage!=offer.campaign_stage or config.elite_encounter!=offer.elite_encounter or config.resolved_enemy_ids!=offer.resolved_enemy_ids or not same_properties(config.generator_settings,offer.generator_settings,EncounterCode.SETTINGS) or not same_properties(config.objective,offer.objective,EncounterCode.OBJECTIVE) or not same_properties(config.difficulty,offer.difficulty,EncounterCode.DIFFICULTY): return false
	if Array(config.hero_ids)!=mission.party or config.battlefield_seed!=mission.seed or mission.configuration_seed!=mission.seed or info.seed!=mission.seed: return false
	if info.preset!=config.generator_settings.preset_id or info.generator_version!=config.generator_settings.generator_version or info.objective!=config.objective.stable_id or info.difficulty!=base.difficulty_id or info.difficulty_version!=config.difficulty.configuration_version: return false
	if info.health_multiplier!=config.difficulty.enemy_health_multiplier or info.damage_multiplier!=config.difficulty.enemy_damage_multiplier or info.enemy_ids!=Array(config.resolved_enemy_ids): return false
	if info.has("generation_attempt") and (not whole(info.generation_attempt,1,9) or info.generation_attempt!=config.requested_attempt): return false
	if info.has("layout_signature") and (not info.layout_signature is String or info.layout_signature.length()>16384): return false
	return true

static func resume(state: CampaignState) -> EncounterConfiguration:
	if state.active.is_empty(): return null
	var decoded := EncounterCode.decode(state.active.encounter.code)
	if decoded.configuration==null: return null
	var config := decoded.configuration
	config.deployment_id=state.active.id; config.campaign_hero_ids=PackedStringArray(state.active.party)
	config.hero_overrides.clear()
	for id: String in state.active.party: config.hero_overrides.append(state.preview_definition(id))
	return config if config.validation_error().is_empty() else null



