class_name FactionBody
extends RefCounted
## Original faction anatomy, rigidly weighted through the existing animation rig.
## Coordinates are model-space metres; FactionVisualKit handles bone-space conversion.
static func build(kit: RefCounted, model: Node3D, faction: String, job: String) -> void:
	# Keep imported skeleton and clips, replacing all original clothing/body/weapons.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).hide()
	model.set_meta("faction_body", faction)
	var bone_color: int = 2 if faction == "hollow" else 4 if faction == "ashfang" else 0
	for side in [-1.0, 1.0]:
		var prefix: String = "L" if side < 0 else "R"
		var x: float = side * .145
		if faction == "hollow":
			# Exposed paired leg bones, separated ribs and hollow pelvis.
			limb(kit, prefix+"_thigh", Vector3(x,.49,0), Vector3(x,.84,0), .042, bone_color)
			for offset in [-.025,.025]:
				limb(kit,prefix+"_shin",Vector3(x+offset,.16,0),Vector3(x+offset,.46,0),.019,2)
			limb(kit,prefix+"_foot",Vector3(x,.07,.06),Vector3(x,.07,-.18),.045,0)
		elif faction == "verdant":
			limb(kit,prefix+"_thigh",Vector3(x,.46,0),Vector3(x,.85,0),.085,0)
			limb(kit,prefix+"_shin",Vector3(x,.12,-.01),Vector3(x,.48,0),.057,0)
			for toe in [-.055,0.0,.055]:
				limb(kit,prefix+"_foot",Vector3(x,.10,0),Vector3(x+toe,.035,-.21),.028,0)
		else:
			limb(kit,prefix+"_thigh",Vector3(x,.45,0),Vector3(x,.86,0),.115,1)
			limb(kit,prefix+"_shin",Vector3(x,.14,0),Vector3(x,.48,0),.09,0)
			profile(kit,prefix+"_foot",[Vector4(x,.025,-.07,.12),Vector4(x,.13,-.07,.12),Vector4(x,.23,0,.075)],0,1.45)
		var upper_radius: float = .105 if faction == "ashfang" else .055
		limb(kit,prefix+"_arm",Vector3(side*.29,1.33,0),Vector3(side*.40,1.08,-.015),upper_radius,bone_color)
		limb(kit,prefix+"_forearm",Vector3(side*.40,1.08,-.015),Vector3(side*.46,.88,-.04),upper_radius*.75,bone_color)
		profile(kit,prefix+"_hand",[Vector4(side*.46,.77,-.04,.045),Vector4(side*.47,.89,-.04,.055)],bone_color,.8)
		if faction == "verdant":
			for y in [1.18,1.31]: kit.leaf(prefix+"_arm",Vector3(side*.30,y,-.06),side*.19,.24,1)
	if faction == "ashfang":
		# Broad barrel chest, heavy jaw and a ragged hide kilt.
		profile(kit,"hips",[Vector4(0,.74,0,.24),Vector4(0,.95,0,.22)],0,.65)
		profile(kit,"chest",[Vector4(0,.97,0,.20),Vector4(0,1.20,0,.31),Vector4(0,1.35,0,.30),Vector4(0,1.40,0,.20)],0,.65)
		profile(kit,"head",[Vector4(0,1.46,-.025,.13),Vector4(0,1.53,-.04,.17),Vector4(0,1.68,0,.155),Vector4(0,1.79,.01,.09)],4,.85)
		for side in [-1.0,1.0]:
			kit.leaf("hips",Vector3(side*.10,.95,-.16),side*.15,.35,1)
			profile(kit,("L" if side<0 else "R")+"_arm",[Vector4(side*.29,1.29,0,.16),Vector4(side*.29,1.42,0,.12)],0,.9)
	elif faction == "hollow":
		limb(kit,"chest",Vector3(0,.97,.04),Vector3(0,1.40,.04),.035,2)
		profile(kit,"hips",[Vector4(0,.79,0,.19),Vector4(0,.90,0,.22),Vector4(0,.95,0,.16)],0,.55)
		for y in [1.08,1.19,1.30]:
			for side in [-1.0,1.0]:
				limb(kit,"chest",Vector3(0,y,.04),Vector3(side*.20,y+.03,0),.025,2)
				limb(kit,"chest",Vector3(side*.20,y+.03,0),Vector3(side*.13,y,-.13),.023,2)
		profile(kit,"head",[Vector4(0,1.48,0,.075),Vector4(0,1.57,.01,.13),Vector4(0,1.71,.01,.15),Vector4(0,1.79,.01,.10)],2,.8)
		# Tattered rear shroud leaves the rib cage exposed from the front.
		for x in [-.18,0.0,.18]: kit.leaf("chest",Vector3(x,1.38,.16),.14,.72,0)
	else:
		# Split bark torso and long root legs; no humanoid tunic or boots.
		profile(kit,"hips",[Vector4(0,.78,0,.18),Vector4(0,.98,0,.16)],0,.7)
		profile(kit,"chest",[Vector4(0,.96,0,.15),Vector4(0,1.20,0,.21),Vector4(0,1.39,0,.25)],0,.65)
		for x in [-.12,0.0,.12]:
			kit.leaf("chest",Vector3(x,1.39,-.13),.13,.45,1)
		profile(kit,"head",[Vector4(0,1.46,0,.065),Vector4(0,1.61,0,.12),Vector4(0,1.77,.01,.085),Vector4(0,1.86,.02,.025)],0,.7)
		for side in [-1.0,1.0]: kit.leaf("head",Vector3(side*.10,1.70,0),side*.19,.24,1)
	limb(kit,"neck",Vector3(0,1.36,0),Vector3(0,1.53,0),.06,bone_color)
	# Bright eyes read at tactical distance without lights or particle nodes.
	for side in [-1.0,1.0]:
		var eye: Array[Vector2] = [Vector2(side*.025,1.64),Vector2(side*.10,1.66),Vector2(side*.095,1.61),Vector2(side*.03,1.61)]
		kit.plate("head",eye,-.15,.018,3)
	if job in ["bowhunter","archer","stalker"]:
		var points: Array[Vector3] = [Vector3(-.48,.30,-.04),Vector3(-.65,.58,-.08),Vector3(-.48,.90,-.04),Vector3(-.65,1.24,-.08),Vector3(-.48,1.51,-.04)]
		for i in range(points.size()-1): limb(kit,"L_hand",points[i],points[i+1],.025,0)
		limb(kit,"L_hand",points[0],points[-1],.004,2)
		limb(kit,"R_hand",Vector3(.47,.85,-.04),Vector3(.47,.85,-.65),.009,2)
	elif job == "grovekeeper":
		kit.branch("R_hand",Vector3(.47,.12,-.04),Vector3(.47,1.94,-.04),0)
		kit.loft("R_hand",Vector3(.47,1.93,-.04),.105,.24,3)
	elif job not in ["shaman","adept","tender"]:
		limb(kit,"R_hand",Vector3(.47,.72,-.04),Vector3(.47,1.48,-.04),.025,0)
		var blade: Array[Vector2] = [Vector2(.43,1.12),Vector2(.52,1.12),Vector2(.54,1.58),Vector2(.47,1.77),Vector2(.41,1.58)]
		kit.plate("R_hand",blade,-.08,.06,2)
	model.set_meta("body_parts",kit.part_count)

