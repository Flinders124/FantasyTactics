extends Node3D
## Standalone art lab. Nothing in normal gameplay loads this directory.
const GEOMETRY = preload("res://dev/art_direction/geometry.gd")
const SURFACE = preload("res://dev/art_direction/surface.gdshader")
const TITLES: Array[String] = ["A  /  STYLISED FANTASY", "B  /  GROUNDED, PAINTERLY FANTASY", "C  /  BOLD, ARTISTIC FANTASY"]
const SUBTITLES: Array[String] = ["The sunlit watch  |  sculpted shapes, enamel & warm limestone", "The weathered watch  |  brushed surfaces, aged stone & silver daylight", "The lantern oath  |  cut-paper silhouettes, ink shadows & copper light"]
const IDS: Array[String] = ["knight","mage","ashfang_shieldguard","hollow_adept","verdant_stalker"]
const PLACEMENTS: Array[Vector3] = [Vector3(-2.8,.035,1.5),Vector3(.4,.035,2.3),Vector3(-4.2,.035,-2.8),Vector3(0,.035,-3.6),Vector3(4.2,.035,-2.8)]
const PALETTES: Array[Dictionary] = [
 {"stone":"ac9a78","edge":"c9b794","dark":"667e82","earth":"687a66","leaf":"3c704b","leaf_light":"799a5b","wood":"694c39","gold":"cba45b","cloth":"387d9c","ink":"283f58","sky":"c1d2ce","ambient":"c8dce5","sun":"fff0cd"},
 {"stone":"95968c","edge":"c0bca7","dark":"555f60","earth":"535f50","leaf":"526747","leaf_light":"809369","wood":"514337","gold":"a58b58","cloth":"53666c","ink":"2d3943","sky":"a5b6b5","ambient":"b5c5ce","sun":"f6ddad"},
 {"stone":"556d83","edge":"85a5ab","dark":"283d59","earth":"273b50","leaf":"b85d49","leaf_light":"efaf69","wood":"303f59","gold":"efb875","cloth":"e48a57","ink":"172e49","sky":"6d8f9c","ambient":"829db7","sun":"ffc88a"}
]
var direction: int = 0
var stage: Node3D
var actors: Array[CharacterVisual] = []
var camera_rig: TacticalCamera
var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var ui: CanvasLayer
var title: Label
var subtitle: Label
var status: Label
var materials: Dictionary = {}
var geometry_cache: Dictionary = {}
var view_id: int = 0
var freeze: bool = true
var current_clip: String = "Idle"
var marker_nodes: Array[Node3D] = []
var show_markers: bool = true

func _ready() -> void:
	environment_node=WorldEnvironment.new();add_child(environment_node)
	sun=DirectionalLight3D.new();add_child(sun)
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65.0
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias=.035
	sun.shadow_normal_bias=.7
	camera_rig=TacticalCamera.new()
	camera_rig.name="TacticalCamera"
	var camera := Camera3D.new()
	camera.name="Camera3D";camera.fov=55.0;camera.current=true;camera.far=150
	camera_rig.add_child(camera);add_child(camera_rig)
	camera_rig.pan_bounds=Vector2(13,10)
	camera_rig.maximum_distance=40
	make_ui()
	set_direction(0)
	set_view(0)

func col(key: String) -> Color:
	return Color(PALETTES[direction][key])

func material(key: String, color: Color, metal: float=0.0, rough: float=.86, vertex: bool=false) -> ShaderMaterial:
	var cache_key: String = key+str(color)+str(metal)+str(vertex)
	if materials.has(cache_key): return materials[cache_key]
	var m := ShaderMaterial.new()
	m.shader=SURFACE
	m.set_shader_parameter("base_color",color)
	m.set_shader_parameter("treatment",float(direction))
	m.set_shader_parameter("metalness",metal)
	m.set_shader_parameter("surface_roughness",rough)
	m.set_shader_parameter("variation",.18 if direction==1 else .07 if direction==0 else .025)
	m.set_shader_parameter("use_vertex_color",vertex)
	materials[cache_key]=m
	return m

