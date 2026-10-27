class_name CharacterPortrait
extends SubViewportContainer
const ART = preload("res://scripts/lantern_art.gd")
## A render of the equipped gameplay asset, not a separate concept illustration.
func setup(role: String) -> void:
	custom_minimum_size = Vector2(132, 180)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.size = Vector2i(256, 300)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.set_meta("oath_portrait",true)
	view.size_changed.connect(func() -> void: view.render_target_update_mode=SubViewport.UPDATE_ONCE)
	view.gui_disable_input = true
	view.transparent_bg = false
	add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.055, 0.085, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.87, 1.0)
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.5
	stage.add_child(light)
	ART.lighting(environment,light,true)
	var visual := CharacterVisual.new()
	stage.add_child(visual)
	visual.load_role(role)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.45
	camera.position = Vector3(2.5, 1.8, -4)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.current = true

	_freeze.call_deferred(view,visual)
func _freeze(view: SubViewport,visual: CharacterVisual) -> void:
	# Wait for import/animation setup and a real draw, not a wall-clock timer.
	for frame in 3:
		if not is_inside_tree() or not is_instance_valid(view): return
		await get_tree().process_frame
	if not is_instance_valid(view) or not is_instance_valid(visual): return
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	if not is_instance_valid(view) or not is_instance_valid(visual): return
	visual.set_process(false)
	if visual.player!=null: visual.player.pause()
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED
