extends "res://assets/courtyard/source/courtyard_mesh_source.gd"
## Original editable milestone-5 kit. Normalized solid blockers share their
## visible triangles with collision; dressing props live beyond the boundary.
func fountain(mat: Material) -> ArrayMesh:
	start(mat)
	var rows: Array[PackedVector3Array]=[]
	# A tall continuous first riser cannot be classified as walkable stairs by
	# Recast's 0.25 m climb / voxel quantization. Gameplay props are blockers.
	for row in [Vector3(0,.48,.48),Vector3(.4,.5,.5),Vector3(.45,.43,.43),Vector3(.48,.34,.34)]: rows.append(ring(row.x,row.y,row.z,true))
	loft(rows,Color("777e73"))
	rows=[]
	for row in [Vector3(.4,.13,.13),Vector3(.7,.10,.10),Vector3(.76,.24,.24),Vector3(.83,.26,.26),Vector3(.87,.16,.16),Vector3(1,.07,.07)]: rows.append(ring(row.x,row.y,row.z,true))
	loft(rows,Color("959783"))
	return finish()

func statue(mat: Material) -> ArrayMesh:
	start(mat)
	bevel_block(Vector3(0,.2,0),Vector3(1,.4,1),.025,Color("777e70"))
	bevel_block(Vector3(0,.45,0),Vector3(.7,.1,.7),.025,Color("929383"))
	var rows: Array[PackedVector3Array]=[]
	for row in [Vector3(.32,.28,.22),Vector3(.55,.18,.14),Vector3(.68,.25,.15),Vector3(.76,.15,.13)]: rows.append(ring(row.x,row.y,row.z))
	loft(rows,Color("9a9c8b"))
	rows=[ring(.76,.1,.10),ring(.88,.14,.12),ring(1,.10,.09)]
	loft(rows,Color("a4a58f"))
	# Broken sword, folded shield and fractured shoulder form the guardian silhouette.
	bevel_block(Vector3(.29,.58,0),Vector3(.09,.35,.10),.015,Color("82897d"))
	bevel_block(Vector3(-.22,.57,-.14),Vector3(.18,.24,.08),.02,Color("8d9382"))
	return finish()

func bench(mat: Material) -> ArrayMesh:
	start(mat)
	for x in [-.65,.65]: bevel_block(Vector3(x,.25,0),Vector3(.25,.5,.55),.05,Color("777d70"))
	bevel_block(Vector3(0,.56,0),Vector3(1.8,.17,.65),.04,Color("959784"))
	return finish()

func barrel(mat: Material) -> ArrayMesh:
	start(mat)
	var rows: Array[PackedVector3Array]=[ring(0,.3,.3),ring(.08,.34,.34),ring(.4,.4,.4),ring(.75,.34,.34),ring(.8,.3,.3)]
	loft(rows,Color("766348"))
	for height in [.13,.65]:
		loft([ring(height,.355,.355),ring(height+.045,.365,.365)],Color("485351"))
	return finish()

func crate(mat: Material) -> ArrayMesh:
	start(mat)
	bevel_block(Vector3(0,.4,0),Vector3(.8,.8,.8),.03,Color("7e6c4f"))
	for x in [-.34,.34]: bevel_block(Vector3(x,.4,-.41),Vector3(.09,.8,.06),.01,Color("a08a61"))
	for y in [.06,.74]: bevel_block(Vector3(0,y,-.41),Vector3(.8,.09,.06),.01,Color("a08a61"))
	return finish()

func cart(mat: Material) -> ArrayMesh:
	start(mat)
	bevel_block(Vector3(0,.5,0),Vector3(1.6,.13,1),.03,Color("756448"))
	for x in [-.76,.76]: bevel_block(Vector3(x,.72,0),Vector3(.1,.4,1),.025,Color("877357"))
	for z in [-.58,.58]:
		var rows: Array[PackedVector3Array]=[]
		for height in [0.0,.12]: rows.append(ring(height,.38,.38))
		# Wheels are built in a separate local tool then transformed into the cart mesh.
		for index in range(8):
			var a := TAU*float(index)/8
			var b := TAU*float(index+1)/8
			tri(Vector3(0,.4,z),Vector3(cos(a)*.38,.4+sin(a)*.38,z),Vector3(cos(b)*.38,.4+sin(b)*.38,z),Color("555b4e"))
	bevel_block(Vector3(.95,.35,0),Vector3(.5,.09,.12),.01,Color("73634a"))
	return finish()

func facade(mat: Material) -> ArrayMesh:
	start(mat)
	for x in [-1.5,1.5]: bevel_block(Vector3(x,1.1,0),Vector3(1.35,2.2,.65),.10,Color("7f877a"))
	for x in [-.65,.65]: bevel_block(Vector3(x,1,0),Vector3(.28,2,.9),.045,Color("a0a18d"))
	bevel_block(Vector3(0,2.12,0),Vector3(1.65,.3,.9),.05,Color("9a9b87"))
	# Recessed, inaccessible doorway behind the arch.
	bevel_block(Vector3(0,.9,.34),Vector3(1.1,1.8,.13),.01,Color("3f4b45"))
	return finish()

func ground_patch(mat: Material,leaves: bool=false) -> ArrayMesh:
	start(mat)
	if leaves:
		for index in range(12):
			var x := sin(index*5.4)*.5
			var z := cos(index*3.1)*.5
			quad(Vector3(x-.03,0,z),Vector3(x,0,z+.07),Vector3(x+.03,0,z),Vector3(x,0,z-.06),Color("777747"))
	else:
		for index in range(7):
			var a := Vector3(-.5+index*.13,0,sin(index*2.3)*.12)
			var b := Vector3(-.5+(index+1)*.13,0,sin((index+1)*2.3)*.12)
			quad(a,a+Vector3(0,0,.015),b+Vector3(0,0,.015),b,Color("515c4b"))
	return finish()
