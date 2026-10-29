class_name CharacterVisual
extends Node3D
## Presentation only. Animation completion never spends resources or unlocks combat.
const ROLES: PackedStringArray = ["knight", "ranger", "mage", "cleric", "raider", "sentinel", "recruit", "aegisbearer", "chainbinder"]
const ART = preload("res://scripts/lantern_art.gd")
const FACTION_KIT = preload("res://scripts/faction_visual_kit.gd")
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var role: String = ""
var unit: Node3D
var _previous_position: Vector3
var _oneshot_remaining: float = 0.0
var _dead: bool = false
var _survival_state: String = "ACTIVE"
var _carrying: bool = false
var current_clip: String = ""
var _clips: Dictionary = {}
var authored: bool = false
var _detached_surfaces: Array[Dictionary] = []
var _flash_remaining: float = 0.0
var _flash_meshes: Array[Dictionary] = []

func flash(color: Color) -> void:
	var owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if owner!=null and owner.preferences.Accessibility.reduced_effects: return
	restore_flash()
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(color,.28)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		_flash_meshes.append({"mesh":mesh,"original":mesh.material_overlay,"flash":material})
		mesh.material_overlay=material
	_flash_remaining=.13

func restore_flash() -> void:
	for entry in _flash_meshes:
		if is_instance_valid(entry.mesh): entry.mesh.material_overlay=entry.original
	_flash_meshes.clear()
	_flash_remaining=0

func configure(owner_unit: Node3D) -> void:
	add_to_group("preference_consumers")
	unit = owner_unit
	var requested: String = unit.definition.visual_id
	if not ROLES.has(requested) and not FACTION_KIT.BASE_ROLES.has(requested):
		requested = "sentinel" if unit.faction == 1 else "ranger"
		if unit.role_label() != "Ranged":
			requested = "raider" if unit.faction == 1 else "knight"
	load_role(requested)
	reset_pose()

func load_role(id: String) -> void:
	if model != null and role == id:
		return
	if model != null:
		restore_flash()
		_detach_surfaces(false)
		model.free()
	role = id
	var authored_path := "res://assets/characters/oath_models/%s.glb"%id
	authored=ResourceLoader.exists(authored_path) and not get_meta("art_comparison",false)
	model = (load(authored_path if authored else "res://assets/characters/models/%s.glb" % FACTION_KIT.base_role(role)) as PackedScene).instantiate() as Node3D
	add_child(model)
	player = _find_player(model)
	skeleton = _find_skeleton(model)
	assert(player != null and skeleton != null, "Character must contain a skeleton and animation player")
	if authored:
		model.set_meta("authored_character",id)
		model.set_meta("lantern_oath",true)
		for child in model.find_children("*","MeshInstance3D",true,false):
			for surface in child.mesh.get_surface_count():
				var source := child.mesh.surface_get_material(surface) as StandardMaterial3D
				if source!=null: child.set_surface_override_material(surface,ART.paint(source.albedo_color,source.metallic,source.roughness,false,true))
	elif FACTION_KIT.BASE_ROLES.has(id):
		var kit := FACTION_KIT.new()
		kit.equip(model, skeleton, id)
	if not authored and not get_meta("art_comparison",false): ART.character(model,skeleton,id)
	_clips.clear()
	for key in player.get_animation_list():
		var short_name := String(key).get_file()
		_clips[short_name] = key
		var clip := player.get_animation(key)
		clip.loop_mode = Animation.LOOP_LINEAR if short_name in ["Idle", "Walk", "Run"] else Animation.LOOP_NONE
	play_clip("Idle")

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func reset_pose() -> void:
	restore_flash()
	_dead = false
	_survival_state = "ACTIVE"
	_carrying = false
	_oneshot_remaining = 0.0
	rotation = Vector3.ZERO
	if unit != null:
		_previous_position = unit.global_position
	if player != null:
		player.speed_scale = 1.0
		player.stop()
		skeleton.reset_bone_poses()
		current_clip = ""
		play_clip("Idle")

