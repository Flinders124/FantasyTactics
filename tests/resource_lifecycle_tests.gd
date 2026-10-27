extends SceneTree

var failures: int = 0
var checks: int = 0
var definitions: Array[WeakRef] = []
var ui_assets: Array[WeakRef] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ui_script := load("res://scripts/oath_ui.gd")
	var shared_theme: Theme = ui_script.theme()
	check(shared_theme == ui_script.theme(), "Screens share the session theme")
	ui_assets.append(weakref(shared_theme))
	for id in ["knight", "lantern", "settings"]:
		var symbol: Texture2D = ui_script.icon(id)
		check(symbol != null and symbol == ui_script.icon(id), "Screens share symbol " + id)
		ui_assets.append(weakref(symbol))
	shared_theme = null
	ui_script = null
	var all_ids := EnemyCatalog.ids()
	all_ids.append_array(["raider", "sentinel"])
	for id in all_ids:
		var definition := EnemyCatalog.find(id)
		check(definition != null, "Catalog loads " + id)
		definitions.append(weakref(definition))
		for repeat in range(20):
			check(EnemyCatalog.find(id) == definition, "Repeated catalog reads share " + id)
	# No caller retains these definitions between frames; the session cache does.
	await process_frame
	for reference in definitions:
		check(reference.get_ref() != null, "Session cache keeps shared definitions alive")
	for reference in ui_assets:
		check(reference.get_ref() != null, "Session cache keeps UI assets alive")
	root.tree_exited.connect(_check_shutdown)
	quit()

func _check_shutdown() -> void:
	for reference in definitions:
		check(reference.get_ref() == null, "Catalog releases definitions when its scene tree exits")
	for reference in ui_assets:
		check(reference.get_ref() == null, "UI releases assets when its scene tree exits")
	print("RESOURCE LIFECYCLE CHECKS: ", checks)
	print("RESOURCE LIFECYCLE RESULT: ", failures, " failures")
	quit(failures)


