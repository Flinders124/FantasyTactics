extends "res://tests/objective_encounter_tests.gd"
var report: Array[Dictionary]=[]
func run() -> void:
	var ids := PackedStringArray(["knight","ranger","mage","cleric"])
	for difficulty in EncounterOptions.difficulties():
		for first in range(4):
			for second in range(first+1,4):
				if OS.get_cmdline_user_args().has("--numeric-only"): continue
				if OS.get_cmdline_user_args().has("--cleric-only") and ids[first]!="cleric" and ids[second]!="cleric": continue
				var config := EncounterConfiguration.new()
				config.hero_ids=PackedStringArray([ids[first],ids[second]])
				config.difficulty=difficulty
				config.objective=EncounterOptions.objectives()[0]
				config.generator_settings=EncounterOptions.presets()[0]
				config.battlefield_seed=7
				config.resolve_roster()
				var encounter := await prepare(config)
				check(encounter.navigation_ready,"Balance encounter navigation ready")
				var combat := encounter.get_node("CombatController") as CombatController
				var enemy := encounter.get_node("EnemyController") as EnemyController
				enemy.enabled=true; enemy.presentation_delay=0
				enemy._on_turn_started(combat.scheduler.active_unit(),combat.turn_serial)
				var serial := -1
				for frame in range(36000):
					if combat.encounter_has_ended() or combat.scheduler.round_number>40: break
					if combat.state==CombatController.State.AWAITING_COMMAND and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
						serial=combat.turn_serial
						await hero_turn(combat,combat.scheduler.active_unit())
					await process_frame
				var health: Dictionary={}
				for unit in combat.units: health[unit.stable_id]=unit.health
				report.append({"pair":Array(config.hero_ids),"difficulty":difficulty.stable_id,"seed":7,"objective":"elimination","preset":"open_courtyard","result":CombatController.State.keys()[combat.state],"round":combat.scheduler.round_number,"health":health,"bounded":combat.encounter_has_ended()})
				print("BALANCE SAMPLE ",JSON.stringify(report[-1]))
				await dispose(encounter)
	var knight := HeroCatalog.find("knight")
	var cleric := HeroCatalog.find("cleric")
	check(cleric.maximum_health>knight.maximum_health and cleric.initiative<knight.initiative,"Cleric durability trades against Knight initiative")
	var healing: CampaignState = LegacyCampaignFixture.new(17,"standard")
	healing.supplies=100
	healing.heroes.cleric.level=4
	for option in ["cleric_2_0","cleric_3_0","cleric_4_0"]: check(healing.learn("cleric",option),"Heal build learns one legal choice per level")
	for item_id in ["kindled_mace","votive_charm"]: check(healing.equip("cleric",healing.purchase(item_id)),"Heal build equips legal owned gear")
	check(healing.preview_definition("cleric").abilities[0].magnitude==13 and healing.preview_definition("cleric").abilities[0].cooldown_turns==2,"Maximum healing build is 13 with two blocked owner turns")
	healing.heroes.cleric.upgrades=["cleric_2_0","cleric_3_0","cleric_4_1"]
	check(healing.preview_definition("cleric").abilities[0].magnitude==11 and healing.preview_definition("cleric").abilities[0].cooldown_turns==1,"Quickened healing trades magnitude for timing")
	for sample in report: check(sample.bounded,"Every diagnostic battle reaches a terminal result")
	var state: CampaignState = LegacyCampaignFixture.new(17,"standard")
	var strategic: Array[Dictionary]=[]
	for mission in range(5):
		var chosen: Dictionary=state.offers[0]
		state.commit(chosen.id,["knight","cleric"])
		var result := CampaignMissionResult.new({"version":1,"mission_id":chosen.id,"outcome":"victory","reason":"Strategic numeric diagnostic","tactical_result":"VICTORY","heroes":{"knight":{"health":20,"maximum_health":20},"cleric":{"health":cleric.maximum_health,"maximum_health":cleric.maximum_health}}})
		check(state.resolve(result),"Strategic diagnostic resolves")
		strategic.append({"resolutions":state.resolutions,"threat":state.threat,"supplies":state.supplies,"ending":state.ending})
	check(state.ending=="victory","Five uninterrupted wins reach ending without threat deadlock")
	check(RegressionReport.write_json("release/balance/samples.json",{"samples":report,"strategic_perfect_run":strategic}),"Regression report written")
	print("RELEASE BALANCE RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)




