extends "res://tests/ai_simulation_tests.gd"
# New classes and unspecialised duplicate-blueprint deployments use real rules.
const ROSTER_PAIRS := [["aegisbearer","chainbinder"],["aegisbearer","mage"],["chainbinder","ranger"],["aegisbearer","cleric"],["chainbinder","knight"],["recruit","recruit"]]
func mission_configuration(index: int) -> EncounterConfiguration:
 var config := EncounterConfiguration.new()
 config.hero_ids=PackedStringArray(ROSTER_PAIRS[index%6])
 config.campaign_hero_ids=PackedStringArray(["person-1","person-2"])
 config.survival_enabled=true
 config.difficulty=EncounterOptions.difficulties()[0]
 config.battlefield_seed=9300+index
 config.objective=EncounterOptions.objectives()[index%3]
 config.faction_id=FactionCatalog.ids()[index%3]
 config.campaign_stage=1
 config.generator_settings=EncounterOptions.presets()[index%5].duplicate(true)
 config.resolve_roster()
 return config