func add_mesh(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D=null) -> MeshInstance3D:
	if parent==null: parent=stage
	var node := MeshInstance3D.new()
	node.mesh=mesh;node.position=at;node.material_override=mat
	parent.add_child(node)
	return node

func block(at: Vector3,size: Vector3,key: String, tint: float=1.0) -> MeshInstance3D:
	var bevel: float = .09 if direction==0 else .025 if direction==1 else .005
	var cache_key: String = str(size)+str(bevel)
	if not geometry_cache.has(cache_key): geometry_cache[cache_key]=GEOMETRY.bevel_box(size,bevel)
	return add_mesh(geometry_cache[cache_key],at,material(key,col(key)*Color(tint,tint,tint,1)))

func set_direction(index: int) -> void:
	assert(index>=0 and index<3)
	direction=index
	actors.clear();marker_nodes.clear()
	if stage!=null: stage.free()
	materials.clear();geometry_cache.clear()
	stage=Node3D.new();stage.name="ReferenceCourtyard";add_child(stage)
	configure_light()
	build_courtyard()
	build_characters()
	batch_static_geometry()
	set_clip(current_clip)
	title.text=TITLES[index]
	subtitle.text=SUBTITLES[index]
	update_status()

func configure_light() -> void:
	var e := Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=col("sky")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=col("ambient")
	e.ambient_light_energy=[.48,.40,.40][direction]
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=true
	e.fog_light_color=col("sky")
	e.fog_density=[.0015,.004,.002][direction]
	environment_node.environment=e
	sun.rotation_degrees=[Vector3(-51,-35,0),Vector3(-35,-42,0),Vector3(-48,-40,0)][direction]
	sun.light_color=col("sun")
	sun.light_energy=[.92,1.05,1.18][direction]
	sun.light_angular_distance=[1.2,.45,.2][direction]

