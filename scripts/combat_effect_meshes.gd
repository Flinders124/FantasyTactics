class_name CombatEffectMeshes
extends RefCounted
## Shapes only, without timers, physics, animation signals or combat references.
static func material(color: Color,alpha: float=.8) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	result.albedo_color=Color(color,alpha)
	return result

static func ring(radius: float,width: float=.035) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius=maxf(.01,radius-width)
	mesh.outer_radius=radius
	mesh.rings=28
	mesh.ring_segments=5
	return mesh

static func visual(parent: Node3D,mesh: Mesh,mat: Material,position: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh=mesh
	item.material_override=mat
	item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.position=position
	parent.add_child(item)
	return item

static func glyph(kind: String) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind in ["swing","power"]:
		for index in range(16):
			var a := -.95+float(index)/16*1.9
			var b := -.95+float(index+1)/16*1.9
			var width := .18 if kind=="power" else .075
			var p := Vector3(sin(a),.08,cos(a))*.9
			var q := Vector3(sin(b),.08,cos(b))*.9
			for v in [p*(1-width),p,q,q,q*(1-width),p*(1-width)]: mesh.surface_add_vertex(v)
	elif kind=="heal":
		for rect in [Rect2(-.085,-.34,.17,.68),Rect2(-.30,-.08,.60,.16)]:
			for p in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,rect.position,rect.end,Vector2(rect.position.x,rect.end.y)]:
				mesh.surface_add_vertex(Vector3(p.x,p.y,0))
	elif kind=="slow":
		for offset in [-.3,0.0,.3]:
			for v in [Vector3(-.14,offset+.12,0),Vector3(0,offset,0),Vector3(.14,offset+.12,0)]: mesh.surface_add_vertex(v)
	else:
		for index in range(7):
			var angle := float(index)*TAU/7
			var point := Vector3(cos(angle),sin(angle),0)
			var side := Vector3(-point.y,point.x,0)*.045
			for v in [point*.13-side,point*.48,point*.13+side]: mesh.surface_add_vertex(v)
	mesh.surface_end()
	return mesh
