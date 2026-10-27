extends SceneTree
const Source = preload("res://assets/courtyard/source/courtyard_mesh_source.gd")
const ROOT: String = "res://assets/courtyard/"

func _initialize() -> void:
	var builder := Source.new()
	var stone := Source.material(Color.WHITE)
	var leaves := Source.material(Color.WHITE,true)
	ResourceSaver.save(stone,ROOT+"materials/stone.tres")
	ResourceSaver.save(leaves,ROOT+"materials/foliage.tres")
	var meshes: Dictionary = {"wall":builder.wall(stone),"pillar":builder.pillar(stone),"ruin_plinth":builder.plinth(stone),"arch":builder.arch(stone),"rubble":builder.rubble(stone),"grass":builder.grass(leaves),"fern":builder.grass(leaves,true),"shrub":builder.shrub(leaves),"moss":builder.moss(leaves),"ivy":builder.ivy(leaves)}
	builder.start(stone)
	builder.bevel_block(Vector3(0,.5,0),Vector3.ONE,.035,Color("7e8473"))
	meshes["boundary_stone"]=builder.finish()
	for variant in range(5): meshes["paver_%d"%variant]=builder.paver(stone,variant)
	var manifest: Array[Dictionary] = []
	for id: String in meshes:
		var mesh := meshes[id] as ArrayMesh
		ResourceSaver.save(mesh,ROOT+"meshes/"+id+".res",ResourceSaver.FLAG_COMPRESS)
		var count: int = mesh.surface_get_array_index_len(0)/3
		manifest.append({"id":id,"triangles":count,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())})
		if id in ["wall","pillar","ruin_plinth"]:
			var collision_mesh := builder.wall(stone,true) if id=="wall" else mesh
			var shape := collision_mesh.create_trimesh_shape()
			shape.backface_collision=true
			ResourceSaver.save(shape,ROOT+"collision/"+id+".res",ResourceSaver.FLAG_COMPRESS)
	var file := FileAccess.open(ROOT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("Courtyard: exported ",meshes.size()," original native mesh assets and 3 matching collision resources")
	quit()
