extends SceneTree
var stage: Node3D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	stage = load("res://scenes/faction_showcase.tscn").instantiate() as Node3D
	root.add_child(stage)
	for view in 4:
		stage.set_view(view)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://assets/characters/factions_view_%d.png" % view)
	for clip in ["Walk", "Attack", "Cast", "Hit", "Death"]:
		stage.set_clip(clip)
		stage.set_view(3)
		for visual in stage.visuals:
			visual.player.pause()
			visual.player.seek(visual.player.get_animation(visual._clips[clip]).length * .6, true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://assets/characters/factions_%s.png" % clip.to_lower())
	stage.free()
	quit()

