extends "res://tests/stability_visual.gd"
var rendered_decisions: Array[Dictionary] = []
var camera_checked: bool = false

func attach_diagnostics() -> void:
	var enemy := flow.combat.get_node("EnemyController") as EnemyController
	if not enemy.decision_chosen.is_connected(record_decision): enemy.decision_chosen.connect(record_decision)
	if not enemy.planning_progress.is_connected(check_camera): enemy.planning_progress.connect(check_camera)

func ready_flow() -> void:
	await super.ready_flow()
	attach_diagnostics()

func start_case(seed_value: int,heroes: PackedStringArray) -> void:
	await super.start_case(seed_value,heroes)
	attach_diagnostics()

func record_decision(data: Dictionary) -> void:
	rendered_decisions.append(data.duplicate(true))
	check(data.path_queries<=48 and data.action_queries<=768,"Rendered planner stays within query caps")

func check_camera(_id: String,_serial: int) -> void:
	if camera_checked: return
	camera_checked=true
	var rig := flow.combat.get_node("TacticalCamera") as TacticalCamera
	var before := rig.distance
	var zoom := InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_WHEEL_UP
	zoom.pressed=true
	rig._unhandled_input(zoom)
	check(rig.distance<before,"Camera zoom remains responsive during incremental planning")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var position_before := rig.position
	rig._process(.02)
	key=key.duplicate() as InputEventKey
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(rig.position!=position_before,"Camera pan remains responsive during planning")
	await snapshot("enemy-planning")

func run() -> void:
	output_directory="res://../verification/tactics"
	await super.run()
	var max_total := 0.0
	var max_chunk := 0.0
	for data in rendered_decisions:
		max_total=maxf(max_total,data.compute_ms)
		max_chunk=maxf(max_chunk,data.max_chunk_ms)
	var file := FileAccess.open(prefix+"-decisions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":rendered_decisions.size(),"camera_checked":camera_checked,"max_compute_ms":max_total,"max_chunk_ms":max_chunk,"decisions":rendered_decisions},"\t"))
	file.close()
	print("Rendered tactical planning: ",rendered_decisions.size()," decisions, maximum total/chunk ms ",max_total,"/",max_chunk)
