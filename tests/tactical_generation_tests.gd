extends "res://tests/generation_tests.gd"
func run() -> void:
 var start := Time.get_ticks_msec()
 var generator := BattlefieldGenerator.new();root.add_child(generator)
 for preset in range(3):
  for kind in range(3):
   for seed_value in range(1,11):
    var config := EncounterConfiguration.new()
    config.generator_settings=EncounterOptions.presets()[preset].duplicate(true);config.generator_settings.generator_version=3
    config.hero_ids=PackedStringArray(["knight","ranger","mage","cleric"].slice(0,2+seed_value%3))
    config.optional_goal_id="cache";config.objective=EncounterOptions.objectives()[kind].duplicate(true);config.battlefield_seed=seed_value
    var decoded := EncounterCode.decode(EncounterCode.encode(config))
    check(decoded.configuration!=null and decoded.configuration.optional_goal_id=="cache" and decoded.configuration.generator_settings.generator_version==3,"New encounter code freezes architecture and goal")
    var encounter := await prepare(config)
    check(encounter.navigation_ready,"Architecture matrix navigates: %d/%d/%d"%[preset,kind,seed_value])
    if encounter.navigation_ready:
     completed+=1
     var layout := config.layout
     var nav: NavigationService=encounter.get_node("NavigationService")
     var runtime: OptionalGoalController=encounter.get_node("CombatController").optional_goals
     check(nav.query_path(layout.spawns[0],runtime.point).valid(),"Optional cache is reachable")
     check(not encounter.get_node("CombatController")._destination_occupied(encounter.get_node("CombatController").units[0],runtime.point),"Optional cache has physical clearance")
     for spawn in layout.spawns:check(nav.query_path(spawn,layout.spawns[0]).valid(),"All larger-party spawns remain connected")
     var repeated := generator.make_layout(seed_value,config.generator_settings,layout.attempt,layout.used_fallback,config.objective,config.enemies.size(),config.hero_ids.size())
     check(repeated.signature()==layout.signature(),"New composed layout reproduces exactly")
     rectangles(layout,config.generator_settings)
    await dispose(encounter)
 for preset in range(3):
  var config := EncounterConfiguration.new();config.generator_settings=EncounterOptions.presets()[preset].duplicate(true);config.generator_settings.generator_version=3;config.generator_settings.arena_size=Vector2.ONE;config.generator_settings.generation_attempts=1;config.optional_goal_id="cache"
  var encounter := await prepare(config)
  check(encounter.navigation_ready and config.layout.used_fallback and config.layout.attempt==2 and config.layout.generator_version==3,"Failed geometry uses bounded architecture-aware fallback")
  await dispose(encounter)
 generator.queue_free();await process_frame
 print("TACTICAL GENERATION maps=%d seconds=%.2f"%[completed,(Time.get_ticks_msec()-start)/1000.0])
 print("TACTICAL GENERATION RESULT: %d failures"%failures);quit(1 if failures else 0)
