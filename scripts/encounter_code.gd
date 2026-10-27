class_name EncounterCode
extends RefCounted
## Versioned configuration sharing, never a save or arbitrary Resource loader.
const PREFIX: String = "FT1"
const MAX_CODE: int = 8192
const MAX_JSON: int = 32768
const SETTINGS: PackedStringArray = ["preset_id","display_name","generator_version","arena_size","obstacle_count","obstacle_min_size","obstacle_max_size","obstacle_height","clearance","boundary_margin","spawn_zone_size","spawn_spacing","opposing_separation","placement_attempts","generation_attempts","dressing_seed_offset","vegetation_density","rubble_density","detail_density"]
const OBJECTIVE: PackedStringArray = ["stable_id","display_name","description","kind","radius","required_rounds","minimum_exit_travel","positioning_weight"]
const DIFFICULTY: PackedStringArray = ["stable_id","display_name","description","configuration_version","enemy_health_multiplier","enemy_damage_multiplier","elimination_roster","hold_roster","extraction_roster","alternate_roster","candidate_limit","raw_candidate_limit","path_query_limit","action_query_limit","ring_samples"]
class Decoded extends RefCounted:
	var configuration: EncounterConfiguration
	var error: String = ""

static func properties(resource: Resource, keys: PackedStringArray) -> Dictionary:
	var result: Dictionary={}
	for key in keys:
		var value: Variant=resource.get(key)
		if value is Vector2: value=[value.x,value.y]
		elif value is PackedStringArray: value=Array(value)
		result[key]=value
	return result

static func content(resource: Resource) -> Dictionary:
	var result: Dictionary={}
	for property in resource.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0 or (int(property.usage)&PROPERTY_USAGE_STORAGE)==0: continue
		var value: Variant=resource.get(property.name)
		# New default metadata must not change fingerprints of shipped v1 units.
		if property.name in ["enemy_id","faction_id","role_icon","strengths","weaknesses"] and value=="": continue
		if property.name in ["is_elite","telegraphed"] and value==false: continue
		if property.name=="encounter_cost" and value==1: continue
		if property.name=="introduction_stage" and value==0: continue
		if value is Resource: value=content(value)
		elif value is Array:
			var values: Array=[]
			for item in value: values.append(content(item) if item is Resource else item)
			value=values
		result[property.name]=value
	return result

static func fingerprint(resource: Resource) -> String:
	return JSON.stringify(content(resource)).sha256_text().substr(0,16)

static func encode(config: EncounterConfiguration) -> String:
	if config==null or not config.validation_error().is_empty(): return ""
	var roster_hash: Array[String]=[]
	var hero_hash: Array[String]=[]
	for definition in config.enemies: roster_hash.append(fingerprint(definition))
	for id in config.hero_ids: hero_hash.append(fingerprint(HeroCatalog.find(id)))
	var data := {"v":1 if config.faction_id=="legacy" else 2,"engine":Engine.get_version_info().hex,"heroes":Array(config.hero_ids),"hero_hash":hero_hash,"seed":config.battlefield_seed,"attempt":config.layout.attempt if config.layout!=null else config.requested_attempt,"roster_version":config.roster_version,"roster":Array(config.resolved_enemy_ids),"roster_hash":roster_hash,"generator":properties(config.generator_settings,SETTINGS),"objective":properties(config.objective,OBJECTIVE),"difficulty":properties(config.difficulty,DIFFICULTY)}
	if config.faction_id!="legacy": data["faction"]={"id":config.faction_id,"stage":config.campaign_stage,"elite":config.elite_encounter}
	var bytes := JSON.stringify(data).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var payload := Marshalls.raw_to_base64(bytes).replace("+","-").replace("/","_").replace("=","")
	return PREFIX+"."+payload+"."+payload.sha256_text().substr(0,8)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value: Variant, minimum: float, maximum: float) -> bool:
	return _number(value) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

static func assign_checked(resource: Resource, data: Variant, keys: PackedStringArray) -> bool:
	if not data is Dictionary or data.size()!=keys.size(): return false
	for key in keys:
		if not data.has(key): return false
		var before: Variant=resource.get(key)
		var value: Variant=data[key]
		if before is Vector2:
			if not value is Array or value.size()!=2 or not _number(value[0]) or not _number(value[1]): return false
			resource.set(key,Vector2(float(value[0]),float(value[1])))
		elif before is PackedStringArray:
			if not value is Array or value.size()>2: return false
			for item in value:
				if not item is String or item.length()>32: return false
			resource.set(key,PackedStringArray(value))
		elif before is int:
			if not _whole(value,-2147483648,4294967295): return false
			resource.set(key,int(value))
		elif before is float:
			if not _number(value): return false
			resource.set(key,float(value))
		elif before is String:
			if not value is String or value.length()>(400 if key=="description" else 80): return false
			resource.set(key,value)
		else: return false
	return true

