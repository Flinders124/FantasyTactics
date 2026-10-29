extends "res://tests/generation_tests.gd"
var records: Array[Dictionary]=[]

func run() -> void:
	var cached: Dictionary={}
	for preset in EncounterOptions.presets():
		for objective in EncounterOptions.objectives():
			for difficulty in EncounterOptions.difficulties():
				for seed_value in range(1,6):
					var config := EncounterConfiguration.new()
					config.battlefield_seed=seed_value
					config.generator_settings=preset.duplicate(true) as BattlefieldSettings
					config.objective=objective.duplicate(true) as ObjectiveDefinition
					config.difficulty=difficulty.duplicate(true) as DifficultyDefinition
					config.resolve_roster()
					var key := preset.preset_id+objective.stable_id+str(seed_value)
					if cached.has(key): config.layout=(cached[key] as BattlefieldLayout).duplicate(true) as BattlefieldLayout
					var scene := await prepare(config)
					check(scene.navigation_ready,"Preset/objective/difficulty/seed playable")
					if scene.navigation_ready:
						completed+=1
						if cached.has(key): check(config.layout.signature()==(cached[key] as BattlefieldLayout).signature(),"Difficulty cannot alter layout stream")
						else: cached[key]=config.layout.duplicate(true)
						var combat := scene.get_node("CombatController") as CombatController
						var navigation := scene.get_node("NavigationService") as NavigationService
						# Production validation runs before bodies spawn. Recheck the
						# static world here while excluding the newly spawned roster.
						check(combat.units.size()==4,"Exactly two heroes and two enemies")
						var excluded: Array[RID]=[]
						for unit in combat.units: excluded.append(unit.get_rid())
						for unit in combat.units:
							var shape := CapsuleShape3D.new()
							shape.radius=.5
							shape.height=1.58
							var query := PhysicsShapeQueryParameters3D.new()
							query.shape=shape
							query.transform=Transform3D(Basis.IDENTITY,unit.global_position+Vector3.UP*.81)
							query.exclude=excluded
							query.collision_mask=1
							check(scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Spawn has static clearance")
							for other in combat.units:
								if other==unit: continue
								check(unit.global_position.distance_to(other.global_position)>1 and navigation.query_path(unit.global_position,other.global_position).valid(),"All roster spawns separate and connected")
						check(scene.generator.validate_objective(config.layout,navigation,objective),"Objective placement/connectivity preserved on every difficulty")
						for slot in range(2):
							var actual := combat.units[slot+2]
							var expected := difficulty.adjusted(config.enemies[slot])
							check(EncounterCode.fingerprint(actual.definition)==EncounterCode.fingerprint(expected) and actual.health==expected.maximum_health,"Fresh enemy stats derive exactly once")
						var code := EncounterCode.encode(config)
						var decoded := EncounterCode.decode(code)
						check(decoded.configuration!=null and decoded.configuration.requested_attempt==config.layout.attempt,"Accepted generation attempt shares correctly")
						records.append({"preset":preset.preset_id,"objective":objective.stable_id,"difficulty":difficulty.stable_id,"seed":seed_value,"attempt":config.layout.attempt,"roster":Array(config.resolved_enemy_ids),"health":[combat.units[2].health,combat.units[3].health],"code_length":code.length()})
					await dispose(scene)
	# All six hero pairs initialize on the highest supported difficulty.
	var heroes: PackedStringArray=["knight","ranger","mage","cleric"]
	for first in range(4):
		for second in range(first+1,4):
			var config := EncounterConfiguration.new()
			config.hero_ids=[heroes[first],heroes[second]]
			config.difficulty=EncounterOptions.difficulties()[2]
			config.resolve_roster()
			var scene := await prepare(config)
			check(scene.navigation_ready and (scene.get_node("CombatController") as CombatController).units[0].definition==HeroCatalog.find(heroes[first]),"Each hero pair initializes without scaling heroes")
			await dispose(scene)
	check(completed==EncounterOptions.presets().size()*EncounterOptions.objectives().size()*EncounterOptions.difficulties().size()*5,"Five fixed seeds across every preset/objective/difficulty combination")
	check(RegressionReport.write_json("difficulty/generation.json",records),"Regression report written")
	print("DIFFICULTY GENERATION RESULT: %d failures; %d configurations; six hero pairs"%[failures,completed])
	quit(0 if failures==0 else 1)
