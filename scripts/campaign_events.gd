class_name CampaignEvents
extends RefCounted
## Campaign-only decisions. Independent seeded streams never advance mission RNG.
const BACKGROUNDS: PackedStringArray=["ferryman","mason","herbalist","scribe","shepherd","courier","smith","gardener"]
const EVENTS: PackedStringArray=["salvage","herbs","watchfire","lessons","caravan","remembrance","rest","stores"]
const LIMIT: int=4
static func definition(id: String) -> CampaignEventDefinition:
	return load("res://definitions/campaign/events/"+id+".tres") as CampaignEventDefinition if EVENTS.has(id) else null
static func background(id: String) -> CampaignBackgroundDefinition:
	return load("res://definitions/campaign/backgrounds/"+id+".tres") as CampaignBackgroundDefinition if BACKGROUNDS.has(id) else null
static func initialise_hero(state: CampaignState,id: String,legacy: bool=false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=(state.seed_value ^ 0x4944454e ^ id.hash())&0x7fffffffffffffff
	state.heroes[id].identity={"background_id":BACKGROUNDS[int(rng.randi())%BACKGROUNDS.size()]}
	state.heroes[id].service=[]
	service(state,id,"record","Record begins here." if legacy else "Joined the Lantern Watch.")
static func service(state: CampaignState,id: String,kind: String,message: String) -> void:
	if not state.heroes[id].has("service"): initialise_hero(state,id,true)
	var entries: Array=state.heroes[id].service
	entries.append({"resolution":state.resolutions,"kind":kind,"text":message})
	while entries.size()>64: entries.pop_front()
static func participants(state: CampaignState,event: CampaignEventDefinition) -> PackedStringArray:
	var ids := state.living_ids(); ids.sort()
	if event.eligibility=="loss" and not state.heroes.values().any(func(hero: Dictionary) -> bool: return hero.dead): return []
	var result: PackedStringArray=[]
	for id: String in ids:
		if event.eligibility=="injured" and state.heroes[id].injury.is_empty(): continue
		if event.eligibility=="specialist" and state.blueprint_id(id)=="recruit": continue
		result.append(id)
	return result
static func freeze(state: CampaignState,event: CampaignEventDefinition) -> Dictionary:
	if not valid_definition(event): return {}
	var ids := participants(state,event)
	if ids.is_empty(): return {}
	var rng := RandomNumberGenerator.new()
	rng.seed=(state.seed_value ^ 0x45564e54 ^ (state.resolutions*65537) ^ event.stable_id.hash())&0x7fffffffffffffff
	var subject: String=ids[int(rng.randi())%ids.size()]
	# Recovery requires an actually injured subject even for mixed future content.
	var choices: Array=event.choices.duplicate(true)
	choices.append({"id":"decline","label":"Continue without accepting an offer","supplies":0,"recovery":0})
	return {"id":"camp-%08x-%04d"%[state.seed_value,state.resolutions],"template":event.stable_id,"revision":event.revision,"resolution":state.resolutions,"subject":subject,"name":state.hero_name(subject),"title":event.display_name,"description":event.description,"choices":choices}
static func offer(state: CampaignState) -> Dictionary:
	if state.resolutions<=0 or not state.ending.is_empty() or not state.active.is_empty() or not state.pending_event.is_empty() or state.event_records.size()>=LIMIT: return {}
	if state.event_records.any(func(entry: Dictionary) -> bool: return entry.resolution==state.resolutions): return {}
	var candidates: Array[CampaignEventDefinition]=[]
	for id: String in EVENTS:
		if state.event_records.any(func(entry: Dictionary) -> bool: return entry.template==id): continue
		var event := definition(id)
		if not participants(state,event).is_empty(): candidates.append(event)
	if candidates.is_empty(): return {}
	var rng := RandomNumberGenerator.new()
	rng.seed=(state.seed_value ^ 0x45564e54 ^ (state.resolutions*65537))&0x7fffffffffffffff
	return freeze(state,candidates[int(rng.randi())%candidates.size()])
static func choice_error(state: CampaignState,instance: String,choice_id: String) -> String:
	if not state.ending.is_empty() or not state.active.is_empty(): return "Camp decisions are available only between missions."
	var event: Dictionary=state.pending_event
	if event.is_empty() or event.id!=instance: return "This camp decision is no longer pending."
	var choice := find_choice(event,choice_id)
	if choice.is_empty(): return "Choose one of the displayed options."
	if choice_id=="decline": return ""
	if not state.living_ids().has(event.subject): return "This companion is no longer available. Decline to continue."
	if choice.supplies<0 and not state.can_spend(-int(choice.supplies)): return "Not enough spare Supplies; the recruitment reserve is protected."
	if state.supplies+int(choice.supplies)>1000000: return "The Supplies store is full."
	if choice.recovery>0 and state.heroes[event.subject].injury.is_empty(): return "This companion has already recovered. Choose another option or decline."
	return ""
static func find_choice(event: Dictionary,id: String) -> Dictionary:
	for choice: Dictionary in event.get("choices",[]):
		if choice.id==id: return choice
	return {}
static func effects(event: Dictionary,choice: Dictionary) -> String:
	var parts: PackedStringArray=[]
	if choice.supplies!=0: parts.append("%+d Supplies"%choice.supplies)
	if choice.recovery>0: parts.append("%s: recover %d existing injury step"%[event.name,choice.recovery])
	return "; ".join(parts) if not parts.is_empty() else "No resources spent or gained; no combat changes."
static func choose(state: CampaignState,instance: String,choice_id: String) -> bool:
	if not choice_error(state,instance,choice_id).is_empty() or state.resolved_events.has(instance): return false
	var event: Dictionary=state.pending_event
	var choice := find_choice(event,choice_id)
	state.supplies+=int(choice.supplies)
	if choice.recovery>0:
		var injury: Dictionary=state.heroes[event.subject].injury
		injury.remaining=maxi(0,int(injury.remaining)-int(choice.recovery))
		if injury.remaining==0: state.heroes[event.subject].injury={}
	var message: String=event.title+": "+choice.label+". "+effects(event,choice)
	state.event_records.append({"id":instance,"template":event.template,"revision":event.revision,"resolution":event.resolution,"subject":event.subject,"choice":choice_id,"text":message})
	state.resolved_events[instance]=true
	state.history.append(message)
	while state.history.size()>60: state.history.pop_front()
	service(state,event.subject,"camp",message)
	state.pending_event={}
	return true

static func valid_identity(hero: Dictionary,resolutions: int) -> bool:
	if not CampaignSaveCodec.object(hero.identity,["background_id"]) or not hero.identity.background_id is String or not BACKGROUNDS.has(hero.identity.background_id): return false
	if not hero.service is Array or hero.service.is_empty() or hero.service.size()>64: return false
	var previous: int=0
	for entry: Variant in hero.service:
		if not CampaignSaveCodec.object(entry,["resolution","kind","text"]) or not CampaignSaveCodec.whole(entry.resolution,previous,resolutions) or entry.kind not in ["record","mission","death","recovery","injury","upgrade","specialisation","camp"] or not entry.text is String or entry.text.length()>1024: return false
		previous=int(entry.resolution)
	return true
static func valid_frozen(event: Variant,data: Dictionary) -> bool:
	if not CampaignSaveCodec.object(event,["id","template","revision","resolution","subject","name","title","description","choices"]): return false
	if not event.template is String: return false
	var source := definition(event.template)
	if source==null or not CampaignSaveCodec.whole(event.revision,1,source.revision): return false
	if not event.title is String or event.title.is_empty() or event.title.length()>100 or not event.description is String or event.description.length()>2048: return false
	if not CampaignSaveCodec.whole(event.resolution,1,data.resolutions) or event.id!="camp-%08x-%04d"%[data.seed,event.resolution] or not event.subject is String or not data.heroes.has(event.subject) or event.name!=data.heroes[event.subject].name: return false
	if not valid_choices(event.choices,true): return false
	# Older authored revisions keep their bounded, displayed snapshot; never reprice an offer.
	if event.revision<source.revision: return true
	var expected: Array=source.choices.duplicate(true)
	expected.append({"id":"decline","label":"Continue without accepting an offer","supplies":0,"recovery":0})
	return event.title==source.display_name and event.description==source.description and event.choices==expected
static func valid_saved(data: Dictionary) -> bool:
	if not data.pending_event is Dictionary or not data.event_records is Array or data.event_records.size()>LIMIT or not data.resolved_events is Dictionary or data.resolved_events.size()!=data.event_records.size(): return false
	var seen: Dictionary={}; var templates: Dictionary={}
	for record: Variant in data.event_records:
		if not CampaignSaveCodec.object(record,["id","template","revision","resolution","subject","choice","text"]) or not record.template is String: return false
		var source := definition(record.template)
		if source==null or not CampaignSaveCodec.whole(record.revision,1,source.revision) or not CampaignSaveCodec.whole(record.resolution,1,data.resolutions): return false
		if record.id!="camp-%08x-%04d"%[data.seed,record.resolution] or seen.has(record.id) or templates.has(record.template) or data.resolved_events.get(record.id)!=true or not record.subject is String or not data.heroes.has(record.subject): return false
		if not record.choice is String or record.choice.is_empty() or record.choice.length()>32 or ":" in record.choice: return false
		if record.revision==source.revision and record.choice!="decline" and not source.choices.any(func(choice: Dictionary) -> bool: return choice.id==record.choice): return false
		if not record.text is String or record.text.length()>1024: return false
		seen[record.id]=true; templates[record.template]=true
	if data.pending_event.is_empty(): return true
	if not data.active.is_empty() or not data.ending.is_empty() or data.event_records.size()>=LIMIT or not valid_frozen(data.pending_event,data): return false
	return data.pending_event.resolution==data.resolutions and not seen.has(data.pending_event.id) and not templates.has(data.pending_event.template)
static func valid_choices(choices: Variant,with_decline: bool=false) -> bool:
	if not choices is Array or choices.size()<(3 if with_decline else 2) or choices.size()>(4 if with_decline else 3): return false
	var ids: Dictionary={}
	for index in range(choices.size()):
		var choice: Variant=choices[index]
		if not CampaignSaveCodec.object(choice,["id","label","supplies","recovery"]) or not choice.id is String or choice.id.is_empty() or ":" in choice.id or choice.id.length()>32 or ids.has(choice.id) or not choice.label is String or choice.label.is_empty() or choice.label.length()>200: return false
		if not CampaignSaveCodec.whole(choice.supplies,-6,6) or not CampaignSaveCodec.whole(choice.recovery,0,1): return false
		if choice.id=="decline" and (not with_decline or index!=choices.size()-1 or choice!={"id":"decline","label":"Continue without accepting an offer","supplies":0,"recovery":0}): return false
		ids[choice.id]=true
	return not with_decline or choices[-1].id=="decline"
static func valid_definition(event: CampaignEventDefinition) -> bool:
	if event==null or not EVENTS.has(event.stable_id) or event.revision<1 or event.display_name.is_empty() or event.display_name.length()>100 or event.description.length()>2048 or event.eligibility not in ["any","injured","specialist","loss"]: return false
	return valid_choices(event.choices)
