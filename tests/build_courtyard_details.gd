extends SceneTree
const Source=preload("res://assets/courtyard/source/courtyard_detail_source.gd")
func _initialize() -> void:
	var builder := Source.new()
	var material := load("res://assets/courtyard/materials/stone.tres") as Material
	var assets: Dictionary={"fountain":builder.fountain(material),"statue":builder.statue(material),"bench":builder.bench(material),"barrel":builder.barrel(material),"crate":builder.crate(material),"cart":builder.cart(material),"facade":builder.facade(material),"cracks":builder.ground_patch(material),"leaves":builder.ground_patch(material,true)}
	var manifest: Array[Dictionary]=[]
	for id: String in assets:
		var mesh := assets[id] as ArrayMesh
		ResourceSaver.save(mesh,"res://assets/courtyard/meshes/"+id+".res",ResourceSaver.FLAG_COMPRESS)
		manifest.append({"id":id,"triangles":mesh.surface_get_array_index_len(0)/3,"classification":"blocking" if id in ["fountain","statue"] else "nonblocking inaccessible-boundary or flush ground"})
		if id in ["fountain","statue"]:
			var shape := mesh.create_trimesh_shape()
			shape.backface_collision=true
			ResourceSaver.save(shape,"res://assets/courtyard/collision/"+id+".res",ResourceSaver.FLAG_COMPRESS)
	var file := FileAccess.open("res://assets/courtyard/details_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("Exported 9 original courtyard detail meshes and 2 matching colliders")
	quit()
