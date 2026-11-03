class_name HeadquartersRules
extends Resource
## Reusable campaign tuning; mutable upgrades and stock belong to CampaignState.
@export var version: int=1
@export var command_costs: PackedInt32Array=[20,30]
@export var command_victories: PackedInt32Array=[1,2]
@export var trader_interval: int=2
@export var trader_offer_count: int=3
@export var helmet_level: int=2
@export var accessory_level: int=3
@export var opening_rosters: Dictionary={"ashfang":PackedStringArray(["ashfang_raider","ashfang_bowhunter"]),"hollow":PackedStringArray(["hollow_gravebound","hollow_archer"]),"verdant":PackedStringArray(["verdant_thornblade","verdant_stalker","verdant_tender"])}
@export var opening_titles: PackedStringArray=["First Watch","The Watch Expands","A Stronger Line"]
@export var opening_briefings: PackedStringArray=["Win your first mission to unlock free class specialisation and the first Commander’s Tent upgrade. Separate the raider from its archer; movement remains available after an action.","Your specialists now face a durable frontline and a ranged attacker. The Commander’s Tent can support a third companion; use different approaches rather than crowding one route.","The enemy now combines mobility, ranged pressure and healing. The Commander’s Tent can support four companions; prioritise useful targets and keep rescue routes open."]

func valid() -> bool:
	if opening_titles.size()!=3 or opening_briefings.size()!=3: return false
	if command_costs.size()!=2 or command_victories.size()!=2 or trader_interval<1 or trader_interval>5 or trader_offer_count!=3: return false
	if helmet_level<2 or helmet_level>4 or accessory_level<helmet_level or accessory_level>4: return false
	for index in range(2):
		if command_costs[index]<1 or command_costs[index]>1000 or command_victories[index]<1 or command_victories[index]>4: return false
	return command_victories[1]>=command_victories[0]
