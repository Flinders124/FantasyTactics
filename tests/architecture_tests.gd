extends "res://tests/generation_tests.gd"
func ray(from: Vector3,to: Vector3) -> Dictionary:
 return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,8))
func run() -> void:
 check(ResourceLoader.exists("res://scripts/courtyard_architecture.gd"),"Courtyard has reusable gameplay architecture")
 if not ResourceLoader.exists("res://scripts/courtyard_architecture.gd"):
  print("ARCHITECTURE RESULT: %d failures"%failures);quit(1);return
 var kit: Variant=load("res://scripts/courtyard_architecture.gd")
 var parent := Node3D.new();root.add_child(parent)
 kit.build(parent,"Gate",Vector3(0,1.8,0),Vector3(1,3.6,4),"arch")
 kit.build(parent,"House",Vector3(6,1.55,0),Vector3(4,3.1,4),"house")
 for kind: String in ["fountain","cart","altar"]:kit.build(parent,kind,Vector3(0,1,-8),Vector3(3,2,2),kind)
 await physics_frame;await physics_frame
 check(ray(Vector3(-2,1,0),Vector3(2,1,0)).is_empty(),"Arch opening admits movement-height visibility")
 check(not ray(Vector3(-2,1,1.65),Vector3(2,1,1.65)).is_empty(),"Arch pillars block attacks")
 check(ray(Vector3(10,1,0),Vector3(6,1,0)).is_empty(),"House doorway opens into interior")
 check(not ray(Vector3(6,1,0),Vector3(2,1,0)).is_empty(),"House rear wall blocks attacks")
 for body: Node in parent.get_children():
  check(body is StaticBody3D and body.collision_layer==9 and body.is_in_group("courtyard_occluder"),"Large props share static obstruction and reversible fading")
 parent.queue_free();await physics_frame
 var generator := BattlefieldGenerator.new();root.add_child(generator)
 var settings := BattlefieldSettings.new();settings.generator_version=3
 var first := generator.make_layout(37,settings,1)
 var second := generator.make_layout(37,settings,1)
 check(first!=null and first.generator_version==3 and first.signature()==second.signature(),"New composed layout is deterministic")
 check(first.obstacle_kinds.has("arch") and first.obstacle_kinds.has("house") and first.obstacle_kinds.has("fountain") and first.obstacle_kinds.has("cart") and first.obstacle_kinds.has("altar"),"Courtyard includes full reusable kit")
 settings.detail_density=0
 check(generator.make_layout(37,settings,1).geometry_signature()==first.geometry_signature(),"Decoration density cannot change new gameplay layout")
 settings.generator_version=2
 check(generator.make_layout(37,settings,1).obstacle_kinds.is_empty(),"Legacy layouts keep original collision kit")
 generator.queue_free();await process_frame
 var config := EncounterConfiguration.new();config.generator_settings.generator_version=3;config.battlefield_seed=37
 var encounter := await prepare(config)
 check(encounter.navigation_ready,"House-interior camera fixture navigates")
 var combat: CombatController=encounter.get_node("CombatController")
 var actor := combat.scheduler.active_unit()
 var index: int=config.layout.obstacle_kinds.find("house")
 var interior := NavigationService.planar(config.layout.obstacle_centers[index])
 check(encounter.get_node("NavigationService").query_path(actor.global_position,interior).valid(),"House interior connects through its actual doorway")
 actor.global_position=interior
 var player: PlayerController=encounter.get_node("PlayerController");player.set_process(false);player.cancel_targeting()
 var rig: TacticalCamera=encounter.get_node("TacticalCamera");rig.position=interior;rig.pitch=-.55;rig.distance=10;rig._update_transform()
 var house_body := encounter.get_node("NavigationRegion3D/Obstacle%d"%index)
 encounter.courtyard_occlusion.update_visibility()
 check(encounter.courtyard_occlusion.entries.has(house_body) and encounter.courtyard_occlusion.entries[house_body].active,"Walls fade when active unit is inside the house bounding box")
 encounter.courtyard_occlusion.restore_all()
 check(encounter.courtyard_occlusion.faded_count==0,"Interior fade restores without touching collision")
 await dispose(encounter)
 print("ARCHITECTURE RESULT: %d failures"%failures);quit(1 if failures else 0)
