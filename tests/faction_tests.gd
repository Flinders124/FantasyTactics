extends SceneTree

var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Retain resources while sampling thousands of rosters; Godot's load cache is weak.
	var retained: Array[UnitDefinition] = []
	for enemy_id in EnemyCatalog.ids(): retained.append(EnemyCatalog.find(enemy_id))
	check(EnemyCatalog.VERSION == 1, "Legacy encounter version remains stable")
	check(EnemyCatalog.find("raider") != null and EnemyCatalog.find("sentinel") != null, "Legacy enemies remain available")
	check(EnemyCatalog.find("unknown") == null, "Unknown enemy rejected")
	check(EnemyCatalog.ids().size() == 15, "Fifteen faction enemies")
	check(FactionCatalog.find("unknown") == null and FactionCatalog.choose("unknown", 1) == "", "Unknown faction rejected")
	check(FactionCatalog.list().size() == 3 and FactionCatalog.descriptions().size() == 3, "Faction discovery descriptions")
	var introduced := 0
	for faction in FactionCatalog.list():
		check(faction.introduction_stage == introduced, "Ordered faction introduction")
		introduced += 1
		check(faction.regular_ids.size() == 4, "Four editable regular definitions")
		var roles := {}
		for enemy_id in faction.regular_ids:
			var unit := EnemyCatalog.find(enemy_id)
			check(unit != null, "Definition loads: " + enemy_id)
			if unit == null: continue
			roles[unit.role] = true
			check(unit.faction_id == faction.stable_id and unit.enemy_id == enemy_id and unit.visual_id == enemy_id, "Identity: " + enemy_id)
			check(not unit.is_elite and unit.encounter_cost >= 1 and unit.introduction_stage == int({"ashfang_shaman":1,"hollow_warden":2,"verdant_tender":3}.get(enemy_id,faction.introduction_stage)), "Regular cost and introduction: " + enemy_id)
			check(unit.basic_attack != null and unit.tactical_profile != null and not unit.abilities.is_empty(), "Equipped regular: " + enemy_id)
			check(not unit.strengths.is_empty() and not unit.weaknesses.is_empty() and not unit.role_icon.is_empty(), "Inspect information: " + enemy_id)
		check(roles.size() == 4, "Four distinct regular roles")
		var elite := EnemyCatalog.find(faction.elite_id)
		check(elite != null and elite.is_elite and elite.introduction_stage == 3, "Elite introduction")
		if elite != null:
			var ground_count := 0
			for ability in elite.abilities:
				if ability.telegraphed:
					ground_count += 1
					check(ability.targeting == AbilityDefinition.Target.GROUND and ability.magnitude in [4, 5], "Elite ground damage")
					check(ability.maximum_range == 8.0 and ability.area_radius == 2.5 and ability.cooldown_turns == 2 and ability.affected_factions == 7, "Elite bounded burst and friendly fire")
			check(ground_count == 1, "One telegraphed ability per elite")
		for difficulty in ["easy", "standard", "hard"]:
			for stage in range(5):
				for elite_battle in [false, true]:
					for seed_value in range(20):
						var roster := FactionCatalog.roster(faction.stable_id, difficulty, stage, elite_battle, seed_value)
						check(roster == FactionCatalog.roster(faction.stable_id, difficulty, stage, elite_battle, seed_value), "Deterministic roster")
						check(roster.size() >= 2 and roster.size() <= (3 if elite_battle else 4), "Spawn capacity and count")
						var cost := 0
						var elite_count := 0
						for enemy_id in roster:
							var unit := EnemyCatalog.find(enemy_id)
							cost += unit.encounter_cost
							elite_count += int(unit.is_elite)
							check(unit.faction_id == faction.stable_id, "One faction per roster")
						check(cost <= (maxi(4,faction.budget(difficulty,stage)) if elite_battle else faction.budget(difficulty,stage)), "Documented budget and elite minimum respected")
						check(elite_count == int(elite_battle), "Elite count")
		# Loaded resources are the live editable composition, not duplicated constants.
		var original := faction.opening_template.duplicate()
		var alternate := faction.reinforcement_template.duplicate()
		faction.opening_template = PackedStringArray([faction.regular_ids[0], faction.regular_ids[0]])
		faction.reinforcement_template = faction.opening_template.duplicate()
		check(FactionCatalog.roster(faction.stable_id, "easy", 0, false, 7) == faction.opening_template, "Editable templates used")
		faction.opening_template = original
		faction.reinforcement_template = alternate
		var old_budget := faction.easy_budget
		faction.easy_budget = 6
		check(faction.budget("easy", 0) == 6, "Editable budget used")
		check(FactionCatalog.roster(faction.stable_id, "easy", 4, false, 7).size() == 4, "Edited budget changes composition")
		faction.easy_budget = old_budget
	var choices := {}
	for seed_value in range(50):
		var chosen := FactionCatalog.choose("random", seed_value)
		choices[chosen] = true
		check(chosen == FactionCatalog.choose("random", seed_value), "Deterministic faction choice")
	check(choices.size() == 3, "Random selection covers all factions")
	print("FACTION DATA CHECKS: %d"%checks)
	print("FACTION DATA RESULT: %d failures"%failures)
	quit(1 if failures else 0)