func build_courtyard() -> void:
	var plane := PlaneMesh.new();plane.size=Vector2(160,160)
	add_mesh(plane,Vector3(0,-.15,0),material("earth",col("earth")))
	# Same terrace, circulation space, stairs and masonry footprint in every option.
	block(Vector3(0,-.38,0),Vector3(19,.35,15),"dark")
	for row in range(-5,6):
		for column in range(-7,8):
			var offset: float = .6 if row%2==0 else 0
			var x: float = column*1.18+offset
			if x>8.7: continue
			var v: float = .94+float(posmod(column*17+row*31,9))*.014
			var p := block(Vector3(x,-.035,row*1.23),Vector3(1.13,.055,1.18),"stone",v)
			if direction==1: p.rotation.y=sin(float(column*13+row*7))*.012
	for side in [-1.0,1.0]:
		for i in range(12):
			block(Vector3(side*9.2,.0,-6.6+i*1.2),Vector3(.40,.19,1.15),"edge")
	for i in range(16):
		block(Vector3(-8.8+i*1.17,0,6.9),Vector3(1.12,.20,.4),"edge")
	for i in 3:
		block(Vector3(0,-.12-float(i)*.12,7.4+i*.4),Vector3(6.0+i*.5,.14,.45),"stone")
	# Quiet geometric floor inlay, always below existing ring height.
	var disc := CylinderMesh.new();disc.top_radius=2.45;disc.bottom_radius=2.45;disc.height=.014;disc.radial_segments=48
	add_mesh(disc,Vector3(0,.03,-.5),material("medallion",col("dark").lerp(col("stone"),.55)))
	var rim := TorusMesh.new();rim.inner_radius=2.31;rim.outer_radius=2.35;rim.rings=48;rim.ring_segments=5
	add_mesh(rim,Vector3(0,.047,-.5),material("bronze",col("gold"),.5,.6))
	for i in 8:
		var ornament := block(Vector3(sin(i*TAU/8)*1.7,.045,-.5+cos(i*TAU/8)*1.7),Vector3(.08,.015,.65),"gold")
		ornament.rotation.y=i*TAU/8
	# A three-bay arcade gives a shared architectural silhouette.
	for x in [-6.0,0.0,6.0]: build_arch(x)
	for x in [-9.0,-3.0,3.0,9.0]:
		block(Vector3(x,0,-6.5),Vector3(1.15,.28,1.22),"dark")
		for course in 5:
			block(Vector3(x,.28+course*.55,-6.5),Vector3(.80,.53,.85),"stone",.95+course*.015)
		block(Vector3(x,3.03,-6.5),Vector3(1.08,.20,1.10),"edge")
		block(Vector3(x,3.23,-6.5),Vector3(.88,.13,.92),"gold")
		# Shaped upper finial: squat A, weathered B, spear-like C.
		var finial := SphereMesh.new();finial.radius=.23;finial.height=.46;finial.radial_segments=8;finial.rings=4
		var node := add_mesh(finial,Vector3(x,3.57,-6.5),material("edge",col("edge")))
		if direction==2: node.scale=Vector3(.7,2,.7)
	# Low garden walls keep the unit play area visually unobstructed.
	for side in [-1.0,1.0]:
		for z in [-3.7,-1.8,.1,2.0,3.9]:
			block(Vector3(side*8.35,0,z),Vector3(.62,.48,1.82),"stone")
			block(Vector3(side*8.35,.48,z),Vector3(.78,.14,1.87),"edge")
		for z in [-4.3,-.1,4.3]:
			planter(Vector3(side*7.1,0,z),side)
		# Same two trees, different crown construction and foliage language.
		tree(Vector3(side*10.8,0,-5.3),side)
		for z in [-4.7,2.5]: banner(Vector3(side*7.8,.65,z))
	# Reuse native courtyard art for rubble, moss and ferns. No collision/nav edits.
	for i in 18:
		var side: float = -1.0 if i%2==0 else 1.0
		var pos := Vector3(side*(9.8+sin(i*4.1)*.6),-.04,-5.5+float(i/2)*1.2)
		var rubble := add_mesh(CourtyardKit.mesh("rubble"),pos,material("rubble",col("dark"),0,.95,true))
		rubble.scale=Vector3.ONE*(.35+float(i%3)*.13);rubble.rotation.y=i*1.7
	for i in 30:
		var side: float = -1.0 if i%2==0 else 1.0
		var moss := add_mesh(CourtyardKit.mesh("moss"),Vector3(side*(6.1+sin(i*3.7)*1.1),.027,-5.1+float(i/2)*.77),material("moss",col("leaf").darkened(.12),0,1,true))
		moss.scale=Vector3(.5,1,.42);moss.rotation.y=i*2.7
	build_landscape()
	# Distant masonry provides depth without post-process effects.
	for side in [-1.0,1.0]:
		var wall := add_mesh(CourtyardKit.mesh("wall"),Vector3(side*14,-.1,-12.5),material("distant",col("dark").lerp(col("sky"),.18),0,.95,true))
		wall.scale=Vector3(5.8,3.4,.8)

func build_arch(x: float) -> void:
	var radius: float = 2.3
	var center := Vector3(x,2.8,-6.5)
	for side in [-1.0,1.0]:
		for row in 5:
			block(Vector3(x+side*2.47,row*.55,-6.5),Vector3(.50,.53,.65),"stone",1.0+row*.012)
	if direction!=2:
		for i in 13:
			var a: float = i*PI/13+.012
			var b: float = (i+1)*PI/13-.012
			add_mesh(GEOMETRY.wedge(a,b,radius,radius+.48,.70),center,material("arch%d"%(i%3),col("edge").darkened(float(i%3)*.035)))
	else:
		# Pointed chevrons replace the round arch with the same spring points/apex.
		for side in [-1.0,1.0]:
			var beam := block(Vector3(x+side*2.3,2.8,-6.5),Vector3(.48,3.25,.70),"edge")
			beam.rotation.z=side*.78
			var inset := block(Vector3(x+side*2.3,2.83,-6.88),Vector3(.08,3.25,.04),"gold")
			inset.rotation.z=side*.78
	# Keystone / lantern badge, same location and count.
	var badge := block(Vector3(x,5.1,-6.91),Vector3(.45,.48,.18),"gold")
	badge.rotation.z=PI*.25 if direction==2 else 0
	for side in [-1.0,1.0]:
		var ivy := add_mesh(CourtyardKit.mesh("ivy"),Vector3(x+side*2.45,2.15,-6.04),material("ivy",col("leaf").darkened(.12),0,.96,true))
		ivy.scale=Vector3(.5,1.0,.8)
		var buttress := block(Vector3(x+side*2.45,0,-6.02),Vector3(.65,.24,.5),"dark")
		buttress.rotation.y=side*.1

