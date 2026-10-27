class_name EliteWarnings
extends Node3D
## Persistent, non-interactive presentation of authoritative committed locations.
var controller: CombatController
var markers: Dictionary={}
func bind(combat: CombatController) -> void:
	controller=combat
	combat.encounter_updated.connect(refresh)
	combat.encounter_reset.connect(refresh)
func refresh() -> void:
	for id: String in markers.keys():
		if not controller.pending_telegraphs.has(id):
			markers[id].queue_free(); markers.erase(id)
	for id: String in controller.pending_telegraphs:
		if markers.has(id): continue
		var unit:=controller.find_unit(id)
		var data: Dictionary=controller.pending_telegraphs[id]
		var ability:=unit.ability_by_id(data.ability_id)
		var marker:=Node3D.new(); add_child(marker); marker.global_position=data.point+Vector3.UP*.12
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=Color(1,.65,.12)
		var mesh:=ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
		# Solid-width boundary and inward warning teeth survive gameplay zoom.
		# Every vertex remains inside the authoritative affected radius.
		for index in range(64):
			var a:=TAU*float(index)/64; var b:=TAU*float(index+1)/64
			var va:=Vector3(cos(a),0,sin(a)); var vb:=Vector3(cos(b),0,sin(b))
			var outer:float=ability.area_radius; var inner:float=maxf(0,outer-.06)
			for v in [va*inner,va*outer,vb*outer,va*inner,vb*outer,vb*inner]:mesh.surface_add_vertex(v)
		for axis:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var side:=axis.cross(Vector3.UP)*.12
			var at:=axis*(ability.area_radius-.13)
			for v in [at-side,at+side,axis*(ability.area_radius-.48)]:mesh.surface_add_vertex(v)
		mesh.surface_end()
		var outline:=MeshInstance3D.new(); outline.mesh=mesh; outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; marker.add_child(outline)
		var label:=Label3D.new(); label.text="! "+ability.display_name+"\nBLAST AT "+unit.definition.display_name+"'S NEXT TURN"
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.font_size=32; label.pixel_size=.006; label.position.y=.4
		label.modulate=Color(1,.85,.35); label.outline_modulate=Color.BLACK; label.outline_size=12; marker.add_child(label)
		markers[id]=marker
