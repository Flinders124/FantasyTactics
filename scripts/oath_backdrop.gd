class_name OathBackdrop
extends Control
## Original vector scenery; static, resolution independent and input transparent.
var title_art: bool=false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),OathUI.INK)
	var w := size.x;var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(w*.52,0),Vector2(w,0),Vector2(w,h),Vector2(w*.72,h)]),Color("142a33"))
	for i in 8:
		var x := w*.56+i*w*.065
		draw_line(Vector2(x,0),Vector2(x-h*.3,h),Color(.32,.5,.53,.055),1)
	draw_line(Vector2(22,12),Vector2(w-22,12),OathUI.EDGE,1)
	draw_line(Vector2(22,h-12),Vector2(w-22,h-12),OathUI.EDGE,1)
	for at in [Vector2(16,12),Vector2(w-16,12),Vector2(16,h-12),Vector2(w-16,h-12)]:
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(4,0),at+Vector2(0,4),at+Vector2(-4,0)]),OathUI.GOLD)
	if not title_art: return
	var c := Vector2(w*.77,h*.43);var s := minf(w*.19,h*.31)
	for i in 3:
		var r := s*(1.05+i*.22)
		var poly := PackedVector2Array()
		for j in 7: poly.append(c+Vector2.from_angle(j*TAU/6-PI/2)*r)
		draw_polyline(poly,Color(.4,.65,.65,.12),1,true)
	var path := PackedVector2Array([Vector2(-.42,-.45),Vector2(0,-.78),Vector2(.42,-.45),Vector2(.31,.45),Vector2(0,.7),Vector2(-.31,.45)])
	for i in path.size(): path[i]=c+path[i]*s
	draw_colored_polygon(path,Color("294d55"));draw_polyline(path+PackedVector2Array([path[0]]),OathUI.GOLD,3,true)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-.39)*s,c+Vector2(.17,.1)*s,c+Vector2(0,.39)*s,c+Vector2(-.17,.1)*s]),OathUI.GOLD)
	draw_line(c+Vector2(-.41,-.43)*s,c+Vector2(.41,-.43)*s,OathUI.GOLD,3)
	draw_line(c+Vector2(-.3,.43)*s,c+Vector2(.3,.43)*s,OathUI.GOLD,3)
	for i in 7:
		var x := w*.5+i*w*.085;var y := h*.87-absf(3-i)*h*.023
		draw_colored_polygon(PackedVector2Array([Vector2(x,h),Vector2(x,y),Vector2(x+w*.025,y-h*.055),Vector2(x+w*.05,y),Vector2(x+w*.05,h)]),Color("0b1822"))
