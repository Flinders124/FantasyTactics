extends RefCounted
## Small modelling library for the development courtyard. All geometry is local.
static func bevel_box(size: Vector3, bevel: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = size.x*.5
	var d: float = size.z*.5
	var b: float = minf(bevel,minf(minf(w,d)*.4,size.y*.45))
	var outline: Array[Vector2] = [Vector2(-w+b,-d),Vector2(w-b,-d),Vector2(w,-d+b),Vector2(w,d-b),Vector2(w-b,d),Vector2(-w+b,d),Vector2(-w,d-b),Vector2(-w,-d+b)]
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		var ring: PackedVector3Array = []
		var inset: float = b if level==0 or level==3 else 0.0
		var y: float = [0.0,b,size.y-b,size.y][level]
		for v in outline:
			ring.append(Vector3(v.x*(1.0-inset/w),y,v.y*(1.0-inset/d)))
		rings.append(ring)
	for row in 3:
		for i in 8:
			var j: int = (i+1)%8
			tri(surface,rings[row][i],rings[row+1][i],rings[row+1][j])
			tri(surface,rings[row][i],rings[row+1][j],rings[row][j])
	for i in 8:
		tri(surface,Vector3(0,size.y,0),rings[3][(i+1)%8],rings[3][i])
		tri(surface,Vector3.ZERO,rings[0][i],rings[0][(i+1)%8])
	surface.generate_normals()
	return surface.commit()

static func tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	surface.add_vertex(a);surface.add_vertex(b);surface.add_vertex(c)

static func wedge(a: float,b: float,inner: float,outer: float,depth: float) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Array[Vector3] = [Vector3(cos(a)*inner,sin(a)*inner,-depth*.5),Vector3(cos(a)*outer,sin(a)*outer,-depth*.5),Vector3(cos(b)*outer,sin(b)*outer,-depth*.5),Vector3(cos(b)*inner,sin(b)*inner,-depth*.5)]
	tri(s,front[0],front[2],front[1]);tri(s,front[0],front[3],front[2])
	var back: Array[Vector3] = []
	for p in front: back.append(p+Vector3(0,0,depth))
	tri(s,back[0],back[1],back[2]);tri(s,back[0],back[2],back[3])
	for i in 4:
		var j: int = (i+1)%4
		tri(s,front[i],front[j],back[j]);tri(s,front[i],back[j],back[i])
	s.generate_normals()
	return s.commit()

static func leaf(width: float,height: float,fold: float) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	tri(s,Vector3(0,0,0),Vector3(-width*.5,height*.48,0),Vector3(0,height*.55,-fold))
	tri(s,Vector3(0,height*.55,-fold),Vector3(-width*.5,height*.48,0),Vector3(0,height,0))
	tri(s,Vector3(0,0,0),Vector3(0,height*.55,-fold),Vector3(width*.5,height*.48,0))
	tri(s,Vector3(0,height*.55,-fold),Vector3(0,height,0),Vector3(width*.5,height*.48,0))
	s.generate_normals()
	return s.commit()