static func limb(kit: RefCounted, bone: String, a: Vector3, b: Vector3, radius: float, material: int) -> void:
	# Two opposed cones form a faceted solid, with no sphere/capsule primitives.
	var middle: Vector3 = a.lerp(b,.5)
	kit.spike(bone,middle,a,radius,material)
	kit.spike(bone,middle,b,radius,material)

static func profile(kit: RefCounted, bone: String, rings: Array[Vector4], material: int, depth: float) -> void:
	var vertices: PackedVector3Array = []
	for row in range(rings.size()-1):
		var a: Vector4 = rings[row]
		var b: Vector4 = rings[row+1]
		for i in 8:
			var angle: float = i*TAU/8.0
			var next: float = (i+1)*TAU/8.0
			var p := Vector3(a.x+cos(angle)*a.w,a.y,a.z+sin(angle)*a.w*depth)
			var q := Vector3(a.x+cos(next)*a.w,a.y,a.z+sin(next)*a.w*depth)
			var r := Vector3(b.x+cos(angle)*b.w,b.y,b.z+sin(angle)*b.w*depth)
			var s := Vector3(b.x+cos(next)*b.w,b.y,b.z+sin(next)*b.w*depth)
			vertices.append_array(PackedVector3Array([p,r,s,p,s,q]))
	for row in [0,rings.size()-1]:
		var a: Vector4 = rings[row]
		for i in 8:
			var p := Vector3(a.x+cos(i*TAU/8.0)*a.w,a.y,a.z+sin(i*TAU/8.0)*a.w*depth)
			var q := Vector3(a.x+cos((i+1)*TAU/8.0)*a.w,a.y,a.z+sin((i+1)*TAU/8.0)*a.w*depth)
			vertices.append_array(PackedVector3Array([Vector3(a.x,a.y,a.z),q,p]))
	kit.part(bone,vertices,material)
