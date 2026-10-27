extends RefCounted
## Shared courtyard vocabulary, fitted around the existing five HQ pick volumes.
const ART = preload("res://scripts/lantern_art.gd")

static func batch(parent: Node3D,id: String,transforms: Array[Transform3D]) -> void:
	if transforms.is_empty(): return
	var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=CourtyardKit.mesh(id);multi.instance_count=transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new();node.name="Camp"+id.capitalize();node.multimesh=multi;node.material_override=ART.scenery(id)
	node.set_meta("dressing_id",id)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id=="tree" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func build(parent: Node3D,points: Array[Vector3]) -> void:
	var kit := CampKit.new()
	var rng := RandomNumberGenerator.new();rng.seed=78231
	preload("res://scripts/lantern_environment.gd").banner(parent,Vector3(-9,0,-2.5),.25)
	preload("res://scripts/lantern_environment.gd").banner(parent,Vector3(9.4,0,2.2),-.2)
	var terrain := PlaneMesh.new();terrain.size=Vector2(250,250)
	var ground := kit.piece(parent,terrain,Vector3(0,-.045,0),CourtyardKit.earth_material());ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paving: Array[Transform3D]=[]
	for i in 20:
		var angle := TAU*i/20.0
		paving.append(Transform3D(Basis(Vector3.UP,-angle)*Basis.from_scale(Vector3(.80,1,.53)),Vector3(cos(angle)*3,.025,1+sin(angle)*3)))
	# Irregular paired stepping stones, retaining the original radial routes.
	for target in points:
		var start := Vector3(0,0,1)
		var end := target+Vector3(0,0,1)
		var steps := ceili(start.distance_to(end)/.9)
		var direction := (end-start).normalized();var across := Vector3(direction.z,0,-direction.x)
		for i in range(1,steps+1):
			for side in [-.38,.38]:
				var at: Vector3 = start.lerp(end,float(i)/steps)+across*(side+rng.randf_range(-.04,.04));at.y=.025
				var basis := Basis(Vector3.UP,atan2(direction.x,direction.z)+rng.randf_range(-.06,.06))*Basis.from_scale(Vector3(.68,1,.81))
				paving.append(Transform3D(basis,at))
	batch(parent,"paver_2",paving)
	var vegetation: Dictionary={"grass":[],"fern":[],"shrub":[],"tree":[],"boundary_stone":[]}
	# Broken, asymmetric groves, with planted islands at tent backs. No pieces
	# are placed in the centre or in the mission/training interaction routes.
	for cluster in 16:
		var angle := TAU*cluster/16.0+rng.randf_range(-.12,.12)
		var radius := rng.randf_range(12.8,15.8)
		var anchor := Vector3(cos(angle)*radius,0,sin(angle)*radius)
		for i in 12:
			var at := anchor+Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(-.8,.8))
			var id := "shrub" if i<2 else "fern" if i%3==0 else "grass"
			vegetation[id].append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(Vector3.ONE*rng.randf_range(.8,1.5)),at))
		if cluster%2==0:
			for i in 2:
				var at := anchor.normalized()*(radius+1.7+i*.9)+Vector3(0,0,i*.7)
				vegetation.tree.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU))*Basis.from_scale(Vector3.ONE*rng.randf_range(.95,1.4)),at))
		vegetation.boundary_stone.append(Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(Vector3(.8,.3,.6)),anchor))
	for id: String in vegetation:
		var transforms: Array[Transform3D]=[];transforms.assign(vegetation[id]);batch(parent,id,transforms)
	# Two welcoming lamps mark the mission approach. Local lights cast no
	# shadows; emissive panes remain restrained under the linear tone mapper.
	for at: Vector3 in [Vector3(-4.9,0,5.5),Vector3(5.5,0,5.7)]:
		kit.beam(parent,at,at+Vector3.UP*2.3,.055,kit.timber)
		kit.box(parent,at+Vector3(0,2.18,0),Vector3(.44,.10,.44),kit.iron)
		var pane := CampKit.material(Color("efb875"));pane.emission_enabled=true;pane.emission=Color("efb875");pane.emission_energy_multiplier=.35
		kit.box(parent,at+Vector3(0,1.93,0),Vector3(.25,.38,.25),pane)
		kit.box(parent,at+Vector3(0,1.68,0),Vector3(.36,.08,.36),kit.iron)
		var light := OmniLight3D.new();light.position=at+Vector3.UP*1.95;light.light_color=Color("ffc080");light.light_energy=.45;light.omni_range=3.5;light.shadow_enabled=false;parent.add_child(light)
