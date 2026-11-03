class_name CourtyardArchitecture
extends RefCounted
## Original editable mesh source. Every solid piece supplies its own matching collision.
const ART=preload("res://scripts/lantern_art.gd")
const SHAPES=preload("res://assets/art/lantern_shapes.gd")
static func part(body: StaticBody3D, mesh: Mesh, at: Vector3, color: Color, basis: Basis=Basis.IDENTITY) -> void:
 var visual := MeshInstance3D.new();visual.mesh=mesh;visual.position=at;visual.basis=basis;visual.material_override=ART.paint(color);body.add_child(visual)
 var collision := CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();collision.position=at;collision.basis=basis
 (collision.shape as ConcavePolygonShape3D).backface_collision=true;body.add_child(collision)
static func box(body: StaticBody3D, at: Vector3, size: Vector3, color: Color) -> void:
 part(body,SHAPES.bevel_box(size,.025),at,color)
static func cylinder(body: StaticBody3D, at: Vector3, radius: float, height: float, color: Color, basis: Basis=Basis.IDENTITY) -> void:
 var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12
 part(body,mesh,at,color,basis)
static func build(parent: Node3D,id: String,center: Vector3,size: Vector3,kind: String) -> StaticBody3D:
 var body := StaticBody3D.new();body.name=id;body.collision_layer=9;body.position=center-Vector3.UP*size.y*.5
 var stone := Color("85a5ab");var dark := Color("50677e");var wood := Color("765b4d");var gold := Color("e2b66c")
 if kind=="arch":
  # Travel along X, clear opening along Z. Actual wedge stones form the arch.
  var scale := size.z/4.0
  for side in [-1.0,1.0]:
   for row in range(4):box(body,Vector3(0,(row+.5)*.4,side*1.65*scale),Vector3(size.x,.39,.66*scale),stone)
  for index in range(12):
   var mesh := SHAPES.wedge(float(index)*PI/12+.008,float(index+1)*PI/12-.008,1.3*scale,1.98*scale,size.x)
   part(body,mesh,Vector3(0,1.6,0),stone.lerp(dark,.15*float(index%3)),Basis(Vector3.UP,PI*.5))
 elif kind=="house":
  var half_x := size.x*.5;var half_z := size.z*.5;var thickness: float=.42
  for row in range(5):
   var y := (float(row)+.5)*size.y/5
   var h := size.y/5-.025
   box(body,Vector3(-half_x+thickness*.5,y,0),Vector3(thickness,h,size.z),stone)
   for side in [-1.0,1.0]:
    box(body,Vector3(0,y,side*(half_z-thickness*.5)),Vector3(size.x-thickness*2,h,thickness),stone.lerp(dark,.1*float(row%2)))
    var wing := maxf(.35,(size.z-2.0)*.5)
    box(body,Vector3(half_x-thickness*.5,y,side*(1.0+wing*.5)),Vector3(thickness,h,wing),stone)
  box(body,Vector3(half_x-thickness*.5,2.45,0),Vector3(.55,.35,2.1),dark)
  # Broken lintels and surviving timber identify a dwelling without an opaque roof.
  box(body,Vector3(0,size.y-.15,-half_z+.2),Vector3(size.x-.4,.18,.26),wood)
 elif kind=="fountain":
  var radius := minf(size.x,size.z)*.48
  cylinder(body,Vector3(0,.18,0),radius,.36,stone)
  cylinder(body,Vector3(0,.37,0),radius*.78,.06,Color("4e969f"))
  for index in range(12):
   var angle := TAU*index/12
   var mesh := SHAPES.wedge(angle+.014,angle+TAU/12-.014,radius*.80,radius,.35)
   part(body,mesh,Vector3(0,.48,0),stone,Basis(Vector3.RIGHT,PI*.5))
  cylinder(body,Vector3(0,.85,0),.22,1.1,dark)
  cylinder(body,Vector3(0,1.43,0),.50,.16,stone)
  cylinder(body,Vector3(0,1.65,0),.12,.28,gold)
 elif kind=="cart":
  box(body,Vector3(0,.72,0),Vector3(size.x*.86,.22,size.z*.76),wood)
  for side in [-1.0,1.0]:
   box(body,Vector3(0,1.0,side*size.z*.39),Vector3(size.x*.9,.44,.12),wood)
   for x in [-.65,.65]:cylinder(body,Vector3(x,.38,side*size.z*.43),.36,.14,dark,Basis(Vector3.RIGHT,PI*.5))
  box(body,Vector3(-.3,1.15,0),Vector3(.65,.64,.65),Color("99764f"))
  box(body,Vector3(.48,1.0,0),Vector3(.55,.35,.6),Color("a4ae8a"))
 elif kind=="altar":
  box(body,Vector3(0,.12,0),Vector3(size.x,.24,size.z),dark)
  box(body,Vector3(0,.65,0),Vector3(size.x*.64,.85,size.z*.66),stone)
  box(body,Vector3(0,1.16,0),Vector3(size.x*.95,.2,size.z*.93),stone)
  box(body,Vector3(0,1.38,0),Vector3(.35,.22,.35),gold)
 else:
  body.free();return CourtyardKit.blocker(parent,id,center,size,kind)
 body.set_meta("courtyard_kind",kind)
 body.set_meta("footprint",Rect2(Vector2(-size.x,-size.z)*.5,Vector2(size.x,size.z)))
 var bounds := AABB()
 for node in body.get_children():
  if node is MeshInstance3D:bounds=bounds.merge(node.transform*node.mesh.get_aabb())
 body.set_meta("occlusion_bounds",bounds);body.add_to_group("courtyard_occluder");parent.add_child(body);return body

