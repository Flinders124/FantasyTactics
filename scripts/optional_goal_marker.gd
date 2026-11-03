class_name OptionalGoalMarker
extends Node3D
var goal: OptionalGoalController
var label: Label3D
func bind(runtime: OptionalGoalController) -> void:
 goal=runtime;position=goal.point
 var ring := MeshInstance3D.new();var shape := TorusMesh.new();shape.inner_radius=goal.definition.radius-.04;shape.outer_radius=goal.definition.radius;ring.mesh=shape;ring.position.y=.06
 var material := StandardMaterial3D.new();material.albedo_color=Color(.5,.75,1);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=material;add_child(ring)
 var chest := MeshInstance3D.new();chest.mesh=preload("res://assets/art/lantern_shapes.gd").bevel_box(Vector3(.45,.35,.35),.04);chest.position.y=.175;chest.material_override=preload("res://scripts/lantern_art.gd").paint(Color("e2b66c"));add_child(chest)
 label=Label3D.new();label.font_size=30;label.position=Vector3(0,.7,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.text="OPTIONAL CACHE\n"+("+%d ON VICTORY"%goal.definition.supplies if goal.campaign_rewards else "BONUS CHALLENGE");add_child(label)
 goal.changed.connect(refresh);refresh()
func refresh() -> void:
 visible=not goal.collected and not goal.finished
