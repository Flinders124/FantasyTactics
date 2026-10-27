extends Node
## Development fixture: all damage/effects travel through real commands.
const CASES := [
	["Blade strike","knight","","legacy"],
	["Power Strike","knight","power_strike","ashfang"],
	["Bow shot","ranger","","hollow"],
	["Crippling Shot / Slowed","ranger","crippling_shot","verdant"],
	["Focus Bolt","mage","","ashfang"],
	["Fireburst (friendly fire)","mage","fireburst","hollow"],
	["Mend","cleric","mend","verdant"],
	["Warcry Burst","knight","elite_ashfang","ashfang"],
	["Grave Eruption","knight","elite_hollow","hollow"],
	["Thorn Eruption","knight","elite_verdant","verdant"],
	["Lethal strike / death","knight","","ashfang"],
	["Fireburst: simultaneous hits","mage","fireburst","verdant"]]
var flow: Node
var encounter: Node
var combat: CombatController
var actor: CombatUnit
var target: CombatUnit
var index: int = 0
var busy: bool = false
var armed: bool = false
var caption: Label
var choices: OptionButton

func _ready() -> void:
	flow=load("res://scenes/main.tscn").instantiate(); add_child(flow)
	flow._clear_screen(); flow.interface_layer.hide()
	var layer := CanvasLayer.new(); layer.layer=100; add_child(layer)
	var panel := PanelContainer.new(); panel.position=Vector2(12,104); layer.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color=Color(.045,.07,.10,.98); style.border_color=Color("e8c77e"); style.set_border_width_all(1); style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=6; style.content_margin_bottom=6
	panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new(); panel.add_child(box)
	caption=Label.new(); caption.text="COMBAT PRESENTATION LAB · real commands"; box.add_child(caption)
	var row := HBoxContainer.new(); box.add_child(row)
	choices=OptionButton.new()
	for entry in CASES: choices.add_item(entry[0])
	choices.item_selected.connect(prepare); row.add_child(choices)
	var replay := Button.new(); replay.text="Replay / resolve warning"; replay.pressed.connect(play_action); row.add_child(replay)
	var slow := CheckButton.new(); slow.text="¼ speed (inspection only)"; slow.toggled.connect(func(on: bool): Engine.time_scale=.25 if on else 1.0); row.add_child(slow)
	var normal := Button.new(); normal.text="Normal encounter"; normal.pressed.connect(normal_encounter); row.add_child(normal)
	prepare(0)

func prepare(choice: int) -> void:
	if busy: return
	busy=true; index=choice; armed=false
	choices.select(choice)
	if is_instance_valid(encounter):
		encounter.shutdown(); encounter.queue_free(); await get_tree().process_frame
	var entry: Array=CASES[index]
	var config := EncounterConfiguration.new()
	config.battlefield_seed=7; config.faction_id=entry[3]
	config.hero_ids=PackedStringArray([entry[1],"ranger" if entry[1]!="ranger" else "cleric"])
	config.elite_encounter=str(entry[2]).begins_with("elite_"); config.campaign_stage=4 if config.elite_encounter else 0
	config.resolve_roster()
	encounter=load("res://scenes/combat_encounter.tscn").instantiate()
	encounter.configuration=config; encounter.get_node("EnemyController").enabled=false; add_child(encounter)
	while encounter.preparing or not encounter.navigation_ready: await get_tree().process_frame
	if encounter.guide!=null: encounter.guide.close()
	encounter.get_node("PlayerController").set_process(false)
	combat=encounter.get_node("CombatController")
	var rig := encounter.get_node("TacticalCamera") as TacticalCamera
	rig.position=Vector3(0,.5,7); rig.distance=15; rig.pitch=-.85; rig.yaw=.18; rig._update_transform()
	flow.audio.apply_preferences(false)
	await stage()
	busy=false
	caption.text="%s · Replay uses real damage / cooldowns. RMB orbit, wheel zoom. F10 accessibility."%entry[0]

func stage() -> void:
	await combat.restart_encounter()
	actor=combat.find_unit("hero-01"); target=combat.find_unit("enemy-01")
	if str(CASES[index][2]).begins_with("elite_"):
		for unit in combat.units:
			if unit.definition.get("is_elite")==true: actor=unit; break
		target=combat.find_unit("hero-01")
	for unit in combat.units:
		unit.position=Vector3(-8+combat.units.find(unit)*3,0,-7)
	actor.position=Vector3(-3,0,7)
	target.position=Vector3(-1.6 if actor.role_label()=="Melee" and (index<7 or index==10) else 2,0,7)
	if index==6:
		target.position=Vector3(8,0,-7)
		target=combat.find_unit("hero-02"); target.position=Vector3(-.5,0,7); target.set_health(maxi(1,target.health-6))
	if index==10: target.set_health(actor.definition.basic_attack.damage)
	if index==11:
		var n := 0
		for unit in combat.units:
			if unit!=actor and unit!=target:
				unit.position=target.position+[Vector3(0,0,1.5),Vector3(1.3,0,.8),Vector3(1.6,0,-.5)][n%3]
				n+=1
	for turn in 20:
		if combat.scheduler.active_unit()==actor: break
		combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	await get_tree().physics_frame; await get_tree().physics_frame
	actor.character.face_point(target.position)
	target.character.face_point(actor.position)

func play_action() -> void:
	if busy or not is_instance_valid(combat): return
	busy=true
	if armed:
		for turn in 20:
			combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
			if not combat.pending_telegraphs.has(actor.stable_id): break
		armed=false; busy=false; return
	await stage()
	var ability: String=CASES[index][2]
	var command: CombatCommand
	if ability.is_empty(): command=AttackCommand.new(actor.stable_id,target.stable_id)
	elif ability=="fireburst" or ability.begins_with("elite_"): command=UseAbilityCommand.on_ground(actor.stable_id,ability,target.position)
	else: command=UseAbilityCommand.new(actor.stable_id,target.stable_id,ability)
	var accepted := combat.submit_command(command)
	caption.text=CASES[index][0]+(" · CONFIRMED" if accepted else " · REJECTED (see combat log)")
	armed=accepted and ability.begins_with("elite_")
	await get_tree().create_timer(.5).timeout
	busy=false

func normal_encounter() -> void:
	if busy: return
	Engine.time_scale=1
	if is_instance_valid(encounter): encounter.shutdown(); encounter.queue_free()
	flow.interface_layer.show(); flow.show_party()
	get_child(1).queue_free()

func _exit_tree() -> void:
	Engine.time_scale=1