func planter(at: Vector3,side: float) -> void:
	block(at,Vector3(1.1,.42,1.25),"dark")
	block(at+Vector3(0,.42,0),Vector3(1.22,.12,1.37),"edge")
	block(at+Vector3(0,.49,0),Vector3(.97,.04,1.10),"earth")
	var leafmesh: ArrayMesh = GEOMETRY.leaf(.35 if direction!=1 else .19,.95 if direction!=2 else 1.2,.10)
	for i in 11:
		var leaf := add_mesh(leafmesh,at+Vector3(sin(i*2.4)*.24,.5,cos(i*2.4)*.26),material("leaf%d"%(i%2),col("leaf" if i%2==0 else "leaf_light")))
		leaf.rotation=Vector3(.28+float(i%3)*.16,i*2.4,side*.15)
		if direction==1: leaf.scale=Vector3(1,1.25,1);leaf.rotation.z+=sin(i*2.1)*.30
	# Two original opaque ferns beneath each planter.
	for i in 2:
		var fern := add_mesh(CourtyardKit.mesh("fern"),at+Vector3(side*.72,.02,float(i)*.65-.3),material("fern",col("leaf"),0,.98,true))
		fern.scale=Vector3.ONE*.7;fern.rotation.y=i*2.5

func tree(at: Vector3,side: float) -> void:
	var trunk := CylinderMesh.new();trunk.top_radius=.16;trunk.bottom_radius=.33;trunk.height=3.7;trunk.radial_segments=7
	add_mesh(trunk,at+Vector3(0,1.85,0),material("wood",col("wood")))
	for i in 5:
		var crown: Mesh
		if direction==2:
			crown=GEOMETRY.leaf(2.8,3.0,.32)
		else:
			var sphere := SphereMesh.new();sphere.radius=1.18;sphere.height=2.1;sphere.radial_segments=8 if direction==0 else 14;sphere.rings=4 if direction==0 else 7
			crown=sphere
		var offset := Vector3(sin(i*2.4)*1.1,3.0+float(i%3)*.65,cos(i*2.4)*.9)
		var node := add_mesh(crown,at+offset,material("crown%d"%(i%3),col("leaf").lerp(col("leaf_light"),float(i%3)*.3)))
		if direction==2: node.rotation.y=i*.7;node.rotation.z=side*.2
		else: node.scale=Vector3(1.05,.82,1)
		if direction==1:
			node.scale=Vector3(1.05+sin(i*2.4)*.18,.48+float(i%3)*.10,1.0)
			var branch := CylinderMesh.new();branch.top_radius=.045;branch.bottom_radius=.10;branch.height=Vector3(offset.x,offset.y-2.1,offset.z).length();branch.radial_segments=6
			var twig := add_mesh(branch,at+Vector3(0,2.1,0)+Vector3(offset.x,offset.y-2.1,offset.z)*.5,material("wood",col("wood")))
			twig.quaternion=Quaternion(Vector3.UP,Vector3(offset.x,offset.y-2.1,offset.z).normalized())

func banner(at: Vector3) -> void:
	var pole := CylinderMesh.new();pole.top_radius=.025;pole.bottom_radius=.035;pole.height=2.7;pole.radial_segments=6
	add_mesh(pole,at+Vector3(0,1.35,0),material("pole",col("gold"),.5,.55))
	var cloth := GEOMETRY.leaf(.90,1.6,.055)
	var node := add_mesh(cloth,at+Vector3(.42,.68,0),material("banner",col("cloth")))
	node.rotation.z=PI
	node.position.y+=1.8
	var badge := block(at+Vector3(.42,1.82,-.08),Vector3(.18,.31,.06),"gold")
	badge.rotation.z=PI*.25