static func decode(code: String) -> Decoded:
	var result := Decoded.new()
	result.error="Malformed encounter code. Copy the whole FT1 code."
	code=code.strip_edges()
	if code.length()>MAX_CODE or code.length()<16: return result
	var pieces := code.split(".")
	if pieces.size()!=3: return result
	if pieces[0]!=PREFIX:
		result.error="Unsupported encounter-code version."
		return result
	var payload: String=pieces[1]
	if payload.length()%4==1 or pieces[2]!=payload.sha256_text().substr(0,8):
		result.error="Encounter-code checksum failed. Copy it again."
		return result
	for index in range(payload.length()):
		var character := payload.unicode_at(index)
		if not (character>=65 and character<=90 or character>=97 and character<=122 or character>=48 and character<=57 or character==45 or character==95): return result
	var base64 := payload.replace("-","+").replace("_","/")
	while base64.length()%4!=0: base64+="="
	var bytes := Marshalls.base64_to_raw(base64)
	# Reject unsupported/corrupt zlib framing before invoking the bounded
	# decompressor. No arbitrary variant/object deserialization is used.
	if bytes.size()<6 or (int(bytes[0])&15)!=8 or ((int(bytes[0])<<8)+int(bytes[1]))%31!=0 or (int(bytes[1])&32)!=0: return result
	var json_bytes := bytes.decompress_dynamic(MAX_JSON,FileAccess.COMPRESSION_DEFLATE)
	if json_bytes.is_empty() or json_bytes.size()>MAX_JSON: return result
	var parser := JSON.new()
	if parser.parse(json_bytes.get_string_from_utf8())!=OK: return result
	var data: Variant=parser.data
	if not data is Dictionary or data.size() not in [12,13]: return result
	for key in ["v","engine","heroes","hero_hash","seed","attempt","roster_version","roster","roster_hash","generator","objective","difficulty"]:
		if not data.has(key): return result
	# Exact schema and engine/content versions prevent silently different battles.
	if (data.v!=1 and data.v!=2) or data.engine!=Engine.get_version_info().hex or data.roster_version!=EnemyCatalog.VERSION:
		result.error="Unsupported engine or encounter-definition version."
		return result
	if not _whole(data.seed,0,4294967295) or not _whole(data.attempt,0,9): return result
	if not data.heroes is Array or data.heroes.size()!=2 or not data.roster is Array or data.roster.size()<2 or data.roster.size()>4: return result
	if not data.hero_hash is Array or data.hero_hash.size()!=2 or not data.roster_hash is Array or data.roster_hash.size()!=data.roster.size(): return result
	for id: Variant in data.roster:
		if not id is String or EnemyCatalog.find(id)==null: return result
	for index in range(data.roster.size()):
		if data.roster_hash[index]!=fingerprint(EnemyCatalog.find(data.roster[index])):
			result.error="Enemy definitions differ from this code."; return result
	for index in range(2):
		if not data.heroes[index] is String or not data.roster[index] is String: return result
		var hero := HeroCatalog.find(data.heroes[index])
		var enemy := EnemyCatalog.find(data.roster[index])
		if hero==null or enemy==null: return result
		if data.hero_hash[index]!=fingerprint(hero) or data.roster_hash[index]!=fingerprint(enemy):
			result.error="Unit definitions differ from this code. Use the matching game version."
			return result
	var config := EncounterConfiguration.new()
	if data.v==2:
		if data.size()!=13 or not data.get("faction") is Dictionary or data.faction.size()!=3: return result
		if not data.faction.get("id") is String or FactionCatalog.find(data.faction.id)==null or not _whole(data.faction.get("stage"),0,4) or not data.faction.get("elite") is bool: return result
		config.faction_id=data.faction.id; config.campaign_stage=int(data.faction.stage); config.elite_encounter=data.faction.elite
	elif data.size()!=12: return result
	config.generator_settings=BattlefieldSettings.new()
	config.objective=ObjectiveDefinition.new()
	config.difficulty=DifficultyDefinition.new()
	if not assign_checked(config.generator_settings,data.generator,SETTINGS) or not assign_checked(config.objective,data.objective,OBJECTIVE) or not assign_checked(config.difficulty,data.difficulty,DIFFICULTY): return result
	if not config.generator_settings.valid() or config.generator_settings.generation_attempts<1 or config.generator_settings.generation_attempts>8 or config.generator_settings.placement_attempts<1 or config.generator_settings.placement_attempts>200: return result
	if config.generator_settings.obstacle_height.y>4 or config.generator_settings.clearance>4 or config.generator_settings.opposing_separation>20: return result
	for value in [config.generator_settings.detail_density,config.generator_settings.vegetation_density,config.generator_settings.rubble_density]:
		if not is_finite(value) or value<0 or value>2: return result
	var expected_kind := ["elimination","hold_ground","extraction"].find(config.objective.stable_id)
	if expected_kind<0 or expected_kind!=config.objective.kind or config.objective.radius<1.5 or config.objective.radius>5 or config.objective.required_rounds<1 or config.objective.required_rounds>10 or config.objective.minimum_exit_travel<6 or config.objective.minimum_exit_travel>25 or config.objective.positioning_weight<0 or config.objective.positioning_weight>20: return result
	config.hero_ids=PackedStringArray(data.heroes)
	config.battlefield_seed=int(data.seed)
	config.requested_attempt=int(data.attempt)
	if not config.difficulty.valid(): return result
	if data.v==2:
		config.resolved_enemy_ids=PackedStringArray(data.roster)
		config.enemies.clear()
		for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
	else: config.resolve_roster()
	if Array(config.resolved_enemy_ids)!=data.roster:
		result.error="Roster does not match the difficulty template and seed."
		return result
	result.error=config.validation_error()
	if result.error.is_empty(): result.configuration=config
	return result
