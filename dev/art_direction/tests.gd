extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: failures+=1;push_error(message)
func run() -> void:
	var slab: ArrayMesh = preload("res://dev/art_direction/geometry.gd").bevel_box(Vector3(1.13,.055,1.18),.09)
	check(slab.get_aabb().position.y>=0 and slab.get_aabb().end.y<=.05501,"Thin paver bevel stays within its physical thickness")
	var scene = load("res://dev/art_direction/comparison.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for view in 3:
		scene.set_view(view)
		var before: Transform3D = scene.camera_rig.camera.global_transform
		for option in 3:
			scene.set_direction(option)
			await process_frame
			check(scene.actors.size()==5,"Five representative characters")
			check(scene.camera_rig.camera.global_transform.is_equal_approx(before),"Option switch preserves camera")
			for i in 5:
				check(scene.actors[i].position.is_equal_approx(scene.PLACEMENTS[i]),"Fixed actor positions")
				check(scene.actors[i]._clips.size()>=6,"Retain six animation clips")
			for clip in ["Idle","Walk","Attack","Cast","Hit","Death"]:
				scene.set_clip(clip)
				await process_frame
				scene.set_clip("Idle")
			check(scene.stage.find_children("*","CollisionObject3D",true,false).is_empty(),"Lab has no gameplay collision")
	scene.free()
	await process_frame
	var flow = load("res://scenes/main.tscn").instantiate()
	root.add_child(flow)
	check(flow.screen=="title","Normal title still opens after lab disposal")
	flow.show_party()
	flow.party.toggle("knight");flow.party.toggle("mage")
	flow.menu.start_button.pressed.emit()
	for frame in 1600:
		if flow.screen!="loading": break
		await process_frame
	check(flow.screen=="combat","Normal generated encounter still starts")
	if flow.combat!=null:
		var controller = flow.combat.get_node("CombatController")
		check(controller.units.size()==2+flow.current_configuration.enemies.size(),"Configured roster transfers after preview without extra actors")
		check(controller.units.filter(func(unit): return unit.faction==CombatUnit.Faction.HERO).size()==2,"Normal encounter has exactly two heroes")
	flow.free()
	await process_frame
	print("ART DIRECTION RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)
