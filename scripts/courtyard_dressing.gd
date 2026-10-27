class_name CourtyardDressing
extends Node3D
## Deterministic cosmetic stream, completely separate from placement/navigation.
const ART = preload("res://scripts/lantern_art.gd")
const STREAM_SALT: int = 0x4355525459415244
var batches: Dictionary = {}
var records: PackedStringArray = []
var occupied: Array[Rect2] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var arena: Vector2
var scenery_count: int = 0

func signature() -> String:
	return str(hash("|".join(records)))

func _instance(id: String,position: Vector3,scale_size: Vector3,angle: float,color: Color=Color.WHITE) -> void:
	if not batches.has(id): batches[id]={"transforms":[],"colors":[]}
	var transform := Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(scale_size),position)
	batches[id].transforms.append(transform)
	batches[id].colors.append(color)
	records.append(str([id,transform,color]))

func _outside_point(near: float,far: float) -> Vector3:
	var edge := rng.randi_range(0,3)
	var distance := rng.randf_range(near,far)
	if edge<2:
		return Vector3((arena.x*.5+distance)*(-1 if edge==0 else 1),-.035,rng.randf_range(-arena.y*.5-2,arena.y*.5+2))
	return Vector3(rng.randf_range(-arena.x*.5-2,arena.x*.5+2),-.035,(arena.y*.5+distance)*(-1 if edge==2 else 1))

func _scenery(id: String,position: Vector3,scale_size: Vector3,angle: float) -> void:
	var node := MeshInstance3D.new()
	node.mesh=CourtyardKit.mesh(id)
	node.material_override=ART.scenery(id)
	node.transform=Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(scale_size),position)
	node.set_meta("occlusion_bounds",node.mesh.get_aabb())
	node.add_to_group("courtyard_occluder")
	var projected := node.transform*node.mesh.get_aabb()
	var footprint := Rect2(Vector2(projected.position.x,projected.position.z),Vector2(projected.size.x,projected.size.z)).grow(.15)
	if occupied.any(func(rect: Rect2) -> bool: return rect.intersects(footprint,true)):
		node.free()
		return
	add_child(node)
	records.append(str([id,node.transform]))
	scenery_count+=1
	var bounds := node.transform*node.mesh.get_aabb()
	occupied.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.3))

