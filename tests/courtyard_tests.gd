extends "res://tests/generation_tests.gd"
## Environment-specific checks supplement the 25-seed navigation suite.

func contains_physics(node: Node) -> bool:
	if node is CollisionObject3D or node is NavigationRegion3D: return true
	for child in node.get_children():
		if contains_physics(child): return true
	return false

func run() -> void:
	var config := EncounterConfiguration.new()
	config.battlefield_seed=7
	var encounter := await prepare(config)
	check(encounter.navigation_ready,"Courtyard is playable after baking")
	var dressing := encounter.get_node("CourtyardDressing") as CourtyardDressing
	check(not contains_physics(dressing),"Dressing cannot block movement, shots or navigation")
	var signature := dressing.signature()
	var layout_signature := config.layout.geometry_signature()
	var duplicate := CourtyardDressing.new()
	root.add_child(duplicate)
	duplicate.build(config.layout,config.generator_settings)
	check(duplicate.signature()==signature,"Retry reproduces exact dressing")
	duplicate.queue_free()
	await process_frame
	var settings := config.generator_settings.duplicate() as BattlefieldSettings
	settings.vegetation_density=0
	settings.rubble_density=0
	settings.dressing_seed_offset=83
	var generator := BattlefieldGenerator.new()
	root.add_child(generator)
	var alternate := generator.make_layout(7,settings,config.layout.attempt,config.layout.used_fallback)
	check(alternate.geometry_signature()==layout_signature,"Cosmetics never alter gameplay random stream")
	var different := CourtyardDressing.new()
	root.add_child(different)
	different.build(alternate,settings)
	check(different.signature()!=signature,"Cosmetic configuration changes dressing independently")
	different.queue_free()
	generator.queue_free()
	var occlusion := encounter.courtyard_occlusion
	check(occlusion!=null and occlusion.roots.size()>=11,"All blocking props and boundaries register visibility bounds")
	var prop := occlusion.roots.filter(func(item: Node3D) -> bool: return (item.get_meta("occlusion_bounds") as AABB).size.y>1.5)[0] as Node3D
	var visual := occlusion._meshes(prop)[0]
	var original := visual.material_override
	var shadow := visual.cast_shadow
	occlusion._fade(prop,true)
	var faded := visual.material_override as ShaderMaterial
	check(faded!=null and faded!=original and is_equal_approx(float(faded.get_shader_parameter("fade_opacity")),.24),"Occlusion creates local transparent material")
	check(prop is StaticBody3D and (prop as StaticBody3D).collision_layer==9,"Fading preserves collision and visibility masks")
	occlusion.restore_all()
	check(visual.material_override==original and visual.cast_shadow==shadow,"Clear view restores exact material and shadow state")
	var controller := encounter.get_node("CombatController") as CombatController
	var actor := controller.scheduler.active_unit()
	var actor_before := actor.position
	var view_before := occlusion.camera.global_position
	actor.position=prop.global_position+Vector3(0,0,4)
	occlusion.camera.global_position=prop.global_position+Vector3(0,1,-4)
	occlusion.update_visibility()
	check(occlusion.faded_count>0,"Camera-to-unit segment fades foreground masonry")
	occlusion.camera.global_position=prop.global_position+Vector3(0,8,4)
	occlusion.update_visibility()
	check(visual.material_override==original,"Moving to clear angle restores foreground prop")
	actor.position=actor_before
	occlusion.camera.global_position=view_before
	occlusion._fade(prop,true)
	encounter.shutdown()
	check(visual.material_override==original,"Encounter shutdown restores faded props")
	await dispose(encounter)
	print("Courtyard determinism, cosmetic isolation, collision masks and occluder cleanup checked")
	print("RESULT: %d failures" % failures)
	quit(0 if failures==0 else 1)


