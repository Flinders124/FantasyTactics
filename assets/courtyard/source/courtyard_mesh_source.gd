class_name CourtyardMeshSource
extends RefCounted
## Original editable loft / bevel / masonry / foliage geometry. No external art.
var tool: SurfaceTool
var triangles: int = 0
var stone_colors: Array[Color] = [Color("818779"),Color("929485"),Color("70796e"),Color("a1a18d"),Color("626d60")]

func start(material: Material) -> void:
	tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	triangles = 0

func tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.length_squared() < 0.5:
		return
	# Godot's native meshes use clockwise front faces (glTF import normally
	# performs this conversion for us). Keep the explicit outward normal.
	for point in [a,c,b]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(point)
	triangles += 1

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	tri(a,b,c,color)
	tri(a,c,d,color)

func finish() -> ArrayMesh:
	tool.index()
	return tool.commit()

func bevel_block(center: Vector3,size: Vector3,bevel: float,color: Color) -> void:
	var x := size.x*0.5
	var z := size.z*0.5
	var b := minf(bevel,minf(x,z)*0.45)
	var corners: Array[Vector2] = [Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
	var rows: Array[PackedVector3Array] = []
	for level in range(4):
		var y: float = [-size.y*.5,-size.y*.5+b,size.y*.5-b,size.y*.5][level]
		var inset := b if level in [0,3] else 0.0
		var row := PackedVector3Array()
		for corner in corners:
			row.append(center+Vector3(corner.x-signf(corner.x)*inset,y,corner.y-signf(corner.y)*inset))
		rows.append(row)
	for level in range(3):
		for k in range(8):
			var next := (k+1)%8
			quad(rows[level][k],rows[level+1][k],rows[level+1][next],rows[level][next],color.darkened(.12) if level==2 else color)
	for k in range(8):
		var next := (k+1)%8
		tri(center+Vector3.UP*size.y*.5,rows[3][next],rows[3][k],color.lightened(.045))
		tri(center-Vector3.UP*size.y*.5,rows[0][k],rows[0][next],color.darkened(.2))

func loft(rows: Array[PackedVector3Array],color: Color) -> void:
	for level in range(rows.size()-1):
		for k in range(rows[level].size()):
			var next := (k+1)%rows[level].size()
			quad(rows[level][k],rows[level][next],rows[level+1][next],rows[level+1][k],color.lightened(float(k%3-1)*.045))
	for level in [0,rows.size()-1]:
		var center := Vector3.ZERO
		for point in rows[level]: center+=point
		center/=rows[level].size()
		for k in range(rows[level].size()):
			var next := (k+1)%rows[level].size()
			if level==0: tri(center,rows[level][next],rows[level][k],color.darkened(.2))
			else: tri(center,rows[level][k],rows[level][next],color.lightened(.03))

func ring(y: float,width: float,depth: float,chipped: bool=false) -> PackedVector3Array:
	var points := PackedVector3Array()
	for k in range(8):
		var angle := -TAU*float(k)/8.0
		var height := y - (float((k*3)%5)*.027 if chipped else 0.0)
		points.append(Vector3(cos(angle)*width,height,sin(angle)*depth))
	return points

func wall(material: Material,collision_only: bool=false) -> ArrayMesh:
	start(material)
	var heights: Array[float] = [.94,1.0,.88,.80,.85,.96,.84]
	# Continuous backing fills every joint and supplies exactly the same collider.
	for k in range(6):
		var left := -.5+float(k)/6.0
		var right := -.5+float(k+1)/6.0
		var a := Vector3(left,heights[k],-.5)
		var b := Vector3(right,heights[k+1],-.5)
		quad(Vector3(left,0,-.5),a,b,Vector3(right,0,-.5),stone_colors[4])
		quad(Vector3(right,0,.5),Vector3(right,heights[k+1],.5),Vector3(left,heights[k],.5),Vector3(left,0,.5),stone_colors[4])
		quad(a,Vector3(left,heights[k],.5),Vector3(right,heights[k+1],.5),b,stone_colors[k%4])
	quad(Vector3(-.5,0,.5),Vector3(-.5,heights[0],.5),Vector3(-.5,heights[0],-.5),Vector3(-.5,0,-.5),stone_colors[2])
	quad(Vector3(.5,0,-.5),Vector3(.5,heights[6],-.5),Vector3(.5,heights[6],.5),Vector3(.5,0,.5),stone_colors[2])
	quad(Vector3(-.5,0,-.5),Vector3(.5,0,-.5),Vector3(.5,0,.5),Vector3(-.5,0,.5),stone_colors[4])
	if not collision_only:
		for course in range(4):
			for k in range(6):
				var left := -.5+float(k)/6.0
				var right := left+1.0/6.0
				var top := minf(heights[k],heights[k+1])
				var bottom := float(course)*.20+.015
				var height := minf(.186,top-bottom-.02)
				if height<.05: continue
				for side in [-1.0,1.0]:
					bevel_block(Vector3((left+right)*.5,bottom+height*.5,side*.492),Vector3(.158,height,.018),.008,stone_colors[(course*7+k*3)%4])
	return finish()

func pillar(material: Material) -> ArrayMesh:
	start(material)
	var rows: Array[PackedVector3Array] = []
	for data in [Vector3(0,.5,.5),Vector3(.10,.5,.5),Vector3(.15,.39,.39),Vector3(.23,.33,.33),Vector3(.76,.31,.31),Vector3(.80,.38,.38),Vector3(.87,.38,.38)]:
		rows.append(ring(data.x,data.y,data.z))
	rows.append(ring(1.0,.31,.31,true))
	loft(rows,stone_colors[1])
	# Fluted grooves and a small weathered diamond inlay, modelled as stone.
	for side in [-1.0,1.0]:
		for x in [-.15,0.0,.15]:
			quad(Vector3(x-.009,.27,side*.317),Vector3(x-.009,.72,side*.317),Vector3(x+.009,.72,side*.317),Vector3(x+.009,.27,side*.317),stone_colors[4])
	return finish()

func plinth(material: Material) -> ArrayMesh:
	start(material)
	bevel_block(Vector3(0,.36,0),Vector3(1,.72,1),.025,stone_colors[2])
	bevel_block(Vector3(0,.72,0),Vector3(.97,.12,.97),.025,stone_colors[1])
	for side in [-1.0,1.0]:
		for course in range(3):
			for k in range(3):
				var x := -.325+float(k)*.325
				var y := .13+float(course)*.205
				bevel_block(Vector3(x,y,side*.493),Vector3(.308,.184,.018),.008,stone_colors[(course+k)%4])
				bevel_block(Vector3(side*.493,y,x),Vector3(.018,.184,.308),.008,stone_colors[(course+k+1)%4])
	for k in range(4):
		var x := -.25+float(k%2)*.5
		var z := -.25+float(k/2)*.5
		var height: float = [.17,.22,.13,.19][k]
		bevel_block(Vector3(x,.78+height*.5,z),Vector3(.47,height,.47),.023,stone_colors[k])
	return finish()

func arch(material: Material) -> ArrayMesh:
	start(material)
	for side in [-1.0,1.0]:
		for k in range(4):
			bevel_block(Vector3(side*1.05,.18+float(k)*.38,0),Vector3(.58,.36,.72),.045,stone_colors[k])
		bevel_block(Vector3(side*1.05,.08,0),Vector3(.82,.16,.88),.035,stone_colors[1])
	for k in range(9):
		if k==2: continue # One missing voussoir; broken but unmistakably a ruin.
		var angle0 := PI*float(k)/9.0
		var angle1 := PI*float(k+1)/9.0
		var a := Vector3(cos(angle0)*.82,1.48+sin(angle0)*.82,-.32)
		var b := Vector3(cos(angle1)*.82,1.48+sin(angle1)*.82,-.32)
		var c := Vector3(cos(angle1)*1.30,1.48+sin(angle1)*1.30,-.32)
		var d := Vector3(cos(angle0)*1.30,1.48+sin(angle0)*1.30,-.32)
		var offset := Vector3(0,0,.64)
		quad(a,b,c,d,stone_colors[k%4])
		quad(d+offset,c+offset,b+offset,a+offset,stone_colors[k%4])
		quad(a,a+offset,b+offset,b,stone_colors[4])
		quad(c,c+offset,d+offset,d,stone_colors[1])
		quad(a,d,d+offset,a+offset,stone_colors[2])
		quad(b+offset,c+offset,c,b,stone_colors[2])
	return finish()

func rubble(material: Material) -> ArrayMesh:
	start(material)
	for k in range(6):
		var x := cos(float(k)*2.4)*(.18+float(k)*.06)
		var z := sin(float(k)*2.4)*(.18+float(k)*.06)
		var width := .18+float((k*7)%5)*.04
		var height := .11+float(k%3)*.075
		var rows: Array[PackedVector3Array] = []
		for row in [ring(0,width,width*.72),ring(height*.45,width*1.06,width*.76),ring(height,width*.55,width*.45,true)]:
			for i in range(row.size()): row[i]+=Vector3(x,0,z)
			rows.append(row)
		loft(rows,stone_colors[k%4])
	return finish()

func grass(material: Material,fern: bool=false) -> ArrayMesh:
	start(material)
	for k in range(9 if not fern else 7):
		var angle := float(k)*2.4
		var side := Vector3(cos(angle),0,sin(angle))
		var cross_side := side.rotated(Vector3.UP,PI*.5)
		var height := .16+float(k%4)*.055 if not fern else .28+float(k%3)*.06
		var base := side*.055
		var middle := base+Vector3.UP*height*.58+side*.06
		var tip := base+Vector3.UP*height+side*(.14 if fern else .055)
		var width := .017 if not fern else .045
		var color := Color("64734c").lightened(float(k%3)*.065)
		quad(base-cross_side*width*.3,middle-cross_side*width,middle+cross_side*width,base+cross_side*width*.3,color)
		tri(middle-cross_side*width,tip,middle+cross_side*width,color.lightened(.08))
		if fern:
			for leaf in range(4):
				var root := base.lerp(tip,float(leaf+1)/6.0)
				for direction in [-1.0,1.0]:
					var end: Vector3 = root+cross_side*direction*(.09-float(leaf)*.013)-Vector3.UP*.01
					tri(root-side*.022,end,root+side*.025+Vector3.UP*.025,color)
	return finish()

func shrub(material: Material) -> ArrayMesh:
	start(material)
	for k in range(7):
		var angle := float(k)*2.4
		var center := Vector3(cos(angle)*.22,.12+float(k%3)*.06,sin(angle)*.22)
		bevel_block(Vector3(center.x,.09,center.z),Vector3(.035,.18,.035),.008,Color("4b4b35"))
		var rows: Array[PackedVector3Array] = [ring(0,.17,.14),ring(.13,.22,.20),ring(.28,.05,.04,true)]
		for row in rows:
			for i in range(row.size()): row[i]+=center
		loft(rows,Color("586645").lightened(float(k%3)*.045))
	return finish()

func paver(material: Material,variant: int) -> ArrayMesh:
	start(material)
	var row := PackedVector3Array()
	var top := PackedVector3Array()
	var cut := .055+float(variant)*.011
	var corners: Array[Vector2] = [Vector2(.5,-.5+cut),Vector2(.5-cut,-.5),Vector2(-.5+cut,-.5),Vector2(-.5,-.5+cut),Vector2(-.5,.5-cut),Vector2(-.5+cut,.5),Vector2(.5-cut,.5),Vector2(.5,.5-cut)]
	for point in corners:
		row.append(Vector3(point.x,-.018,point.y))
		top.append(Vector3(point.x-signf(point.x)*.012,0,point.y-signf(point.y)*.012))
	loft([row,top],Color("747b6f").lightened(float(variant-2)*.012))
	return finish()

func moss(material: Material) -> ArrayMesh:
	start(material)
	for k in range(12):
		var a := -TAU*float(k)/12.0
		var b := -TAU*float(k+1)/12.0
		var radius_a := .35+float((k*7)%5)*.035
		var radius_b := .35+float(((k+1)*7)%5)*.035
		tri(Vector3.ZERO,Vector3(cos(a)*radius_a,0,sin(a)*radius_a),Vector3(cos(b)*radius_b,0,sin(b)*radius_b),Color("4e603c").lightened(float(k%3)*.025))
	return finish()

func ivy(material: Material) -> ArrayMesh:
	start(material)
	for vine in range(4):
		for leaf in range(7-vine):
			var x := -.27+float(vine)*.18+sin(float(leaf)*1.8)*.035
			var y := -float(leaf)*.085
			var side := -1.0 if leaf%2==0 else 1.0
			var a := Vector3(x,y,0)
			var tip := Vector3(x+side*.09,y-.06,-.015)
			var color := Color("526844").lightened(float(leaf%3)*.05)
			tri(a,Vector3(x+side*.07,y+.015,-.008),tip,color)
			tri(a,tip,Vector3(x+side*.015,y-.09,-.008),color.darkened(.06))
	return finish()

static func material(color: Color,double_sided: bool=false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=0.95
	result.vertex_color_use_as_albedo=true
	result.vertex_color_is_srgb=true
	if double_sided: result.cull_mode=BaseMaterial3D.CULL_DISABLED
	return result
