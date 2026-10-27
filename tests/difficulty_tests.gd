extends "res://tests/objective_tests.gd"

func repack(data: Dictionary) -> String:
	var payload := Marshalls.raw_to_base64(JSON.stringify(data).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)).replace("+","-").replace("/","_").replace("=","")
	return "FT1."+payload+"."+payload.sha256_text().substr(0,8)

func unpack(code: String) -> Dictionary:
	var text := code.split(".")[1].replace("-","+").replace("_","/")
	while text.length()%4!=0: text+="="
	return JSON.parse_string(Marshalls.base64_to_raw(text).decompress_dynamic(32768,FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8()) as Dictionary

func run() -> void:
	var base := EnemyCatalog.find("sentinel")
	var before := EncounterCode.fingerprint(base)
	var hero_before := EncounterCode.fingerprint(HeroCatalog.find("ranger"))
	var codes: PackedStringArray=[]
	for index in range(3):
		var difficulty := EncounterOptions.difficulties()[index]
		check(difficulty.valid(),"Editable difficulty valid")
		var modified := difficulty.adjusted(base)
		check(modified!=base and modified.basic_attack!=base.basic_attack and modified.maximum_health==[15,18,20][index] and modified.basic_attack.damage==[3,4,5][index],"Health/basic rounding and independent resources")
		for slot in range(base.abilities.size()):
			var original := base.abilities[slot]
			var ability := modified.abilities[slot]
			check(ability!=original and ability.cooldown_turns==original.cooldown_turns,"Cooldown unchanged; ability definition independent")
			check(ability.magnitude==(difficulty.scaled_damage(original.magnitude) if original.effect==AbilityDefinition.Effect.DAMAGE else original.magnitude),"All offensive magnitudes scale; healing does not")
			if original.applied_status!=null:
				check(ability.applied_status.affected_turns==original.applied_status.affected_turns and ability.applied_status.movement_multiplier==original.applied_status.movement_multiplier,"Status duration/modifier unchanged")
		if index==1: check(EncounterCode.fingerprint(modified)==before,"Standard preserves complete baseline definition content")
		check(modified.initiative==base.initiative and modified.movement_allowance==base.movement_allowance,"Difficulty preserves initiative/movement")
		var config := EncounterConfiguration.new()
		config.hero_ids=["mage","cleric"]
		config.battlefield_seed=4294967295
		config.difficulty=difficulty.duplicate(true) as DifficultyDefinition
		config.objective=EncounterOptions.objectives()[index].duplicate(true) as ObjectiveDefinition
		config.generator_settings=EncounterOptions.presets()[index].duplicate(true) as BattlefieldSettings
		config.resolve_roster()
		var code := EncounterCode.encode(config)
		codes.append(code)
		check(code.begins_with("FT1.") and code.length()<4096,"Compact bounded code")
		var decoded := EncounterCode.decode(code)
		check(decoded.error.is_empty() and decoded.configuration!=null,"Code decodes: "+decoded.error)
		if decoded.configuration!=null:
			check(EncounterCode.encode(decoded.configuration)==code,"Canonical round trip")
			check(decoded.configuration.resolved_enemy_ids==config.resolved_enemy_ids and decoded.configuration.battlefield_seed==4294967295,"Code preserves exact roster/32-bit seed")
		var model := PartySelection.new()
		check(model.import_code(code) and model.ready() and model.seed_text=="4294967295","Import populates a valid setup")
		var frozen_health := model.imported_configuration.difficulty.enemy_health_multiplier
		model.toggle("mage")
		model.toggle("knight")
		check(model.configuration(1).difficulty.enemy_health_multiplier==frozen_health,"Editing hero preserves imported tuning")
		model.seed_text="-1"
		check(not model.ready(),"Negative seed blocks Start")
		model.seed_text="4294967296"
		check(not model.ready(),"Overflow seed blocks Start")
		model.seed_text="1.5"
		check(not model.ready(),"Fraction seed blocks Start")
		model.seed_text=""
		check(model.ready(),"Optional random seed valid")
		model.imported_configuration.difficulty.enemy_health_multiplier=0
		check(not model.ready() and model.validation_error().contains("tuning"),"Invalid editable tuning blocks Start with a clear reason")
	check(before==EncounterCode.fingerprint(base) and hero_before==EncounterCode.fingerprint(HeroCatalog.find("ranger")),"Shared enemy/hero resource graphs untouched")
	var alternate := EncounterOptions.difficulties()[1].duplicate(true) as DifficultyDefinition
	alternate.alternate_roster=["sentinel","raider"]
	for seed_value in range(20):
		var first := alternate.roster_for("elimination",seed_value)
		for noise in range(12): randi()
		check(first==alternate.roster_for("elimination",seed_value),"Roster stream independent of global/audio variation")
	for bad in ["", "FT2.abc.00000000",codes[0].substr(0,codes[0].length()-1)+"X","FT1."+"A".repeat(9000)+".deadbeef"]:
		check(EncounterCode.decode(bad).configuration==null,"Malformed/version/checksum/size rejection")
	for change in ["seed","heroes","generator","difficulty","roster_hash","attempt","engine","height","schema"]:
		var data := unpack(codes[1])
		match change:
			"seed": data.seed=-1
			"heroes": data.heroes=["knight","knight"]
			"generator": data.generator.generator_version=999
			"difficulty": data.difficulty.enemy_damage_multiplier=100
			"roster_hash": data.roster_hash=["wrong","wrong"]
			"attempt": data.attempt=99
			"engine": data.engine=1
			"height": data.generator.obstacle_height=[1,1000000]
			"schema": data.extra="unsupported"
		check(EncounterCode.decode(repack(data)).configuration==null,"Validated code rejects "+change)
	# Exercise real resolution with derived definitions, then restart repeatedly.
	await fixture(0)
	var hard := EncounterOptions.difficulties()[2]
	raider.definition=hard.adjusted(EnemyCatalog.find("raider"))
	raider.reset_for_encounter()
	controller.submit_command(EndTurnCommand.new(hero.stable_id))
	hero.position=raider.position+Vector3(1.5,0,0)
	await physics_frame
	await physics_frame
	var health_before := hero.health
	check(controller.submit_command(UseAbilityCommand.new(raider.stable_id,hero.stable_id,"power_strike")),"Enemy offensive ability uses same command")
	check(hero.health==health_before-8 and not raider.action_available,"Scaled ability applies once and spends shared action")
	await wait_for_action()
	for retry in range(3):
		await controller.restart_encounter()
		check(raider.health==18 and raider.definition.basic_attack.damage==5 and raider.ability_by_id("power_strike").magnitude==8,"Restart never compounds difficulty")
	encounter.queue_free()
	await process_frame
	check(RegressionReport.write_json("difficulty/example-codes.json",Array(codes)),"Regression report written")
	print("DIFFICULTY RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
