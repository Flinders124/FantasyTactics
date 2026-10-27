class_name ObjectiveMarker
extends Node3D
var objective: ObjectiveController
var label: Label3D
var material: StandardMaterial3D

func bind(runtime: ObjectiveController) -> void:
	objective=runtime
	visible=objective.definition.kind!=ObjectiveDefinition.Kind.ELIMINATION
	position=objective.center+Vector3.UP*.075
	material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	# Match the circular inclusion rule; double outlines and eight radial ticks
	# distinguish objectives from filled ability previews. 128 segments keep the
	# visual edge within 0.001 m of the configured radius at the default size.
	for ring in [1.0,.94]:
		for index in range(128):
			for endpoint in [index,index+1]:
				var angle := TAU*float(endpoint)/128
				mesh.surface_add_vertex(Vector3(cos(angle),0,sin(angle))*objective.radius*ring)
	for index in range(8):
		var direction := Vector3(cos(TAU*float(index)/8),0,sin(TAU*float(index)/8))
		mesh.surface_add_vertex(direction*objective.radius)
		mesh.surface_add_vertex(direction*(objective.radius+.22))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh=mesh
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	label=Label3D.new()
	label.position=Vector3(0,.85,objective.radius+.35)
	label.font_size=48
	label.pixel_size=.014
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false
	add_child(label)
	objective.changed.connect(refresh)
	refresh()

func refresh() -> void:
	material.albedo_color=Color(1,.75,.3) if objective.control!="Controlled" else Color(.4,.9,.85)
	if objective.definition.kind==ObjectiveDefinition.Kind.HOLD_GROUND:
		label.text="HOLD\n%d / %d - %s"%[objective.progress,objective.definition.required_rounds,objective.control.to_upper()]
	else:
		label.text="EXIT\n%d / 2 HEROES"%objective.heroes_inside
