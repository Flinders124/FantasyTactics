class_name CourtyardKit
extends RefCounted
## Presentation may evolve independently of the original static collision kit.
## Decorations never receive CollisionObjects or navigation layers.
const ART = preload("res://scripts/lantern_art.gd")
const ENVIRONMENT = preload("res://scripts/lantern_environment.gd")
const ROOT: String = "res://assets/courtyard/"

static func mesh(id: String) -> ArrayMesh:
	# ResourceLoader already shares live native resources. Static GDScript caches
	# unnecessarily retain the entire kit through engine shutdown in Godot 4.7.
	if id=="arch": return ART.arch()
	if id=="tree": return ENVIRONMENT.tree()
	var upgraded := ENVIRONMENT.mesh(id)
	if upgraded!=null:
		# CampKit also uses this factory without an instance override.
		upgraded.surface_set_material(0,ART.scenery(id))
		return upgraded
	return load(ROOT+"meshes/"+id+".res") as ArrayMesh

static func earth_material() -> Material:
	var material := ART.paint(Color("344a59"))
	material.set_shader_parameter("surface_kind",2.0)
	return material

static func obstacle_kind(layout: BattlefieldLayout,index: int) -> String:
	if layout.preset_id=="central_plaza" and index==0: return "statue"
	if layout.preset_id=="central_plaza": return "pillar"
	if layout.preset_id=="open_courtyard" and index==0: return "fountain"
	var size := layout.obstacle_sizes[index]
	if maxf(size.x,size.z)/minf(size.x,size.z)>1.35:
		return "wall"
	if minf(size.x,size.z)<1.8 and size.y>1.8:
		return "pillar"
	return "ruin_plinth"

static func blocker(parent: Node3D,id: String,center: Vector3,size: Vector3,kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name=id
	body.collision_layer=9 # Movement/world + static visibility. No ground picking.
	body.position=center-Vector3.UP*size.y*.5
	var rotate := kind=="wall" and size.z>size.x
	var scale_size := Vector3(size.z,size.y,size.x) if rotate else size
	var basis := Basis(Vector3.UP,PI*.5 if rotate else 0.0)*Basis.from_scale(scale_size)
	var visual := MeshInstance3D.new()
	visual.name="Masonry"
	visual.mesh=mesh(kind)
	visual.material_override=ART.scenery(kind)
	visual.transform=Transform3D(basis,Vector3.ZERO)
	body.add_child(visual)
	if kind in ["wall","ruin_plinth"]:
		var ivy := MeshInstance3D.new()
		ivy.name="ClingingIvy"
		ivy.mesh=mesh("ivy")
		ivy.material_override=ART.scenery("ivy")
		ivy.position=Vector3(0,size.y*.90,-size.z*.502)
		ivy.scale=Vector3(size.x*.8,size.y*.9,1)
		ivy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(ivy)
	var source := load(ROOT+"collision/"+kind+".res") as ConcavePolygonShape3D
	var points := source.get_faces()
	for k in range(points.size()): points[k]=basis*points[k]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(points)
	shape.backface_collision=true
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	body.set_meta("courtyard_kind",kind)
	body.set_meta("footprint",Rect2(Vector2(-size.x,-size.z)*.5,Vector2(size.x,size.z)))
	body.set_meta("occlusion_bounds",visual.transform*visual.mesh.get_aabb())
	body.add_to_group("courtyard_occluder")
	parent.add_child(body)
	return body

static func ground(parent: Node3D,size: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name="Ground"
	body.position=Vector3(0,-.25,0)
	body.collision_layer=11 # World + ground picking + static visibility.
	var shape := BoxShape3D.new()
	shape.size=Vector3(size.x,.5,size.y)
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	var plane := PlaneMesh.new()
	plane.size=size
	var visual := MeshInstance3D.new()
	visual.mesh=plane
	visual.position.y=.248
	visual.material_override=earth_material()
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	parent.add_child(body)

static func boundary(parent: Node3D,id: String,center: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name=id
	body.position=center-Vector3.UP*size.y*.5
	body.collision_layer=9
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	collision.position.y=size.y*.5
	body.add_child(collision)
	var along_x := size.x>size.z
	var length := maxf(size.x,size.z)
	var count := ceili(length/1.3)
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=mesh("boundary_stone")
	multimesh.instance_count=count
	for k in range(count):
		var scale_size := Vector3(length/float(count),size.y,minf(size.x,size.z))
		var offset := -length*.5+(float(k)+.5)*length/float(count)
		var basis := Basis(Vector3.UP,0.0 if along_x else PI*.5)*Basis.from_scale(scale_size)
		multimesh.set_instance_transform(k,Transform3D(basis,Vector3(offset if along_x else 0.0,0,0.0 if along_x else offset)))
	var visual := MultiMeshInstance3D.new()
	visual.multimesh=multimesh
	visual.material_override=ART.scenery("boundary_stone")
	body.add_child(visual)
	body.set_meta("occlusion_bounds",AABB(Vector3(-size.x*.5,0,-size.z*.5),size))
	body.add_to_group("courtyard_occluder")
	parent.add_child(body)
