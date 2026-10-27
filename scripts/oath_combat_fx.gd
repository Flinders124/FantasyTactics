extends Node3D
## Bounded presentation pool. No collision, timers, callbacks or gameplay writes.
const CAPACITY := 32
const TRAIL_LIMIT := 8
var slots: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var shapes: Dictionary = {}
var view: Camera3D
var clock: float = 0
var reduced: bool = false
var quality: int = 1
var peak: int = 0
var dropped: int = 0

func _ready() -> void:
	for kind in ["blade","blunt","ember","arcane","grave","thorn","heal","slow","death"]:
		shapes[kind]=make_shape(kind)
	for index in CAPACITY:
		var node := MeshInstance3D.new()
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := CombatEffectMeshes.material(Color.WHITE)
		node.material_override=mat
		node.visible=false
		add_child(node)
		slots.append({"node":node,"material":mat,"active":false,"age":0.0,"life":.3,"priority":0,"point":Vector3.ZERO,"drift":Vector3.ZERO,"size":1.0,"kind":""})

static func tint(role: String, ability: String="") -> Color:
	if ability=="crippling_shot": return Color("b9a2ee")
	if role.begins_with("ashfang"): return Color("f6a45d")
	if role.begins_with("hollow"): return Color("90ddd4")
	if role.begins_with("verdant"): return Color("b5d780")
	if role=="mage": return Color("75cee8")
	return Color("f4d79a")

static func area_tint(role: String) -> Color:
	return tint(role) if role.begins_with("hollow") or role.begins_with("verdant") else Color("f6a45d")

static func family(role: String) -> String:
	if role.begins_with("ashfang"): return "ember"
	if role.begins_with("hollow"): return "grave"
	if role.begins_with("verdant"): return "thorn"
	return "arcane"

func burst(point: Vector3, kind: String, color: Color, direction: Vector3=Vector3.UP, size: float=1.0, priority: int=2) -> void:
	if reduced or not point.is_finite(): return
	var chosen: Dictionary={}
	for slot in slots:
		if not slot.active:
			chosen=slot
			break
	if chosen.is_empty():
		for slot in slots:
			if slot.priority<priority and (chosen.is_empty() or slot.age>chosen.age): chosen=slot
	if chosen.is_empty():
		dropped+=1
		return
	chosen.active=true; chosen.age=0.0; chosen.life=.52 if kind in ["heal","death"] else .28
	chosen.priority=priority; chosen.point=point; chosen.kind=kind; chosen.size=size
	chosen.drift=direction.normalized()*(.6 if kind=="heal" else .18)
	chosen.node.mesh=shapes.get(kind,shapes.blade)
	chosen.material.albedo_color=Color(color,.78)
	chosen.node.position=point; chosen.node.scale=Vector3.ONE*size
	chosen.node.rotation=Vector3.ZERO
	if is_instance_valid(view) and point.distance_squared_to(view.global_position)>.01:
		chosen.node.look_at(view.global_position)
	chosen.node.visible=true
	peak=maxi(peak,active_count())

func active_count() -> int:
	var count := 0
	for slot in slots:
		if slot.active: count+=1
	return count

func begin_trail(unit: CombatUnit, color: Color, heavy: bool) -> void:
	if reduced or unit==null or not unit.character.authored: return
	if trails.size()>=TRAIL_LIMIT: _remove_trail(0)
	var mesh := ImmediateMesh.new()
	var node := CombatEffectMeshes.visual(self,mesh,CombatEffectMeshes.material(color,.46))
	trails.append({"node":node,"mesh":mesh,"unit":weakref(unit),"age":0.0,"samples":[],"heavy":heavy})

func _remove_trail(index: int) -> void:
	trails[index].node.free()
	trails.remove_at(index)

func _process(delta: float) -> void:
	clock+=delta
	for slot in slots:
		if not slot.active: continue
		slot.age+=delta
		var phase: float=slot.age/slot.life
		if phase>=1 or reduced:
			slot.active=false; slot.node.visible=false
			continue
		slot.node.position=slot.point+slot.drift*phase
		slot.node.scale=Vector3.ONE*slot.size*(.7+phase*.55)
		slot.material.albedo_color.a=.78*pow(1-phase,1.4)
	for index in range(trails.size()-1,-1,-1):
		var trail: Dictionary=trails[index]
		trail.age+=delta
		var unit: CombatUnit=trail.unit.get_ref()
		if reduced or unit==null or not unit.is_alive() or trail.age>.26 or unit.character.current_clip!="Attack":
			_remove_trail(index)
			continue
		var samples: Array=trail.samples
		if trail.age<.17:
			var edge := unit.character.weapon_edge()
			if samples.is_empty() or edge[1].distance_squared_to(samples[-1].edge[1])>.0002:
				samples.append({"edge":edge,"time":clock})
		while not samples.is_empty() and (clock-samples[0].time>.075 or samples.size()>8): samples.pop_front()
		trail.mesh.clear_surfaces()
		if samples.size()<2: continue
		trail.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(1,samples.size()):
			var a: PackedVector3Array=samples[j-1].edge
			var b: PackedVector3Array=samples[j].edge
			var width := .6 if trail.heavy else .33
			var inner_a: Vector3=a[1].lerp(a[0],width)
			var inner_b: Vector3=b[1].lerp(b[0],width)
			for v: Vector3 in [inner_a,a[1],b[1],inner_a,b[1],inner_b]: trail.mesh.surface_add_vertex(v)
		trail.mesh.surface_end()

func clear() -> void:
	for slot in slots:
		slot.active=false; slot.node.visible=false
	while not trails.is_empty(): _remove_trail(0)

func configure(prefs: Dictionary) -> void:
	reduced=prefs.Accessibility.reduced_effects
	quality=prefs.Display.graphics
	if reduced: clear()

# Angular, finite silhouettes: chips for steel, embers, split runes, thorns.
# Cached once per presentation instance, one draw per burst rather than particles.
static func make_shape(kind: String) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 6 if kind in ["blade","blunt","ember"] else 4
	for i in count:
		var angle := TAU*float(i)/count+.18
		var axis := Vector3(cos(angle),sin(angle),0)
		var side := Vector3(-axis.y,axis.x,0)
		var near := axis*.12
		var far := axis*(.64 if kind=="blunt" else .48)
		var width := .055 if kind in ["blade","ember"] else .09
		if kind=="thorn": far=axis*.7+Vector3(0,.14,0)
		if kind=="grave": near=axis*.29
		if kind=="heal":
			near=Vector3(cos(angle)*.26,-.3, sin(angle)*.26)
			far=near+Vector3(0,.45,0)
		if kind=="slow": far.y=-absf(far.y)
		for v in [near-side*width,far,near+side*width]: mesh.surface_add_vertex(v)
		if kind in ["arcane","grave","heal","thorn"]:
			for v in [near+side*width,far,far+side*width*.6]: mesh.surface_add_vertex(v)
	mesh.surface_end()
	return mesh
