extends RefCounted
## Permanent Lantern Oath art. Rendering only; no gameplay/collider access.
const SHADER = preload("res://assets/art/lantern_surface.gdshader")
const FADE = preload("res://assets/art/lantern_fade.gdshader")
const SHAPES = preload("res://assets/art/lantern_shapes.gd")
const CAMP_COLORS: Dictionary = {"536052":"273b50","8d8064":"556d83","78614a":"b85d49","cfb47c":"efb875","49352c":"303f59","404b51":"85a5ab","d8c79e":"efe3b6","426b75":"378b9b","ffc475":"ffc475","638181":"378b9b","966848":"c77556","5b6579":"556d83","82715d":"bd815f","342e2a":"273b50","344a43":"b85d49"}

static func paint(color: Color,metal: float=0.0,rough: float=.86,vertex: bool=false,actor: bool=false,sway: float=0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new();m.shader=SHADER;m.resource_name="LanternOath"
	m.set_shader_parameter("base_color",color)
	m.set_shader_parameter("metalness",metal)
	m.set_shader_parameter("surface_roughness",rough)
	m.set_shader_parameter("use_vertex_color",vertex)
	m.set_shader_parameter("rim_strength",.17 if actor else 0.0)
	m.set_shader_parameter("surface_kind",1.0 if actor or sway>0 else 0.0)
	m.set_shader_parameter("sway",sway)
	return m

static func scenery(id: String) -> ShaderMaterial:
	var color := Color("556d83")
	if id.begins_with("paver_"): color=Color("697f91")
	elif id in ["boundary_stone","pillar","arch","statue"]: color=Color("85a5ab")
	elif id in ["grass","fern","ivy","shrub","leaves","tree"]: color=Color("bd7954")
	elif id=="moss": color=Color("3c6265")
	elif id=="cracks": color=Color("283d59")
	elif id in ["cart","crate","barrel","bench"]: color=Color("394b61")
	var m := paint(color,0,.88,true,false,.018 if id in ["grass","fern","shrub"] else 0.0)
	m.set_shader_parameter("surface_kind",2.0 if id.begins_with("paver_") else 4.0 if id in ["grass","fern","shrub","ivy","leaves"] else 0.0)
	return m

static func fade_material(source: ShaderMaterial,opacity: float) -> ShaderMaterial:
	var faded := source.duplicate() as ShaderMaterial
	faded.shader=FADE
	faded.set_shader_parameter("fade_opacity",opacity)
	return faded

static func lighting(environment_node: WorldEnvironment,sun: DirectionalLight3D,portrait: bool=false,camp: bool=false) -> void:
	var e := Environment.new();e.background_mode=Environment.BG_COLOR
	e.background_color=Color("172e49") if portrait else Color("647e91")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("a8c1cc");e.ambient_light_energy=.54 if not portrait else .44
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.fog_enabled=not portrait;e.fog_light_color=Color("647e91");e.fog_density=.003
	environment_node.environment=e
	sun.rotation_degrees=Vector3(-48,-40,0);sun.light_color=Color("ffd0a1");sun.light_energy=1.16 if not portrait else 1.08
	if camp: sun.light_color=Color("ffd7ad");sun.light_energy=1.12
	sun.shadow_enabled=not portrait;sun.directional_shadow_max_distance=65.0
	sun.shadow_bias=.12;sun.shadow_normal_bias=2.0
	sun.set_meta("lantern_shadow_source",not portrait)
	var host := sun.get_parent()
	var fill := host.get_node_or_null("LanternFill") as DirectionalLight3D
	if fill==null: fill=DirectionalLight3D.new();fill.name="LanternFill";host.add_child(fill)
	fill.rotation_degrees=Vector3(-25,135,0);fill.light_color=Color("9ecbde");fill.light_energy=.22;fill.shadow_enabled=false
	fill.set_meta("lantern_shadow_source",false)

static func character_color(color: Color,hint: String,id: String) -> Color:
	if id.begins_with("ashfang_") or id=="raider":
		return Color("f1a469") if color.v>.68 else Color("a54648") if color.v>.4 else Color("503047")
	if id.begins_with("hollow_"):
		return Color("efe3b6") if color.s<.4 and color.v>.65 else Color("8de2da") if color.v>.7 else Color("344d73")
	if id.begins_with("verdant_"):
		return Color("d6e5a1") if color.v>.65 else Color("77b5a0") if color.v>.42 else Color("4b8589")
	match hint:
		"steel": return Color("a0d3d3")
		"cloth": return Color({"knight":"378b9b","mage":"d66d58","cleric":"ded5ad","ranger":"789f99","sentinel":"8b657b"}.get(id,"378b9b"))
		"skin": return Color("f0cc9b")
		"leather": return Color("354963")
		"gold": return Color("efb875")
		"hair": return Color("303f59")
		"magic": return Color("ffdc9c")
	return color

static func character(model: Node3D,rig: Skeleton3D,id: String) -> void:
	if model.get_meta("lantern_oath",false): return
	model.set_meta("lantern_oath",true)
	# Scale only presentation beneath CharacterVisual: picking/physics remain fixed.
	model.scale=Vector3(1.13,1.03,1.0)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var node := child as MeshInstance3D
		if not node.visible: continue
		if node.get_parent() is BoneAttachment3D:
			if (node.get_parent() as BoneAttachment3D).bone_name=="head": node.scale=Vector3.ONE*1.22
		if node.skin!=null: reshape(node,rig)
		for surface in node.mesh.get_surface_count():
			var source: Material = node.material_override if node.material_override!=null else node.get_surface_override_material(surface)
			if source==null: source=node.mesh.surface_get_material(surface)
			var standard := source as StandardMaterial3D
			if standard==null: continue
			var m := paint(character_color(standard.albedo_color,standard.resource_name,id),standard.metallic,.48 if standard.metallic>.2 else .88,false,true)
			if node.material_override!=null: node.material_override=m
			else: node.set_surface_override_material(surface,m)
	if id=="knight":
		for side in [-1.0,1.0]:
			var joint := BoneAttachment3D.new();joint.bone_name="L_arm" if side<0 else "R_arm";rig.add_child(joint)
			part(joint,SHAPES.bevel_box(Vector3(.25,.16,.30),.008),Vector3(-side*.015,-.015,0),paint(Color("a0d3d3"),.65,.42,false,true))
			part(joint,SHAPES.bevel_box(Vector3(.27,.04,.32),.015),Vector3(-side*.015,-.02,0),paint(Color("efb875"),.6,.5,false,true))
		var hand := BoneAttachment3D.new();hand.bone_name="L_hand";rig.add_child(hand)
		var badge := part(hand,SHAPES.leaf(.18,.30,.025),Vector3(-.01,.17,-.265),paint(Color("efc58a"),.65,.4,false,true));badge.rotation.z=PI
	if id=="mage":
		var joint := BoneAttachment3D.new();joint.bone_name="chest";rig.add_child(joint)
		var jewel: ArrayMesh = SHAPES.leaf(.13,.15,.04)
		part(joint,jewel,Vector3(0,.03,-.22),paint(Color("efb875"),.5,.4,false,true))

static func part(parent: Node3D,mesh: Mesh,at: Vector3,material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=material;parent.add_child(node);return node

static func reshape(node: MeshInstance3D,rig: Skeleton3D) -> void:
	var result := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for i in vertices.size():
			if bones.is_empty(): continue
			var bind: int = bones[i*4]
			if bind>=node.skin.get_bind_count(): continue
			var index: int = node.skin.get_bind_bone(bind)
			if index<0: index=rig.find_bone(node.skin.get_bind_name(bind))
			if index<0: continue
			var bone: String = rig.get_bone_name(index)
			var origin: Vector3 = rig.get_bone_global_rest(index).origin
			var factor: float = 1.24 if bone=="head" else 1.10 if bone.ends_with("arm") else 1.0
			vertices[i]=origin+(vertices[i]-origin)*factor
		arrays[Mesh.ARRAY_VERTEX]=vertices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,node.mesh.surface_get_material(surface))
	node.mesh=result

static func arch() -> ArrayMesh:
	# Decorative only. Blocker meshes and all collision resources are untouched.
	var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for row in 4:
			tool.append_from(SHAPES.bevel_box(Vector3(.5,.36,.72),.012),0,Transform3D(Basis.IDENTITY,Vector3(side*1.05,row*.38,0)))
		tool.append_from(SHAPES.bevel_box(Vector3(.82,.16,.88),.015),0,Transform3D(Basis.IDENTITY,Vector3(side*1.05,0,0)))
		tool.append_from(SHAPES.bevel_box(Vector3(.32,1.56,.70),.008),0,Transform3D(Basis(Vector3.BACK,side*.74),Vector3(side*1.05,1.48,0)))
	tool.set_material(scenery("arch"))
	return tool.commit()

static func theme_world(root: Node) -> void:
	if root.has_method("load_role") and root.has_method("face_point"): return
	if root is MeshInstance3D:
		var node := root as MeshInstance3D
		for surface in node.mesh.get_surface_count():
			var source: Material = node.material_override if node.material_override!=null else node.get_surface_override_material(surface)
			if source==null: source=node.mesh.surface_get_material(surface)
			var standard := source as StandardMaterial3D
			if standard==null or standard.emission_enabled or standard.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED: continue
			if standard.albedo_color.is_equal_approx(Color(1,.8,.35)): continue # Existing interactive camp rings.
			var color: Color = standard.albedo_color
			var m: ShaderMaterial
			if node.has_meta("lantern_material"): m=scenery(node.get_meta("lantern_material"))
			elif "/courtyard/meshes/" in node.mesh.resource_path: m=scenery(node.mesh.resource_path.get_file().get_basename())
			else: m=paint(Color(CAMP_COLORS.get(color.to_html(false),"556d83")),standard.metallic,.9)
			if node.material_override!=null: node.material_override=m
			else: node.set_surface_override_material(surface,m)
	for child in root.get_children(): theme_world(child)
