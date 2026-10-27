extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene = load("res://dev/art_direction/reference_c.tscn").instantiate()
	root.add_child(scene)
	for view in 4:
		if view==3: scene.focus_characters()
		else: scene.set_view(view)
		for state in [false,true]:
			scene.reference_enabled=state;scene.set_direction(2);scene.set_clip("Idle")
			await process_frame
			await RenderingServer.frame_post_draw
			await create_timer(.1).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+("reference" if state else "baseline")+"-"+["gameplay","ensemble","architecture","characters"][view]+".png")
	var sheet := Image.create_empty(1920,1080,false,Image.FORMAT_RGB8)
	for row in 2:
		for column in 2:
			var source := Image.load_from_file(output+"/"+("baseline" if column==0 else "reference")+"-"+["ensemble","characters"][row]+".png")
			source.convert(Image.FORMAT_RGB8);source.resize(960,540,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(source,Rect2i(0,0,960,540),Vector2i(column*960,row*540))
	sheet.save_png(output+"/before-after.png")
	root.size=Vector2i(1280,720);scene.set_view(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/reference-gameplay-720p.png")
	scene.free();await process_frame
	print("C REFERENCE CAPTURES COMPLETE")
	quit()