func build_characters() -> void:
	for i in IDS.size():
		var visual := CharacterVisual.new()
		visual.set_meta("art_comparison",true)
		stage.add_child(visual);visual.position=PLACEMENTS[i];visual.rotation.y=PI-.12
		visual.load_role(IDS[i]);actors.append(visual)
		style_character(visual,i)
		make_marker(i)

func character_color(source: Color, name_hint: String, index: int) -> Color:
	if index<2:
		match name_hint:
			"steel": return [Color("88a8ba"),Color("818984"),Color("86c7cc")][direction]
			"cloth": return ([Color("286cb0"),Color("3e526c"),Color("267c8c")] if index==0 else [Color("8c54b9"),Color("736478"),Color("d66a50")])[direction]
			"skin": return [Color("d8a079"),Color("b9977b"),Color("f0cc9b")][direction]
			"leather": return [Color("664536"),Color("534639"),Color("293c51")][direction]
			"gold": return col("gold")
			"hair": return col("wood")
			"magic": return [Color("83d9ed"),Color("b5caca"),Color("ffc278")][direction]
			_: return source
	var h: float = source.h
	var s: float = source.s
	var v: float = source.v
	if direction==0:
		return Color.from_hsv(h,minf(.65,s*1.04),minf(1,v*1.06))
	if direction==1:
		return Color.from_hsv(h,s*.63,v*.92+.035)
	if index==2:
		return Color("f1a469") if v>.68 else Color("a54648") if v>.4 else Color("503047")
	if index==3:
		return Color("efe3b6") if s<.4 and v>.65 else Color("8de2da") if v>.7 else Color("344d73")
	return Color("d7d88b") if v>.65 else Color("508f8b") if v>.42 else Color("416e75")

func style_character(visual: CharacterVisual,index: int) -> void:
	# Work only on instances. Rest rig and all imported animation resources stay intact.
	visual.scale=[Vector3(1.07,1.0,1.07),Vector3(.94,1.04,.94),Vector3(1.13,1.03,1.0)][direction]
	for child in visual.model.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if not mesh.visible: continue
		if mesh.get_parent() is BoneAttachment3D:
			var attachment := mesh.get_parent() as BoneAttachment3D
			if attachment.bone_name=="head": mesh.scale=Vector3.ONE*[1.12,.94,1.22][direction]
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.material_override if mesh.material_override!=null else mesh.get_surface_override_material(surface)
			if source==null: source=mesh.mesh.surface_get_material(surface)
			var standard := source as StandardMaterial3D
			if standard==null: continue
			var c: Color = character_color(standard.albedo_color,standard.resource_name,index)
			var m: ShaderMaterial = material("character%d_%s"%[index,standard.resource_name],c,standard.metallic,.48 if standard.metallic>.2 else .88)
			if mesh.material_override!=null: mesh.material_override=m
			else: mesh.set_surface_override_material(surface,m)
		# Hero mesh proportions are edited around each bind joint, not a global head cut.
		if mesh.skin!=null and index<2: reshape_skinned(mesh,visual.skeleton)
	# Small crafted armour overlays demonstrate geometry, not just recolouring.
	if index==0:
		var rig: Skeleton3D = visual.skeleton
		for side in [-1.0,1.0]:
			var attachment := BoneAttachment3D.new();attachment.bone_name="L_arm" if side<0 else "R_arm";rig.add_child(attachment)
			var armour := add_mesh(GEOMETRY.bevel_box(Vector3(.25,.16,.30),.045 if direction!=2 else .008),Vector3(-side*.015,-.015,0),material("pauldron",character_color(Color.WHITE,"steel",0),.65,.42),attachment)
			armour.rotation.z=side*-.18
			add_mesh(GEOMETRY.bevel_box(Vector3(.27,.04,.32),.015),Vector3(-side*.015,-.02,0),material("trim",col("gold"),.6,.5),attachment)
	if index==1:
		var attachment := BoneAttachment3D.new();attachment.bone_name="chest";visual.skeleton.add_child(attachment)
		var clasp := SphereMesh.new();clasp.radius=.065;clasp.height=.15;clasp.radial_segments=6;clasp.rings=3
		add_mesh(clasp,Vector3(0,.03,-.22),material("clasp",col("gold"),.5,.4),attachment)

