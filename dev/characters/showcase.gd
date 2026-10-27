extends Node3D
## Development-only inspector. F6 this scene; the exported game excludes it.
const ART=preload("res://scripts/lantern_art.gd")
const IDS:PackedStringArray=["knight","ranger","mage","cleric","raider","sentinel","ashfang_raider","ashfang_shieldguard","ashfang_bowhunter","ashfang_shaman","ashfang_chieftain","hollow_gravebound","hollow_archer","hollow_adept","hollow_warden","hollow_castellan","verdant_thornblade","verdant_stalker","verdant_tender","verdant_sentinel","verdant_grovekeeper"]
const CLIPS:PackedStringArray=["Idle","Walk","Run","Attack","Cast","Hit","Death"]
var visuals:Array=[]
var camera:Camera3D
var selection:OptionButton
var group_choice:OptionButton
var clip_choice:OptionButton
var camera_yaw:float=0
var camera_pitch:float=.14
var zoom:float=3.1
var focus:Vector3=Vector3(0,1.05,0)
var clip:String="Idle"
var dragging:bool=false
var paused:bool=false
var elapsed:float=0
func _ready():
 get_viewport().msaa_3d=Viewport.MSAA_4X
 var env=WorldEnvironment.new();add_child(env);var sun=DirectionalLight3D.new();add_child(sun);ART.lighting(env,sun)
 var floor=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2(100,100);floor.mesh=mesh;floor.material_override=ART.paint(Color("334759"));add_child(floor)
 camera=Camera3D.new();add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
 var layer=CanvasLayer.new();add_child(layer);var bar=VBoxContainer.new();bar.position=Vector2(18,18);layer.add_child(bar)
 var title=Label.new();title.text="LANTERN OATH / CHARACTER INSPECTOR";title.add_theme_font_size_override("font_size",22);bar.add_child(title)
 var row=HBoxContainer.new();bar.add_child(row)
 selection=OptionButton.new();row.add_child(selection)
 for id in IDS:selection.add_item(id)
 selection.item_selected.connect(func(_i):group_choice.select(0);rebuild())
 group_choice=OptionButton.new();row.add_child(group_choice)
 for value in ["Solo","Heroes + legacy","Ashfang","Hollow","Verdant"]:group_choice.add_item(value)
 group_choice.item_selected.connect(func(_i):rebuild())
 clip_choice=OptionButton.new();row.add_child(clip_choice)
 for value in CLIPS:clip_choice.add_item(value)
 clip_choice.item_selected.connect(func(i):set_clip(CLIPS[i]))
 var pause_button=Button.new();pause_button.text="Pause / resume";row.add_child(pause_button);pause_button.pressed.connect(toggle_pause)
 var replay=Button.new();replay.text="Replay";row.add_child(replay);replay.pressed.connect(func():set_clip(clip))
 var views=HBoxContainer.new();bar.add_child(views)
 for i in 5:
  var button=Button.new();button.text=["Front","Side","Rear","Tactical","Equipment close-up"][i];views.add_child(button)
  button.pressed.connect(func():set_view(i))
 var help=Label.new();help.text="Drag right mouse to orbit · Wheel zoom · Select a roster group or inspect one character.\nAll animation is presentation only; this scene has no combat or collision rules.";bar.add_child(help)
 rebuild()
func rebuild():
 for v in visuals:v.free()
 visuals.clear()
 var group=group_choice.selected;var ids:Array=[]
 if group==0:ids=[IDS[selection.selected]]
 elif group==1:ids=Array(IDS.slice(0,6))
 else:ids=Array(IDS.slice(6+(group-2)*5,11+(group-2)*5))
 for i in ids.size():
  var v=CharacterVisual.new();add_child(v);v.load_role(ids[i]);v.position.x=(i-(ids.size()-1)*.5)*1.6;visuals.append(v)
  var label=Label3D.new();label.text=ids[i];label.font_size=24;label.pixel_size=.004;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=Vector3(0,-.13,0);v.add_child(label)
 zoom=3.1 if ids.size()==1 else 5.4;focus=Vector3(0,1.05,0);camera_yaw=0;camera_pitch=.14;set_clip(clip);update_camera()
func set_clip(value:String):
 clip=value;elapsed=0;paused=false
 for v in visuals:v.reset_pose();v.play_clip(clip,true)
func toggle_pause():
 paused=not paused
 for v in visuals:
  if paused:v.player.pause()
  else:v.player.play(v._clips[clip])
func set_view(index:int):
 camera_yaw=[0,PI*.5,PI,0,0][index];camera_pitch=.95 if index==3 else .14;zoom=1.05 if index==4 else (3.1 if visuals.size()==1 else 5.4);focus=Vector3(0,1.32,0) if index==4 else Vector3(0,1.05,0);update_camera()
func update_camera():
 camera.size=zoom;camera.position=focus+Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),-cos(camera_yaw)*cos(camera_pitch))*12;camera.look_at(focus)
func _unhandled_input(event):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:zoom=clampf(zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.7,8);update_camera()
 if event is InputEventMouseMotion and dragging:camera_yaw-=event.relative.x*.008;camera_pitch=clampf(camera_pitch+event.relative.y*.005,-.10,1.25);update_camera()
func _process(delta):
 if paused:return
 elapsed+=delta
 # One-shots hold their end pose; Replay makes repeated contacts inspectable.
