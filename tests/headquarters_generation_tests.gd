extends "res://tests/generation_tests.gd"
func run() -> void:
 var started := Time.get_ticks_msec()
 var generator := BattlefieldGenerator.new();root.add_child(generator)
 for count in [3,4]:
  for preset in range(3):
   for objective in range(3):
    for seed_value in [7,17,37,71,101]:
     var config := EncounterConfiguration.new()
     config.hero_ids=PackedStringArray(["knight","ranger","mage","cleric"].slice(0,count))
     config.generator_settings=EncounterOptions.presets()[preset].duplicate(true)
     config.objective=EncounterOptions.objectives()[objective].duplicate(true)
     config.battlefield_seed=seed_value
     var encounter := await prepare(config)
     var context := "%d heroes preset%d objective%d seed%d"%[count,preset,objective,seed_value]
     check(encounter.navigation_ready,"Connected generation: "+context)
     if encounter.navigation_ready:
      completed+=1
      var layout := config.layout
      var nav: NavigationService=encounter.get_node("NavigationService")
      var repeated := generator.make_layout(seed_value,config.generator_settings,layout.attempt,layout.used_fallback,config.objective,config.enemies.size(),count)
      check(repeated!=null and repeated.signature()==layout.signature() and repeated.spawns==layout.spawns,"Deterministic larger squad: "+context)
      rectangles(layout,config.generator_settings)
      for index in range(layout.spawns.size()):
       check(nav.query_path(layout.spawns[0],layout.spawns[index]).valid(),"All spawns connected: "+context)
       for previous in range(index):
        check(layout.spawns[index].distance_to(layout.spawns[previous])>.85,"Spawn separation: "+context)
     await dispose(encounter)
 print("HEADQUARTERS GENERATION maps=%d seconds=%.2f"%[completed,(Time.get_ticks_msec()-started)/1000.0])
 generator.queue_free();await process_frame
 print("HEADQUARTERS GENERATION RESULT: %d failures"%failures);quit(1 if failures else 0)