func reshape_skinned(mesh: MeshInstance3D,rig: Skeleton3D) -> void:
	var result := ArrayMesh.new()
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		for i in vertices.size():
			if bones.is_empty(): continue
			var joint: int = bones[i*4]
			if joint>=mesh.skin.get_bind_count(): continue
			var bone_index: int = mesh.skin.get_bind_bone(joint)
			if bone_index<0: bone_index=rig.find_bone(mesh.skin.get_bind_name(joint))
			if bone_index<0: continue
			var bone: String = rig.get_bone_name(bone_index)
			var origin: Vector3 = rig.get_bone_global_rest(bone_index).origin
			var delta: Vector3 = vertices[i]-origin
			var factor: float = [1.12,.96,1.24][direction] if bone=="head" else [1.05,.98,1.10][direction] if bone.ends_with("arm") else 1.0
			vertices[i]=origin+delta*factor
		arrays[Mesh.ARRAY_VERTEX]=vertices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# Keep each instance's material overrides; source mesh remains shared and untouched.
	var overrides: Array[Material] = []
	for i in mesh.mesh.get_surface_count(): overrides.append(mesh.get_surface_override_material(i))
	mesh.mesh=result
	for i in overrides.size(): mesh.set_surface_override_material(i,overrides[i])

func make_marker(index: int) -> void:
	var marker := Node3D.new();stage.add_child(marker);marker.position=PLACEMENTS[index];marker.position.y=.07;marker.visible=show_markers;marker_nodes.append(marker)
	# Reuse the actual shipped selection-ring geometry and proportions.
	var source := load("res://scenes/combat_unit.tscn") as PackedScene
	var fixture := source.instantiate()
	var ring_mesh: Mesh = fixture.get_node("ActiveIndicator").mesh
	var ring_material := StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color=Color("f4cf65") if index==0 else Color("6fbed5") if index==1 else Color("ec8d78")
	add_mesh(ring_mesh,Vector3.ZERO,ring_material,marker)
	fixture.free()
	var label := Label3D.new();label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false
	label.text=["WARDEN","ARCANIST","ASHFANG","HOLLOW","VERDANT"][index]
	label.font_size=28;label.pixel_size=.006;label.position=Vector3(0,2.55,0)
	label.outline_size=7;label.modulate=Color("f6edda");marker.add_child(label)

func set_view(index: int) -> void:
	view_id=index
	camera_rig.position=[Vector3(0,0,0),Vector3(0,1,-.6),Vector3(0,1,-2.3)][index]
	camera_rig.distance=[30.0,14.5,23.0][index]
	camera_rig.pitch=[-1.05,-.48,-.31][index]
	camera_rig.yaw=[.12,.12,.34][index]
	camera_rig._update_transform()
	update_status()

func set_clip(clip: String) -> void:
	current_clip=clip
	for visual in actors:
		visual.reset_pose();visual.play_clip(clip,true)
		if freeze:
			visual.player.pause()
			visual.player.seek(.35 if clip!="Death" else .72,true)
		visual.rotation.y=PI-.12

func update_status() -> void:
	if status!=null: status.text="%s  |  55 deg FOV  |  %s  |  Compatibility renderer" % [["GAMEPLAY / 30 m","DETAIL / 14.5 m","ARCHITECTURE / 23 m"][view_id],"FROZEN POSE" if freeze else "ANIMATED"]

