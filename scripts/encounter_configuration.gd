class_name EncounterConfiguration
extends Resource

@export var optional_goal_id: String=""
@export var faction_id: String = "legacy"
@export var campaign_stage: int = 0
@export var elite_encounter: bool = false
@export var hero_ids: PackedStringArray = ["knight", "ranger"]
@export var allow_duplicate_classes: bool = false
@export var survival_enabled: bool = false
@export var deployment_id: String = ""
@export var campaign_hero_ids: PackedStringArray = []
@export var hero_overrides: Array[UnitDefinition] = []
@export var enemies: Array[UnitDefinition] = []
@export var battlefield_seed: int = 1
@export var generator_settings: BattlefieldSettings = BattlefieldSettings.new()
@export var objective: ObjectiveDefinition = preload("res://definitions/objectives/elimination.tres")
@export var difficulty: DifficultyDefinition = preload("res://definitions/difficulties/standard.tres")
@export var resolved_enemy_ids: PackedStringArray = ["raider","sentinel"]
@export var requested_attempt: int = 0
@export var roster_version: int = EnemyCatalog.VERSION
@export var layout: BattlefieldLayout

func _init() -> void:
	enemies = [EnemyCatalog.find("raider").duplicate(true) as UnitDefinition, EnemyCatalog.find("sentinel").duplicate(true) as UnitDefinition]

func valid_party() -> bool:
	if difficulty==null or not difficulty.valid() or objective==null or hero_ids.size()<2 or hero_ids.size()>4 or enemies.size()<2 or enemies.size()>4: return false
	var seen: Dictionary={}
	var people: Dictionary={}
	var campaign := survival_enabled and campaign_hero_ids.size()==hero_ids.size()
	for index in range(hero_ids.size()):
		var id: String=hero_ids[index]
		if HeroCatalog.find(id)==null: return false
		if seen.has(id) and not allow_duplicate_classes and not campaign: return false
		seen[id]=true
		if campaign:
			var person: String=campaign_hero_ids[index]
			if person.is_empty() or people.has(person): return false
			people[person]=true
	return enemies.all(func(unit: UnitDefinition) -> bool: return unit!=null)


# Returning the Resource base avoids a self-typed Resource script cycle in Godot 4.7.2.
func snapshot() -> Resource:
	var result: Resource = get_script().new()
	result.optional_goal_id=optional_goal_id
	result.faction_id=faction_id
	result.campaign_stage=campaign_stage
	result.elite_encounter=elite_encounter
	result.hero_ids = hero_ids.duplicate()
	result.deployment_id=deployment_id
	result.survival_enabled=survival_enabled
	result.allow_duplicate_classes=allow_duplicate_classes
	result.campaign_hero_ids=campaign_hero_ids.duplicate()
	result.hero_overrides.clear()
	for hero in hero_overrides: result.hero_overrides.append(hero.duplicate(true) as UnitDefinition)
	result.enemies.clear()
	for enemy in enemies: result.enemies.append(enemy.duplicate(true) as UnitDefinition)
	result.resolved_enemy_ids=resolved_enemy_ids.duplicate()
	result.difficulty=difficulty.duplicate(true) as DifficultyDefinition
	result.requested_attempt=requested_attempt
	result.roster_version=roster_version
	result.battlefield_seed = battlefield_seed
	result.generator_settings = generator_settings.duplicate(true) as BattlefieldSettings if generator_settings != null else BattlefieldSettings.new()
	result.objective = objective.duplicate(true) as ObjectiveDefinition if objective!=null else ObjectiveDefinition.new()
	result.layout = layout.duplicate(true) as BattlefieldLayout if layout != null else null
	return result


func resolve_roster() -> void:
	if faction_id=="legacy":
		resolved_enemy_ids=difficulty.roster_for(objective.stable_id,battlefield_seed)
	else:
		faction_id=FactionCatalog.choose(faction_id,battlefield_seed)
		resolved_enemy_ids=FactionCatalog.roster(faction_id,difficulty.stable_id,campaign_stage,elite_encounter,battlefield_seed)
	enemies.clear()
	for id in resolved_enemy_ids:
		var base := EnemyCatalog.find(id)
		if base!=null: enemies.append(base.duplicate(true) as UnitDefinition)

func validation_error() -> String:
	if not optional_goal_id.is_empty() and OptionalGoals.find(optional_goal_id)==null: return "Unsupported optional goal."
	if not hero_overrides.is_empty():
		if deployment_id.is_empty() or hero_overrides.size()!=hero_ids.size() or campaign_hero_ids.size()!=hero_ids.size(): return "Invalid campaign deployment snapshot."
		for index in range(hero_ids.size()):
			if hero_overrides[index]==null or hero_overrides[index].selection_id!=hero_ids[index]: return "Invalid campaign hero definition."
	if campaign_stage<0 or campaign_stage>4 or (faction_id!="legacy" and FactionCatalog.find(faction_id)==null): return "Unsupported faction or campaign stage."
	if faction_id!="legacy" and not FactionCatalog.valid_roster(resolved_enemy_ids,faction_id,difficulty.stable_id,campaign_stage,elite_encounter): return "Invalid faction composition, budget or elite restrictions."
	if not valid_party(): return "Choose 2–4 valid heroes and a supported difficulty/roster."
	if generator_settings==null or not EncounterOptions.presets().any(func(preset: BattlefieldSettings) -> bool: return preset.preset_id==generator_settings.preset_id) or generator_settings.generator_version not in [2,3]: return "Unsupported battlefield preset or generator version."
	if objective.stable_id not in ["elimination","hold_ground","extraction"]: return "Unsupported objective."
	if battlefield_seed<0 or battlefield_seed>4294967295: return "Seed must be a whole number from 0 to 4294967295."
	if roster_version!=EnemyCatalog.VERSION or not DifficultyDefinition.valid_roster(resolved_enemy_ids): return "Unsupported enemy roster version."
	if requested_attempt<0 or requested_attempt>clampi(generator_settings.generation_attempts,1,8)+1: return "Unsupported generation attempt."
	return ""
