class_name FactionVisualKit
extends RefCounted
## Original reusable faceted equipment, in metres, facing -Z. No gameplay nodes.
const BASE_ROLES: Dictionary = {
	"ashfang_raider":"raider", "ashfang_shieldguard":"raider", "ashfang_bowhunter":"sentinel", "ashfang_shaman":"mage", "ashfang_chieftain":"raider",
	"hollow_gravebound":"raider", "hollow_archer":"sentinel", "hollow_adept":"mage", "hollow_warden":"cleric", "hollow_castellan":"raider",
	"verdant_thornblade":"raider", "verdant_stalker":"ranger", "verdant_tender":"cleric", "verdant_sentinel":"raider", "verdant_grovekeeper":"mage"
}
const BODY = preload("res://scripts/faction_body.gd")
var skeleton: Skeleton3D
var materials: Array[StandardMaterial3D] = []
var part_count: int = 0

static func base_role(id: String) -> String:
	return String(BASE_ROLES.get(id, id))

func equip(model: Node3D, rig: Skeleton3D, id: String) -> void:
	if not BASE_ROLES.has(id): return
	skeleton = rig
	model.set_meta("faction_visual_id", id)
	var faction: String = id.get_slice("_", 0)
	var job: String = id.trim_prefix(faction + "_")
	var colors: Array[Color]
	match faction:
		"ashfang": colors = [Color("542b20"), Color("b44c25"), Color("ecd19a"), Color("f28432")]
		"hollow": colors = [Color("293944"), Color("527780"), Color("d5d4b8"), Color("8de8d4")]
		_: colors = [Color("463723"), Color("488149"), Color("b6cd70"), Color("b6ecc0")]
	colors.append(Color("a88158") if faction == "ashfang" else colors[2])
	for color in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		materials.append(material)
	BODY.build(self, model, faction, job)
	if faction == "ashfang":
		# Forward tusks and a jagged leather gorget, with exposed warm skin.
		plate("chest", [Vector2(-.28,1.37),Vector2(-.16,1.13),Vector2(0,1.23),Vector2(.18,1.11),Vector2(.29,1.37)], -.215, .06, 0)
		for side in [-1.0, 1.0]:
			spike("head", Vector3(side*.10,1.52,-.12),Vector3(side*.18,1.68,-.18),.035,2)
	elif faction == "hollow":
		# A rigid death mask and open ribs distinguish these from living troops.
		plate("head", [Vector2(-.15,1.72),Vector2(.15,1.72),Vector2(.12,1.51),Vector2(0,1.45),Vector2(-.12,1.51)], -.17, .045, 2)
		for side in [-1.0,1.0]:
			plate("head", [Vector2(side*.025,1.62),Vector2(side*.11,1.65),Vector2(side*.095,1.59)], -.222,.012,0)
			for y in [1.12,1.22,1.32]:
				spike("chest",Vector3(side*.03,y,-.205),Vector3(side*.24,y+.035,-.20),.024,2)
	else:
		# Forked antlers and pointed leaves create a broad organic silhouette.
		for side in [-1.0,1.0]:
			branch("head",Vector3(side*.12,1.76,.04),Vector3(side*.32,2.04,.04),0)
			leaf("chest",Vector3(side*.27,1.35,-.13),side*.23,.25,1)
	# Role silhouettes add equipment, rather than relying on scale or color.
	match job:
		"shieldguard", "warden", "sentinel":
			plate("L_hand",[Vector2(-.78,.48),Vector2(-.49,.35),Vector2(-.20,.48),Vector2(-.21,1.29),Vector2(-.49,1.44),Vector2(-.77,1.29)],-.30,.10,0)
			plate("L_hand",[Vector2(-.66,.60),Vector2(-.49,.48),Vector2(-.32,.60),Vector2(-.32,1.20),Vector2(-.49,1.31),Vector2(-.66,1.20)],-.415,.025,1)
			spike("L_hand",Vector3(-.49,.88,-.46),Vector3(-.49,.94,-.63),.095,2)
		"bowhunter", "archer", "stalker":
			for side in [-1.0,1.0]:
				spike("L_hand",Vector3(-.58,.91+side*.35,-.12),Vector3(-.72,.91+side*.64,-.11),.036,2)
			for x in [.12,.20,.28]:
				spike("chest",Vector3(x,1.50,.26),Vector3(x,1.80,.26),.014,2)
			leaf("head",Vector3(0,1.81,.03),.12,.30,1)
		"shaman", "adept", "tender":
			branch("R_hand",Vector3(.47,.92,-.04),Vector3(.47,1.94,-.04),0)
			loft("R_hand",Vector3(.47,1.93,-.04),.105,.24,3)
			for side in [-1.0,1.0]:
				leaf("chest",Vector3(side*.26,1.36,-.08),side*.18,.33,1)
		"chieftain", "castellan", "grovekeeper":
			for x in [-.22,-.11,0.0,.11,.22]:
				spike("head",Vector3(x,1.77,.0),Vector3(x*1.5,2.12-absf(x),.025),.045,2)
			for side in [-1.0,1.0]:
				leaf("chest",Vector3(side*.25,1.34,.10),side*.30,.55,1)
			plate("chest",[Vector2(-.12,1.34),Vector2(.12,1.34),Vector2(.16,.79),Vector2(0,.63),Vector2(-.16,.79)],-.22,.045,0)
			loft("chest",Vector3(0,1.25,-.29),.07,.15,3)
		_:
			# Rank-and-file carry an asymmetric axe crescent and shoulder teeth.
			plate("R_hand",[Vector2(.49,1.24),Vector2(.76,1.31),Vector2(.83,1.58),Vector2(.63,1.54),Vector2(.49,1.46)],-.12,.10,2)
			for x in [-.37,-.28,-.19]:
				spike("L_arm",Vector3(x,1.40,0),Vector3(x-.06,1.61,.01),.04,2)
	model.set_meta("equipment_parts", part_count)

