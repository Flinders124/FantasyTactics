extends SceneTree
var output: String = ""
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output=args[0] if args.size()>0 else "user://art_direction"
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene = load("res://dev/art_direction/comparison.tscn").instantiate()
	root.add_child(scene)
	var report: Array[Dictionary] = []
	for option in 3:
		scene.set_direction(option)
		for view in 3:
			scene.set_view(view)
			scene.set_clip("Idle")
			await process_frame
			await RenderingServer.frame_post_draw
			await create_timer(.15).timeout
			await RenderingServer.frame_post_draw
			var filename: String = "%s/%s-%s.png" % [output,["A","B","C"][option],["gameplay","detail","architecture"][view]]
			root.get_texture().get_image().save_png(filename)
			print("CAPTURE "+filename)
		scene.set_view(0)
		var frames: Array[float] = []
		for warmup in 20: await process_frame
		for frame in 90:
			var start: int = Time.get_ticks_usec()
			await process_frame
			frames.append((Time.get_ticks_usec()-start)/1000.0)
		frames.sort()
		report.append({"option":["A","B","C"][option],"cpu_wall_frame_ms_median":frames[45],"cpu_wall_frame_ms_p95":frames[85],"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))})
	# Matching lower-resolution readability captures.
	root.size=Vector2i(1280,720)
	for option in 3:
		scene.set_direction(option);scene.set_view(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s-gameplay-720p.png" % [output,["A","B","C"][option]])
	make_contact_sheet("comparison-all-views.png",["gameplay","detail","architecture"])
	make_contact_sheet("comparison-detail.png",["detail"])
	make_contact_sheet("comparison-gameplay.png",["gameplay"])
	var file := FileAccess.open(output+"/render-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	scene.free()
	await process_frame
	print("ART CAPTURE COMPLETE")
	quit()

func make_contact_sheet(filename: String,views: Array[String]) -> void:
	var sheet := Image.create_empty(2880,540*views.size(),false,Image.FORMAT_RGB8)
	for row in views.size():
		for column in 3:
			var source := Image.load_from_file("%s/%s-%s.png"%[output,["A","B","C"][column],views[row]])
			source.convert(Image.FORMAT_RGB8)
			source.resize(960,540,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(source,Rect2i(0,0,960,540),Vector2i(column*960,row*540))
	sheet.save_png(output+"/"+filename)