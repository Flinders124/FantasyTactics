@static_unload
class_name CampaignEquipment
extends RefCounted
## Shared equipment catalogue/gates. Purchasing never assigns an owner.
const IDS: PackedStringArray=["watch_helm","crest_helm","pathfinder_charm","wayfinder_charm","veteran_plate","veteran_blade","beacon_blade","beacon_helm","beacon_plate","duskward_charm","veteran_bow","beacon_bow","veteran_staff","beacon_staff","veteran_mace","beacon_mace","veteran_spear","beacon_spear","veteran_hook","beacon_hook"]
const SLOTS: PackedStringArray=["weapon","garb","helmet","accessory"]
const ART_ROOT: String="res://assets/equipment/icons/generated_v1/"
const ART_IDS: PackedStringArray=["common_sword","common_helmet","common_armour","rare_sword","rare_helmet","rare_armour","legendary_sword_a","legendary_sword_b","legendary_helmet_a","legendary_helmet_b","legendary_armour_a","legendary_armour_b"]
static func find(id: String) -> CampaignItemDefinition:
	if not IDS.has(id): return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree==null: return load("res://definitions/campaign/equipment/"+id+".tres") as CampaignItemDefinition
	if not tree.root.has_meta(&"_headquarters_equipment"):
		var definitions: Dictionary={}
		tree.root.set_meta(&"_headquarters_equipment",definitions)
		tree.root.tree_exiting.connect(func() -> void: definitions.clear(),CONNECT_ONE_SHOT)
	var cache: Dictionary=tree.root.get_meta(&"_headquarters_equipment")
	if not cache.has(id): cache[id]=load("res://definitions/campaign/equipment/"+id+".tres")
	return cache[id] as CampaignItemDefinition
static func catalogue(state: CampaignState) -> Array[CampaignItemDefinition]:
	var result: Array[CampaignItemDefinition]=[]
	for entry in state.rules.items: result.append(entry as CampaignItemDefinition)
	for id: String in IDS: result.append(find(id))
	return result
static func slot_level(slot: String,rules: HeadquartersRules) -> int:
	return rules.helmet_level if slot=="helmet" else rules.accessory_level if slot=="accessory" else 1
static func slot_name(slot: String) -> String:
	return "Body armour" if slot=="garb" else slot.capitalize()
static func level_for(item: CampaignItemDefinition,rules: HeadquartersRules) -> int:
	return maxi(item.minimum_level,slot_level(item.slot,rules))
static func eligible(state: CampaignState,hero_id: String,item: CampaignItemDefinition) -> bool:
	return state.living_ids().has(hero_id) and item.compatible_heroes.has(state.blueprint_id(hero_id)) and int(state.heroes[hero_id].level)>=level_for(item,state.headquarters_rules)
static func purchase_error(state: CampaignState,item: CampaignItemDefinition,vendor: String="armoury") -> String:
	if item==null or item.cost<=0: return "This item is not for sale."
	if not state.active.is_empty() or not state.ending.is_empty(): return "Buy equipment between missions."
	if item.vendor!=vendor: return "This equipment is sold only by the visiting trader."
	var compatible := false
	for id: String in state.living_ids():
		if item.compatible_heroes.has(state.blueprint_id(id)): compatible=true
		if eligible(state,id,item):
			return "" if state.can_spend(item.cost) else "Not enough spare Supplies; recruitment reserves are protected."
	return "Requires a level %d compatible companion."%level_for(item,state.headquarters_rules) if compatible else "No current companion has a compatible class."
static func texture(item: CampaignItemDefinition,variant: String="") -> Texture2D:
	var art: String=variant if item.icon_variants.has(variant) else item.icon_id
	if art.is_empty():
		if item.slot=="garb": art="common_armour"
		elif item.slot=="helmet": art="common_helmet"
		elif item.slot=="weapon":
			if item.compatible_heroes.has("knight") or item.compatible_heroes.has("recruit"): art="common_sword"
			else: return OathUI.icon(item.compatible_heroes[0] if not item.compatible_heroes.is_empty() else "attack")
	if ART_IDS.has(art): return load(ART_ROOT+art+".png") as Texture2D
	return OathUI.icon("lantern")
static func comparison(state: CampaignState,hero: String,item_id: String) -> String:
	var before := state.preview_definition(hero)
	var after := state.projected_definition(hero,item_id)
	var result := "Health %d → %d (%+d) · Movement %.2f → %.2f m (%+.2f)\nBasic damage %d → %d (%+d) · Reach %.2f → %.2f m"%[before.maximum_health,after.maximum_health,after.maximum_health-before.maximum_health,before.movement_allowance,after.movement_allowance,after.movement_allowance-before.movement_allowance,before.basic_attack.damage,after.basic_attack.damage,after.basic_attack.damage-before.basic_attack.damage,before.basic_attack.maximum_range,after.basic_attack.maximum_range]
	for ability in after.abilities: result+="\n"+ability.description
	return result
static func variant_for(state: CampaignState,item: CampaignItemDefinition,sequence: int) -> String:
	if item.icon_variants.is_empty(): return ""
	var rng := RandomNumberGenerator.new();rng.seed=(state.seed_value^0x415254^sequence)&0x7fffffffffffffff
	return item.icon_variants[int(rng.randi())%item.icon_variants.size()]
static func signature() -> String:
	var values: PackedStringArray=[EncounterCode.fingerprint(load("res://definitions/campaign/headquarters_rules.tres"))]
	for id: String in IDS: values.append(EncounterCode.fingerprint(find(id)))
	return "|".join(values).sha256_text()