func build(layout: BattlefieldLayout,settings: BattlefieldSettings) -> void:
	arena=layout.arena_size
	rng.seed=(layout.original_seed ^ STREAM_SALT ^ (layout.attempt*104729) ^ settings.dressing_seed_offset)&0x7fffffffffffffff
	set_meta("cosmetic_seed",rng.seed)
	var vegetation := clampf(settings.vegetation_density,0.0,2.0) if is_finite(settings.vegetation_density) else 1.0
	var rubble_density := clampf(settings.rubble_density,0.0,2.0) if is_finite(settings.rubble_density) else 1.0
	var skirt := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=arena+Vector2.ONE*1000
	skirt.mesh=plane
	skirt.position.y=-.042
	skirt.material_override=CourtyardKit.earth_material()
	skirt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)
	# Low, nearly flush flagstones. Staggering, chipped corners and subtle tints
	# break the paving pattern without introducing a tactical movement grid.
	var z := -arena.y*.5
	while z<arena.y*.5-.01:
		var row_height := minf(rng.randf_range(.9,1.55),arena.y*.5-z)
		var x := -arena.x*.5
		while x<arena.x*.5-.01:
			var width := minf(rng.randf_range(1.05,2.35),arena.x*.5-x)
			var center := Vector2(x+width*.5,z+row_height*.5)
			var edge := minf(arena.x*.5-absf(center.x),arena.y*.5-absf(center.y))
			var route := absf(center.y)<2.1 or absf(center.x)<1.6
			var tint := rng.randf_range(.94,1.04)*(.85 if edge<1.3 else 1.07 if route else 1.0)
			var color := Color(tint,tint,tint*.98)
			if layout.preset_id=="central_plaza" and center.distance_to(Vector2(layout.objective_center.x,layout.objective_center.z))<4.8: color=Color(tint*1.07,tint*1.035,tint*.88)
			_instance("paver_%d"%rng.randi_range(0,4),Vector3(center.x,.018,center.y),Vector3(maxf(.03,width-.035),1,maxf(.03,row_height-.035)),rng.randf_range(-.008,.008),color)
			x+=width
		z+=row_height
	# Flat moss fragments are below feet and all path/selection graphics. They
	# add age to paving without becoming vegetation in movement corridors.
	for k in range(int(42*vegetation)):
		var point := Vector3(rng.randf_range(-arena.x*.5+.5,arena.x*.5-.5),.021,rng.randf_range(-arena.y*.5+.5,arena.y*.5-.5))
		var flat := Vector2(point.x,point.z)
		if layout.hero_zone.grow(.35).has_point(flat) or layout.enemy_zone.grow(.35).has_point(flat): continue
		if minf(arena.x*.5-absf(point.x),arena.y*.5-absf(point.z))>1.1: continue
		_instance("moss",point,Vector3(rng.randf_range(.25,.65),1,rng.randf_range(.2,.5)),rng.randf_range(-PI,PI))
	_detail(layout,settings)
	for side in [-1.0,1.0]:
		preload("res://scripts/lantern_environment.gd").banner(self,Vector3(side*(arena.x*.5+1.6),0,-arena.y*.5+2.5),side*.25)
	# A partial arch beyond the north kerb provides a restrained landmark.
	_scenery("arch",Vector3(-arena.x*.12,-.035,-arena.y*.5-4.2),Vector3.ONE*1.25,rng.randf_range(-.16,.16))
	for k in range(6):
		var point := Vector3((-1 if k%2==0 else 1)*(arena.x*.5+3.4),0,-arena.y*.5+2+k*2.3)
		if occupied.any(func(rect: Rect2) -> bool: return rect.grow(1.0).has_point(Vector2(point.x,point.z))): continue
		if k%3==0:
			_scenery("wall",point,Vector3(rng.randf_range(2.3,4.5),rng.randf_range(1.3,2.1),.75),rng.randf_range(-PI,PI))
		else:
			_scenery("pillar",point,Vector3(.9,rng.randf_range(1.5,2.8),.9),rng.randf_range(-PI,PI))
	for k in range(int(26*rubble_density)):
		var point := _outside_point(.9,6.5)
		if occupied.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(point.x,point.z))): continue
		_instance("rubble",point,Vector3.ONE*rng.randf_range(.7,1.5),rng.randf_range(-PI,PI))
	# Sheltered planting islands: jitter around a few roots instead of uniform
	# scatter. All upright vegetation remains outside the playable rectangle.
	for cluster in range(int(18*vegetation)):
		var anchor := _outside_point(1.8,5.2)
		_instance("moss",anchor+Vector3.UP*.04,Vector3(3.4,1,2.4),rng.randf_range(-PI,PI))
		for k in range(15):
			var angle := rng.randf_range(0,TAU)
			var radius := sqrt(rng.randf())*1.35
			var point := anchor+Vector3(cos(angle)*radius,0,sin(angle)*radius*.65)
			if occupied.any(func(rect: Rect2) -> bool: return rect.grow(.15).has_point(Vector2(point.x,point.z))): continue
			var id := "shrub" if k<2 else "fern" if k%4==0 else "grass"
			var height := rng.randf_range(.7,1.7)
			_instance(id,point,Vector3(height,height*rng.randf_range(.8,1.25),height),angle,Color(rng.randf_range(.85,1.05),.95,.92))
	# Paired groves frame the rear corners, leaving the camera-facing edge open.
	for side in [-1.0,1.0]:
		for k in 3:
			var at := Vector3(side*(arena.x*.5+3.8+k*.9),0,-arena.y*.5-1.8-k*1.3)
			_instance("tree",at,Vector3.ONE*rng.randf_range(.9,1.45),rng.randf_range(-PI,PI))
	# Mossy grass rooted in the existing perimeter stones, outside the traversable
	# footprint. Spawn zones and all combat corridors receive only flush paving.
	for k in range(int((arena.x+arena.y)*vegetation*.6)):
		var edge := k%4
		var point := Vector3.ZERO
		if edge<2: point=Vector3((-1 if edge==0 else 1)*(arena.x*.5+.25),.79,rng.randf_range(-arena.y*.5,arena.y*.5))
		else: point=Vector3(rng.randf_range(-arena.x*.5,arena.x*.5),.79,(-1 if edge==2 else 1)*(arena.y*.5+.25))
		_instance("grass",point,Vector3.ONE*rng.randf_range(.55,.85),rng.randf_range(-PI,PI))
	for id: String in batches:
		var batch: Dictionary = batches[id]
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.use_colors=true
		multimesh.mesh=CourtyardKit.mesh(id)
		multimesh.instance_count=batch.transforms.size()
		for index in range(multimesh.instance_count):
			multimesh.set_instance_transform(index,batch.transforms[index])
			multimesh.set_instance_color(index,batch.colors[index])
		var visual := MultiMeshInstance3D.new()
		visual.name=id.capitalize()+"Batch"
		visual.set_meta("dressing_id",id)
		visual.multimesh=multimesh
		visual.visibility_range_end=90
		visual.material_override=ART.scenery(id)
		visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id=="tree" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
	add_to_group("courtyard_dressing")

