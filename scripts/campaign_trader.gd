class_name CampaignTrader
extends RefCounted
## Mission-based, bounded stock. No elapsed-time or gameplay-layout RNG.
static func arrival(state: CampaignState) -> Dictionary:
	var interval: int=state.headquarters_rules.trader_interval
	if not state.headquarters_rules.valid() or state.resolutions<=0 or state.resolutions%interval!=0 or not state.active.is_empty() or not state.ending.is_empty(): return {}
	if not state.trader.is_empty() and state.trader.resolution==state.resolutions: return state.trader.duplicate(true)
	var ready: Array[CampaignItemDefinition]=[]
	var future: Array[CampaignItemDefinition]=[]
	for id: String in CampaignEquipment.IDS:
		var item := CampaignEquipment.find(id)
		if item.vendor!="trader": continue
		var usable := false
		var compatible := false
		for hero: String in state.living_ids():
			if item.compatible_heroes.has(state.blueprint_id(hero)): compatible=true
			if CampaignEquipment.eligible(state,hero,item): usable=true
		if usable: ready.append(item)
		elif compatible: future.append(item)
	var rng := RandomNumberGenerator.new();rng.seed=(state.seed_value^0x54524144^(state.resolutions*104729))&0x7fffffffffffffff
	var chosen: Array[CampaignItemDefinition]=[]
	for pool: Array[CampaignItemDefinition] in [ready,future]:
		while not pool.is_empty() and chosen.size()<state.headquarters_rules.trader_offer_count:
			var index := int(rng.randi())%pool.size();chosen.append(pool[index]);pool.remove_at(index)
	if chosen.size()!=state.headquarters_rules.trader_offer_count: return {}
	var visit := "trader-%08x-%04d"%[state.seed_value,state.resolutions]
	var offers: Array[Dictionary]=[]
	for index in range(chosen.size()):
		var item := chosen[index]
		offers.append({"offer_id":visit+"-"+str(index),"item_id":item.stable_id,"price":item.cost,"art_variant":CampaignEquipment.variant_for(state,item,state.resolutions*97+index),"sold":false})
	return {"version":1,"visit_id":visit,"resolution":state.resolutions,"offers":offers}
static func offer(state: CampaignState,id: String) -> Dictionary:
	for entry: Dictionary in state.trader.get("offers",[]):
		if entry.offer_id==id: return entry
	return {}
static func purchase_error(state: CampaignState,id: String) -> String:
	if state.trader.is_empty(): return "The trader is away."
	var choice := offer(state,id)
	if choice.is_empty(): return "This offer is no longer available."
	if choice.sold or state.used_operations.has("trader:"+id): return "SOLD OUT · one instance per offer."
	if not valid_saved(state.snapshot(),state): return "Trader stock could not be verified. No Supplies spent."
	return CampaignEquipment.purchase_error(state,state.item(choice.item_id),"trader")
static func purchase(state: CampaignState,id: String) -> String:
	if not purchase_error(state,id).is_empty(): return ""
	var choice := offer(state,id)
	var instance := state.create_item(choice.item_id,choice.art_variant)
	if instance.is_empty(): return ""
	state.supplies-=int(choice.price);choice.sold=true;state.used_operations["trader:"+id]=true
	state.history.append("Trader: bought %s [%s] for %d Supplies."%[state.item(choice.item_id).display_name,instance,choice.price])
	return instance
static func status(state: CampaignState) -> String:
	if not state.trader.is_empty(): return "TRADER IN CAMP · Leaves when you deploy. Each offer has one item."
	var interval: int=state.headquarters_rules.trader_interval
	return "Trader next arrives after mission resolution %d (every %d missions)."%[(int(state.resolutions/interval)+1)*interval,interval]
static func valid_saved(data: Dictionary,base: CampaignState) -> bool:
	if not data.trader is Dictionary: return false
	if data.trader.is_empty(): return true
	var stock: Dictionary=data.trader
	if not CampaignSaveCodec.object(stock,["version","visit_id","resolution","offers"]) or stock.version!=1 or not data.active.is_empty() or not data.ending.is_empty(): return false
	if not CampaignSaveCodec.whole(stock.resolution,1,data.resolutions) or stock.resolution!=data.resolutions or int(stock.resolution)%base.headquarters_rules.trader_interval!=0 or stock.visit_id!="trader-%08x-%04d"%[data.seed,stock.resolution]: return false
	if not stock.offers is Array or stock.offers.size()!=base.headquarters_rules.trader_offer_count: return false
	var items: Dictionary={}
	for index in range(stock.offers.size()):
		var entry: Variant=stock.offers[index]
		if not CampaignSaveCodec.object(entry,["offer_id","item_id","price","art_variant","sold"]) or not entry.item_id is String: return false
		var item := CampaignEquipment.find(entry.item_id)
		if item==null or item.vendor!="trader" or items.has(entry.item_id) or entry.offer_id!=str(stock.visit_id)+"-"+str(index) or not CampaignSaveCodec.whole(entry.price,30,45) or entry.price!=item.cost or not entry.sold is bool: return false
		if not entry.art_variant is String or (item.icon_variants.is_empty() and entry.art_variant!="") or (not item.icon_variants.is_empty() and not item.icon_variants.has(entry.art_variant)): return false
		if entry.sold!=data.used_operations.get("trader:"+str(entry.offer_id),false): return false
		items[entry.item_id]=true
	return true
