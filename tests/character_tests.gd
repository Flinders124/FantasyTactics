extends "res://tests/attack_tests.gd"

func run() -> void:
	for role in CharacterVisual.ROLES:
		var visual := CharacterVisual.new()
		root.add_child(visual)
		visual.load_role(role)
		check(visual.skeleton.get_bone_count() == 18, role + " imports the shared rig")
		check(visual._clips.size() >= 6, role + " imports six skeletal clips")
		var meshes := visual.model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), role + " contains actual meshes")
		var triangles: int = 0
		for node in meshes:
			var mesh := (node as MeshInstance3D).mesh
			check(mesh is ArrayMesh, role + " uses imported geometry, not placeholder primitives")
			check((node as MeshInstance3D).skin != null or node.get_parent() is BoneAttachment3D, role + " follows the animated rig")
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				check((node as MeshInstance3D).get_active_material(surface) != null, "Visible material exists")
		check(triangles > 1000 and triangles < 5000, role + " has modest shaped mesh complexity")
		for clip in ["Idle", "Walk", "Attack", "Cast", "Hit", "Death"]:
			visual.reset_pose()
			visual.play_clip(clip, true)
			visual.player.pause()
			visual.player.seek(visual.player.get_animation(visual._clips[clip]).length * 0.6, true)
			var changed: bool = false
			for bone in visual.skeleton.get_bone_count():
				changed = changed or not visual.skeleton.get_bone_pose_rotation(bone).is_equal_approx(Quaternion.IDENTITY)
			check(changed, role + " " + clip + " changes a real skeletal pose")
		visual.reset_pose()
		check(not visual._dead and visual.current_clip == "Idle", "Reset recovers a living idle pose")
		visual.free()
	encounter = (load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate()
	encounter.get_node("EnemyController").enabled = false
	root.add_child(encounter)
	while not encounter.navigation_ready:
		await physics_frame
	controller = encounter.get_node("CombatController") as CombatController
	hero = controller.find_unit("hero-01")
	raider = controller.find_unit("enemy-01")
	hero.position = Vector3(-4, 0, 3)
	raider.position = Vector3(-1, 0, 3)
	await physics_frame
	await physics_frame
	check(controller.submit_command(MoveCommand.new(hero.stable_id, Vector3(-3, 0, 3))), "Actual movement accepted")
	for frame in range(6):
		await physics_frame
	check(hero.character.current_clip in ["Walk","Run"], "Actual displacement drives the speed-matched gait")
	await wait_for_action()
	for frame in range(3):
		await physics_frame
	check(hero.character.current_clip == "Idle", "Movement returns to idle")
	var before := raider.health
	check(controller.submit_command(AttackCommand.new(hero.stable_id, raider.stable_id)), "Actual melee accepted")
	check(hero.character.current_clip == "Attack" and raider.character.current_clip == "Hit", "Authoritative attack/damage trigger distinct animations")
	for iteration in range(3):
		hero.character.player.seek(.3, true)
	check(raider.health == before - 4, "Seeking presentation cannot repeat damage")
	await wait_for_action()
	hero.set_health(hero.health - 2)
	hero.action_available = true
	check(controller.submit_command(UseAbilityCommand.new(hero.stable_id, hero.stable_id, "mend")), "Actual self heal accepted")
	check(hero.character.current_clip == "Cast", "Healing triggers cast")
	raider.set_health(0)
	check(raider.character.current_clip == "Death" and raider.collision_layer == 0, "Death poses while gameplay collision disables immediately")
	await controller.restart_encounter()
	await physics_frame
	for unit in controller.units:
		check(unit.is_alive() and not unit.character._dead and unit.character.current_clip == "Idle", "Restart resets runtime and visual state")
		check(unit.get_node("Visual").get_child_count() == 1, "Restart never duplicates model instances")
	encounter.free()
	await process_frame
	print("CHARACTER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
