extends "res://tests/objective_encounter_tests.gd"

var played: int = 0
var decision_count: int = 0
var role_turns: Dictionary = {}
var results: Array[Dictionary] = []
var retained: Array[UnitDefinition] = []

func exercise(config: EncounterConfiguration, rounds: int = 1) -> void:
	check(config.validation_error().is_empty(), "Faction configuration validates: " + config.validation_error())
	var scene := await prepare(config)
	check(scene.navigation_ready, "Faction generation and variable spawn count become playable")
	if not scene.navigation_ready:
		await dispose(scene)
		return
	var combat := scene.get_node("CombatController") as CombatController
	var enemy := scene.get_node("EnemyController") as EnemyController
	check(combat.units.size() == config.enemies.size() + 2, "All requested opponents spawn")
	check(config.layout.spawns.size() == combat.units.size(), "Generated layout matches variable roster")
	for index in range(config.enemies.size()):
		var unit := combat.find_unit("enemy-%02d" % (index + 1))
		check(unit != null and unit.definition.enemy_id == config.resolved_enemy_ids[index], "Spawned role identity")
	var serials := {}
	var counts := {}
	var starts := {}
	var endings := {}
	enemy.routine_started.connect(func(actor_id: String, serial: int) -> void:
		serials[actor_id] = serial
		starts[serial] = actor_id)
	enemy.command_submitted.connect(func(actor_id: String, kind: String, accepted: bool) -> void:
		var serial: int = serials.get(actor_id, -1)
		var key := "%d:%s" % [serial, kind]
		counts[key] = int(counts.get(key, 0)) + 1
		check(counts[key] <= 1, "At most one movement, action and end per enemy turn")
		if kind == "end":
			check(accepted, "Every enemy routine legally ends its turn")
			endings[serial] = true
			var unit := combat.find_unit(actor_id)
			role_turns[unit.definition.enemy_id] = int(role_turns.get(unit.definition.enemy_id, 0)) + 1)
	enemy.decision_chosen.connect(func(record: Dictionary) -> void:
		decision_count += 1
		var profile := combat.find_unit(record.actor_id).definition.tactical_profile
		check(record.path_queries <= profile.max_path_queries and record.action_queries <= profile.max_action_queries and record.evaluated_positions <= profile.max_candidates, "Faction decision respects bounded profile")
		check(record.turn_path_queries <= 144 and record.turn_action_queries <= 3072, "Faction total turn queries bounded"))
	enemy.presentation_delay = 0.0
	combat.motor.movement_speed = 80.0
	combat.attack_resolution_seconds = 0.05
	if scene.guide != null: scene.guide.close()
	enemy.enabled = true
	var actor := combat.scheduler.active_unit()
	if actor != null and actor.faction == CombatUnit.Faction.ENEMY:
		combat.turn_started.emit(actor, combat.turn_serial)
	var last_serial := -1
	for frame in range(10000):
		if combat.encounter_has_ended() or combat.scheduler.round_number > rounds: break
		if combat.state == CombatController.State.AWAITING_COMMAND:
			actor = combat.scheduler.active_unit()
			if actor != null and actor.faction == CombatUnit.Faction.HERO and last_serial != combat.turn_serial:
				last_serial = combat.turn_serial
				check(combat.submit_player_command(EndTurnCommand.new(actor.stable_id)), "Passive hero command remains legal")
		await process_frame
	check(combat.encounter_has_ended() or combat.scheduler.round_number > rounds, "Faction rounds finish within watchdog")
	# The first actor of the next round may have started but has not completed yet.
	for serial: int in starts:
		if serial < combat.turn_serial: check(endings.has(serial) or combat.encounter_has_ended(), "Every completed enemy turn submits End Turn")
	results.append({"faction": config.faction_id, "objective": config.objective.stable_id, "difficulty": config.difficulty.stable_id, "seed": config.battlefield_seed, "enemies": config.resolved_enemy_ids, "round": combat.scheduler.round_number, "ends": endings.size()})
	played += 1
	print("FACTION ENCOUNTER ", results[-1])
	await dispose(scene)

func run() -> void:
	if "--campaign-check" in OS.get_cmdline_user_args():
		var campaign: CampaignState = LegacyCampaignFixture.new(17, "easy")
		for stage in range(5):
			campaign.victories = stage
			campaign.resolutions = stage
			campaign.generate_offers()
			for offer in campaign.offers:
				var decoded := EncounterCode.decode(offer.code)
				check(decoded.configuration != null, "Campaign faction code round trip: " + decoded.error)
				var config := campaign.prepare(offer.id, ["knight", "ranger"])
				check(config != null and config.validation_error().is_empty(), "Campaign faction offer prepares")
				check(FactionCatalog.find(offer.faction).introduction_stage <= stage, "Campaign respects faction introduction")
				check(not offer.elite or stage >= 3, "Campaign elite opportunity introduction")
				check(stage != 4 or offer.elite, "Final campaign mission guarantees elite")
				print("CAMPAIGN CONFIG stage=", stage, " faction=", offer.faction, " elite=", offer.elite, " code error=", decoded.error)
		print("CAMPAIGN CONFIG RESULT: %d failures" % failures)
		quit(0 if failures == 0 else 1)
		return
	for enemy_id in EnemyCatalog.ids(): retained.append(EnemyCatalog.find(enemy_id))
	for faction_id in FactionCatalog.ids():
		for objective in EncounterOptions.objectives():
			for difficulty in EncounterOptions.difficulties():
				for seed_value in range(3):
					var config := EncounterConfiguration.new()
					config.faction_id = faction_id
					config.objective = objective
					config.difficulty = difficulty
					config.battlefield_seed = seed_value
					config.resolve_roster()
					await exercise(config)
	# Explicit regular and elite fixtures guarantee turns for all fifteen role IDs.
	for faction in FactionCatalog.list():
		for elite in [false, true]:
			var config := EncounterConfiguration.new()
			config.faction_id = faction.stable_id
			config.battlefield_seed = 1
			config.campaign_stage = 4
			config.elite_encounter = elite
			if not elite: config.difficulty = EncounterOptions.difficulties()[2]
			config.resolved_enemy_ids = PackedStringArray([faction.elite_id, faction.regular_ids[0]]) if elite else faction.regular_ids.duplicate()
			config.enemies.clear()
			for enemy_id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(enemy_id).duplicate(true) as UnitDefinition)
			await exercise(config, 2)
	for enemy_id in EnemyCatalog.ids(): check(role_turns.has(enemy_id), "Every faction role completes a legal AI turn: " + enemy_id)
	var heroes: PackedStringArray = ["knight", "ranger", "mage", "cleric"]
	for first in range(heroes.size()):
		for second in range(first + 1, heroes.size()):
			var config := EncounterConfiguration.new()
			config.hero_ids = PackedStringArray([heroes[first], heroes[second]])
			config.faction_id = FactionCatalog.ids()[(first + second) % 3]
			config.battlefield_seed = first * 4 + second
			config.resolve_roster()
			await exercise(config)
	check(played == 93, "81 combination/seed encounters, six all-role fixtures and six hero pairs")
	check(RegressionReport.write_json("faction-encounters.json",{"failures": failures, "encounters": results, "role_turns": role_turns, "decisions": decision_count}),"Regression report written")
	print("FACTION ENCOUNTER RESULT: %d failures; %d encounters; %d bounded decisions; %d roles" % [failures, played, decision_count, role_turns.size()])
	quit(0 if failures == 0 else 1)
