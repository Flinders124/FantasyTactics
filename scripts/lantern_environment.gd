extends RefCounted
## Presentation meshes only. Gameplay continues to use the original collision kit.
const SHAPES = preload("res://assets/art/lantern_shapes.gd")
const ART = preload("res://scripts/lantern_art.gd")

static func block(s: SurfaceTool,size: Vector3,at: Vector3,tone: float=1.0,angle: float=0.0,bevel: float=.025) -> void:
	var mesh := SHAPES.bevel_box(size,bevel)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var basis := Basis(Vector3.UP,angle)
	for i in points.size():
		var face := i-i%3
		# Flat normals keep the broad faces quiet under the banded lighting;
		# averaging cap edges creates enormous false highlights on thin slabs.
		var normal := (points[face+2]-points[face]).cross(points[face+1]-points[face]).normalized()
		s.set_color(Color(tone,tone,tone));s.set_normal(basis*normal);s.add_vertex(basis*points[i]+at)

static func mesh(id: String) -> ArrayMesh:
	var s := SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	if id.begins_with("paver_"):
		var variant := int(id.trim_prefix("paver_"))
		block(s,Vector3(1,.038,1),Vector3(0,-.038,0),.94+variant*.025,0,.014)
	elif id in ["wall","ruin_plinth"]:
		# Course joints and broad capstones read at tactical scale; all within the
		# original normalized footprint and height, including chipped bevels.
		for row in 4:
			var widths: Array = [.49,.49] if row%2==0 else [.235,.49,.235]
			var x := -.49
			for col in widths.size():
				var width: float=widths[col]
				block(s,Vector3(width-.012,.208,.91),Vector3(x+width*.5,.045+row*.218,0),.88+float((row*7+col*3)%5)*.045,0,.025)
				x+=width+.01
		block(s,Vector3(1,.075,1),Vector3(0,.925,0),1.16,0,.025)
		block(s,Vector3(1,.045,1),Vector3.ZERO,.90,0,.012)
	elif id=="pillar":
		block(s,Vector3(1,.11,1),Vector3.ZERO,1.14,0,.028)
		for row in 4:
			block(s,Vector3(.73,.18,.73),Vector3(0,.12+row*.185,0),.90+row*.035,0,.035)
		block(s,Vector3(.88,.06,.88),Vector3(0,.865,0),.77,0,.015)
		block(s,Vector3(1,.075,1),Vector3(0,.925,0),1.18,0,.026)
	elif id=="boundary_stone":
		block(s,Vector3(.98,.74,.89),Vector3.ZERO,.88,0,.055)
		block(s,Vector3(1,.22,1),Vector3(0,.78,0),1.12,0,.055)
	elif id=="ivy":
		for i in 24:
			var leaf := SHAPES.leaf(.10,.17,.025)
			var a := leaf.surface_get_arrays(0)
			var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var b := Basis(Vector3.BACK,PI+sin(i*1.8)*.6)
			for k in v.size():
				var tone := .8+float(i%4)*.09
				s.set_color(Color(tone,tone,tone));s.set_normal(b*n[k]);s.add_vertex(b*v[k]+Vector3(sin(i*1.8)*.32,-float(i%8)*.10,-.025))
	elif id in ["grass","fern","shrub"]:
		# Folded copper leaves replace needle-like grass. Baked variation, one
		# opaque surface, no alpha cards or expensive foliage shadows.
		var count: int=7 if id=="grass" else 15 if id=="fern" else 25
		for i in count:
			var angle := i*2.399963
			var radius := .035 if id=="grass" else .13 if id=="fern" else .25
			var height := .22+float(i%4)*.045 if id!="shrub" else .32+float(i%5)*.06
			var width := .06 if id=="grass" else .12 if id=="fern" else .20
			var leaf := SHAPES.leaf(width,height,.04)
			var a := leaf.surface_get_arrays(0)
			var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var b := Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,.25+float(i%3)*.19)
			for k in v.size():
				var tone := .78+float(i%5)*.085
				s.set_color(Color(tone,tone,tone));s.set_normal(b*n[k]);s.add_vertex(b*v[k]+Vector3(cos(angle)*radius,0,sin(angle)*radius))
	elif id=="crate":
		block(s,Vector3(.72,.74,.72),Vector3.ZERO,.72,0,.02)
		for side in [-1.0,1.0]:
			for x in [-.29,.29]: block(s,Vector3(.09,.78,.07),Vector3(x,0,side*.39),1.3,0,.012)
			for y in [0.0,.69]: block(s,Vector3(.8,.09,.07),Vector3(0,y,side*.39),1.18,0,.012)
		for x in [-.26,0,.26]: block(s,Vector3(.24,.045,.74),Vector3(x,.76,0),1.0,0,.008)
	else:
		return null
	return s.commit()

static func tree() -> ArrayMesh:
	var s := SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	block(s,Vector3(.17,2.4,.19),Vector3.ZERO,.35,.2,.025)
	# Asymmetric angular crown; clustered forms instead of identical cone stacks.
	for i in 7:
		var angle := i*2.399963
		var at := Vector3(cos(angle)*(.48 if i>0 else 0),1.65+float(i%3)*.48,sin(angle)*.48)
		block(s,Vector3(1.15,1.1,1.05),at,.82+float(i%4)*.12,angle,.26)
	return s.commit()

static func banner(parent: Node3D,at: Vector3,angle: float=0.0) -> void:
	var root := Node3D.new();root.name="OathStandard";root.position=at;root.rotation.y=angle;parent.add_child(root)
	ART.part(root,SHAPES.bevel_box(Vector3(.13,3.3,.13),.015),Vector3(-.65,0,0),ART.paint(Color("394b61")))
	ART.part(root,SHAPES.bevel_box(Vector3(1.3,.09,.12),.012),Vector3(-.1,3.03,0),ART.paint(Color("efb875"),.45,.55))
	var cloth := SurfaceTool.new();cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Array[Vector3]=[Vector3(-.5,3,0),Vector3(.5,3,0),Vector3(.5,1.65,0),Vector3(0,1.32,.06),Vector3(-.5,1.65,0)]
	for i in 5: SHAPES.tri(cloth,Vector3(0,2.3,.08),edge[i],edge[(i+1)%5])
	cloth.generate_normals();ART.part(root,cloth.commit(),Vector3.ZERO,ART.paint(Color("378b9b")))
	ART.part(root,SHAPES.leaf(.33,.55,.025),Vector3(0,2.05,.095),ART.paint(Color("efe3b6")))
	ART.part(root,SHAPES.bevel_box(Vector3(.48,.16,.48),.04),Vector3(-.65,0,0),ART.scenery("boundary_stone"))
	root.set_meta("occlusion_bounds",AABB(Vector3(-.9,0,-.3),Vector3(1.6,3.35,.6)))
	root.add_to_group("courtyard_occluder")
