extends "res://tests/movement_tests.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 encounter=load("res://scenes/combat_encounter.tscn").instantiate();encounter.get_node("EnemyController").enabled=false;root.add_child(encounter)
 while not encounter.navigation_ready:await physics_frame
 controller=encounter.get_node("CombatController");navigation=encounter.get_node("NavigationService");motor=encounter.get_node("MovementMotor");hero=controller.scheduler.active_unit()
 check(controller.has_method("plan_player_move"),"Player moves expose one shared maximum-distance plan")
 if not controller.has_method("plan_player_move"):
  encounter.queue_free();await process_frame;print("TACTICAL MOVEMENT RESULT: %d failures"%failures);quit(1);return
 hero.global_position=Vector3(-5,0,6);hero.movement_remaining=2.5;await physics_frame
 var goal := Vector3(4,0,6)
 var plan: Variant=controller.call("plan_player_move",hero,goal)
 check(plan.valid() and plan.limited and plan.full_route.distance>8.9 and plan.route.distance<=2.5,"Over-budget target yields affordable prefix of full actual path")
 if not plan.valid():
  print("Plan error: ",plan.route.error);encounter.queue_free();await process_frame;print("TACTICAL MOVEMENT RESULT: %d failures"%failures);quit(1);return
 check(plan.route.distance>2.45 and plan.route.path[-1].distance_to(Vector3(-2.5,0,6))<.02,"Marker reaches remaining allowance rather than requiring precise click")
 var other := controller.units[1];var saved := other.global_position
 other.global_position=plan.route.path[-1];await physics_frame
 var blocked: Variant=controller.call("plan_player_move",hero,goal)
 check(blocked.valid() and blocked.route.distance<2.0 and not controller._destination_occupied(hero,blocked.route.path[-1]),"Occupied boundary chooses an earlier legal endpoint")
 other.global_position=saved;await physics_frame
 check(not controller.call("plan_player_move",hero,Vector3(100,0,100)).valid(),"Clipping cannot turn unreachable destination into valid movement")
 var player: Node=encounter.get_node("PlayerController")
 player.set_process(false)
 player.call("show_move_preview",goal)
 for frame in range(3):await process_frame
 var hud: Node=encounter.get_node("HUD")
 check(hud.preview_label.get_global_rect().end.y<=700,"Movement range feedback fits above the viewport bottom without scrolling")
 check(player.line.mesh.get_surface_count()==2,"Movement path has distinct affordable and unaffordable surfaces")
 check(player.destination_marker.visible and player.requested_marker.visible,"Reachable stop and requested target have distinct markers")
 var command := MoveCommand.new(hero.stable_id,goal);command.set("allow_partial",true)
 motor.movement_speed=12
 var start := hero.global_position
 check(controller.submit_player_command(command),"Over-range player click submits a legal partial move")
 check(not controller.submit_player_command(command),"Repeated input cannot queue another partial move")
 await wait_for_motor()
 check(controller.state==CombatController.State.AWAITING_COMMAND and start.distance_to(hero.global_position)<=2.502 and hero.movement_remaining<.02,"Actual travel spends only remaining allowance and returns control")
 check(hero.global_position.distance_to(plan.route.path[-1])<.02,"Execution matches stopping marker")
 hero.movement_remaining=0
 check(not controller.call("plan_player_move",hero,goal).valid(),"No movement remains a separate rejection")
 hero.global_position=Vector3(-4,0,0);hero.movement_remaining=4;await physics_frame
 var bent: Variant=controller.call("plan_player_move",hero,Vector3(4,0,0))
 check(bent.valid() and bent.full_route.distance>8.1 and bent.route.distance<=4.000001,"Clipped movement measures the actual route around the central wall")
 var sliced := NavigationService.slice_path(PackedVector3Array([Vector3.ZERO,Vector3(3,0,0),Vector3(3,0,4)]),1,5)
 check(is_equal_approx(NavigationService.path_length(sliced),4),"Green/red geometry splits across bends without losing length")
 var enemy := controller.find_unit("enemy-01")
 check(not controller.call("plan_player_move",enemy,goal).valid(),"Player partial moves never control enemies")
 encounter.queue_free();await process_frame
 print("TACTICAL MOVEMENT RESULT: %d failures"%failures);quit(1 if failures else 0)
