class_name CourtyardOcclusion
extends Node
const ART = preload("res://scripts/lantern_art.gd")
## Conservative segment/AABB visibility aid. No collider, navigation or combat
## property is ever changed. StandardMaterial alpha works in Compatibility.
@export_range(.05,.25) var update_interval: float = .08
@export_range(.1,.65) var faded_opacity: float = .24
var camera: Camera3D
var controller: CombatController
var player: PlayerController
var roots: Array[Node3D] = []
var entries: Dictionary = {}
var elapsed: float = 0.0
var faded_count: int = 0

func bind(combat: CombatController,input: PlayerController,view: Camera3D,encounter: Node3D) -> void:
	controller=combat
	player=input
	camera=view
	for node in get_tree().get_nodes_in_group("courtyard_occluder"):
		if encounter.is_ancestor_of(node): roots.append(node as Node3D)
	controller.state_changed.connect(func(state: CombatController.State) -> void:
		if state in [CombatController.State.SETUP,CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: restore_all())
	controller.encounter_reset.connect(restore_all)

func _meshes(node: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if node is MeshInstance3D or node is MultiMeshInstance3D: result.append(node as GeometryInstance3D)
	for child in node.get_children(): result.append_array(_meshes(child))
	return result

func _fade(root: Node3D,enabled: bool) -> void:
	if not entries.has(root):
		if not enabled: return
		var data: Array[Dictionary] = []
		for visual in _meshes(root):
			var mesh := (visual as MeshInstance3D).mesh if visual is MeshInstance3D else (visual as MultiMeshInstance3D).multimesh.mesh
			var base: Material = visual.material_override
			if base==null: base=mesh.surface_get_material(0)
			if base==null: continue
			var faded: Material
			if base is ShaderMaterial and (base as ShaderMaterial).shader==ART.SHADER:
				faded=ART.fade_material(base as ShaderMaterial,faded_opacity)
			elif base is StandardMaterial3D:
				var standard := base.duplicate() as StandardMaterial3D
				standard.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				standard.albedo_color.a=faded_opacity
				faded=standard
			else: continue
			data.append({"node":visual,"original":visual.material_override,"faded":faded,"shadow":visual.cast_shadow})
		entries[root]={"meshes":data,"active":false}
	var entry: Dictionary = entries[root]
	if entry.active==enabled: return
	entry.active=enabled
	for data in entry.meshes:
		if is_instance_valid(data.node):
			data.node.material_override=data.faded if enabled else data.original
			data.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else data.shadow

func restore_all() -> void:
	for root in entries:
		if is_instance_valid(root): _fade(root,false)
	faded_count=0

func update_visibility() -> void:
	if controller==null or camera==null: return
	if controller.state in [CombatController.State.SETUP,CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]:
		restore_all()
		return
	var points: Array[Vector3] = []
	if controller.objectives.definition.kind!=ObjectiveDefinition.Kind.ELIMINATION: points.append(controller.objectives.center+Vector3.UP*.3)
	var active := controller.scheduler.active_unit()
	if active!=null and active.is_alive(): points.append(active.global_position+Vector3.UP*1.1)
	if player.hovered_target!=null and player.hovered_target.is_alive(): points.append(player.hovered_target.target_point())
	if player.ground_selected: points.append(player.selected_ground+Vector3.UP*.25)
	elif player.destination_marker.visible: points.append(player.destination_marker.global_position+Vector3.UP*.25)
	faded_count=0
	for root in roots:
		if not is_instance_valid(root): continue
		var local_bounds: AABB = root.get_meta("occlusion_bounds")
		var bounds: AABB = root.global_transform*local_bounds
		var obscures := false
		for point in points:
			if not bounds.has_point(point) and bounds.grow(.06).intersects_segment(camera.global_position,point)!=null:
				obscures=true
				break
		_fade(root,obscures)
		if obscures: faded_count+=1

func _physics_process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=update_interval:
		elapsed=0
		update_visibility()

func _exit_tree() -> void:
	restore_all()