func branch(bone: String, a: Vector3, b: Vector3, material: int) -> void:
	spike(bone,a,b,.035,material)
	var fork: Vector3 = a.lerp(b,.65)
	spike(bone,fork,b+Vector3(.14,.04,.02),.025,material)

func leaf(bone: String, at: Vector3, width: float, height: float, material: int) -> void:
	plate(bone,[Vector2(at.x,at.y),Vector2(at.x+width,at.y-height*.35),Vector2(at.x+width*.45,at.y-height),Vector2(at.x-width*.25,at.y-height*.65)],at.z,.045,material)

func spike(bone: String, a: Vector3, b: Vector3, radius: float, material: int) -> void:
	var axis: Vector3 = (b-a).normalized()
	var u: Vector3 = axis.cross(Vector3.FORWARD).normalized()
	if u.length_squared() < .1: u = Vector3.RIGHT
	var v: Vector3 = axis.cross(u).normalized()
	var vertices: PackedVector3Array = []
	for index in 6:
		var p: Vector3 = a + radius*(u*cos(index*TAU/6.0)+v*sin(index*TAU/6.0))
		var q: Vector3 = a + radius*(u*cos((index+1)*TAU/6.0)+v*sin((index+1)*TAU/6.0))
		vertices.append_array(PackedVector3Array([p,b,q,a,p,q]))
	part(bone,vertices,material)

func loft(bone: String, at: Vector3, radius: float, height: float, material: int) -> void:
	spike(bone,at,at+Vector3.UP*height,radius,material)
	spike(bone,at,at-Vector3.UP*height*.55,radius,material)

func plate(bone: String, outline: Array[Vector2], z: float, depth: float, material: int) -> void:
	var center := Vector3.ZERO
	for p in outline: center += Vector3(p.x,p.y,z)
	center /= outline.size()
	var rear: Vector3 = center + Vector3(0,0,depth)
	var vertices: PackedVector3Array = []
	for index in outline.size():
		var p := Vector3(outline[index].x,outline[index].y,z)
		var q := Vector3(outline[(index+1)%outline.size()].x,outline[(index+1)%outline.size()].y,z)
		var back_p: Vector3 = p+Vector3(0,0,depth)
		var back_q: Vector3 = q+Vector3(0,0,depth)
		vertices.append_array(PackedVector3Array([center,q,p,rear,back_p,back_q,p,q,back_q,p,back_q,back_p]))
	part(bone,vertices,material)

func part(bone: String, vertices: PackedVector3Array, material: int) -> void:
	var bone_index: int = skeleton.find_bone(bone)
	assert(bone_index >= 0, "Shared rig attachment bone missing: " + bone)
	var attachment := BoneAttachment3D.new()
	attachment.name = "FactionPart%d" % part_count
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var origin: Vector3 = skeleton.get_bone_global_rest(bone_index).origin
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices: surface.add_vertex(vertex-origin)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = materials[material]
	# Two-sided thin shaped plates remain readable from the tactical camera.
	materials[material].cull_mode = BaseMaterial3D.CULL_DISABLED
	attachment.add_child(mesh)
	part_count += 1