static func compose(layout: BattlefieldLayout,settings: BattlefieldSettings,objective: ObjectiveDefinition) -> void:
 var rng := RandomNumberGenerator.new();rng.seed=(layout.original_seed^0x41524348^(layout.attempt*104729))&0x7fffffffffffffff
 var width := layout.arena_size.x;var depth := layout.arena_size.y
 var x := maxf(0,width*.5-settings.boundary_margin-settings.spawn_zone_size.x-settings.clearance-2.0)
 var z := depth*.35
 var candidates: Array[Dictionary]=[]
 candidates.append({"kind":"house","at":Vector3(-x,0,z),"size":Vector3(3.8,3.1,3)})
 candidates.append({"kind":"house","at":Vector3(x,0,-z),"size":Vector3(3.8,3.1,3)})
 for side in [-1.0,1.0]:candidates.append({"kind":"arch","at":Vector3(side*width*.16,0,0),"size":Vector3(1,3.6,4)})
 candidates.append({"kind":"fountain","at":Vector3(0,0,depth*.27),"size":Vector3(3.2,1.9,3.2)})
 candidates.append({"kind":"altar","at":Vector3(0,0,-depth*.27),"size":Vector3(2.6,1.6,2.1)})
 candidates.append({"kind":"cart","at":Vector3(-x,0,-depth*.27),"size":Vector3(2.6,1.6,1.4)})
 if layout.preset_id in ["ruined_lanes","narrow_approach"]:
  candidates.append({"kind":"house","at":Vector3(x,0,z),"size":Vector3(3.8,3.1,3)})
 if layout.preset_id in ["central_plaza","split_courtyard"]:
  candidates[1].kind="statue";candidates[1].size=Vector3(2,2.7,2)
 var arena := Rect2(-layout.arena_size*.5+Vector2.ONE*settings.boundary_margin,layout.arena_size-Vector2.ONE*settings.boundary_margin*2)
 var occupied: Array[Rect2]=[]
 for candidate in candidates:
  var at: Vector3=candidate.at
  # Small seeded longitudinal variation keeps routes deliberate and reproducible.
  if not layout.used_fallback:at.z+=rng.randf_range(-.10,.10)
  var size: Vector3=candidate.size
  var rect := Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
  if not arena.encloses(rect) or rect.intersects(layout.hero_zone.grow(settings.clearance),true) or rect.intersects(layout.enemy_zone.grow(settings.clearance),true):continue
  if occupied.any(func(other: Rect2) -> bool:return rect.grow(settings.clearance*.5).intersects(other.grow(settings.clearance*.5),true)):continue
  if objective!=null and objective.kind!=ObjectiveDefinition.Kind.ELIMINATION:
   var nearest := Vector2(layout.objective_center.x,layout.objective_center.z).clamp(rect.position,rect.end)
   if nearest.distance_to(Vector2(layout.objective_center.x,layout.objective_center.z))<=layout.objective_radius+BattlefieldSettings.NAV_RADIUS:continue
  layout.obstacle_centers.append(at+Vector3.UP*size.y*.5);layout.obstacle_sizes.append(size);layout.obstacle_kinds.append(candidate.kind);occupied.append(rect)