func face_point(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(-direction.x, -direction.z)

func play_clip(clip: String, oneshot: bool = false) -> void:
	if player == null or not _clips.has(clip):
		return
	if _dead and clip != "Death":
		return
	if current_clip == clip and not oneshot:
		return
	# Legacy clips have partial tracks. Authored clips contain complete poses,
	# allowing AnimationPlayer to blend without stopping/resetting every joint.
	if not authored:
		player.stop()
		skeleton.reset_bone_poses()
	current_clip = clip
	player.speed_scale = 1.0
	player.play(_clips[clip], (.025 if oneshot else .10) if authored else .08)
	if oneshot:
		_oneshot_remaining = player.get_animation(_clips[clip]).length
	if clip == "Death":
		_dead = true

func action(cast: bool = false) -> void:
	var definition: Variant=unit.get("definition") if unit!=null else null
	var base := FACTION_KIT.base_role(role)
	# The crowned Hollow caster has a blade silhouette but a ranged magic attack.
	var ranged_cast: bool=definition!=null and definition.basic_attack!=null and definition.basic_attack.type_label()=="Ranged" and base not in ["ranger","sentinel"]
	play_clip("Cast" if cast or base=="mage" or ranged_cast else "Attack", true)

func hit() -> void:
	if not _dead:
		play_clip("Hit", true)

func die() -> void:
	play_clip("Death", true)

# Presentation accepts state names only; it never changes combat life state.
func set_survival_pose(state: String, carrying: bool = false) -> void:
	var next_state := state.to_upper()
	if _survival_state == next_state and _carrying == carrying:
		return
	_survival_state = next_state
	_carrying = carrying
	if player == null:
		return
	if next_state in ["DOWNED", "STABILISED"]:
		_dead = false
		play_clip("Death", true)
		player.advance(0)
		player.seek(player.get_animation(_clips["Death"]).length, true)
		player.pause()
		_dead = true
	elif next_state == "ACTIVE":
		_dead = false
		_oneshot_remaining = 0.0
		current_clip = ""
		play_clip("Idle")

func _physics_process(delta: float) -> void:
	if _flash_remaining>0:
		_flash_remaining-=delta
		if _flash_remaining<=0: restore_flash()
	if unit == null or player == null:
		return # Standalone showcase/portraits control animation explicitly.
	var displacement := unit.global_position - _previous_position
	_previous_position = unit.global_position
	if _dead:
		return
	if displacement.length() > 0.002:
		_oneshot_remaining = 0.0 # Movement may interrupt presentation, never rules.
		if authored: rotation.y=lerp_angle(rotation.y,atan2(-displacement.x,-displacement.z),minf(1.0,delta*18))
		else: face_point(global_position + displacement)
		var speed := displacement.length()/delta
		var gait := "Run" if authored and speed>2.8 else "Walk"
		play_clip(gait)
		player.speed_scale = clampf(speed/(3.0 if gait=="Run" else 2.0 if authored else 2.4), 0.7, 1.8)
	else:
		_oneshot_remaining = maxf(0.0, _oneshot_remaining - delta)
		if _oneshot_remaining > 0.0:
			return
		player.speed_scale = 1.0
		play_clip("Idle")

	if _carrying and skeleton != null:
		var forearm := skeleton.find_bone("L_forearm")
		if forearm >= 0:
			skeleton.set_bone_pose_rotation(forearm, Quaternion(Vector3.RIGHT, -0.85))

func apply_preferences(owner: GameAudio) -> void:
	for entry in _flash_meshes:
		if is_instance_valid(entry.mesh): entry.mesh.material_overlay=entry.original if owner.preferences.Accessibility.reduced_effects else entry.flash



# Landmarks from the authored mesh source, transformed by the exact skin joint.
# These never replace the gameplay AttackOrigin / TargetPoint markers.
func weapon_landmark(rest_point: Vector3, hand: String="R_hand") -> Vector3:
	if skeleton==null: return global_position+Vector3.UP
	var bone := skeleton.find_bone(hand)
	if bone<0: return global_position+Vector3.UP
	var local := skeleton.get_bone_global_rest(bone).affine_inverse()*rest_point
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)*local

func weapon_edge() -> PackedVector3Array:
	var blunt := role in ["cleric","hollow_warden"]
	var tip := Vector3(.46,1.58 if role=="recruit" else 2.06 if role=="chainbinder" else 1.57 if blunt else 1.83,-.065)
	if role.begins_with("ashfang_"): tip=Vector3(.70,1.76,-.065)
	return PackedVector3Array([weapon_landmark(Vector3(.46,1.08,-.065)),weapon_landmark(tip)])

func emission_point() -> Vector3:
	var base := FACTION_KIT.base_role(role)
	if base in ["ranger","sentinel"]: return weapon_landmark(Vector3(-.46,.84,-.065),"L_hand")
	if base=="mage" or role=="verdant_tender": return weapon_landmark(Vector3(.48,2.08,-.065))
	return weapon_landmark(Vector3(.46,.88,-.065))

func _detach_surfaces(remember: bool) -> void:
	if not is_instance_valid(model): return
	# Geometry must release its override before the privately owned material RID.
	# Same-frame teardown otherwise leaves deferred shader-parameter queries stale.
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		var surfaces: Array[Material]=[]
		for index in mesh.mesh.get_surface_count(): surfaces.append(mesh.get_surface_override_material(index))
		if remember: _detached_surfaces.append({"mesh":mesh,"override":mesh.material_override,"surfaces":surfaces})
		mesh.material_override=null
		for index in surfaces.size(): mesh.set_surface_override_material(index,null)

func _exit_tree() -> void:
	restore_flash()
	_detached_surfaces.clear()
	_detach_surfaces(true)

func _enter_tree() -> void:
	# Removing/reparenting a visual is not disposal; restore the exact materials.
	for entry in _detached_surfaces:
		if not is_instance_valid(entry.mesh): continue
		entry.mesh.material_override=entry.override
		for index in entry.surfaces.size(): entry.mesh.set_surface_override_material(index,entry.surfaces[index])
	_detached_surfaces.clear()
