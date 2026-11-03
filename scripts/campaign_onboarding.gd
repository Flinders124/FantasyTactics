class_name CampaignOnboarding
extends RefCounted
## Session-only observations. No campaign state or preferences are written here.
var visible: bool=true
var operations: Dictionary={}
func reset(show_guide: bool=true) -> void:
 visible=show_guide;operations.clear()
func observe(method: String) -> void:
 operations[method]=true
func summary(state: CampaignState) -> String:
 var ready: int=0
 var injured: int=0
 for id in state.living_ids():
  if state.blueprint_id(id)=="recruit" and state.heroes[id].level>=2: ready+=1
  if not state.heroes[id].injury.is_empty(): injured+=1
 if ready>0:
  return "CLASS CHOICE AVAILABLE · %d recruit(s) can choose a permanent specialisation in the Training Yard. Inspect weapons and abilities before confirming; no purchase is required."%ready
 if injured>0:
  return "RECOVERY · %d injured companions may still deploy. Existing injuries recover 1 step deployed or 2 resting. Training costs %d Supplies; recruitment costs %d. Prepare a reserve before risking your last pair."%[injured,state.roster_rules.training_cost,state.roster_rules.recruit_cost]
 if state.command_tier<2 and state.victories>=state.headquarters_rules.command_victories[state.command_tier]:
  return "COMMAND UPGRADE AVAILABLE · The Commander’s Tent can raise deployment to %d companions for %d Supplies. Equipment is bought at the Outfitter and equipped from a character slot."%[state.deployment_capacity()+1,state.headquarters_rules.command_costs[state.command_tier]]
 if state.resolutions==0:
  return "GETTING STARTED · Select two distinct companions at the Mission Board. Recruits unlock a permanent class at level 2 (%d XP). Optional training costs %d Supplies and brings at least %d XP; winning a mission also earns progression."%[state.rules.xp_thresholds[1],state.roster_rules.training_cost,state.roster_rules.training_xp]
 return "PREPARE YOUR NEXT MISSION · Review adjusted stats, injuries, enemy roles and the objective. Basic attacks, abilities and rescue share one action; movement is separate. Camp Rules explains consequences; Rescue Practice never changes this campaign."
static func deployment(state: CampaignState,offer: Dictionary,party: PackedStringArray) -> String:
 var ignored: int=0
 for other in state.offers:
  if other.id!=offer.id: ignored+=int(other.ignored)
 ignored=mini(ignored,state.rules.maximum_ignored_threat)
 var lines: PackedStringArray=["COMMITMENT · Victory: +%d Supplies, threat %+d. Failure: +%d Supplies, threat %+d (including ignored offers)."%[offer.supplies,state.rules.victory_threat+ignored,state.rules.failure_supplies,state.rules.failure_threat+ignored],"No free campaign retry. Safely extracted companions can survive a failed mission; unrescued losses are permanent."]
 var error := state.deployment_error(offer.id,party)
 if not error.is_empty(): lines.append("NOT READY · "+error)
 for id in party:
  if not state.living_ids().has(id): continue
  var definition := state.preview_definition(id)
  var record: Dictionary=state.heroes[id]
  if not record.injury.is_empty(): lines.append("INJURED · %s: %s, %d resolutions left. Listed health and movement already include penalties."%[state.hero_name(id),record.injury.name,record.injury.remaining])
  if state.blueprint_id(id)=="recruit": lines.append("RECRUIT · %s has no class abilities yet; specialisation unlocks at %d XP. Optional training costs %d Supplies."%[state.hero_name(id),state.rules.xp_thresholds[1],state.roster_rules.training_cost])
  lines.append("%s · %d HP · %.2f m movement"%[state.hero_name(id),definition.maximum_health,definition.movement_allowance])
 return "\n".join(lines)
