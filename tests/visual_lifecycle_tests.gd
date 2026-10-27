extends SceneTree
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)
func run() -> void:
	var original: Array[WeakRef]=[]
	for index in 12:
		var visual:=CharacterVisual.new();root.add_child(visual);visual.load_role(["knight","ranger","mage","cleric"][index%4])
		original.append(weakref(visual))
		# Reparent must preserve the exact private override materials.
		var mesh:=visual.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var material:=mesh.get_surface_override_material(0)
		root.remove_child(visual);root.add_child(visual)
		check(mesh.get_surface_override_material(0)==material,"Reentry preserves material identity")
		visual.queue_free()
	for frame in 6:await process_frame
	for reference in original:check(reference.get_ref()==null,"Visual freed")
	for index in 8:
		var portrait:=CharacterPortrait.new();root.add_child(portrait);portrait.setup("knight");original.append(weakref(portrait));portrait.queue_free()
	for frame in 6:await process_frame
	for reference in original:check(reference.get_ref()==null,"Portrait/visual batch released")
	print("VISUAL LIFECYCLE RESULT: %d failures"%failures);quit(0 if failures==0 else 1)
