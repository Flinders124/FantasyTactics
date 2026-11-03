extends SceneTree
var failures := 0
func check(value: bool) -> void:
	if not value: failures += 1; push_error("Specialisation data assertion failed")
func _initialize() -> void:
	check(HeroCatalog.definitions().size() == 4)
	check(SpecialisationCatalog.ids().size() == 6)
	check(not SpecialisationCatalog.ids().has("recruit"))
	check(HeroCatalog.find("recruit").abilities.is_empty())
	for id in ["aegisbearer", "chainbinder"]:
		var base := SpecialisationCatalog.definition(id)
		check(base.abilities.size() == 2)
		var key: String = base.abilities[0].stable_id
		var derived := CampaignStats.derive(base, {"ability_range:" + key: 1, "ability_magnitude:" + key: 1, "cooldown:" + key: -99})
		check(derived.abilities[0].maximum_range == base.abilities[0].maximum_range + 1)
		check(derived.abilities[0].magnitude == base.abilities[0].magnitude + 1)
		check(derived.abilities[0].cooldown_turns == 1)
		check(base.abilities[0].cooldown_turns == 2)
	var knight := HeroCatalog.find("knight")
	check(CampaignStats.derive(knight, {"cooldown:power_strike": -99}).abilities[0].cooldown_turns == 0)
	var aegis := HeroCatalog.find("aegisbearer")
	check(CampaignStats.derive(aegis, {"offense": 4}).abilities[0].magnitude == 3)
	var recruit := HeroCatalog.find("recruit")
	check(recruit.maximum_health == 20 and recruit.initiative == 12 and recruit.movement_allowance == 6.0)
	check(recruit.basic_attack.damage == 4 and recruit.basic_attack.maximum_range == 1.5)
	var campaign := load("res://definitions/campaign/lantern_watch.tres") as CampaignDefinition
	for class_id in ["aegisbearer", "chainbinder"]:
		var upgrade_count := 0
		var weapon_count := 0
		for upgrade in campaign.upgrades:
			if upgrade.hero_id == class_id: upgrade_count += 1
		for item in campaign.items:
			if item.slot == "weapon" and item.compatible_heroes.has(class_id): weapon_count += 1
		check(upgrade_count == 6 and weapon_count >= 3)
	var enemy_tuning := DifficultyDefinition.new()
	enemy_tuning.enemy_damage_multiplier=1.5
	var chain := HeroCatalog.find("chainbinder")
	var adjusted := enemy_tuning.adjusted(chain)
	check(adjusted.abilities[0].magnitude==3 and adjusted.abilities[1].magnitude==chain.abilities[1].magnitude)
	check(enemy_tuning.adjusted(aegis).abilities[0].magnitude==aegis.abilities[0].magnitude)
	check(chain.abilities[0].magnitude==2)
	print("SPECIALISATION RESULT: %d failures" % failures)
	quit(1 if failures else 0)



