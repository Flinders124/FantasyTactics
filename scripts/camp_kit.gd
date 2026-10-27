class_name CampKit
extends RefCounted
## Original editable camp mesh source. Presentation only: no physics/navigation.
var canvas: StandardMaterial3D = material(Color("78614a"))
var trim: StandardMaterial3D = material(Color("cfb47c"))
var timber: StandardMaterial3D = material(Color("49352c"))
var iron: StandardMaterial3D = material(Color("404b51"))
var parchment: StandardMaterial3D = material(Color("d8c79e"))
var blue: StandardMaterial3D = material(Color("426b75"))
var glow: StandardMaterial3D = material(Color("ffc475"))

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color; result.roughness=.93
	return result

func piece(parent: Node3D,mesh: Mesh,at: Vector3,paint: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh=mesh; node.position=at; node.material_override=paint
	parent.add_child(node); return node

func box(parent: Node3D,at: Vector3,size: Vector3,paint: Material) -> MeshInstance3D:
	var mesh := preload("res://assets/art/lantern_shapes.gd").bevel_box(size,minf(.045,size.y*.2))
	return piece(parent,mesh,at-Vector3.UP*size.y*.5,paint)

func beam(parent: Node3D,from: Vector3,to: Vector3,width: float,paint: Material) -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius=width; mesh.bottom_radius=width; mesh.height=from.distance_to(to); mesh.radial_segments=6
	var node := piece(parent,mesh,(from+to)*.5,paint)
	node.quaternion=Quaternion(Vector3.UP,(to-from).normalized())

func cloth(parent: Node3D,vertices: Array[Vector3],paint: Material) -> void:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var center := Vector3.ZERO
	for point in vertices: center+=point/float(vertices.size())
	var normal := (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0])
	var reverse := normal.dot(Vector3(center.x,.5,center.z))<0
	for k in range(1,vertices.size()-1):
		for point: Vector3 in ([vertices[0],vertices[k+1],vertices[k]] if reverse else [vertices[0],vertices[k],vertices[k+1]]): surface.add_vertex(point)
	surface.generate_normals()
	var node := piece(parent,surface.commit(),Vector3.ZERO,paint)
	# Canvas must remain visible from either side of an open tent.
	var two_sided := paint.duplicate() as StandardMaterial3D; two_sided.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=two_sided

func tent(parent: Node3D,at: Vector3,tint: Color,angle: float=0) -> Node3D:
	var root := Node3D.new(); root.name="CanvasTent"; root.position=at; root.rotation.y=angle; parent.add_child(root)
	var fabric := material(tint)
	# Peaked canvas with an eave and inset folds, rather than a primitive cone.
	for side: float in [-1.0,1.0]:
		cloth(root,[Vector3(0,3.1,-2),Vector3(side*1.8,1.5,-1.9),Vector3(side*1.95,1.45,0),Vector3(side*1.8,1.5,1.9),Vector3(0,3.1,2)],fabric)
		cloth(root,[Vector3(side*1.8,1.5,-1.9),Vector3(side*1.95,.08,-1.9),Vector3(side*1.95,.08,1.9),Vector3(side*1.8,1.5,1.9)],fabric)
		# Open front flaps frame a genuinely dark interior.
		cloth(root,[Vector3(0,3.1,2),Vector3(side*1.8,1.5,1.9),Vector3(side*1.95,.08,1.9),Vector3(side*.8,.05,1.98),Vector3(side*.6,1.9,2.02)],fabric)
		cloth(root,[Vector3(0,3.1,-2),Vector3(side*1.8,1.5,-1.9),Vector3(side*1.95,.08,-1.9),Vector3(0,.08,-2)],fabric)
		for z: float in [-1.9,1.9]:
			beam(root,Vector3(side*1.8,1.5,z),Vector3(side*2.5,.08,z+.4),.022,trim)
			beam(root,Vector3(side*2.5,0,z+.4),Vector3(side*2.5,.32,z+.4),.06,timber)
		beam(root,Vector3(0,3.12,2.03),Vector3(side*1.8,1.51,1.93),.035,trim)
	beam(root,Vector3(0,.02,1.8),Vector3(0,3.25,1.8),.075,timber)
	beam(root,Vector3(0,3.15,-2.1),Vector3(0,3.15,2.1),.065,timber)
	box(root,Vector3(0,.03,0),Vector3(3.7,.04,3.8),material(Color("342e2a")))
	# Distinct faction pennant and trim shared with camp signage.
	cloth(root,[Vector3(0,3.4,.6),Vector3(0,3.4,-.7),Vector3(0,2.65,-.35),Vector3(0,3,.6)],blue)
	return root