func make_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var panel := PanelContainer.new();panel.position=Vector2(24,22);ui.add_child(panel)
	var style := StyleBoxFlat.new();style.bg_color=Color(.035,.055,.085,.94);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=14;style.content_margin_bottom=14;style.border_width_left=3;style.border_color=Color("d9b66f");panel.add_theme_stylebox_override("panel",style)
	var rows := VBoxContainer.new();rows.add_theme_constant_override("separation",7);panel.add_child(rows)
	var kicker := Label.new();kicker.text="THE LANTERN WATCH  /  ART DIRECTION LAB";kicker.add_theme_font_size_override("font_size",12);kicker.modulate=Color("d9b66f");rows.add_child(kicker)
	title=Label.new();title.add_theme_font_size_override("font_size",23);rows.add_child(title)
	subtitle=Label.new();subtitle.add_theme_font_size_override("font_size",14);subtitle.modulate=Color("b8c8cf");rows.add_child(subtitle)
	var buttons := HBoxContainer.new();buttons.add_theme_constant_override("separation",8);rows.add_child(buttons)
	for i in 3:
		var button := Button.new();button.text=["1  Stylised","2  Painterly","3  Bold"][i];button.pressed.connect(set_direction.bind(i));buttons.add_child(button)
	for i in 3:
		var button := Button.new();button.text=["G  Gameplay","D  Detail","L  Architecture"][i];button.pressed.connect(set_view.bind(i));buttons.add_child(button)
	status=Label.new();status.add_theme_font_size_override("font_size",12);status.modulate=Color("d5c6a7");rows.add_child(status)
	var footer := Label.new();footer.text="RMB orbit / MMB or arrows pan / Wheel zoom / Space animate / Q W E R T Y clips / H markers / F9 interface";footer.add_theme_font_size_override("font_size",14);footer.add_theme_constant_override("outline_size",5);footer.position=Vector2(24,690);ui.add_child(footer)
	get_viewport().size_changed.connect(func(): footer.position.y=get_viewport().get_visible_rect().size.y-32)
	footer.position.y=get_viewport().get_visible_rect().size.y-32

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: set_direction(0)
		KEY_2: set_direction(1)
		KEY_3: set_direction(2)
		KEY_G: set_view(0)
		KEY_D: set_view(1)
		KEY_L: set_view(2)
		KEY_SPACE:
			freeze=not freeze;set_clip(current_clip);update_status()
		KEY_H:
			show_markers=not show_markers
			for node in marker_nodes: node.visible=show_markers
		KEY_F9: ui.visible=not ui.visible
		KEY_Q: set_clip("Idle")
		KEY_W: set_clip("Walk")
		KEY_E: set_clip("Attack")
		KEY_R: set_clip("Cast")
		KEY_T: set_clip("Hit")
		KEY_Y: set_clip("Death")

func batch_static_geometry() -> void:
	# Shared blocks are instanced, including their shadows. Characters remain articulated.
	var groups: Dictionary = {}
	for child in stage.get_children():
		if not child is MeshInstance3D: continue
		var node := child as MeshInstance3D
		var key: String = str(node.mesh.get_instance_id())+"_"+str(node.material_override.get_instance_id())
		if not groups.has(key): groups[key]=[]
		groups[key].append(node)
	for group in groups.values():
		if group.size()<2: continue
		var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=group[0].mesh;multi.instance_count=group.size()
		var batch := MultiMeshInstance3D.new();batch.multimesh=multi;batch.material_override=group[0].material_override;stage.add_child(batch)
		for i in group.size():
			multi.set_instance_transform(i,group[i].transform)
			group[i].free()

func build_landscape() -> void:
	# Matching distant hills frame the arcade; no expensive sky/fog volume or backplate.
	for row in 3:
		for i in 9:
			var hill := SphereMesh.new();hill.radius=1;hill.height=2;hill.radial_segments=8 if direction!=1 else 12;hill.rings=4
			var color: Color = col("earth").lerp(col("sky"),.16+row*.15).darkened(.10)
			var at := Vector3(-40+i*10+row*2,-2,-22-row*18)
			var node := add_mesh(hill,at,material("hill%d"%row,color))
			node.scale=Vector3(10,3.6+sin(i*3.1+row)*1.2,8)
			if direction==2: node.rotation.z=sin(i*1.7)*.35
	# Shrub beds / fallen foliage beyond the low walls, kept out of the actor lanes.
	for side in [-1.0,1.0]:
		for i in 8:
			var shrub := add_mesh(CourtyardKit.mesh("shrub"),Vector3(side*(10.2+sin(i*3.1)*.3),0,-5.3+i*1.6),material("shrub",col("leaf").darkened(.18),0,.95,true))
			shrub.scale=Vector3(1.4,.75,1.2);shrub.rotation.y=i*.7