func _detail(layout: BattlefieldLayout,settings: BattlefieldSettings) -> void:
	var density := clampf(settings.detail_density,0,2)
	# Inaccessible outer landmarks never lie on navigation or pretend to be a
	# walkable solid. Foreground tall pieces use the existing reversible fading.
	var landmark := "facade" if layout.preset_id=="ruined_lanes" else ("statue" if layout.preset_id=="central_plaza" else "fountain")
	_scenery(landmark,Vector3(0,0,-arena.y*.5-2.5),Vector3(2.4,2.3,2.4),0)
	for edge in range(4):
		var angle := PI*.5*edge
		var distance := (arena.x if edge%2==0 else arena.y)*.5+3.2
		var radial := Vector3(cos(angle),0,sin(angle))
		var tangent := Vector3(-sin(angle),0,cos(angle))
		if layout.preset_id=="ruined_lanes":
			_scenery("facade",radial*(distance+1)+tangent*4,Vector3(1.4,1.25,1.4),-angle-PI*.5)
		elif layout.preset_id=="central_plaza":
			_scenery("pillar",radial*(distance+1)+tangent*4,Vector3(1.25,3,1.25),angle)
		for index in range(int(3*density)):
			var base := radial*distance+tangent*(-4+index*2.8)
			_scenery(["bench","cart","crate"][index%3],base,Vector3.ONE*rng.randf_range(.85,1.1),-angle-PI*.5+rng.randf_range(-.15,.15))
			_instance("barrel",base+tangent*1.5+radial*.7,Vector3.ONE*.85,rng.randf_range(-PI,PI))
	# Cluster fine ground marks around existing obstacle edges and boundary
	# seams. All marks are flush, opaque, non-blocking and below path graphics.
	for index in range(int(48*density)):
		var point := Vector3.ZERO
		if index%2==0 and not layout.obstacle_centers.is_empty():
			var owner := index%layout.obstacle_centers.size()
			var obstacle := layout.obstacle_centers[owner]
			var size := layout.obstacle_sizes[owner]
			point=Vector3(obstacle.x+size.x*.5+rng.randf_range(.12,.7),.026,obstacle.z+rng.randf_range(-size.z*.5,size.z*.5))
		else:
			point=Vector3(rng.randf_range(-arena.x*.5+.3,arena.x*.5-.3),.026,rng.randf_range(-arena.y*.5+.3,arena.y*.5-.3))
		var flat := Vector2(point.x,point.z)
		if layout.hero_zone.grow(.5).has_point(flat) or layout.enemy_zone.grow(.5).has_point(flat): continue
		if layout.objective_radius>0 and point.distance_to(layout.objective_center)<layout.objective_radius+.8: continue
		var inside := false
		for k in range(layout.obstacle_sizes.size()):
			var size := layout.obstacle_sizes[k]
			var center := layout.obstacle_centers[k]
			if Rect2(Vector2(center.x-size.x*.5,center.z-size.z*.5),Vector2(size.x,size.z)).has_point(flat): inside=true
		if inside: continue
		_instance("leaves" if index%3==0 else "cracks",point,Vector3.ONE*rng.randf_range(.25,.65),rng.randf_range(-PI,PI))
