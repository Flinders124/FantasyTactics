extends "res://tests/generation_tests.gd"
const ART = preload("res://scripts/lantern_art.gd")
const SHAPES = preload("res://assets/art/lantern_shapes.gd")

func contains_physics(node: Node) -> bool:
	if node is CollisionObject3D or node is NavigationRegion3D: return true
	for child in node.get_children():
		if contains_physics(child): return true
	return false

func run() -> void:
	var box := SHAPES.bevel_box(Vector3.ONE,.04)
	var data := box.surface_get_arrays(0)
	var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		if vertices[i].is_equal_approx(Vector3(0,1,0)):
			check(normals[i].dot(Vector3.UP)>.99,"Bevel cap has an outward, flat normal")
	for id in ["wall","ruin_plinth","pillar","boundary_stone"]:
		var bounds := CourtyardKit.mesh(id).get_aabb()
		check(AABB(Vector3(-.501,-.001,-.501),Vector3(1.002,1.002,1.002)).encloses(bounds),"Masonry stays within the original footprint: "+id)
	check(CourtyardKit.mesh("crate").surface_get_material(0) is ShaderMaterial,"Shared camp props have an authored default material")
	var owner := GameAudio.new();owner.preferences=SettingsSchema.defaults()
	for preset: String in ["open_courtyard","ruined_lanes","central_plaza"]:
		var config := EncounterConfiguration.new();config.battlefield_seed=19
		config.generator_settings=load("res://definitions/presets/"+preset+".tres")
		config.objective=load("res://definitions/objectives/hold_ground.tres")
		var encounter := await prepare(config)
		check(encounter.navigation_ready,"Upgraded "+preset+" bakes and loads")
		var layout := config.layout
		var signature := layout.geometry_signature()
		check(not contains_physics(encounter.get_node("CourtyardDressing")),"Dressing remains entirely non-physical")
		for index in layout.obstacle_sizes.size():
			var body := encounter.get_node("NavigationRegion3D/Obstacle%d"%index)
			var kind := CourtyardKit.obstacle_kind(layout,index)
			var size := layout.obstacle_sizes[index]
			var rotated := kind=="wall" and size.z>size.x
			var basis := Basis(Vector3.UP,PI*.5 if rotated else 0.0)*Basis.from_scale(Vector3(size.z,size.y,size.x) if rotated else size)
			var expected := (load("res://assets/courtyard/collision/"+kind+".res") as ConcavePolygonShape3D).get_faces()
			for k in expected.size(): expected[k]=basis*expected[k]
			var shapes := body.find_children("*","CollisionShape3D",true,false)
			check(shapes.size()==1 and shapes[0].shape.get_faces()==expected,"Original collider faces retained exactly")
		for quality in 3:
			owner.preferences.Display.graphics=quality
			SettingsPresentation.apply_tree(root,owner)
			check(root.msaa_3d==[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality],"AA follows the supported preset")
			check(not encounter.get_node("LanternFill").shadow_enabled,"Fill never casts redundant shadows")
			check(encounter.get_node("Sun").shadow_enabled==(quality>0),"Only sun shadows follow quality")
			check(signature==layout.geometry_signature(),"Quality switching preserves geometry and objectives")
		for spawn in layout.spawns:
			check(encounter.get_node("NavigationService").query_path(spawn,layout.objective_center).valid(),"Objective remains reachable")
		await dispose(encounter)
	owner.free()
	print("ENVIRONMENT RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