func board(parent: Node3D,at: Vector3) -> void:
	var root := Node3D.new(); root.position=at; parent.add_child(root)
	for x: float in [-1.0,1.0]: beam(root,Vector3(x,0,0),Vector3(x,2.7,0),.1,timber)
	box(root,Vector3(0,1.85,0),Vector3(2.5,1.5,.18),timber)
	box(root,Vector3(0,1.85,.12),Vector3(2.23,1.22,.04),blue)
	for i in range(3):
		var paper := box(root,Vector3(-.7+i*.69,1.9,.16),Vector3(.52,.78,.025),parchment); paper.rotation.z=(i-1)*.12
		for line in range(3): box(paper,Vector3(0,.2-line*.16,.02),Vector3(.3,.025,.01),timber)
		var pin := SphereMesh.new(); pin.radius=.045; pin.height=.09
		piece(root,pin,Vector3(-.7+i*.69,2.25,.2),glow)
	box(root,Vector3(0,2.7,0),Vector3(2.8,.15,.5),timber)

func dummy(parent: Node3D,at: Vector3) -> void:
	beam(parent,at,at+Vector3.UP*2.1,.085,timber)
	beam(parent,at+Vector3(-.8,1.5,0),at+Vector3(.8,1.5,0),.085,timber)
	var straw := CylinderMesh.new(); straw.top_radius=.29; straw.bottom_radius=.4; straw.height=.85; straw.radial_segments=8
	piece(parent,straw,at+Vector3.UP*1.45,trim)
	var head := SphereMesh.new(); head.radius=.24; head.height=.48; head.radial_segments=8; head.rings=4
	piece(parent,head,at+Vector3.UP*2.1,trim)
	for level: float in [1.2,1.6]:
		var ring := TorusMesh.new(); ring.inner_radius=.32; ring.outer_radius=.36; ring.rings=8; ring.ring_segments=6
		piece(parent,ring,at+Vector3.UP*level,timber)

func rack(parent: Node3D,at: Vector3) -> void:
	for x: float in [-.9,.9]: beam(parent,at+Vector3(x,0,0),at+Vector3(x,1.9,0),.08,timber)
	beam(parent,at+Vector3(-1,1.6,0),at+Vector3(1,1.6,0),.09,timber)
	for x: float in [-.55,0,.55]:
		beam(parent,at+Vector3(x,.45,.16),at+Vector3(x,1.75,.16),.035,iron)
		box(parent,at+Vector3(x,1.12,.16),Vector3(.4,.07,.09),trim)

func table(parent: Node3D,at: Vector3) -> void:
	box(parent,at+Vector3.UP*.95,Vector3(2.3,.15,1.5),timber)
	for x: float in [-.9,.9]:
		for z: float in [-.5,.5]: box(parent,at+Vector3(x,.45,z),Vector3(.15,.9,.15),timber)
	box(parent,at+Vector3(0,1.04,0),Vector3(1.6,.025,1.1),parchment)
	for i in range(4): box(parent,at+Vector3(-.6+i*.35,1.06,.15*sin(i)),Vector3(.15,.035,.1),blue)

func fire(parent: Node3D,at: Vector3) -> MeshInstance3D:
	for i in range(10):
		var angle := TAU*i/10
		var rock := CourtyardKit.mesh("boundary_stone")
		var stone := piece(parent,rock,at+Vector3(cos(angle)*.8,0,sin(angle)*.8),null); stone.scale=Vector3(.42,.3,.4); stone.rotation.y=angle
	for i in range(3):
		var a := TAU*i/3
		beam(parent,at+Vector3(cos(a)*.6,.18,sin(a)*.6),at+Vector3(-cos(a)*.6,.18,-sin(a)*.6),.12,timber)
	var flame := PrismMesh.new(); flame.size=Vector3(.7,1.0,.6)
	glow.emission_enabled=true; glow.emission=Color("e78c39"); glow.emission_energy_multiplier=1.4
	return piece(parent,flame,at+Vector3.UP*.65,glow)
