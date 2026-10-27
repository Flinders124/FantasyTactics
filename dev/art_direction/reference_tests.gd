extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: failures+=1;push_error(message)
func run() -> void:
	var scene = load("res://dev/art_direction/reference_c.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.direction==2 and scene.reference_enabled,"Selected C reference opens")
	for view in 4:
		if view==3: scene.focus_characters()
		else: scene.set_view(view)
		var camera: Transform3D = scene.camera_rig.camera.global_transform
		for toggle in 2:
			scene.toggle_reference()
			await process_frame
			check(scene.camera_rig.camera.global_transform.is_equal_approx(camera),"Before/after preserves camera")
			check(scene.actors.size()==5,"Five fixed actors")
			for i in 5:
				check(scene.actors[i].position.is_equal_approx(scene.PLACEMENTS[i]),"Composition preserved")
		for clip in ["Idle","Walk","Attack","Cast","Hit","Death"]:
			scene.set_clip(clip)
			await process_frame
			scene.set_clip("Idle")
			check(scene.actors.all(func(actor): return not actor._dead and actor.current_clip=="Idle"),"Clip resets recover Idle")
	scene.free()
	await process_frame
	print("C REFERENCE RESULT: %d failures"%failures)
	quit(1 if failures else 0)
